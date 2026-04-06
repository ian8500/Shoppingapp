from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from app.schemas import (
    AddInventoryFromBarcodeRequest,
    AddInventoryFromBarcodeResponse,
    BarcodeLookupResponse,
    BarcodeMappingCreateRequest,
    BarcodeMappingCreateResponse,
    BarcodeMappingSource,
    InventoryAdjustmentReason,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryUnit,
)
from app.services.inventory_service import InventoryService
from app.services.supabase_client import get_supabase_service_client


@dataclass
class BarcodeService:
    inventory_service: InventoryService

    def lookup(self, user_id: UUID, household_id: UUID, barcode: str) -> BarcodeLookupResponse:
        client = self._get_client_or_raise()
        self.inventory_service._assert_household_access(client, user_id=user_id, household_id=household_id)
        normalized_barcode = barcode.strip()

        household_mapping = self._find_mapping(client=client, barcode=normalized_barcode, household_id=household_id)
        global_mapping = None if household_mapping else self._find_mapping(client=client, barcode=normalized_barcode, household_id=None)
        mapping = household_mapping or global_mapping

        if mapping:
            return BarcodeLookupResponse(
                barcode=normalized_barcode,
                found=True,
                product_id=mapping["product_id"],
                product_name=mapping["products"]["canonical_name"],
                mapping_source=mapping["source"],
                mapping_confidence=mapping["confidence"],
                metadata=mapping.get("metadata") or {},
            )

        # Extension point for future external catalog lookup.
        external_hit = self._lookup_external_catalog(barcode=normalized_barcode)
        if external_hit:
            return external_hit

        return BarcodeLookupResponse(barcode=normalized_barcode, found=False)

    def create_mapping(
        self,
        user_id: UUID,
        household_id: UUID,
        payload: BarcodeMappingCreateRequest,
    ) -> BarcodeMappingCreateResponse:
        client = self._get_client_or_raise()
        self.inventory_service._assert_household_access(client, user_id=user_id, household_id=household_id)

        product_id = payload.product_id or self.inventory_service._resolve_or_create_product_id(
            client=client,
            household_id=household_id,
            raw_name=payload.product_name,
        )

        product_row = self._get_product(client=client, product_id=product_id)
        mapping_row = self._upsert_mapping(
            client=client,
            household_id=household_id,
            barcode=payload.barcode.strip(),
            product_id=product_id,
            source=payload.source,
            confidence=payload.confidence,
            metadata=payload.metadata,
            user_id=user_id,
        )

        return BarcodeMappingCreateResponse(
            barcode=mapping_row["barcode"],
            product_id=mapping_row["product_id"],
            product_name=product_row["canonical_name"],
            source=mapping_row["source"],
            confidence=mapping_row["confidence"],
            metadata=mapping_row.get("metadata") or {},
        )

    def add_inventory_from_barcode(
        self,
        user_id: UUID,
        household_id: UUID,
        payload: AddInventoryFromBarcodeRequest,
    ) -> AddInventoryFromBarcodeResponse:
        client = self._get_client_or_raise()
        self.inventory_service._assert_household_access(client, user_id=user_id, household_id=household_id)

        lookup = self.lookup(user_id=user_id, household_id=household_id, barcode=payload.barcode)
        mapping_created = False

        if lookup.found and lookup.product_id:
            product_id = lookup.product_id
            product_name = lookup.product_name or "Unnamed item"
        else:
            if not payload.product_name:
                raise ValueError("product_name is required when barcode is unknown")
            product_id = self.inventory_service._resolve_or_create_product_id(
                client=client,
                household_id=household_id,
                raw_name=payload.product_name,
            )
            product = self._get_product(client=client, product_id=product_id)
            product_name = product["canonical_name"]

            if payload.save_mapping:
                self._upsert_mapping(
                    client=client,
                    household_id=household_id,
                    barcode=payload.barcode.strip(),
                    product_id=product_id,
                    source=payload.source,
                    confidence=payload.confidence,
                    metadata=payload.metadata,
                    user_id=user_id,
                )
                mapping_created = True

        inventory_item = self._add_or_increment_inventory(
            client=client,
            user_id=user_id,
            household_id=household_id,
            product_id=product_id,
            product_name=product_name,
            quantity=payload.quantity,
            unit=payload.unit,
            location=payload.location,
        )

        return AddInventoryFromBarcodeResponse(
            barcode=payload.barcode.strip(),
            mapping_created=mapping_created,
            product_id=product_id,
            product_name=product_name,
            inventory_item=inventory_item,
        )

    def _add_or_increment_inventory(
        self,
        client,
        user_id: UUID,
        household_id: UUID,
        product_id: UUID,
        product_name: str,
        quantity: Decimal,
        unit: InventoryUnit,
        location: str | None,
    ) -> InventoryItemResponse:
        query = (
            client.table("inventory_items")
            .select("id")
            .eq("household_id", str(household_id))
            .eq("product_id", str(product_id))
            .eq("unit", unit.value)
        )
        query = query.is_("location", "null") if location is None else query.eq("location", location)
        existing = query.limit(1).execute()

        if existing.data:
            return self.inventory_service.increment_quantity(
                user_id=user_id,
                household_id=household_id,
                item_id=UUID(existing.data[0]["id"]),
                payload=InventoryQuantityDeltaRequest(
                    amount=quantity,
                    reason=InventoryAdjustmentReason.purchase,
                    note=f"Barcode scan: {product_name}",
                ),
            )

        return self.inventory_service.create_item(
            user_id=user_id,
            household_id=household_id,
            payload=InventoryItemCreateRequest(
                product_id=product_id,
                raw_name=None,
                quantity=quantity,
                unit=unit,
                location=location,
                low_stock_threshold=None,
                notes="Added by barcode scan",
            ),
        )

    def _find_mapping(self, client, barcode: str, household_id: UUID | None) -> dict | None:
        query = (
            client.table("barcode_mappings")
            .select("barcode, product_id, source, confidence, metadata, products!inner(canonical_name)")
            .eq("barcode", barcode)
        )
        if household_id:
            query = query.eq("household_id", str(household_id))
        else:
            query = query.is_("household_id", "null")

        result = query.order("updated_at", desc=True).limit(1).execute()
        if not result.data:
            return None
        return result.data[0]

    def _upsert_mapping(
        self,
        client,
        household_id: UUID,
        barcode: str,
        product_id: UUID,
        source: BarcodeMappingSource,
        confidence: Decimal,
        metadata: dict,
        user_id: UUID,
    ) -> dict:
        existing = self._find_mapping(client=client, barcode=barcode, household_id=household_id)
        payload = {
            "barcode": barcode,
            "product_id": str(product_id),
            "household_id": str(household_id),
            "source": source.value,
            "confidence": float(confidence),
            "metadata": metadata,
            "created_by": str(user_id),
        }

        if existing:
            updated = (
                client.table("barcode_mappings")
                .update(payload)
                .eq("barcode", barcode)
                .eq("household_id", str(household_id))
                .execute()
            )
            if not updated.data:
                raise RuntimeError("Barcode mapping update failed")
            return updated.data[0]

        created = client.table("barcode_mappings").insert(payload).execute()
        if not created.data:
            raise RuntimeError("Barcode mapping creation failed")
        return created.data[0]

    def _get_product(self, client, product_id: UUID) -> dict:
        product = client.table("products").select("id, canonical_name").eq("id", str(product_id)).limit(1).execute()
        if not product.data:
            raise LookupError("Product not found")
        return product.data[0]

    @staticmethod
    def _lookup_external_catalog(barcode: str) -> BarcodeLookupResponse | None:
        return None

    @staticmethod
    def _get_client_or_raise():
        client = get_supabase_service_client()
        if client is None:
            raise RuntimeError("Supabase service role is not configured")
        return client


def get_barcode_service() -> BarcodeService:
    return BarcodeService(inventory_service=InventoryService())
