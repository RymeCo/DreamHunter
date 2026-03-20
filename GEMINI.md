# Gemini CLI Workflow Mandates

This project follows a streamlined development workflow to ensure high velocity while maintaining clear traceability through Jira.

## SCRUM & Jira Automation
- **Task Initiation**: Whenever the user requests a new feature or task, the agent MUST use the Atlassian MCP server to create a new Jira SCRUM ticket (e.g., `SCRUM-XX`). 
- **Naming**: The agent will automatically generate a descriptive title and description for the ticket based on the user's request.
- **Traceability**: Every commit message MUST start with the corresponding Jira ticket key (e.g., `SCRUM-XX: implemented feature y`).

## Git Workflow (Direct-to-Dev)
To maintain momentum, all development is performed directly on the **`development`** branch.
1. **Sync**: Always start by pulling the latest changes: `git pull origin development`.
2. **Develop**: Implement the requested changes directly on the `development` branch.
3. **Verify**: Run static analysis (`flutter analyze`) and compilation checks (`py_compile`) before committing.
4. **Commit**: Commit with the Jira key prefix: `git commit -m "SCRUM-XX: description"`.
5. **Deployment (Auto-Push)**:
    - If the changes include **Backend (Python/FastAPI)** code, the agent MUST automatically push to origin immediately after committing to trigger the Render deployment.
    - For **Frontend-only** changes, the agent should ask the user before pushing, or push immediately if specifically requested.

## Project Structure
- `backend/`: Python (FastAPI/Firebase) backend.
- `frontend/`: Flutter/Flame application.
- `admin_app/`: Standalone Flutter Admin Control Center.

## Standardized Naming & Data
- **Naming Convention**: Use `camelCase` for all Firestore field names.
- **User Identification**: Always use the Firebase `uid` as the primary document ID.
- **Data Serialization**: Convert Firestore "Sentinels" to ISO strings in backend responses.

## Deployment & Environments
- **Render Deployment**: Render monitors the `development` branch. 
- **Mandate**: Backend changes ONLY take effect on the live server after they are pushed to the `development` branch on origin.

## GSD Mode (Get Shit Done)
**Isolated Automation**: This directory supports GSD automation. 
- **Toggle**: Use `/gsd:on` to enable auto-commits and `/gsd:off` to disable them.
- **Workflow**: When GSD is ON, every file change triggers a local git commit with the current active SCRUM key. 
