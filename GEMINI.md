# Gemini CLI Workflow Mandates

This project follows a streamlined development workflow to ensure high velocity while maintaining clear traceability through Jira.

## 1. Core Mandates
- **Offline-First & Modular**: The application is primarily offline. Modularity and maintainability are the **HIGHEST priorities** when generating code. Always prefer reusable components, clean abstractions, and modular structures to avoid code duplication ("copy-paste" logic).
- **Service Hub Authority**: The `admin_app` acts as the authoritative Service Hub for the "Online Bridge" (Sync, Chat, Auth).

## 2. Broad Request & Planning Protocol
When a request is broad, complex, or identified as a "multi-step feature":
1. **Initial Plan**: The agent MUST first create a comprehensive plan and stop for user review and approval.
2. **Plan Persistence**: Upon approval, the agent MUST create an `.md` plan file (e.g., in `docs/plans/` or the project root) that divides the task into clear, modular sub-tasks.
3. **Task De-composition**: Break down the implementation into logical increments (e.g., Backend -> Provider -> UI).
4. **Context Checkpointing (/compress)**: After each successful sub-task, the agent MUST stop and wait for the user to confirm they have executed the `/compress` command (to clear session history) before proceeding to the next sub-task.
5. **Instruction Wait**: Once all sub-tasks in a plan are finished, the agent MUST stop and wait for another instruction.

## 3. SCRUM & Jira Automation
- **Task Initiation**: Whenever the user requests a new feature or task, the agent MUST use the Atlassian MCP server to create a new Jira SCRUM ticket (e.g., `SCRUM-XX`). 
- **Naming**: The agent will automatically generate a descriptive title and description for the ticket based on the user's request.
- **Sprint Management**: For general feature additions or fixes, the agent MUST create a new Jira sprint (if a suitable active one doesn't exist) and move the corresponding SCRUM tickets into it before starting work.
- **Traceability**: Every commit message MUST start with the corresponding Jira ticket key (e.g., `SCRUM-XX: implemented feature y`).
- **Resilient SCRUM Tracking**: If the Atlassian server is unreachable, the agent MUST still proceed with the development and commit. In this case, the agent will check the git log for the last used key (e.g., `SCRUM-67`), increment the number (to `SCRUM-68`), and use it for the commit prefix. The agent MUST explicitly mention in the commit message that Jira was offline. Once connectivity is restored, the agent (or the user) should ensure the corresponding ticket is created to maintain history.

## 4. Git Workflow (Direct-to-Dev)
To maintain momentum, all development is performed directly on the **`development`** branch.
1. **Sync**: Always start by pulling the latest changes: `git pull origin development`.
2. **Develop**: Implement the requested changes directly on the `development` branch.
3. **Verify**: Use the Dart MCP `analyze_files` tool for static analysis (it is faster and more efficient for identifying errors) and run compilation checks (`py_compile`) before committing.
- **Commit**: Commit with the Jira key prefix: `git commit -m "SCRUM-XX: description"`.
- **Deployment (Auto-Push)**:
    - If the changes include **Backend (Python/FastAPI)** code, the agent MUST automatically push to origin immediately after committing to trigger the Render deployment.
    - For **Frontend-only** changes, the agent should ask the user before pushing, or push immediately if specifically requested.
- **Jira Finalization**: Once the task is committed and pushed, the agent MUST update the corresponding Jira ticket (transition to 'Done' or add a comment) to reflect the completion.

## 5. Project Structure
- `backend/`: Python (FastAPI/Firebase) backend.
- `frontend/`: Flutter/Flame application.
- `admin_app/`: Standalone Flutter Admin Control Center.

## 6. Standardized Naming & Data
- **Naming Convention**: Use `camelCase` for all Firestore field names.
- **User Identification**: Always use the Firebase `uid` as the primary document ID.
- **Data Serialization**: Convert Firestore "Sentinels" to ISO strings in backend responses.

## 7. Deployment & Environments
- **Render Deployment**: Render monitors the `development` branch. 
- **Mandate**: Backend changes ONLY take effect on the live server after they are pushed to the `development` branch on origin.
