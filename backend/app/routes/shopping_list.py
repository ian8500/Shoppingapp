from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies.auth import get_authenticated_user
from app.schemas import (
    AuthenticatedUser,
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
    ShoppingListResponse,
)
from app.services.shopping_list_service import ShoppingListService, get_shopping_list_service

router = APIRouter(prefix="/households/{household_id}/shopping-items", tags=["shopping-list"])


@router.get("", response_model=ShoppingListResponse)
def list_shopping_items(
    household_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    shopping_service: ShoppingListService = Depends(get_shopping_list_service),
) -> ShoppingListResponse:
    try:
        items = shopping_service.list_items_for_household(user_id=user.id, household_id=household_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

    return ShoppingListResponse(items=items)


@router.post("", response_model=ShoppingListItemResponse, status_code=status.HTTP_201_CREATED)
def create_shopping_item(
    household_id: UUID,
    payload: ShoppingListItemCreateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    shopping_service: ShoppingListService = Depends(get_shopping_list_service),
) -> ShoppingListItemResponse:
    try:
        return shopping_service.create_item(user_id=user.id, household_id=household_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.patch("/{item_id}", response_model=ShoppingListItemResponse)
def update_shopping_item(
    household_id: UUID,
    item_id: UUID,
    payload: ShoppingListItemUpdateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    shopping_service: ShoppingListService = Depends(get_shopping_list_service),
) -> ShoppingListItemResponse:
    try:
        return shopping_service.update_item(user_id=user.id, household_id=household_id, item_id=item_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/{item_id}/mark-bought", response_model=ShoppingListItemResponse)
def mark_item_bought(
    household_id: UUID,
    item_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    shopping_service: ShoppingListService = Depends(get_shopping_list_service),
) -> ShoppingListItemResponse:
    try:
        return shopping_service.set_bought(user_id=user.id, household_id=household_id, item_id=item_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def archive_shopping_item(
    household_id: UUID,
    item_id: UUID,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    shopping_service: ShoppingListService = Depends(get_shopping_list_service),
) -> None:
    try:
        shopping_service.archive_item(user_id=user.id, household_id=household_id, item_id=item_id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
