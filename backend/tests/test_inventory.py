from uuid import uuid4

from fastapi.testclient import TestClient

from app.dependencies.auth import get_authenticated_user
from app.main import app
from app.schemas import AuthenticatedUser, InventoryItemResponse, InventoryTransactionResponse, InventoryUnit
from app.services.inventory_service import get_inventory_service

HOUSEHOLD_ID = uuid4()
ITEM_ID = uuid4()
PRODUCT_ID = uuid4()


class StubInventoryService:
    def list_items_for_household(self, user_id, household_id):
        return [
            InventoryItemResponse(
                id=ITEM_ID,
                household_id=household_id,
                product_id=PRODUCT_ID,
                raw_name="Eggs",
                quantity=6,
                unit=InventoryUnit.count,
                location="fridge",
                low_stock_threshold=3,
                notes=None,
                is_low_stock=False,
                created_at="2026-04-06T00:00:00+00:00",
                updated_at="2026-04-06T00:00:00+00:00",
            )
        ]

    def list_transactions_for_household(self, user_id, household_id):
        return [
            InventoryTransactionResponse(
                id=uuid4(),
                household_id=household_id,
                inventory_item_id=ITEM_ID,
                product_id=PRODUCT_ID,
                quantity_delta=-3,
                unit=InventoryUnit.count,
                reason="consume",
                note="Used in omelette",
                actor_user_id=user_id,
                occurred_at="2026-04-06T00:00:00+00:00",
                created_at="2026-04-06T00:00:00+00:00",
            )
        ]

    def create_item(self, user_id, household_id, payload):
        return InventoryItemResponse(
            id=ITEM_ID,
            household_id=household_id,
            product_id=PRODUCT_ID,
            raw_name=payload.raw_name or "Eggs",
            quantity=payload.quantity,
            unit=payload.unit,
            location=payload.location,
            low_stock_threshold=payload.low_stock_threshold,
            notes=payload.notes,
            is_low_stock=False,
            created_at="2026-04-06T00:00:00+00:00",
            updated_at="2026-04-06T00:00:00+00:00",
        )

    def patch_item(self, user_id, household_id, item_id, payload):
        return self.create_item(
            user_id,
            household_id,
            type("Payload", (), {"raw_name": "Eggs", "quantity": 3, "unit": InventoryUnit.count, "location": payload.location, "low_stock_threshold": payload.low_stock_threshold, "notes": payload.notes})(),
        )

    def set_quantity(self, user_id, household_id, item_id, payload):
        return InventoryItemResponse(
            id=item_id,
            household_id=household_id,
            product_id=PRODUCT_ID,
            raw_name="Eggs",
            quantity=payload.quantity,
            unit=InventoryUnit.count,
            location="fridge",
            low_stock_threshold=3,
            notes=None,
            is_low_stock=float(payload.quantity) <= 3,
            created_at="2026-04-06T00:00:00+00:00",
            updated_at="2026-04-06T00:00:00+00:00",
        )

    def increment_quantity(self, user_id, household_id, item_id, payload):
        return self.set_quantity(user_id, household_id, item_id, type("Payload", (), {"quantity": 7})())

    def decrement_quantity(self, user_id, household_id, item_id, payload):
        return self.set_quantity(user_id, household_id, item_id, type("Payload", (), {"quantity": 3})())

    def mark_finished(self, user_id, household_id, item_id):
        return self.set_quantity(user_id, household_id, item_id, type("Payload", (), {"quantity": 0})())



def override_user():
    return AuthenticatedUser(id=uuid4(), email="test@example.com")


def override_service():
    return StubInventoryService()


app.dependency_overrides[get_authenticated_user] = override_user
app.dependency_overrides[get_inventory_service] = override_service
client = TestClient(app)


def test_inventory_item_flow_contract():
    create_response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/inventory",
        json={"raw_name": "Eggs", "quantity": 6, "unit": "count", "location": "fridge", "low_stock_threshold": 3},
    )
    assert create_response.status_code == 201
    assert create_response.json()["quantity"] == "6"

    decrement_response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/inventory/{ITEM_ID}/decrement",
        json={"amount": 3, "reason": "consume", "note": "Breakfast"},
    )
    assert decrement_response.status_code == 200
    assert decrement_response.json()["quantity"] == "3"
    assert decrement_response.json()["is_low_stock"] is True


def test_inventory_transactions_contract():
    tx_response = client.get(f"/api/v1/households/{HOUSEHOLD_ID}/inventory/transactions")
    assert tx_response.status_code == 200
    body = tx_response.json()
    assert len(body["transactions"]) == 1
    assert body["transactions"][0]["quantity_delta"] == "-3"
