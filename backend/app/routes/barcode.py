from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies.auth import get_authenticated_user
from app.schemas import (
    AddInventoryFromBarcodeRequest,
    AddInventoryFromBarcodeResponse,
    AuthenticatedUser,
    BarcodeLookupResponse,
    BarcodeMappingCreateRequest,
    BarcodeMappingCreateResponse,
)
from app.services.barcode_service import BarcodeService, get_barcode_service

router = APIRouter(prefix="/households/{household_id}/barcode-mappings", tags=["barcode"])


@router.get("/{barcode}", response_model=BarcodeLookupResponse)
def lookup_barcode(
    household_id: UUID,
    barcode: str,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    barcode_service: BarcodeService = Depends(get_barcode_service),
) -> BarcodeLookupResponse:
    try:
        return barcode_service.lookup(user_id=user.id, household_id=household_id, barcode=barcode)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("", response_model=BarcodeMappingCreateResponse, status_code=status.HTTP_201_CREATED)
def create_barcode_mapping(
    household_id: UUID,
    payload: BarcodeMappingCreateRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    barcode_service: BarcodeService = Depends(get_barcode_service),
) -> BarcodeMappingCreateResponse:
    try:
        return barcode_service.create_mapping(user_id=user.id, household_id=household_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/add-to-inventory", response_model=AddInventoryFromBarcodeResponse)
def add_inventory_from_barcode(
    household_id: UUID,
    payload: AddInventoryFromBarcodeRequest,
    user: AuthenticatedUser = Depends(get_authenticated_user),
    barcode_service: BarcodeService = Depends(get_barcode_service),
) -> AddInventoryFromBarcodeResponse:
    try:
        return barcode_service.add_inventory_from_barcode(user_id=user.id, household_id=household_id, payload=payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
