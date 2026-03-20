# Implementation Plan - DreamHunter Economy & Shop System

This plan outlines the integration of a dual-currency economy (Dream Coins & Hell Stones), a clickable Shop Stall, and a Currency HUD in the dashboard with offline support and backend security.

## 1. Backend & Database (FastAPI + Firestore)

### Firestore Schema Updates
- **`users` collection**: Add fields:
    - `dreamCoins`: integer (default 0)
    - `hellStones`: integer (default 0)
    - `lastKnownDreamCoins`: integer (for security revert)
    - `lastKnownHellStones`: integer (for security revert)
    - `lastSyncTimestamp`: timestamp

### Security Validation
- **Anomaly Detection Logic**: 
    - Before updating currency, check growth delta against expected max rates (e.g., `maxDreamCoinsPerHour = 5000`).
    - If a request exceeds the threshold, revert to `lastKnown` values and log a security alert in `audit_logs`.
    - Flag the user account for manual review.

### API Endpoints (`backend/main.py`)
- Update `get_user_profile_data` to return currency and sync info.
- Add `POST /economy/sync`: Synchronize offline-earned coins with the backend, subject to security validation.
- Add `POST /economy/convert`: Authenticated Hell Stone to Dream Coin conversion.

### Admin API (`backend/admin.py`)
- Add `PATCH /admin/users/{uid}/currency`: Admin manual adjustment (bypasses anomaly detection).

## 2. Admin Dashboard (`admin_app`)

### Service Extension (`admin_service.dart`)
- Implement `updatePlayerCurrency(uid, dreamCoins, hellStones)`.

### UI Updates
- **`PlayerActionsDialog`**: Add "Currency Management" with current and "Last Known" (safe) balances.

## 3. Frontend Dashboard & UI (`frontend`)

### Offline Support & Caching
- **`OfflineCache` service**:
    - Add `saveCurrency(dreamCoins, hellStones)` and `getCurrency()`.
    - Persist to `SharedPreferences` as JSON.
- **Sync Logic**:
    - Periodically (or on app launch) attempt to sync local currency with the backend via `POST /economy/sync`.
    - If offline, continue incrementing the local cache.

### Currency HUD (`lib/screens/dashboard_screen.dart`)
- **Top-Left HUD** in the `AppBar`.
- Display current local/cached balance (Dream Coins & Hell Stones) using small `LiquidGlassDialog` wrappers.

### Shop Stall Interaction (`lib/screens/dashboard_screen.dart`)
- Replace static `shop_stall.png` with `MakeItButton`.
- Action: Trigger `_showShopDialog()`.

### Shop UI (`lib/widgets/shop_dialog.dart`)
- Modal with **Three Tabs**:
    1.  **Essential Gear** (Items)
    2.  **Ethereal Boosts** (Power Ups)
    3.  **Arcane Relics** (Super Power Ups)

## 4. Verification Plan

### Security Testing
- Attempt to send a sync request with a massive coin jump and verify the backend reverts to the last known safe amount.

### Manual Testing
1.  **Offline Flow**: Disable network, "earn" coins in-game, verify `OfflineCache` updates. Enable network, verify sync with backend.
2.  **Dashboard Flow**: Verify currency HUD at top-left.
3.  **Shop Flow**: Tap stall, open 3-tab dialog.
