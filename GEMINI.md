# Gemini CLI Workflow Mandates

This project follows a strict development workflow to ensure consistency and clean repository management.
SCRUM-39 is the focus for the Admin Backend infrastructure.
SCRUM-38 is the focus for the standalone Admin Flutter App.
SCRUM-35 is the focus for performance optimization, startup fixes, and general cleanup.
SCRUM-33 is always the go to if its just minor change so this scrum is called  clean up so use this for commits

## Git Workflow
For every new task (SCRUM-XX):
0. **Initiation Mandate**: The agent MUST instruct the user to provide a Jira/SCRUM ticket number for the feature. Once provided, the agent will automatically generate a descriptive task name based on the current objective and create the corresponding branch (e.g., `SCRUM-XX-task-name`).
1. **Branch Creation**: Create a new branch from `development` with the name `SCRUM-XX-task-name`.
2. **Implementation**: Perform the required changes within the branch. **DO NOT push to origin automatically; always ask the user for confirmation before pushing.**
3. **Review**: Create a Pull Request (PR) to `development` (after user confirms push). **Wait for Baz review and user confirmation.**
4. **Finalization**: ONLY after the user explicitly confirms:
   - Switch to `development` and merge.
   - Delete the local branch: `git branch -d SCRUM-XX-task-name`.
   - Delete the remote branch: `git push origin --delete SCRUM-XX-task-name`.

## Project Structure
- `backend/`: Python (FastAPI/Firebase) backend.
- `frontend/`: Flutter/Flame application.

## Standardized Naming & Data
- **Naming Convention**: Use `camelCase` for all Firestore field names (e.g., `displayName`, `playerNumber`, `createdAt`) across both backend and frontend.
- **User Identification**: Always use the Firebase `uid` as the primary document ID for user records in the Firestore `users` collection.
- **Data Serialization**: In backend JSON responses, convert Firestore "Sentinels" (like `SERVER_TIMESTAMP`) to ISO strings (`now.isoformat()`) to ensure compatibility.

## Backend Standards (FastAPI)
- **RESTful Design**: Use lowercase, kebab-case for URL paths (e.g., `/users/display-name`).
- **HTTP Methods**: Use `GET` for fetching, `PATCH` for partial updates, and `POST` for creating new resources.
- **Security**: Every protected endpoint must use the `verify_firebase_token` dependency and expect an `Authorization: Bearer <ID_TOKEN>` header.
- **Secrets Management**: Never commit `serviceAccountKey.json`. Use the `FIREBASE_SERVICE_ACCOUNT` environment variable for production deployment on Render.

## Frontend Standards (Flutter)
- **Service Layer**: Centralize API communication in the `BackendService` class. Do not use the `http` package directly in screens or widgets.
- **UI Consistency**: Maintain the "Glassmorphism" aesthetic by using the `LiquidGlassDialog` for all modal windows and dropdown menus.
- **Interaction Feedback**: Always use `showCustomSnackBar` for user notifications (success/error/info) to ensure a consistent look and feel.
- **Flutter Modernization**: Avoid deprecated members. Use `.withValues(alpha: 0.x)` instead of `withOpacity()`. Enable `android:enableOnBackInvokedCallback="true"` in the manifest for modern Android gestures.

## Asset Management
Always register new assets in `frontend/pubspec.yaml` under the appropriate category to ensure the Flame engine can load them correctly.

## SCRUM Finalization
- **Post-Merge Cleanup**: Once a PR is successfully merged into `development`, immediately delete the local task branch and the remote branch to keep the repository clean.
- **Workflow Integrity**: A SCRUM task is only "Done" when the feature is merged and the branch is removed from both local and origin.
