# Spec: Dashboard Spreadsheet (GSD Mode)

**Date:** 2026-03-19
**Ticket:** SCRUM-33 / SCRUM-39
**Status:** Draft

## 1. Objective
Replace the current chart-based dashboard in the Admin Flutter App with a dense, spreadsheet-style "Metric | Value" list. This will provide more detailed and actionable "layers" of data for administrators at a glance.

## 2. Requirements
- Remove the `BarChart` and `LineChart` from `DashboardScreen`.
- Implement a table-like list using `LiquidGlassDialog` components for consistent styling.
- Display metrics in "layers" with columns for:
  - Metric Name (Label)
  - Current Value (Data)
  - Change/Trend (Optional, 24h delta)
  - Status (Colored indicator)

## 3. Data Layers (Metrics)
### A. Support/Reports Summary
- **Pending Reports:** Count of reports with status 'pending'.
- **Active Cases:** Count of reports with status 'working'.
- **Resolved Today:** Reports resolved in the last 24h.

### B. System & API Performance
- **API Latency:** Average response time for backend calls (ms).
- **Recent Errors:** Count of 4xx/5xx errors in the last 1 hour.
- **Server Health:** Global status indicator based on ping and resource usage.

### C. Platform Growth/Users
- **Total Users:** Total registered accounts in Firestore.
- **New Today:** Users created in the last 24h.
- **Daily Active Users (DAU):** Unique logins in the last 24h.

## 4. Technical Architecture
### Backend (FastAPI - `backend/admin.py`)
- Update `@router.get("/stats/summary")` to include:
  - `systemHealth`: `{ latency: float, errorCount: int, status: string }`
  - `userGrowth`: `{ total: int, newToday: int, dau: int }`
  - Refine `reportStats` to be more accurate.

### Frontend (Flutter - `admin_app/lib/screens/dashboard_screen.dart`)
- Update `_DashboardScreenState` to handle the expanded `_statsSummary` map.
- Replace `_buildChartsSection()` with `_buildSpreadsheetSection()`.
- Use `num?` for all numeric values to maintain safety against `double` vs `int` mismatches.

## 5. UI Design (Glassmorphism)
- Each layer is a `Row` inside a `LiquidGlassDialog`.
- Alternating or subtle separators for readability.
- Status dots:
  - Green: All good.
  - Yellow: Warning (e.g., latency > 200ms).
  - Red: Critical (e.g., > 5 errors/hr).

## 6. Testing Strategy
- **Unit Test (Backend):** Verify `/admin/stats/summary` returns all required fields.
- **Widget Test (Frontend):** Verify the dashboard displays values for all 3 layers.
- **Verification:** Manually refresh dashboard and check alignment and type-safety.
