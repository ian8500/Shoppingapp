from datetime import datetime
from decimal import Decimal
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class ShoppingItemStatus(str, Enum):
    active = "active"
    bought = "bought"
    archived = "archived"


class ShoppingListItemBase(BaseModel):
    product_id: UUID | None = None
    raw_name: str = Field(min_length=1, max_length=200)
    quantity: Decimal | None = Field(default=None, ge=0)
    unit: str | None = Field(default=None, max_length=50)
    category: str | None = Field(default=None, max_length=80)
    notes: str | None = Field(default=None, max_length=500)


class ShoppingListItemCreateRequest(ShoppingListItemBase):
    pass


class ShoppingListItemUpdateRequest(BaseModel):
    product_id: UUID | None = None
    raw_name: str | None = Field(default=None, min_length=1, max_length=200)
    quantity: Decimal | None = Field(default=None, ge=0)
    unit: str | None = Field(default=None, max_length=50)
    category: str | None = Field(default=None, max_length=80)
    notes: str | None = Field(default=None, max_length=500)
    status: ShoppingItemStatus | None = None


class ShoppingListItemResponse(BaseModel):
    id: UUID
    household_id: UUID
    product_id: UUID | None = None
    raw_name: str
    quantity: Decimal | None = None
    unit: str | None = None
    category: str | None = None
    notes: str | None = None
    status: ShoppingItemStatus
    added_by: UUID | None = None
    bought_by: UUID | None = None
    created_at: datetime
    updated_at: datetime


class ShoppingListResponse(BaseModel):
    items: list[ShoppingListItemResponse]
