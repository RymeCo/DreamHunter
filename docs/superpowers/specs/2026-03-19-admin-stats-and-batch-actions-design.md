# Admin Stats, Batch Actions, and Health Monitoring Design

**Date:** 2026-03-19
**Ticket:** SCRUM-39 (Backend) / SCRUM-38 (Admin App)
**Topic:** Admin Infrastructure Enhancements

## 1. Objective
Enhance the DreamHunter Admin infrastructure with robust monitoring, performance insights via data visualization, and efficient moderation through batch player actions.

## 2. Technical Design

### 2.1 Backend Enhancements (FastAPI)

#### 2.1.1 Pinned Requirements
- **Goal:** Absolute reproducibility across local and Render environments.
- **Action:** Update `backend/requirements.txt` with specific versions:
    ```text
    fastapi==0.104.1
    uvicorn==0.23.2
    firebase-admin==6.2.0
    python-dotenv==1.0.0
    pydantic==2.5.2
    pydantic-settings==2.1.0
    ```

#### 2.1.2 Health Check Monitoring
- **Endpoint:** `GET /health`
- **Logic:** 
    - Verify Firestore connectivity by fetching `metadata/system_config`.
    - Return `200 OK` with JSON: `{"status": "ok", "db": "up", "timestamp": "ISO"}`.
    - Serve as the primary liveness probe for Render.

#### 2.1.3 Consolidated Admin Stats
- **Endpoint:** `GET /admin/stats/summary`
- **Data Payload:**
    - `reportStats`: Object with counts of `pending`, `working`, `resolved`.
    - `activityTrends`: List of `{date, messages, logins}` for the last 7 days.
    - `violationSummary`: Counts of categories (Toxicity, Spam, etc.).
- **Security:** Requires `verify_admin` dependency.

#### 2.1.4 Batch Player Actions
- **Endpoint:** `PATCH /admin/users/batch-action`
- **Payload:**
    ```json
    {
      "uids": ["uid1", "uid2"],
      "action": "ban" | "mute" | "unban" | "unmute",
      "params": { "until": "ISO-DATE", "durationHours": 24 }
    }
    ```
- **Audit Logging:** Single `audit_logs` entry for the batch operation.

### 2.2 Frontend Enhancements (Flutter Admin App)

#### 2.2.1 Dependencies
- Add `fl_chart: ^0.70.2` to `pubspec.yaml` for data visualization.

#### 2.2.2 Dashboard Visuals
- **Report Pie Chart:** Displays the distribution of report statuses.
- **Activity Line Chart:** Displays unique logins and message volume trends over 7 days.
- **Integration:** Use `AdminService.getStatsSummary()` to populate charts.

#### 2.2.3 Players Screen: Contextual Action Bar (CAB)
- **Selection Mode:** Long-press on a player card to trigger.
- **State:** `SelectionController` using `ValueNotifier<Set<String>>`.
- **UI:** Swap `AppBar` for CAB when selections exist. Action buttons for "Batch Ban" and "Batch Mute".
- **Interaction:** Cards highlight when selected using the established Glassmorphism theme.

## 3. Standards Compliance
- **Naming:** `camelCase` for all new Firestore fields and JSON keys.
- **UI:** Maintain "LiquidGlass" aesthetic for all chart containers and CAB.
- **Feedback:** Use `showCustomSnackBar` for batch action success/error.
- **Modernization:** Use `.withValues(alpha: 0.x)` for selection highlights.

## 4. Testing Strategy
- **Unit Tests (Backend):** Mock Firestore to verify `batch-action` logic and `stats` aggregation.
- **Integration Tests (Frontend):** Verify `SelectionController` toggles correctly and stats fetch updates the UI.
- **Manual Verification:** Test CAB behavior on mobile emulator (Android 14+) for gesture responsiveness.
