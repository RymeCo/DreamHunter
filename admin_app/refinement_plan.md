# Refinement Plan: DreamHunter Admin Hub & Service Sync (v2)

## 1. Architectural Mandates
*   **Service Hub:** Admin App is the authority. Online features (Sync, Chat, Leaderboard) are the "Bridge".
*   **Superban:** User can play offline, but all "Bridge" features are disabled.
*   **Mod Hierarchy:** 
    *   **Moderators:** Max 24h mute, "Request Ban" (logs as CRITICAL report).
    *   **Admins:** Unlimited mute, Full Ban, Superban, Economy Injection.
*   **UX Persistence:** Dialogs must show loading states and NOT close until manually dismissed.

## 2. Logic Gap Analysis
*   **Shadow Hash Sync:** Admin edits must recalculate hash using `DREAM_HUNTER_SECURE_2026_!#@_S@LT_v1`.
*   **Online/Offline Tweaks:** If user is online during a save tweak, prompt Admin. If offline, queue for next login via `save_tweak_pending`.
*   **Leaderboard:** Investigation needed into `leaderboard_service` or query constraints.

## 3. Tasks (Halt after each for /compress)

### Task 6: Economy Injection & Shadow Hash (SCRUM-106)
- [x] **Backend:** Implement `POST /admin/users/{uid}/currency` with hash recalculation.
- [x] **Admin App:** Add DC/HS fields to `PlayerActionsDialog`. 
- [x] **Admin App:** Implement "Inject" with persistent loading.

### Task 7: Superban & Advanced Moderation (SCRUM-107)
- [x] **Backend:** Add `isSuperBanned` field to user model.
- [x] **Backend:** Refactor Ban endpoint to support Toggle (Ban/Unban/Superban).
- [x] **Admin App:** Update UI to show Superban option and Toggle labels.

### Task 8: Moderator Hierarchy & Reporting (SCRUM-108)
- [x] **Admin App:** If `!isAdmin`, "Ban" button becomes "Request Ban" (POST to `reports` with `priority: "CRITICAL"`).
- [x] **Admin App:** Dynamic Mute (Mod cap 24h).
- [x] **Admin App:** Add "Grant Moderator" toggle.

### Task 9: UX Persistence & Auto-Mod (SCRUM-109)
- [x] **UX:** Remove all `Navigator.pop()` from action buttons.
- [x] **Auto-Mod:** Strike system (3 warnings -> 24h mute).
- [x] **Notifications:** Use `lastAction` + Custom Snackbar on player frontend.

### Task 10: Save Tweak & Admin Surprise Flow (SCRUM-110)
- [x] **Admin App:** Implement "Tweak Mode" selector (Additive vs. Force Override).
- [x] **Admin App:** "Tweak Summary" confirmation dialog with Online Status indicator.
- [x] **Backend:** Implement `POST /admin/users/{uid}/tweak` that triggers the `ADMIN_TWEAK` lastAction.
- [x] **Frontend (Player):** Create `AdminSurpriseDialog` (Liquid Glass).
- [x] **Frontend (Player):** Background logic to merge `tweak_data` into local save (Protection: don't downgrade level unless 'Override' is forced).
- [x] **Frontend (Player):** Ensure surprise only triggers for logged-in users, not guests.

### Task 11: Leaderboard Repair (SCRUM-111)
- [x] **Debug:** Check Firestore indexes and query logic for Leaderboards.
- [x] **Fix:** Ensure Admin App can fetch top players.

### Task 12: Cleanup & UI Fix (SCRUM-112)
- [x] **Cleanup:** Remove `ShopManagementScreen` and `ConfigEditorScreen`.
- [x] **UI:** Fix overflow in `ServiceOpsScreen`.

## 4. Verification Plan
- [x] `flutter analyze` & `py_compile`.
- [x] Manual check of `audit_logs` for every action.
