from datetime import datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class InventoryUnit(str, Enum):
    count = "count"
    pack = "pack"
    g = "g"
    kg = "kg"
    ml = "ml"
    l = "l"


class InventoryLocation(str, Enum):
    fridge = "fridge"
    freezer = "freezer"
    cupboard = "cupboard"
    other = "other"


class InventoryAdjustmentReason(str, Enum):
    manual_adjustment = "manual_adjustment"
    purchase = "purchase"
    consume = "consume"
    waste = "waste"
    recipe_use = "recipe_use"
    transfer = "transfer"
    correction = "correction"


class InventoryItemCreateRequest(BaseModel):
    product_id: UUID | None = None
    raw_name: str | None = Field(default=None, min_length=1, max_length=200)
    quantity: Decimal = Field(ge=0)
    unit: InventoryUnit
    location: InventoryLocation | None = None
    low_stock_threshold: Decimal | None = Field(default=None, ge=0)
    notes: str | None = Field(default=None, max_length=500)


class InventoryQuantityUpdateRequest(BaseModel):
    quantity: Decimal = Field(ge=0)
    reason: InventoryAdjustmentReason = InventoryAdjustmentReason.manual_adjustment
    note: str | None = Field(default=None, max_length=500)


class InventoryQuantityDeltaRequest(BaseModel):
    amount: Decimal = Field(gt=0)
    reason: InventoryAdjustmentReason = InventoryAdjustmentReason.manual_adjustment
    note: str | None = Field(default=None, max_length=500)


class InventoryItemPatchRequest(BaseModel):
    low_stock_threshold: Decimal | None = Field(default=None, ge=0)
    notes: str | None = Field(default=None, max_length=500)
    location: InventoryLocation | None = None


class InventoryItemResponse(BaseModel):
    id: UUID
    household_id: UUID
    product_id: UUID
    raw_name: str
    quantity: Decimal
    unit: InventoryUnit
    location: InventoryLocation | None = None
    low_stock_threshold: Decimal | None = None
    notes: str | None = None
    is_low_stock: bool
    created_at: datetime
    updated_at: datetime


class InventoryTransactionResponse(BaseModel):
    id: UUID
    household_id: UUID
    inventory_item_id: UUID | None = None
    product_id: UUID
    quantity_delta: Decimal
    unit: InventoryUnit
    reason: InventoryAdjustmentReason
    note: str | None = None
    actor_user_id: UUID | None = None
    occurred_at: datetime
    created_at: datetime


class InventoryListResponse(BaseModel):
    items: list[InventoryItemResponse]


class InventoryTransactionListResponse(BaseModel):
    transactions: list[InventoryTransactionResponse]
