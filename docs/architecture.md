# Household Food Management App Architecture

## System Overview

This repository is organized into three deployable concerns:

- `ios-app`: SwiftUI client for iPhone/iPad usage across household members.
- `backend`: FastAPI API layer that handles business logic, access control, and orchestration with Supabase.
- `docs`: architecture and engineering documentation.

Supabase is the system of record for authentication, PostgreSQL data storage, and realtime events. The backend provides a stable domain-oriented API so the iOS app can evolve without tight coupling to schema details.

## Data Flow

1. User authenticates in the iOS app (future Supabase Auth integration).
2. iOS sends authenticated requests to backend API (`/api/v1/...`).
3. Backend validates payloads through schemas and coordinates domain services.
4. Services use Supabase client for persistence and realtime-compatible updates.
5. Backend returns normalized domain responses to iOS.
6. Realtime updates from Supabase can be consumed by iOS for shared list/inventory sync.

## Major Components

### iOS (SwiftUI)
- `Models`: domain entities used by views/view models.
- `Services`: API and configuration abstractions.
- `ViewModels`: state and UI orchestration.
- `Views`: feature surfaces (shopping, inventory, recipes) with a tabbed navigation shell.

### Backend (FastAPI)
- `config`: environment-driven settings and application configuration.
- `routes`: HTTP endpoints and route composition.
- `schemas`: Pydantic request/response contracts.
- `services`: business logic and external integration adapters.
- `models`: persistence/domain model package (ready for SQLModel/ORM migration or rich domain objects).

## Future Extension Points

- **Barcode pipeline:** add OCR/barcode scan endpoint and product enrichment service (e.g., OpenFoodFacts or commercial catalog).
- **Recipe ingestion:** parser service for imported recipes and ingredient normalization.
- **Inventory matching engine:** service for unit normalization and fuzzy ingredient matching against household stock.
- **Realtime collaboration:** subscribe iOS views to Supabase Realtime channels for low-latency shared editing.
- **Offline-first sync:** local cache plus operation queue in iOS for intermittent connectivity.
- **Role-based permissions:** household roles (`owner`, `adult`, `child`, `guest`) enforced at API service layer.
