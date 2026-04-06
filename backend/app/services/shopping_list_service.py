from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from app.schemas.shopping_list import (
    ShoppingItemStatus,
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
)
from app.services.supabase_client import get_supabase_service_client

_DB_STATUS_FROM_API = {
    ShoppingItemStatus.active: "pending",
    ShoppingItemStatus.bought: "purchased",
    ShoppingItemStatus.archived: "archived",
}

_API_STATUS_FROM_DB = {
    "pending": ShoppingItemStatus.active,
    "in_progress": ShoppingItemStatus.active,
    "purchased": ShoppingItemStatus.bought,
    "archived": ShoppingItemStatus.archived,
}


@dataclass
class ShoppingListService:
    """Business logic for household-scoped shopping list operations."""

    def list_items_for_household(self, user_id: UUID, household_id: UUID) -> list[ShoppingListItemResponse]:
        client = self._get_client_or_raise()
        self._assert_household_access(client=client, user_id=user_id, household_id=household_id)

        query = (
            client.table("shopping_list_items")
            .select(
                "id, household_id, product_id, item_name, quantity, unit, category, notes, "
                "status, added_by, bought_by, created_at, updated_at"
            )
            .eq("household_id", str(household_id))
            .order("status")
            .order("created_at", desc=True)
            .execute()
        )

        return [self._row_to_item(row) for row in (query.data or [])]

    def create_item(
        self,
        user_id: UUID,
        household_id: UUID,
        payload: ShoppingListItemCreateRequest,
    ) -> ShoppingListItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client=client, user_id=user_id, household_id=household_id)

        insert_result = (
            client.table("shopping_list_items")
            .insert(
                {
                    "household_id": str(household_id),
                    "product_id": str(payload.product_id) if payload.product_id else None,
                    "item_name": payload.raw_name.strip(),
                    "quantity": float(payload.quantity) if payload.quantity is not None else None,
                    "unit": payload.unit.strip() if payload.unit else None,
                    "category": payload.category.strip() if payload.category else None,
                    "notes": payload.notes.strip() if payload.notes else None,
                    "status": _DB_STATUS_FROM_API[ShoppingItemStatus.active],
                    "added_by": str(user_id),
                }
            )
            .execute()
        )

        if not insert_result.data:
            raise RuntimeError("Shopping list item creation failed")

        return self._row_to_item(insert_result.data[0])

    def update_item(
        self,
        user_id: UUID,
        household_id: UUID,
        item_id: UUID,
        payload: ShoppingListItemUpdateRequest,
    ) -> ShoppingListItemResponse:
        client = self._get_client_or_raise()
        self._assert_household_access(client=client, user_id=user_id, household_id=household_id)

        existing = self._get_item_row(client=client, household_id=household_id, item_id=item_id)

        updates: dict[str, object | None] = {}
        if payload.product_id is not None:
            updates["product_id"] = str(payload.product_id)
        if payload.raw_name is not None:
            updates["item_name"] = payload.raw_name.strip()
        if payload.quantity is not None:
            updates["quantity"] = float(payload.quantity)
        if payload.unit is not None:
            updates["unit"] = payload.unit.strip()
        if payload.category is not None:
            updates["category"] = payload.category.strip()
        if payload.notes is not None:
            updates["notes"] = payload.notes.strip()
        if payload.status is not None:
            updates["status"] = _DB_STATUS_FROM_API[payload.status]
            if payload.status == ShoppingItemStatus.bought:
                updates["bought_by"] = str(user_id)
                updates["bought_at"] = datetime.now(timezone.utc).isoformat()
            elif payload.status != ShoppingItemStatus.bought:
                updates["bought_by"] = None
                updates["bought_at"] = None

        if not updates:
            return self._row_to_item(existing)

        result = (
            client.table("shopping_list_items")
            .update(updates)
            .eq("id", str(item_id))
            .eq("household_id", str(household_id))
            .execute()
        )

        if not result.data:
            raise RuntimeError("Shopping list item update failed")

        return self._row_to_item(result.data[0])

    def set_bought(
        self,
        user_id: UUID,
        household_id: UUID,
        item_id: UUID,
    ) -> ShoppingListItemResponse:
        return self.update_item(
            user_id=user_id,
            household_id=household_id,
            item_id=item_id,
            payload=ShoppingListItemUpdateRequest(status=ShoppingItemStatus.bought),
        )

    def archive_item(self, user_id: UUID, household_id: UUID, item_id: UUID) -> None:
        client = self._get_client_or_raise()
        self._assert_household_access(client=client, user_id=user_id, household_id=household_id)
        self._get_item_row(client=client, household_id=household_id, item_id=item_id)

        client.table("shopping_list_items").update({"status": _DB_STATUS_FROM_API[ShoppingItemStatus.archived]}).eq(
            "id", str(item_id)
        ).eq("household_id", str(household_id)).execute()

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

    def _get_item_row(self, client, household_id: UUID, item_id: UUID) -> dict:
        response = (
            client.table("shopping_list_items")
            .select(
                "id, household_id, product_id, item_name, quantity, unit, category, notes, "
                "status, added_by, bought_by, created_at, updated_at"
            )
            .eq("id", str(item_id))
            .eq("household_id", str(household_id))
            .limit(1)
            .execute()
        )

        if not response.data:
            raise LookupError("Shopping list item not found")

        return response.data[0]

    @staticmethod
    def _get_client_or_raise():
        client = get_supabase_service_client()
        if client is None:
            raise RuntimeError("Supabase service role is not configured")
        return client

    @staticmethod
    def _row_to_item(row: dict) -> ShoppingListItemResponse:
        return ShoppingListItemResponse.model_validate(
            {
                "id": row["id"],
                "household_id": row["household_id"],
                "product_id": row.get("product_id"),
                "raw_name": row.get("item_name") or "Unnamed item",
                "quantity": row.get("quantity"),
                "unit": row.get("unit"),
                "category": row.get("category"),
                "notes": row.get("notes"),
                "status": _API_STATUS_FROM_DB.get(row.get("status"), ShoppingItemStatus.active),
                "added_by": row.get("added_by"),
                "bought_by": row.get("bought_by"),
                "created_at": row.get("created_at"),
                "updated_at": row.get("updated_at"),
            }
        )


def get_shopping_list_service() -> ShoppingListService:
    return ShoppingListService()
