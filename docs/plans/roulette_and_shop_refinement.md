# Plan: Roulette & Shop Refinement (SCRUM-113 to SCRUM-120)

This plan covers the simplification of the Roulette UI, the implementation of a reusable Insufficient Funds flow, and the refactoring of the Shop module to use the new `DashboardController` and `InsufficientFundsDialog`.

## Phase 3: Roulette Refinement (Completed)
- **SCRUM-113: Simplify Roulette Actions**
    - Removed redundant "REFILL" logic (which was price-inconsistent).
    - Simplified UI to "WATCH AD (+1 Free Spin)" and "BUY SINGLE SPIN (50 DC)".
    - Fixed "setState during build" crashes in `GlassButton`.
- **SCRUM-115: Restore Suspense & Safety Net** (Completed)
    - Refactored `_spin` logic to grant rewards *after* animation (restoring suspense).
    - Implemented `pendingReward` in `RouletteService` to prevent loss of rewards on crash/close.
    - Added safety check in `DashboardScreen` to claim interrupted rewards on startup.
- **SCRUM-116: Roulette Session Recovery** (Next)
    - Implement `isSpinning` and `targetRotation` in `RouletteState`.
    - Modify `RouletteDialog` to "resume" a spin if the app was closed mid-animation.
    - This creates a seamless "live" experience where the wheel keeps spinning across restarts.

## Phase 4: Insufficient Funds Flow (Completed)
- **SCRUM-114: Reusable Insufficient Funds Dialog**
    - Created `InsufficientFundsDialog` with "Liquid Glass" aesthetic.
    - Integrated "Go to Exchange" redirection logic.
    - Refactored `RouletteDialog` to trigger this flow when balance is < 50 DC.

## Phase 5: Shop Dialog Refactor (Next Steps)
- **SCRUM-116: Shop Data & Controller Integration**
    - Refactor `ShopDialog` to use `DashboardController` for currency state.
    - Move hardcoded items to a cleaner data structure or service.
- **SCRUM-117: Shop Purchase Logic**
    - Implement purchase validation using `InsufficientFundsDialog.show()`.
    - Ensure "Offline-First" persistence for purchased items (e.g., skins, boosters).
- **SCRUM-118: UI Polishing**
    - Ensure Shop items match the "Liquid Glass" aesthetic.
    - Add hover effects and purchase confirmation animations.

## Phase 6: Final Validation
- Full end-to-end testing of the currency loop:
    1. Earn Stones (Mocked).
    2. Exchange Stones -> Coins.
    3. Spend Coins on Roulette/Shop.
    4. Verify persistence across app restarts.
