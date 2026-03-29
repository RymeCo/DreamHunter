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
- **Sound:** Enhanced `AudioService` with SFX support and track assets for dashboard and game.
- **UI:** Implemented bed interaction, sleeping state, and energy generation logic.
- **UI:** Refined Roulette and Shop dialogs with centralized data and reusable painters.
- **Game:** Improved collision detection and map alignment for `dorm-01`.
- **Assets:** Consolidated Tiled project files and images into `assets/images/tiles`.

### Backend
- **Jira:** Ongoing synchronization with the `SCRUM` project for task tracking.
