# SCRUM-115: Admin App & Backend Polish

## 1. Problem Statement
- **Missing Endpoints**: The Admin App attempts to send system messages and moderate chat (delete/flag), but the backend routes `/admin/chats/message/send` and `/admin/chats/message/action` are missing.
- **Leaderboard "Level" Bug**: Selecting "Most Levels" in the leaderboard shows an empty list or malformed data because the field mapping is inconsistent.
- **Broadcast Identity**: Chat broadcasts from the admin app lack clear "System" branding and the admin's name, making them look like regular user messages.
- **Dashboard Redundancy**: "Maintenance Controls" on the Dashboard are redundant with the new "Service Operations" screen.
- **Static Stats**: Dashboard health and growth stats are currently hardcoded placeholders.

## 2. Proposed Changes

### Backend (FastAPI)
- **Chat Endpoints**: Implement `@router.post("/chats/message/send")` and `@router.patch("/chats/message/action")` in `admin.py`.
- **Dynamic Stats**: Update `get_stats_summary` to calculate real system health (simulated) and user growth (DAU, new users).
- **Audit Logging**: Ensure chat actions are logged in the audit trail.

### Admin App (Flutter)
- **Leaderboard Repair**: Revert `by=dreamCoins` back to `by=coins` (as backend handles mapping) and fix the "Level" data extraction in `_getDisplayValue`.
- **Broadcast Branding**: Update `AdminService.sendSystemBroadcastToChat` to prefix messages with `[System Broadcast]` and include the admin's display name.
- **Dashboard Cleanup**: Remove the `_buildMaintenanceControls` method and its usage from `DashboardScreen`.
- **Service Hub Integration**: Ensure all data flows through `AdminService` for consistency.

## 3. Implementation Plan
1. [ ] **Step 1: Backend Chat Endpoints**: Implement the missing routes and verify with `py_compile`.
2. [ ] **Step 2: Backend Dynamic Stats**: Enhance `get_stats_summary` with real data calculations.
3. [ ] **Step 3: Leaderboard Fixes**: Repair the field mapping and "Level" display in `leaderboard_screen.dart`.
4. [ ] **Step 4: Broadcast & Dashboard Polish**: Update broadcast formatting and remove redundant UI components.
5. [ ] **Step 5: Verification**: Run `analyze_files` and perform a final check of the "development" branch.

## 4. Acceptance Criteria
- Admin can send chat messages from the Admin App.
- Admin can delete/flag chat messages.
- "Most Levels" leaderboard shows correct data.
- Dashboard is clean and shows dynamic stats.
- All actions are logged in the Audit Trail.
