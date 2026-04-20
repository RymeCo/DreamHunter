# Gemini CLI Workflow Mandates (Technical Co-Founder Framework)

This project follows a 5-phase "Technical Co-Founder" lifecycle to ensure we build a **real, polished product**.

## 1. Core Mandates: The Technical Co-Founder Role
The agent acts as your **Technical Co-Founder**. My job is to:
- Help build a **real product** you can use, share, or launch.
- Explain technical approaches in **plain language** (no jargon).
- **Push back** if you are overcomplicating or going down a bad path.
- Be honest about limitations and adjust expectations early.
- Keep the Product Owner (you) in the loop and in control.

## 2. The 5-Phase Project Framework
Every significant request MUST follow these phases:
1.  **Phase 1: Discovery** (Understand needs, challenge assumptions).
2.  **Phase 2: Planning** (Propose V1, estimate complexity).
3.  **Phase 3: Building** (Incremental builds, explain progress).
4.  **Phase 4: Polish** (Professional look, error handling).
5.  **Phase 5: Handoff** (Instructions and documentation).

## 3. Multi-Component Scope
These mandates apply to the entire project ecosystem:
- `frontend/` (Flutter/Flame Game) - **Current focus.**
- `backend/` (FastAPI/Firebase Backend) - **Future Development.**
- `admin/` (Dashboard/App) - **Future Development.**
- Database/Security (`firestore.rules`, `firestore.indexes.json`).

## 4. SCRUM & Jira Automation
- **Traceability:** Every commit MUST start with a Jira ticket key if available (e.g., `SCRUM-116: refined layout`).
- **Resilient Workflow:** If Jira is offline, use the last known relevant key or a descriptive tag.
- **Change Tracking:** Instead of external scrum files, all major task completions are logged in the **Append-Only Log** at the end of this file.

## 5. Strict Validation & Git Workflow
- **Pre-Commit Mandate:** Every commit MUST pass `analyze_files` (static analysis) for the relevant component.
- **Auto-Fix:** Run `dart_fix` and `dart_format` before committing Flutter code.
- **Direct-to-Dev:** All development is performed directly on the `development` branch.
- **Sync:** Always `git pull origin development` before starting work.

## 6. Mandatory Documentation (Append-Only)
Every non-trivial edit MUST be documented by **appending** a new entry to the `## 8. Append-Only Change Log` section at the bottom of this file. 
- **Format:** Use a JSON-like or simple list format.
- **Rule:** Do NOT modify previous entries. Always add to the end.
- **Content:** Date, Task/Ticket, and a brief description of what was changed.

## 7. Gameplay Rewrite Mandate (Composition & Behavior Architecture)
- **Composition First:** All game entities MUST inherit from `BaseEntity` and use behaviors for logic.
- **Categorization:** Every entity MUST have a `categories` property (tags).
- **Effects Engine:** Buffs/debuffs MUST use the `Effect` and `EffectReceiverBehavior` system.
- **Tiled Map Sync:** Map architecture MUST stay synced with `dorm-01.tmx`.

## 8. Append-Only Change Log
- [2026-04-20] SCRUM-000: Initial Project Reset. Removed legacy game logic and archives. Kept Dashboard and Loading Screen foundations. Updated GEMINI.md to use append-only logging.
- [2026-04-20] SYSTEM-ANALYSIS: 
  - **Overall State:** Clean foundation. Legacy gameplay systems and archives have been completely purged.
  - **Frontend (`frontend/lib/`):** 53 files across 7 directories. Core surviving components: Dashboard (UI, action menus, shop stubs), Auth/Profile dialogs, and a `GameLoadingScreen` that pre-loads assets before handing off to a gutted `GameScreen` placeholder. Static analysis (`analyze_files`) passes with 0 errors.
  - **Backend & Admin:** Marked for future development. No active logic present in the current workspace.
  - **Git State:** 40+ files deleted (mostly legacy game logic like pathfinding, AI actors, HUD, grace period timer, and admin surprise dialog). All deletions are clean and staged on the `development` branch.
- [2026-04-20] REGISTRY-OVERHAUL:
  - **ShopItem:** Gutted Firestore logic and reduced to a lightweight data structure.
  - **ItemRegistry:** Created a central "Source of Truth" for all items. IDs are now the primary way items are identified.
  - **PlayerModel:** Overhauled to be strictly minimalist. Removed redundant Auth data (email, photoUrl, lastLogin). Standardized property names to be simple (coins, stones, playTime) for easier modding and Firestore visibility.
- [2026-04-20] SYSTEM-ANALYSIS-V2:
  - **Overall State:** 100% clean and verified. Blueprints (Models) are separated from Registry (Data).
  - **Structure:**
    - `lib/models/`: Lean blueprints for `Item` and `PlayerModel`.
    - `lib/data/`: `ItemRegistry` acts as the master item catalog.
    - `lib/services/` & `lib/widgets/`: Core dashboard logic and UI components preserved and verified error-free.
  - **Verification:** Static analysis (`analyze_files`) confirms 0 errors across the entire frontend.
- [2026-04-20] THEME-CENTRALIZATION:
  - **Organization:** Moved `app_theme.dart` to `lib/core/theme/` and renamed `clickable_image.dart` to `glass_button.dart` for better architectural clarity.
  - **Styling:** Implemented a `GlassTheme` extension for centralized glassmorphism properties (blur, opacity).
  - **Typography:** Synchronized the "Economy HUD" font (Quicksand Bold) across `GlassButton`, `LiquidGlassDialog`, `CurrencyDisplay`, and `GameDialogHeader` using a global `TextTheme`.
  - **Dialog Synchronization:** Updated `SettingsDialog`, `LeaderboardDialog`, `ShopDialog`, `LoginDialog`, `RegisterDialog`, `ConfirmationDialog`, and `InsufficientFundsDialog` to fully respect the centralized `AppTheme` and `GlassTheme` extension.
  - **Refactoring:** Theme-ified `AuthUIHelper` to standardize authentication form styling across the app.
  - **Verification:** Preserved unique dashboard button colors while ensuring they all benefit from the new centralized theme logic. 0 static analysis errors.
- [2026-04-20] SYSTEM-CLEANUP:
  - **Dead Code:** Deleted `frontend/lib/services/backend_config.dart` as it was completely unused and contained outdated mock data.
  - **Refactoring:** Simplified `BackendService` into a minimalist mock implementation and refactored `ConnectivityService` to be a fire-and-forget bridge for real-time status updates.
  - **Singletons:** Converted `UserService` and `ShopService` into minimalist Singletons. Migrated shop caching logic from `UserService` to `ShopService` for better responsibility separation.
  - **Pruning:** Deleted `ChatService` and `AuthUIHelper`. Removed unused dependencies (`uuid`, `device_info_plus`) from `pubspec.yaml`.
- [2026-04-20] UI-STABILITY-FIX:
  - **Overflow Fix:** Resolved a `RenderFlex` crash in `ConfirmationDialog` by removing fixed heights and using `MainAxisSize.min`.
  - **Leaderboard:** Improved responsiveness by using `MediaQuery` for dialog height and removed the deprecated "Time" tab.
  - **Verification:** Static analysis confirms 0 errors. UI is now stable on multiple screen heights.
  - **Auth & Profile:** Overhauled `AuthService` into a minimalist Singleton. Removed redundant Firestore dependencies and fixed the registration flow (auto-login enabled). Fully "Theme-ified" `ProfileDialog` for visual consistency.
- [2026-04-20] ARCHITECTURE-REFINEMENT:
  - **PlayerModel:** Refactored to include `createdAt` (tie-breaker) and `banned` (moderation) fields. Removed `playTime` to simplify the model and data payload.
  - **Cleanup:** Deleted `frontend/lib/services/format_utils.dart` and removed "Playtime" tasks from `DailyTasksDialog`.
  - **Planning:** Created `docs/BACKEND_PLAN.md` (FastAPI/Leaderboard logic) and `docs/ADMIN_PLAN.md` (Moderation/Analytics).
- [2026-04-20] GAME-TIME-FOUNDATION:
  - **PlayerModel:** Restored `totalGameTime` field to track active match seconds (not dashboard time).
  - **Daily Tasks:** Restored "Time Traveler" task and updated its description to reflect active gameplay requirements.
  - **Strategy:** Established monotonic tracking logic using Flame's delta time to prevent system-clock manipulation.
  - **Verification:** Static analysis confirms 0 errors. UI is "Theme-ified" and reflects correct tracking intent.
- [2026-04-20] LEVELING-FOUNDATION:
  - **Logic:** Refactored `LevelingService` into a Singleton. Added `calculateProgress` to return detailed level-up metadata (essential for future Reward Screens).
  - **Rewards:** Implemented `calculateMatchXP` formula based on match performance and play duration.
  - **Verification:** 0 static analysis errors. Code is prepped for post-match UI integration.
  - **Verification:** Static analysis confirms 0 errors. UI correctly reflects removed playtime dependencies.
- [2026-04-20] ECONOMY-OVERHAUL:
  - **Logic Fixes:** Converted `DashboardController` into a Singleton to prevent state desync. Consolidated currency updates into a single `updateBalance` method with negative balance prevention (no more debt!).
  - **Optimization:** Improved saving logic to prevent redundant disk writes.
  - **Refactoring:** Updated `DashboardScreen`, `ShopDialog`, and `RouletteDialog` to use the new Singleton pattern, removing redundant "refresh" callbacks and manual controller instantiations.
  - **Verification:** Static analysis confirms 0 errors across all affected UI components.
- [2026-04-20] REORG-&-RECOVERY:
  - **Reorganization:** Bundled related services into logical sub-folders (`core`, `identity`, `economy`, `progression`, `loading`) and reorganized the `widgets` folder into `auth`, `shop`, `social`, and `game` sub-directories.
  - **Renaming:** Refactored all service classes to use more \"human-like\" names (e.g., `OfflineCache` ➔ `StorageEngine`, `DashboardController` ➔ `WalletManager`).
  - **Crash Recovery:** Implemented a `pending_save_conflict` flag. If the app closes during login, the user is re-prompted to resolve the save conflict on the next launch.
  - **Verification:** Static analysis confirms 0 errors. All imports and references successfully updated to absolute package paths.
- [2026-04-20] SAVE-CONFLICT-RESOLUTION:
  - **Logic:** Implemented a non-destructive "Save Conflict" system. Upon login, users choose between Local Progress (archived guest data) or Cloud Save.
  - **Archival:** Guest data is preserved under `guest_` keys and never deleted, ensuring recovery upon logout.
  - **Standardization:** Converted all core services (`OfflineCache`, `AuthService`, `RouletteService`, etc.) to a consistent Singleton pattern using factory constructors.
  - **Verification:** Static analysis confirms 0 errors. All UI components (Login, Register, Dashboard) correctly trigger and handle conflict resolution.
- [2026-04-20] FINAL-CLEANUP-&-REORG:
  - **Dead Code:** Deleted `report_dialog.dart` and `leveling_system.dart`. Removed the `intl` package from dependencies.
  - **Organization:** Renamed `game_widgets.dart` to `common_ui.dart` and extracted `AppLogo` and `RouletteWheelPainter` into dedicated files.
  - **Simplification:** Streamlined `LayoutBaseline` and standardized all utility imports to absolute package paths.
  - **Verification:** Static analysis confirmed 0 errors across 49 files.
- [2026-04-20] DASHBOARD-CLEANUP:
  - **Backup:** Created `dashboard_v1_backup.dart` to preserve the current high-quality UI layout.
  - **Refactoring:** Simplified the `DashboardScreen` code by extracting the complex Auth Flow into a dedicated `AuthFlowDialog` and breaking down the `build` method into readable helper methods.
  - **Preservation:** The visual UI layout (coordinates, images, animations) remains 100% identical as per user preference.
  - **Verification:** Static analysis confirms 0 errors.
- [2026-04-20] TASK-SYSTEM-REFACTOR:
  - **Model:** Introduced a structured `DailyTask` model to handle progress, completion logic, and type safety.
  - **Logic Fixes:** Resolved the "Claim" gap by integrating the dialog with `WalletManager.instance.updateBalance`. Claimed rewards are now persistent.
  - **Simplification:** Refactored the build method into clean helper widgets and removed redundant map-based status flags.
  - **Theme:** Synchronized visual properties with the `GlassTheme` extension for better glassmorphism consistency.
  - **Haptics:** Integrated `HapticManager` for physical feedback during the claim flow.
  - **Verification:** Static analysis confirms 0 errors across the new model and dialog.
- [2026-04-20] CONFIRMATION-DIALOG-STANDARDIZATION:
  - **Reusability:** Refactored `ConfirmationDialog` to be a true "fire-and-forget" utility with a powerful `show` helper.
  - **Logic:** Added `isDestructive` mode to automatically handle red styling and heavy haptic feedback for high-stakes actions.
  - **UX:** Improved entrance animations and integrated `AudioManager.instance` and `HapticManager.instance` for consistent feedback.
  - **Cleanup:** Migrated to absolute package imports and resolved static analysis warnings.
- [2026-04-20] SNACKBAR-SIMPLIFICATION:
  - **Architecture:** Replaced the complex manual `Overlay` queue with Flutter's standard `ScaffoldMessenger` for better stability and built-in animations.
  - **Theme-Centric:** Fully integrated `GlassTheme` for blur and dynamic opacity. Notifications now match the game's liquid-glass aesthetic.
  - **Haptics:** Standardized light/medium haptic feedback for all notification types (Success, Error, Warning).
  - **Verification:** Static analysis confirms 0 errors.
- [2026-04-20] GAME-WIDGETS-STANDARDIZATION:
  - **Logic:** Updated `GameDialogHeader` and other utility widgets to use `AudioManager.instance` and `HapticManager.instance`.
  - **Theme:** Synchronized all core game widgets with the global `AppTheme` and `GlassTheme` extension.
  - **Polish:** Added a `Hero` animation to `AppLogo` and refined the `RouletteWheelPainter` for better visual alignment.
  - **Verification:** Static analysis confirms 0 errors.
- [2026-04-20] GLASS-BUTTON-OPTIMIZATION:
  - **Singletons:** Migrated to `AudioManager.instance` and `HapticManager.instance`.
  - **Performance:** Optimized pulse animation controllers to only run when necessary.
  - **Styling:** Fully synced with `GlassTheme` extension for dynamic alphas and hover effects.
  - **Cleanup:** Deleted the unused `MakeItButton` legacy wrapper.
  - **Verification:** Static analysis confirms 0 errors.
