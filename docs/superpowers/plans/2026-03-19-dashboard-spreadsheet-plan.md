# Dashboard Spreadsheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chart-based dashboard with a dense, "spreadsheet-style" metric list for better data visibility.

**Architecture:** Update the backend stats endpoint to provide comprehensive metrics across 3 categories (Support, System, Growth), then refactor the Flutter dashboard to display these as a list of styled rows.

**Tech Stack:** FastAPI, Flutter, Firestore.

---

### Task 1: Update Backend Stats Summary

**Files:**
- Modify: `backend/admin.py`

- [ ] **Step 1: Update `get_stats_summary` endpoint**

```python
@router.get("/stats/summary")
async def get_stats_summary(admin: dict = Depends(verify_admin)):
    db = firestore.client()
    
    # 1. Report Stats (Optimized)
    reports_ref = db.collection('reports')
    pending = reports_ref.where("status", "==", "pending").count().get()[0][0].value
    working = reports_ref.where("status", "==", "working").count().get()[0][0].value
    resolved = reports_ref.where("status", "==", "resolved").count().get()[0][0].value
    
    # 2. User Growth Stats
    users_ref = db.collection('users')
    total_users = users_ref.count().get()[0][0].value
    
    # Mock DAU and New Today for now (In production, use indexed timestamps)
    new_today = 5 # Mock
    dau = 12      # Mock
    
    # 3. System Health (Mock / Placeholder)
    latency = 45.5
    error_count = 0
    
    return {
        "reportStats": {
            "pending": pending,
            "working": working,
            "resolved": resolved
        },
        "systemHealth": {
            "latency": latency,
            "errorCount": error_count,
            "status": "Healthy" if latency < 200 else "Degraded"
        },
        "userGrowth": {
            "total": total_users,
            "newToday": new_today,
            "dau": dau
        }
    }
```

- [ ] **Step 2: Verify endpoint manually (or with curl)**

Run: `curl -H "Authorization: Bearer <TOKEN>" http://localhost:8000/admin/stats/summary`
Expected: JSON response with `reportStats`, `systemHealth`, and `userGrowth`.

- [ ] **Step 3: Commit**

```bash
git add backend/admin.py
git commit -m "feat(backend): expand stats summary for spreadsheet dashboard"
```

### Task 2: Refactor Dashboard UI to Spreadsheet Style

**Files:**
- Modify: `admin_app/lib/screens/dashboard_screen.dart`

- [ ] **Step 1: Replace chart methods with `_buildSpreadsheetSection`**

```dart
  Widget _buildSpreadsheetSection() {
    final reportStats = _statsSummary?['reportStats'] as Map<String, dynamic>? ?? {};
    final systemHealth = _statsSummary?['systemHealth'] as Map<String, dynamic>? ?? {};
    final userGrowth = _statsSummary?['userGrowth'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildDataLayer('Support & Reports', [
          _dataRow('Pending Reports', reportStats['pending'], Colors.redAccent),
          _dataRow('Active Cases', reportStats['working'], Colors.orangeAccent),
          _dataRow('Resolved Today', reportStats['resolved'], Colors.greenAccent),
        ]),
        const SizedBox(height: 16),
        _buildDataLayer('System Performance', [
          _dataRow('API Latency', '${systemHealth['latency'] ?? 0} ms', Colors.blueAccent),
          _dataRow('Recent Errors', systemHealth['errorCount'], Colors.redAccent),
          _dataRow('Server Status', systemHealth['status'] ?? 'Unknown', Colors.greenAccent),
        ]),
        const SizedBox(height: 16),
        _buildDataLayer('Platform Growth', [
          _dataRow('Total Users', userGrowth['total'], Colors.amberAccent),
          _dataRow('New Today', userGrowth['newToday'], Colors.amberAccent),
          _dataRow('Daily Active (DAU)', userGrowth['dau'], Colors.amberAccent),
        ]),
      ],
    );
  }

  Widget _buildDataLayer(String title, List<Widget> rows) {
    return LiquidGlassDialog(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _dataRow(String label, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Update `build` method to use the new section**

Replace `_buildChartsSection()` with `_buildSpreadsheetSection()` in the `build` method.

- [ ] **Step 3: Run analysis and verification**

Run: `dart analyze` and manually verify the dashboard layout.

- [ ] **Step 4: Commit**

```bash
git add admin_app/lib/screens/dashboard_screen.dart
git commit -m "feat(admin_app): replace dashboard charts with spreadsheet-style metric list"
```
