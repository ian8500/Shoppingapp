from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from app.schemas.inventory import (
    InventoryAdjustmentReason,
    InventoryItemCreateRequest,
    InventoryItemPatchRequest,
    InventoryItemResponse,
    InventoryQuantityDeltaRequest,
    InventoryQuantityUpdateRequest,
    InventoryTransactionResponse,
)
from app.services.supabase_client import get_supabase_service_client


@dataclass
class InventoryService:
    def list_items_for_household(self, user_id: UUID, household_id: UUID) -> list[InventoryItemResponse]:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)

        rows = (
            client.table("inventory_items")
            .select(
                "id, household_id, product_id, quantity, unit, location, low_stock_threshold, notes, "
                "created_at, updated_at, products!inner(canonical_name)"
            )
            .eq("household_id", str(household_id))
            .order("updated_at", desc=True)
            .execute()
        )

        return [self._row_to_item(row) for row in (rows.data or [])]

    def list_transactions_for_household(self, user_id: UUID, household_id: UUID) -> list[InventoryTransactionResponse]:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)

        rows = (
            client.table("inventory_transactions")
            .select(
                "id, household_id, inventory_item_id, product_id, quantity_delta, unit, reason, "
                "note, actor_user_id, occurred_at, created_at"
            )
            .eq("household_id", str(household_id))
            .order("occurred_at", desc=True)
            .execute()
        )

        return [InventoryTransactionResponse.model_validate(row) for row in (rows.data or [])]

    def create_item(self, user_id: UUID, household_id: UUID, payload: InventoryItemCreateRequest) -> InventoryItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)

        product_id = payload.product_id or self._resolve_or_create_product_id(
            client=client, household_id=household_id, raw_name=payload.raw_name
        )

        created = (
            client.table("inventory_items")
            .insert(
                {
                    "household_id": str(household_id),
                    "product_id": str(product_id),
                    "quantity": float(payload.quantity),
                    "unit": payload.unit.value,
                    "location": payload.location.value if payload.location else None,
                    "low_stock_threshold": float(payload.low_stock_threshold) if payload.low_stock_threshold is not None else None,
                    "notes": payload.notes,
                }
            )
            .execute()
        )
        if not created.data:
            raise RuntimeError("Inventory item creation failed")

        created_row = created.data[0]
        self._insert_transaction(
            client=client,
            household_id=household_id,
            item_id=UUID(created_row["id"]),
            product_id=product_id,
            unit=payload.unit.value,
            delta=payload.quantity,
            reason=InventoryAdjustmentReason.purchase,
            user_id=user_id,
            note="Initial stock",
        )

        item_row = self._get_inventory_row(client=client, household_id=household_id, item_id=UUID(created_row["id"]))
        return self._row_to_item(item_row)

    def patch_item(
        self,
        user_id: UUID,
        household_id: UUID,
        item_id: UUID,
        payload: InventoryItemPatchRequest,
    ) -> InventoryItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)
        self._get_inventory_row(client=client, household_id=household_id, item_id=item_id)

        updates: dict[str, object | None] = {
            "location": payload.location.value if payload.location else None,
            "low_stock_threshold": float(payload.low_stock_threshold) if payload.low_stock_threshold is not None else None,
            "notes": payload.notes,
        }

        result = (
            client.table("inventory_items")
            .update(updates)
            .eq("id", str(item_id))
            .eq("household_id", str(household_id))
            .execute()
        )

        if not result.data:
            raise RuntimeError("Inventory item update failed")

        return self._row_to_item(self._get_inventory_row(client=client, household_id=household_id, item_id=item_id))

    def set_quantity(
        self,
        user_id: UUID,
        household_id: UUID,
        item_id: UUID,
        payload: InventoryQuantityUpdateRequest,
    ) -> InventoryItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)
        existing = self._get_inventory_row(client=client, household_id=household_id, item_id=item_id)

        previous = Decimal(str(existing["quantity"]))
        delta = payload.quantity - previous
        if delta == 0:
            return self._row_to_item(existing)

        self._update_quantity(client=client, household_id=household_id, item_id=item_id, quantity=payload.quantity)

        self._insert_transaction(
            client=client,
            household_id=household_id,
            item_id=item_id,
            product_id=UUID(existing["product_id"]),
            unit=existing["unit"],
            delta=delta,
            reason=payload.reason,
            user_id=user_id,
            note=payload.note,
        )

        return self._row_to_item(self._get_inventory_row(client=client, household_id=household_id, item_id=item_id))

    def increment_quantity(
        self, user_id: UUID, household_id: UUID, item_id: UUID, payload: InventoryQuantityDeltaRequest
    ) -> InventoryItemResponse:
        return self._apply_delta(user_id, household_id, item_id, payload, multiplier=Decimal("1"))

    def decrement_quantity(
        self, user_id: UUID, household_id: UUID, item_id: UUID, payload: InventoryQuantityDeltaRequest
    ) -> InventoryItemResponse:
        return self._apply_delta(user_id, household_id, item_id, payload, multiplier=Decimal("-1"))

    def mark_finished(self, user_id: UUID, household_id: UUID, item_id: UUID) -> InventoryItemResponse:
        return self.set_quantity(
            user_id=user_id,
            household_id=household_id,
            item_id=item_id,
            payload=InventoryQuantityUpdateRequest(
                quantity=Decimal("0"),
                reason=InventoryAdjustmentReason.consume,
                note="Marked finished",
            ),
        )

    def _apply_delta(
        self,
        user_id: UUID,
        household_id: UUID,
        item_id: UUID,
        payload: InventoryQuantityDeltaRequest,
        multiplier: Decimal,
    ) -> InventoryItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client, user_id=user_id, household_id=household_id)
        existing = self._get_inventory_row(client=client, household_id=household_id, item_id=item_id)

        current = Decimal(str(existing["quantity"]))
        applied_delta = payload.amount * multiplier
        next_quantity = current + applied_delta
        if next_quantity < 0:
            raise ValueError("Quantity cannot be negative")

        self._update_quantity(client=client, household_id=household_id, item_id=item_id, quantity=next_quantity)

        self._insert_transaction(
            client=client,
            household_id=household_id,
            item_id=item_id,
            product_id=UUID(existing["product_id"]),
            unit=existing["unit"],
            delta=applied_delta,
            reason=payload.reason,
            user_id=user_id,
            note=payload.note,
        )

        return self._row_to_item(self._get_inventory_row(client=client, household_id=household_id, item_id=item_id))

    def _update_quantity(self, client, household_id: UUID, item_id: UUID, quantity: Decimal) -> None:
        updated = (
            client.table("inventory_items")
            .update({"quantity": float(quantity)})
            .eq("id", str(item_id))
            .eq("household_id", str(household_id))
            .execute()
        )

        if not updated.data:
            raise RuntimeError("Inventory quantity update failed")

    def _insert_transaction(
        self,
        client,
        household_id: UUID,
        item_id: UUID,
        product_id: UUID,
        unit: str,
        delta: Decimal,
        reason: InventoryAdjustmentReason,
        user_id: UUID,
        note: str | None,
    ) -> None:
        client.table("inventory_transactions").insert(
            {
                "household_id": str(household_id),
                "inventory_item_id": str(item_id),
                "product_id": str(product_id),
                "quantity_delta": float(delta),
                "unit": unit,
                "reason": reason.value,
                "note": note,
                "actor_user_id": str(user_id),
            }
        ).execute()

    def _resolve_or_create_product_id(self, client, household_id: UUID, raw_name: str | None) -> UUID:
        if not raw_name:
            raise ValueError("Either product_id or raw_name is required")

        normalized = raw_name.strip().lower()
        existing = (
            client.table("products")
            .select("id")
            .eq("owning_household_id", str(household_id))
            .eq("canonical_name_normalized", normalized)
            .limit(1)
            .execute()
        )
        if existing.data:
            return UUID(existing.data[0]["id"])

        created = (
            client.table("products")
            .insert(
                {
                    "canonical_name": raw_name.strip(),
                    "canonical_name_normalized": normalized,
                    "owning_household_id": str(household_id),
                }
            )
            .execute()
        )

        if not created.data:
            raise RuntimeError("Product creation failed")

        return UUID(created.data[0]["id"])

    def _assert_household_access(self, client, user_id: UUID, household_id: UUID) -> None:
        membership = (
            client.table("household_members")
            .select("id")
            .eq("household_id", str(household_id))
            .eq("user_id", str(user_id))
            .eq("status", "active")
            .limit(1)
            .execute()
        )
        if not membership.data:
            raise PermissionError("User is not an active member of this household")

    def _get_inventory_row(self, client, household_id: UUID, item_id: UUID) -> dict:
        row = (
            client.table("inventory_items")
            .select(
                "id, household_id, product_id, quantity, unit, location, low_stock_threshold, notes, created_at, updated_at, "
                "products!inner(canonical_name)"
            )
            .eq("id", str(item_id))
            .eq("household_id", str(household_id))
            .limit(1)
            .execute()
        )

        if not row.data:
            raise LookupError("Inventory item not found")

        return row.data[0]

    @staticmethod
    def _row_to_item(row: dict) -> InventoryItemResponse:
        quantity = Decimal(str(row["quantity"]))
        threshold_raw = row.get("low_stock_threshold")
        threshold = Decimal(str(threshold_raw)) if threshold_raw is not None else None
        return InventoryItemResponse.model_validate(
            {
                "id": row["id"],
                "household_id": row["household_id"],
                "product_id": row["product_id"],
                "raw_name": row.get("products", {}).get("canonical_name", "Unnamed item"),
                "quantity": row["quantity"],
                "unit": row["unit"],
                "location": row.get("location"),
                "low_stock_threshold": row.get("low_stock_threshold"),
                "notes": row.get("notes"),
                "is_low_stock": bool(threshold is not None and quantity <= threshold),
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
            }
        )

    @staticmethod
    def _get_client_or_raise():
        client = get_supabase_service_client()
        if client is None:
            raise RuntimeError("Supabase service role is not configured")
        return client


def get_inventory_service() -> InventoryService:
    return InventoryService()
