from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class HouseholdCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class HouseholdResponse(BaseModel):
    id: UUID
    name: str
    created_by: UUID
    created_at: datetime


class HouseholdMembershipResponse(BaseModel):
    id: UUID
    household_id: UUID
    household_name: str
    user_id: UUID
    role: str
    status: str
    joined_at: datetime | None = None


class HouseholdCreateResponse(BaseModel):
    household: HouseholdResponse
    membership: HouseholdMembershipResponse


class HouseholdMembershipListResponse(BaseModel):
    memberships: list[HouseholdMembershipResponse]
