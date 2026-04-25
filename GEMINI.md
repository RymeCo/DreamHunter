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
- **Change Tracking:** Instead of external scrum files, all major task completions are logged in the [CHANGELOG.md](./CHANGELOG.md) file.

## 5. Strict Validation & Git Workflow
- **Pre-Commit Mandate:** Every commit MUST pass `analyze_files` (static analysis) for the relevant component.
- **Auto-Fix:** Run `dart_fix` and `dart_format` before committing Flutter code.
- **Feature Branches:** Use feature branches for all development (e.g., `git checkout -b feature/SCRUM-123`).
- **PR Workflow:** Merge changes into the `development` branch via Pull Requests or simulated reviews. Never commit directly to `development`.
- **Sync:** Always `git pull origin development` to stay updated with the main integration branch.

## 6. Mandatory Documentation (Append-Only)
Every non-trivial edit MUST be documented by **appending** a new entry to the `CHANGELOG.md` file in the project root. 
- **Format:** Use a bulleted list format.
- **Rule:** Do NOT modify previous entries. Always add to the end.
- **Content:** Date, Task/Ticket ID, and a brief description of the change.

## 7. Gameplay Rewrite Mandate (Composition & Behavior Architecture)
- **Composition First:** All game entities MUST inherit from `BaseEntity` and use behaviors for logic.
- **Categorization:** Every entity MUST have a `categories` property (tags).
- **Effects Engine:** Buffs/debuffs MUST use the `Effect` and `EffectReceiverBehavior` system.
- **Tiled Map Sync:** Map architecture MUST stay synced with `dorm-01.tmx`.

## 8. Change Log Reference
The append-only change log has been migrated to a dedicated file for better maintainability and context efficiency.
- **Location:** [CHANGELOG.md](./CHANGELOG.md)
