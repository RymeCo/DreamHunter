# Firestore Schema Documentation (DreamHunter)

This document defines the authoritative Firestore schema for the DreamHunter project. All field names use `camelCase`.

## Collections

### 1. `users/{uid}`
Authoritative user profile and stats. Primary identification is via the Firebase `uid`.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `uid` | string | Unique user identifier (Firebase Auth UID). |
| `email` | string | User email address. |
| `displayName` | string | Publicly visible player name. |
| `playerNumber` | number | Globally incremented player counter (e.g. #1, #2). |
| `createdAt` | timestamp | ISO string or Server Timestamp of account creation. |
| `isBanned` | boolean | Flag for banning account. |
| `isModerator` | boolean | Flag for moderator permissions. |
| `isAdmin` | boolean | Flag for admin permissions. |
| `dreamCoins` | number | Primary in-game currency (default 0). |
| `hellStones` | number | Premium in-game currency (default 0). |
| `lastKnownDreamCoins`| number | Last safe known balance for anomaly revert. |
| `lastKnownHellStones` | number | Last safe known balance for anomaly revert. |
| `lastSyncTimestamp` | string | ISO string of the last economy reconciliation. |
| `xp` | number | Total accumulated experience points. |
| `level` | number | Calculated player level based on XP. |
| `playtime` | number | Total playtime in seconds. |
| `freeSpins` | number | Number of available roulette spins. |
| `avatarId` | number | ID of the selected player avatar. |
| `inventory` | string[] | List of unlocked item/character IDs. |
| `processedTransactionIds`| string[] | List of unique IDs for reconciled transactions. |
| `dailyTasks` | object | Nested daily task progress (see below). |

#### `dailyTasks` structure:
- `lastReset`: ISO string of the last task reset.
- `tasks`: Array of objects:
    - `id`: Unique task ID.
    - `title`: Display title.
    - `progress`: Current progress.
    - `target`: Target for completion.
    - `reward`: Amount of Dream Coins.
    - `completed`: Boolean flag.
    - `type`: Category (chat, spin, login, playtime).

### 2. `metadata/{docId}`
Global game configurations and counters.

- **`counters`**:
    - `totalPlayers`: number (Globally incremented).
- **`system_config`**:
    - `chatMaintenance`: boolean.
    - `shopMaintenance`: boolean.
- **`roulette_config`**:
    - `dailyFreeSpins`: number.
    - `maxFreeSpins`: number.
    - `rewards`: Array of objects (weight, color, amount, type).

### 3. `audit_logs/{id}`
Immutable logs for admin actions and system anomalies.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `adminUid` | string | The UID of the admin or "SYSTEM_SECURITY". |
| `action` | string | Category (ECONOMY_ANOMALY, BAN, MUTE). |
| `target` | string | The UID of the affected user. |
| `timestamp` | timestamp | Server Timestamp of the action. |
| `details` | string | Detailed description of the event. |

### 4. `reports/{id}`
User-generated reports for moderation.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `reporterUid` | string | UID of the reporting user. |
| `targetUid` | string | UID of the reported user. |
| `messageId` | string | ID of the reported chat message. |
| `status` | string | pending, reviewed, resolved. |
| `reportTimestamp` | timestamp | Server Timestamp of the report. |
