# Gemini CLI Workflow Mandates

This project follows a strict development workflow to ensure consistency and clean repository management.

## Git Workflow
For every new task (SCRUM-XX):
1. **Branch Creation**: Create a new branch from `development` with the name `SCRUM-XX-task-name`.
2. **Implementation**: Perform the required changes within the branch and push to origin.
3. **Review**: Create a Pull Request (PR) to `development`. **Wait for Baz review and user confirmation.**
4. **Finalization**: ONLY after the user explicitly confirms:
   - Switch to `development` and merge.
   - Delete the local branch: `git branch -d SCRUM-XX-task-name`.
   - Delete the remote branch: `git push origin --delete SCRUM-XX-task-name`.

## Project Structure
- `backend/`: Python (FastAPI/Firebase) backend.
- `frontend/`: Flutter/Flame application.

## Asset Management
Always register new assets in `frontend/pubspec.yaml` under the appropriate category to ensure the Flame engine can load them correctly.
