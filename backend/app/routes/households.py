from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies.auth import get_authenticated_user
from app.schemas import (
    AuthenticatedUser,
    HouseholdCreateRequest,
    HouseholdCreateResponse,
    HouseholdMembershipListResponse,
)
from app.services.household_service import HouseholdService, get_household_service

router = APIRouter(prefix="/households", tags=["households"])


@router.post("", response_model=HouseholdCreateResponse, status_code=status.HTTP_201_CREATED)
def create_household(
    payload: HouseholdCreateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    household_service: HouseholdService = Depends(get_household_service),
) -> HouseholdCreateResponse:
    try:
        household, membership = household_service.create_household_for_user(user.id, payload.name)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return HouseholdCreateResponse(household=household, membership=membership)


@router.get("/memberships", response_model=HouseholdMembershipListResponse)
def list_household_memberships(
    user: AuthenticatedUser = Depends(get_authenticated_user),
    household_service: HouseholdService = Depends(get_household_service),
) -> HouseholdMembershipListResponse:
    try:
        memberships = household_service.list_memberships_for_user(user.id)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return HouseholdMembershipListResponse(memberships=memberships)
