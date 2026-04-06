from decimal import Decimal
from enum import Enum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from .inventory import InventoryItemResponse, InventoryUnit


class BarcodeMappingSource(str, Enum):
    manual = "manual"
    openfoodfacts = "openfoodfacts"
    receipt_ocr = "receipt_ocr"
    system = "system"
    external_catalog = "external_catalog"


class BarcodeLookupResponse(BaseModel):
    barcode: str
    found: bool
    product_id: UUID | None = None
    product_name: str | None = None
    mapping_source: BarcodeMappingSource | None = None
    mapping_confidence: Decimal | None = Field(default=None, ge=0, le=1)
    metadata: dict[str, Any] = Field(default_factory=dict)


class BarcodeMappingCreateRequest(BaseModel):
    barcode: str = Field(min_length=1, max_length=64)
    product_id: UUID | None = None
    product_name: str | None = Field(default=None, min_length=1, max_length=200)
    source: BarcodeMappingSource = BarcodeMappingSource.manual
    confidence: Decimal = Field(default=Decimal("1"), ge=0, le=1)
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("barcode")
    @classmethod
    def normalize_barcode(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("barcode must not be empty")
        return normalized


class BarcodeMappingCreateResponse(BaseModel):
    barcode: str
    product_id: UUID
    product_name: str
    source: BarcodeMappingSource
    confidence: Decimal
    metadata: dict[str, Any] = Field(default_factory=dict)


class AddInventoryFromBarcodeRequest(BaseModel):
    barcode: str = Field(min_length=1, max_length=64)
    quantity: Decimal = Field(default=Decimal("1"), gt=0)
    unit: InventoryUnit = InventoryUnit.count
    location: str | None = Field(default=None, max_length=64)
    product_name: str | None = Field(default=None, min_length=1, max_length=200)
    save_mapping: bool = True
    source: BarcodeMappingSource = BarcodeMappingSource.manual
    confidence: Decimal = Field(default=Decimal("1"), ge=0, le=1)
    metadata: dict[str, Any] = Field(default_factory=dict)


class AddInventoryFromBarcodeResponse(BaseModel):
    barcode: str
    mapping_created: bool
    product_id: UUID
    product_name: str
    inventory_item: InventoryItemResponse
