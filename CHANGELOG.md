# Changelog

All notable changes to the **DreamHunter** project will be documented in this file.

## [Unreleased]

### Repository Management
- **Cleanup:** Removed unused desktop platform folders (`frontend/windows/`, `frontend/macos/`, `frontend/linux/`).
- **Cleanup:** Deleted boilerplate image `frontend/flutter_01.png` and default `frontend/README.md`.

### Workflow
- **Refinement:** Adopted the **Technical Co-Founder** framework.
- **Rules:** Implemented strict pre-commit validation (100% pass on `analyze_files` and `run_tests`).
- **Tickets:** Updated Jira/SCRUM policy to allow grouping of small fixes.
- **Docs:** Mandated documentation updates for every edit.

### Frontend
- **Sound:** Fixed track2 asset typo (`tract2.ogg` -> `track2.ogg`) and updated references in `AudioService` and `PreLoader`.
- **Sound:** Enhanced `AudioService` with `WidgetsBindingObserver` to automatically resume BGM when app returns from background (resilience against WayDroid focus loss).
- **Sound:** Refined BGM playlist logic with `ReleaseMode.stop` to ensure smooth alternating between track1 and track2.
- **Sound:** Optimized BGM for Android/WayDroid by using `AndroidUsageType.game` and `AndroidAudioFocus.none` for all players, preventing SFX from cutting music. Fixed `AudioContext` assertion by removing iOS-specific configurations in this Android-only app.
- **Sound:** Implemented seamless volume transitions when entering the game (20% boost without track restart).
- **Sound:** Refactored to V3 Audio Architecture with a global mixing baseline to prevent SFX from interrupting BGM.
- **Sound:** Implemented a 3-player SFX pool to allow rapid, overlapping UI sounds without performance hits.
- **Sound:** Integrated "Buffer Warm-up" for critical assets (`roulette.ogg`, `click.ogg`) to achieve 0ms latency.
- **Sound:** Increased base music volume by an additional 10% (0.72 -> 0.79) for a more immersive experience.
- **Sound:** Implemented a dashboard BGM playlist that automatically alternates between `track1.ogg` and `track2.ogg`.
- **Sound:** Integrated `roulette.ogg`, `reward.ogg`, and `levelup.ogg` into the `AudioService`.
- **Sound:** Fixed Android "SoundPool not READY" errors by implementing SFX pre-caching in the `SplashScreen` via `PreLoader`.
- **Sound:** Configured independent Audio Contexts for BGM and SFX to allow seamless overlapping.
- **UI:** Enhanced the `RouletteDialog` with synchronized SFX for spinning and winning.
- **UI:** Performed global SFX injection across 12+ dashboard widgets for consistent feedback.
- **UI:** Implemented bed interaction, sleeping state, and energy generation logic.
- **UI:** Refined Roulette and Shop dialogs with centralized data and reusable painters.
- **Game:** Improved collision detection and map alignment for `dorm-01`.
- **Assets:** Consolidated Tiled project files and images into `assets/images/tiles`.

### Backend
- **Jira:** Ongoing synchronization with the `SCRUM` project for task tracking.
