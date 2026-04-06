from uuid import uuid4

from fastapi.testclient import TestClient

from app.dependencies.auth import get_authenticated_user
from app.main import app
from app.schemas import AuthenticatedUser, ShoppingItemStatus, ShoppingListItemResponse
from app.services.shopping_list_service import get_shopping_list_service

HOUSEHOLD_ID = uuid4()
ITEM_ID = uuid4()


class StubShoppingListService:
    def list_items_for_household(self, user_id, household_id):
        if str(household_id) != str(HOUSEHOLD_ID):
            raise PermissionError("forbidden")
        return [
            ShoppingListItemResponse(
                id=ITEM_ID,
                household_id=household_id,
                product_id=None,
                raw_name="Milk",
                quantity=1,
                unit="gallon",
                category="Dairy",
                notes=None,
                status=ShoppingItemStatus.active,
                added_by=user_id,
                bought_by=None,
                created_at="2026-04-06T00:00:00+00:00",
                updated_at="2026-04-06T00:00:00+00:00",
            )
        ]

    def create_item(self, user_id, household_id, payload):
        return ShoppingListItemResponse(
            id=ITEM_ID,
            household_id=household_id,
            product_id=payload.product_id,
            raw_name=payload.raw_name,
            quantity=payload.quantity,
            unit=payload.unit,
            category=payload.category,
            notes=payload.notes,
            status=ShoppingItemStatus.active,
            added_by=user_id,
            bought_by=None,
            created_at="2026-04-06T00:00:00+00:00",
            updated_at="2026-04-06T00:00:00+00:00",
        )

    def update_item(self, user_id, household_id, item_id, payload):
        return ShoppingListItemResponse(
            id=item_id,
            household_id=household_id,
            product_id=payload.product_id,
            raw_name=payload.raw_name or "Milk",
            quantity=payload.quantity,
            unit=payload.unit,
            category=payload.category,
            notes=payload.notes,
            status=payload.status or ShoppingItemStatus.active,
            added_by=user_id,
            bought_by=user_id if payload.status == ShoppingItemStatus.bought else None,
            created_at="2026-04-06T00:00:00+00:00",
            updated_at="2026-04-06T00:00:00+00:00",
        )

    def set_bought(self, user_id, household_id, item_id):
        return self.update_item(
            user_id=user_id,
            household_id=household_id,
            item_id=item_id,
            payload=type("Payload", (), {"product_id": None, "raw_name": "Milk", "quantity": 1, "unit": "gallon", "category": "Dairy", "notes": None, "status": ShoppingItemStatus.bought})(),
        )

    def archive_item(self, user_id, household_id, item_id):
        return None



def override_user():
    return AuthenticatedUser(id=uuid4(), email="test@example.com")


def override_service():
    return StubShoppingListService()


app.dependency_overrides[get_authenticated_user] = override_user
app.dependency_overrides[get_shopping_list_service] = override_service
client = TestClient(app)


def test_list_shopping_items_contract():
    response = client.get(f"/api/v1/households/{HOUSEHOLD_ID}/shopping-items")
    assert response.status_code == 200

    body = response.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["raw_name"] == "Milk"
    assert body["items"][0]["status"] == "active"


def test_add_shopping_item_contract():
    response = client.post(
        f"/api/v1/households/{HOUSEHOLD_ID}/shopping-items",
        json={
            "raw_name": "Eggs",
            "quantity": 12,
            "unit": "count",
            "category": "Dairy",
            "notes": "Large",
        },
    )
    assert response.status_code == 201

    body = response.json()
    assert body["raw_name"] == "Eggs"
    assert body["status"] == "active"


def test_mark_bought_contract():
    response = client.post(f"/api/v1/households/{HOUSEHOLD_ID}/shopping-items/{ITEM_ID}/mark-bought")
    assert response.status_code == 200
    assert response.json()["status"] == "bought"


def test_archive_shopping_item_contract():
    response = client.delete(f"/api/v1/households/{HOUSEHOLD_ID}/shopping-items/{ITEM_ID}")
    assert response.status_code == 204
