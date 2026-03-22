# SCRUM-113: Address Critical Logic Gaps in Sync & Admin Systems

## 1. Problem Statement
The current sync and admin systems have several logic gaps that could lead to data loss or integrity issues:
- **Sync Overwrites Admin Tweaks**: If a user has unsynced local changes, they can overwrite an administrator's manual adjustments in the cloud.
- **Incomplete Audit Logs**: The backend doesn't handle null emails gracefully in the audit trail.
- **Client-Side Leveling Spoofing**: There's no backend verification of the XP-to-Level ratio during a sync.
- **Duplicate Admin Dialogs**: The current "Admin Surprise" dialog logic depends on a local cache that can be cleared, potentially leading to repeated dialogs.

## 2. Proposed Changes

### Backend (Python/FastAPI)
- **Economy Reconciliation**: Update `reconcile_economy` in `economy.py` to check for a `lastAction == "ADMIN_TWEAK"` flag. If present, it will merge the admin's changes with the user's local transactions rather than just overwriting them.
- **Audit Trail Fix**: Ensure `log_audit` handles missing emails by providing a fallback value.
- **Level Verification**: In the sync endpoint, verify that the user's reported `level` is consistent with their `xp`.

### Frontend (Flutter)
- **Admin Surprise Persistence**: Store the `last_processed_tweak` timestamp in the Firestore user document (e.g., as `lastProcessedTweakTimestamp`) so it persists even if the user clears their local cache.
- **Authoritative Data Merging**: Modify `performFullSync` to properly handle cases where the cloud data is authoritative.

## 3. Implementation Plan
1. [x] **Step 1: Backend Audit & Leveling Verification**: Fix `admin.py` audit logs and add level-to-xp verification logic.
2. [x] **Step 2: Admin Tweak Protection**: Implement logic in `economy.py` to prevent admin adjustments from being overwritten by stale client syncs.
3. [x] **Step 3: Persistence Improvements**: Move the `last_processed_tweak` timestamp to the Firestore user document and update the frontend logic.
4. [x] **Step 4: Verification**: Run backend and frontend tests to ensure the fixes are working as expected.

## 4. Acceptance Criteria
- Admin tweaks are never lost during a user's sync.
- Audit logs are complete and handle missing fields gracefully.
- Leveling up is verified on the backend during sync.
- "Admin Surprise" dialogs are shown only once per tweak, even if the user clears their local data.

**Wait for user approval before implementation.**
