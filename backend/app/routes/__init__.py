from fastapi import APIRouter

from .health import router as health_router
from .households import router as households_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(households_router)
