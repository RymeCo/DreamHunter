# SCRUM-114: Admin App Resilience, Service Ops Repair & Configurable Leaderboard

## 1. Problem Statement
- **App Not Responding**: Render cold starts and lack of retry logic in `AdminService` cause the app to hang.
- **Service Ops UI Gap**: Large empty space in `Service Operations` due to `GridView` constraints and potential document initialization issues.
- **Leaderboard Mismatch**: "Most Coins" is empty due to `by=coins` vs `by=dreamCoins`.
- **New Requirement**: Leaderboard should update every X hours (default 4), configurable in `Service Ops`. No manual refresh.

## 2. Proposed Changes

### AdminService (Resilience & Config)
- **Retry Logic**: Implement `_authenticatedRequest` with 3 retries and 30s timeout.
- **System Config Extension**: Add `leaderboardRefreshHours` to `system_config` update logic.

### Service Ops Screen (UI Fix)
- **Grid Repair**: Replace `GridView` with a more robust responsive `Column` or fixed-height `Wrap` to eliminate the gap.
- **Leaderboard Config**: Add a slider/input to configure `leaderboardRefreshHours`.

### Leaderboard Screen (Cached Logic)
- **Field Alignment**: Use `by=dreamCoins`.
- **Timed Refresh**: Check `lastFetchTimestamp` against `leaderboardRefreshHours` from `system_config`. Only fetch if expired.
- **Remove RefreshIndicator**: As requested by the user.

## 3. Implementation Plan
1. [x] **Step 1: AdminService Resilience**: Implement retry logic and timeout handling.
2. [x] **Step 2: Backend/Service Ops Config**: Ensure `system_config` supports `leaderboardRefreshHours` and add UI to `ServiceOpsScreen`.
3. [x] **Step 3: Service Ops UI Repair**: Fix the layout gap in `ServiceOpsScreen`.
4. [x] **Step 4: Leaderboard logic**: Implement field fix and timed refresh.
5. [x] **Step 5: Verification**: `mcp_dart_analyze_files` and manual review.

## 4. Acceptance Criteria
- No "Not Responding" hangs.
- Service Ops UI is tight and functional (no gaps).
- Leaderboard shows Coins correctly.
- Leaderboard updates automatically based on the configured interval.

**Wait for user approval before implementation.**
