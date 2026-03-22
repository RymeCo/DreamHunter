# Admin App Strategic Plan: "The Control Room"

## Objective
Rebuild the `admin_app` to be the primary command center for the DreamHunter ecosystem, fully aligned with the frontend's "Liquid Glass" aesthetic and "Offline-First" architecture.

## 1. Visual Alignment: Liquid Glass UI
The Admin App should feel like an extension of the game.
- **Action**: Refactor `AdminCard`, `AdminButton`, and `AdminTextField` in `admin_app/lib/widgets/admin_ui_components.dart`.
- **Style**: Use `BackdropFilter` (blur), semi-transparent gradients, and "Glowing" borders (Amber/Cyan accents).
- **Layout**: Keep the dashboard-centric layout but with "glass panels."

## 2. Offline-First Management (Global Configs)
Since the game functions offline, the Admin App is where "Global Truths" are defined.
- **Global Constants Screen**:
    - Manage `dailyTaskDefinitions`.
    - Configure `rouletteOdds` and `spinRewards`.
    - Set `economyMultipliers` (XP/Coin rates).
- **Action**: Create `admin_app/lib/screens/config_screen.dart` to push these to Firestore.

## 3. Integrity & Anti-Cheat Monitoring
With local saves being the norm, the Admin App must surface integrity issues.
- **Integrity Dashboard**: Show a list of users with "Mismatched Checksums" reported during their last sync.
- **Save Auditor**: View the detailed breakdown of a user's local vs. cloud save (Level, XP, Coins, Stones).
- **Action**: Update `admin_app/lib/screens/audit_screen.dart` to include "Integrity Status" badges.

## 4. Live Operations
- **Maintenance Toggle**: Instantly put the game into "Read Only" or "Maintenance" mode.
- **Broadcast System**: Send global alerts that appear in the game's chat or as popups.
- **Shop Manager**: Add/Remove items from the game's shop dynamically.

## 5. Implementation Steps (Phased)
### Phase 1: The Glass Overhaul
- Port `LiquidGlassDialog` logic to `admin_app`.
- Update all existing screens (`AutoMod`, `Dashboard`, `Audit`) to use the new glass components.

### Phase 2: Game Configuration (The "Brain")
- Implement the `ConfigScreen` for editing game constants.
- Ensure the `frontend` is set up to listen to these changes (via Firestore).

### Phase 3: Anti-Cheat & Conflict Resolution
- Build the "Integrity Dashboard."
- Add "Force Overwrite" tools for admins to fix corrupted/cheated player saves.
