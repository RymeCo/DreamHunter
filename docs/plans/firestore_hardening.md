# Implementation Plan: Firestore & Backend Hardening (Epic SCRUM-99)

This plan outlines the steps to transition the DreamHunter database from an open, client-driven model to a secure, backend-authoritative architecture.

## 1. Documentation & Security Base
- **SCRUM-100**: Create `docs/FIRESTORE.md` schema documentation.
- **SCRUM-101**: Implement strict `firestore.rules` (reject direct client writes for currency/stats).
- **SCRUM-104**: Define `firestore.indexes.json` for leaderboards and audit logs.

## 2. Backend Authority (FastAPI)
- **SCRUM-102**: Centralize Registration & Economy logic.
    - Move `playerNumber` generation and user initialization to `POST /auth/register`.
    - Harden `/economy/reconcile` and `/economy/sync` with strict validation.
    - Convert all sentinels to ISO strings in backend responses.

## 3. Frontend Refactoring (Flutter)
- **SCRUM-103**: Refactor `AuthService` and `UserService`.
    - Remove direct Firestore writes for registration and currency.
    - Ensure all updates flow through `BackendService`.

## 4. Verification & Testing
- Attempt direct client writes and verify rejection by rules.
- Test the new registration flow from the frontend.
- Verify economy reconciliation and anomaly detection.
