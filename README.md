# Household Food Management App

Production-minded scaffold for a shared household food management platform with:

- Shared household accounts across multiple devices
- Shopping lists
- Home food inventory
- Barcode-based item entry foundations
- Recipes and ingredient tracking
- Recipe-to-shopping-list expansion
- Recipe matching against household inventory

## Repository Layout

- `ios-app/` — SwiftUI app shell with modular feature folders
- `backend/` — FastAPI service with clean layering and env-based configuration
- `docs/` — architecture documentation

## Backend Setup

### Prerequisites

- Python 3.11+
- `pip` and virtualenv tooling

### Install

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
cp .env.example .env
```

### Run Locally

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health endpoint:

```bash
curl http://localhost:8000/api/v1/health
```

## iOS Setup

1. Open `ios-app` in Xcode and create/use a project target pointing to `FoodManagerApp` sources.
2. Ensure runtime environment variables are configured in the scheme (see below).
3. Build and run on simulator/device.

## Required Environment Variables

### Backend (`backend/.env`)

- `APP_NAME`
- `ENVIRONMENT`
- `DEBUG`
- `HOST`
- `PORT`
- `CORS_ALLOWED_ORIGINS` (comma-separated)
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

### iOS Scheme Environment

- `API_BASE_URL` (e.g., `http://localhost:8000`)
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Architecture Summary

- FastAPI backend provides stable, versioned API routes (`/api/v1`) and isolates infrastructure concerns behind service modules.
- Supabase remains the platform for Postgres/Auth/Realtime while backend enforces domain rules and allows future multi-client expansion.
- SwiftUI app follows a clean split between views, view models, services, and models to support feature growth and easier testing.
- Domain boundaries are shaped around shopping, inventory, recipes, and collaboration, with placeholders ready for barcode ingestion and inventory matching logic.
