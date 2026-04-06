from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies.auth import get_authenticated_user
from app.schemas import (
    AuthenticatedUser,
    InventoryItemCreateRequest,
    InventoryItemPatchRequest,
    InventoryItemResponse,
    InventoryListResponse,
    InventoryQuantityDeltaRequest,
    InventoryQuantityUpdateRequest,
    InventoryTransactionListResponse,
)
from app.services.inventory_service import InventoryService, get_inventory_service

router = APIRouter(prefix="/households/{household_id}/inventory", tags=["inventory"])


@router.get("", response_model=InventoryListResponse)
def list_inventory_items(
    household_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryListResponse:
    try:
        items = inventory_service.list_items_for_household(user_id=user.id, household_id=household_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return InventoryListResponse(items=items)


@router.get("/transactions", response_model=InventoryTransactionListResponse)
def list_inventory_transactions(
    household_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryTransactionListResponse:
    try:
        txs = inventory_service.list_transactions_for_household(user_id=user.id, household_id=household_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return InventoryTransactionListResponse(transactions=txs)


@router.post("", response_model=InventoryItemResponse, status_code=status.HTTP_201_CREATED)
def create_inventory_item(
    household_id: UUID,
    payload: InventoryItemCreateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.create_item(user_id=user.id, household_id=household_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.patch("/{item_id}", response_model=InventoryItemResponse)
def patch_inventory_item(
    household_id: UUID,
    item_id: UUID,
    payload: InventoryItemPatchRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.patch_item(user_id=user.id, household_id=household_id, item_id=item_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/{item_id}/set-quantity", response_model=InventoryItemResponse)
def set_inventory_quantity(
    household_id: UUID,
    item_id: UUID,
    payload: InventoryQuantityUpdateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.set_quantity(user_id=user.id, household_id=household_id, item_id=item_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/{item_id}/increment", response_model=InventoryItemResponse)
def increment_inventory_quantity(
    household_id: UUID,
    item_id: UUID,
    payload: InventoryQuantityDeltaRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.increment_quantity(user_id=user.id, household_id=household_id, item_id=item_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/{item_id}/decrement", response_model=InventoryItemResponse)
def decrement_inventory_quantity(
    household_id: UUID,
    item_id: UUID,
    payload: InventoryQuantityDeltaRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.decrement_quantity(user_id=user.id, household_id=household_id, item_id=item_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/{item_id}/mark-finished", response_model=InventoryItemResponse)
def mark_inventory_finished(
    household_id: UUID,
    item_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    inventory_service: InventoryService = Depends(get_inventory_service),
) -> InventoryItemResponse:
    try:
        return inventory_service.mark_finished(user_id=user.id, household_id=household_id, item_id=item_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
