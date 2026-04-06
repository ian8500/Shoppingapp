from fastapi import APIRouter

from .health import router as health_router
from .households import router as households_router
from .shopping_list import router as shopping_list_router
from .inventory import router as inventory_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(households_router)
api_router.include_router(shopping_list_router)
api_router.include_router(inventory_router)
