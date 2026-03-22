# Admin App Implementation Plan: "The Service Hub"

## Task 1: Glass UI Foundation [DONE]
- [x] Port `LiquidGlassDialog` logic to `admin_app/lib/widgets/liquid_glass_panel.dart`.
- [x] Refactor `AdminCard`, `AdminButton`, and `AdminTextField` in `admin_app/lib/widgets/admin_ui_components.dart` to use Glassmorphism (blur + semi-transparent gradients).
- [x] Update `MainLayout` in `main.dart` with a Glass-themed AppBar and background.

## Task 2: Player Save Tweaking & Locked Economy [DONE]
- [x] Update `PlayerActionsDialog`:
    - Display Dream Coins and Hell Stones as **non-clickable badges**.
    - Add a "Save State Editor" to tweak Level, XP, and Sync flags.
    - Simplified "Access Control" (one-tap Reset Spam, Mute, Ban).

## Task 3: Moderator Hub & One-Tap Chat Tools [DONE]
- [x] Update `LiveChatScreen`:
    - Functional `mod-only` coordination channel.
    - "Quick Action" mini-buttons on chat tiles (Mute 1h, Warn, Hide) for rapid moderation.

## Task 4: Service Operations (Broadcast & Maintenance) [DONE]
- [x] Implement `ServiceOpsScreen`:
    - Maintenance toggles for "Sync Service" and "Chat Service".
    - "High Priority" Global Broadcast tool.

## Task 5: Global Config Editor [DONE]
- [x] Create `ConfigEditorScreen`:
    - Edit offline game constants (Daily rewards, Roulette odds) stored in Firestore.
