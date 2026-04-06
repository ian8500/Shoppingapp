# Household Food Management App

Production-minded scaffold for a shared household food management platform.

This iteration includes an integrated auth + household flow:

- Supabase Auth sign-up/sign-in from iOS
- FastAPI household creation + membership listing endpoints
- Owner/admin membership assignment on household creation
- SwiftUI onboarding flow (login, signup, create household, dashboard)
- Session persistence in iOS (restored from `UserDefaults`)

## Repository Layout

- `ios-app/` — SwiftUI client
- `backend/` — FastAPI service
- `backend/migrations/` — SQL schema/migrations for Supabase Postgres
- `docs/` — architecture notes

---

## Local Setup (Exact Steps)

## 1) Create a Supabase project

1. Create a Supabase project at https://supabase.com.
2. In **Project Settings → API**, copy:
   - Project URL (`SUPABASE_URL`)
   - `anon` public key (`SUPABASE_ANON_KEY`)
   - `service_role` key (`SUPABASE_SERVICE_ROLE_KEY`)
3. In **SQL Editor**, run:
   - `backend/migrations/20260406_0001_initial_household_food_schema.sql`

> The household endpoints rely on `households` and `household_members` from this migration.

## 2) Backend setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
cp .env.example .env
```

Edit `backend/.env` and set real values:

```dotenv
APP_NAME=Household Food API
ENVIRONMENT=development
DEBUG=true
HOST=0.0.0.0
PORT=8000
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SUPABASE_SERVICE_ROLE_KEY
```

Run backend:

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Quick check:

```bash
curl http://localhost:8000/api/v1/health
```

## 3) iOS setup

1. Open `ios-app` sources in Xcode with your app target.
2. Set these **Scheme Environment Variables** (Run scheme):
   - `API_BASE_URL` = `http://localhost:8000`
   - `SUPABASE_URL` = your Supabase URL
   - `SUPABASE_ANON_KEY` = your Supabase anon key
3. Build and run on simulator/device.

If testing on a physical device, use your machine LAN IP for `API_BASE_URL` instead of localhost.

---

## API Contracts

### `POST /api/v1/households`

Auth: Bearer token (Supabase access token)

Request:

```json
{
  "name": "Home"
}
```

Response:

```json
{
  "household": {
    "id": "uuid",
    "name": "Home",
    "created_by": "uuid",
    "created_at": "2026-04-06T00:00:00+00:00"
  },
  "membership": {
    "id": "uuid",
    "household_id": "uuid",
    "household_name": "Home",
    "user_id": "uuid",
    "role": "owner",
    "status": "active",
    "joined_at": "2026-04-06T00:00:00+00:00"
  }
}
```

### `GET /api/v1/households/memberships`

Auth: Bearer token

Response:

```json
{
  "memberships": [
    {
      "id": "uuid",
      "household_id": "uuid",
      "household_name": "Home",
      "user_id": "uuid",
      "role": "owner",
      "status": "active",
      "joined_at": "2026-04-06T00:00:00+00:00"
    }
  ]
}
```

---

## Current Product Flow

1. User signs up (or signs in) from SwiftUI.
2. App persists auth session locally.
3. App loads memberships from backend.
4. If no memberships exist, user creates a household.
5. Backend creates household + owner membership.
6. App lands on household dashboard.
7. If multiple memberships exist in future, user can switch households from dashboard.

---

## Notes for Future Invite/Permissions Work

- Add invite endpoints (`POST /households/{id}/invites`, `POST /invites/{token}/accept`).
- Expand `role` handling to enforce admin/member actions in backend services.
- Add backend auth dependency helpers for permission checks by household.
- Add dashboard sections for pending invites and member management.
