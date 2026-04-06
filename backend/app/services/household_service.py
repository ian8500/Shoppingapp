from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from app.schemas.households import HouseholdMembershipResponse, HouseholdResponse
from app.services.supabase_client import get_supabase_service_client


@dataclass
class HouseholdService:
    """Business logic for household and membership operations."""

    def create_household_for_user(self, user_id: UUID, household_name: str) -> tuple[HouseholdResponse, HouseholdMembershipResponse]:
        client = get_supabase_service_client()
        if client is None:
            raise RuntimeError("Supabase service role is not configured")

        household_insert = client.table("households").insert(
            {
                "name": household_name.strip(),
                "created_by": str(user_id),
            }
        ).execute()

        if not household_insert.data:
            raise RuntimeError("Household creation failed")

        household_row = household_insert.data[0]

        membership_insert = client.table("household_members").insert(
            {
                "household_id": household_row["id"],
                "user_id": str(user_id),
                "role": "owner",
                "status": "active",
                "joined_at": datetime.now(timezone.utc).isoformat(),
            }
        ).execute()

        if not membership_insert.data:
            raise RuntimeError("Household membership creation failed")

        membership_row = membership_insert.data[0]

        household = HouseholdResponse.model_validate(household_row)
        membership = HouseholdMembershipResponse.model_validate(
            {
                **membership_row,
                "household_name": household.name,
            }
        )

        return household, membership

    def list_memberships_for_user(self, user_id: UUID) -> list[HouseholdMembershipResponse]:
        client = get_supabase_service_client()
        if client is None:
            raise RuntimeError("Supabase service role is not configured")

        memberships_query = (
            client.table("household_members")
            .select("id, household_id, user_id, role, status, joined_at, households(name)")
            .eq("user_id", str(user_id))
            .neq("status", "removed")
            .execute()
        )

        memberships: list[HouseholdMembershipResponse] = []
        for row in memberships_query.data or []:
            household_meta = row.get("households") or {}
            memberships.append(
                HouseholdMembershipResponse.model_validate(
                    {
                        "id": row["id"],
                        "household_id": row["household_id"],
                        "household_name": household_meta.get("name", "Unknown Household"),
                        "user_id": row["user_id"],
                        "role": row["role"],
                        "status": row["status"],
                        "joined_at": row.get("joined_at"),
                    }
                )
            )

        return memberships


def get_household_service() -> HouseholdService:
    return HouseholdService()
