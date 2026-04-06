from uuid import uuid4

from fastapi.testclient import TestClient

from app.dependencies.auth import get_authenticated_user
from app.main import app
from app.schemas import (
    AddInventoryFromBarcodeResponse,
    AuthenticatedUser,
    BarcodeLookupResponse,
    BarcodeMappingCreateResponse,
    InventoryItemResponse,
    InventoryUnit,
)
from app.services.barcode_service import get_barcode_service

HOUSEHOLD_ID = uuid4()
PRODUCT_ID = uuid4()
ITEM_ID = uuid4()


class StubBarcodeService:
    def lookup(self, user_id, household_id, barcode):
        if barcode == "012345":
            return BarcodeLookupResponse(
                barcode=barcode,
                found=True,
                product_id=PRODUCT_ID,
                product_name="Milk",
                mapping_source="manual",
                mapping_confidence=1,
                metadata={"seed": True},
            )
        return BarcodeLookupResponse(barcode=barcode, found=False)

    def create_mapping(self, user_id, household_id, payload):
        return BarcodeMappingCreateResponse(
            barcode=payload.barcode,
            product_id=PRODUCT_ID,
            product_name=payload.product_name or "Milk",
            source=payload.source,
            confidence=payload.confidence,
            metadata=payload.metadata,
        )

    def add_inventory_from_barcode(self, user_id, household_id, payload):
        return AddInventoryFromBarcodeResponse(
            barcode=payload.barcode,
            mapping_created=payload.product_name is not None,
            product_id=PRODUCT_ID,
            product_name=payload.product_name or "Milk",
            inventory_item=InventoryItemResponse(
                id=ITEM_ID,
                household_id=household_id,
                product_id=PRODUCT_ID,
                raw_name=payload.product_name or "Milk",
                quantity=payload.quantity,
                unit=InventoryUnit.count,
                location=None,
                low_stock_threshold=None,
                notes="Added by barcode scan",
                is_low_stock=False,
                created_at="2026-04-06T00:00:00+00:00",
                updated_at="2026-04-06T00:00:00+00:00",
            ),
        )


def override_user():
    return AuthenticatedUser(id=uuid4(), email="test@example.com")


def override_service():
    return StubBarcodeService()


app.dependency_overrides[get_authenticated_user] = override_user
app.dependency_overrides[get_barcode_service] = override_service
client = TestClient(app)


def test_lookup_and_create_mapping_contract():
    found_response = client.get(f"/api/v1/households/{HOUSEHOLD_ID}/barcode-mappings/012345")
    assert found_response.status_code == 200
    assert found_response.json()["found"] is True

    unknown_response = client.get(f"/api/v1/households/{HOUSEHOLD_ID}/barcode-mappings/999999")
    assert unknown_response.status_code == 200
    assert unknown_response.json()["found"] is False

    create_response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/barcode-mappings",
        json={"barcode": "999999", "product_name": "Custom Cocoa", "source": "manual", "confidence": 1},
    )
    assert create_response.status_code == 201
    assert create_response.json()["product_name"] == "Custom Cocoa"


def test_add_inventory_from_barcode_contract():
    known_response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/barcode-mappings/add-to-inventory",
        json={"barcode": "012345", "quantity": 2, "unit": "count"},
    )
    assert known_response.status_code == 200
    assert known_response.json()["mapping_created"] is False

    unknown_response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/barcode-mappings/add-to-inventory",
        json={"barcode": "999999", "product_name": "Cocoa", "quantity": 1, "unit": "count", "save_mapping": True},
    )
    assert unknown_response.status_code == 200
    assert unknown_response.json()["mapping_created"] is True
