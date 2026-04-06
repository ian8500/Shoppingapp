from uuid import uuid4

from fastapi.testclient import TestClient

from app.dependencies.auth import get_authenticated_user
from app.main import app
from app.schemas import AuthenticatedUser, HouseholdMembershipResponse, HouseholdResponse
from app.services.household_service import get_household_service


class StubHouseholdService:
    def create_household_for_user(self, user_id, household_name):
        household_id = uuid4()
        household = HouseholdResponse(
            id=household_id,
            name=household_name,
            created_by=user_id,
            created_at="2026-04-06T00:00:00+00:00",
        )
        membership = HouseholdMembershipResponse(
            id=uuid4(),
            household_id=household_id,
            household_name=household_name,
            user_id=user_id,
            role="owner",
            status="active",
            joined_at="2026-04-06T00:00:00+00:00",
        )
        return household, membership

    def list_memberships_for_user(self, user_id):
        return [
            HouseholdMembershipResponse(
                id=uuid4(),
                household_id=uuid4(),
                household_name="Main Home",
                user_id=user_id,
                role="owner",
                status="active",
                joined_at="2026-04-06T00:00:00+00:00",
            )
        ]


def override_user():
    return AuthenticatedUser(id=uuid4(), email="test@example.com")


def override_service():
    return StubHouseholdService()


app.dependency_overrides[get_authenticated_user] = override_user
app.dependency_overrides[get_household_service] = override_service
client = TestClient(app)


def test_create_household_returns_created_contract():
    response = client.post("/api/v1/households", json={"name": "My Household"})
    assert response.status_code == 201

    body = response.json()
    assert body["household"]["name"] == "My Household"
    assert body["membership"]["role"] == "owner"
    assert body["membership"]["status"] == "active"


def test_list_memberships_returns_list_contract():
    response = client.get("/api/v1/households/memberships")
    assert response.status_code == 200

    body = response.json()
    assert len(body["memberships"]) == 1
    assert body["memberships"][0]["household_name"] == "Main Home"
