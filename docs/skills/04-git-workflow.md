# Git Submodule Workflow Skill

## Context
We use Git Submodules to manage `tofi-core` (backend) and `tofi-ui` (frontend). This allows them to be independent repositories while being aggregated here.

## The "Update Parent" Rule
**Goal:** Whenever code is modified and committed inside `tofi-core/` or `tofi-ui/`, the parent repository MUST be updated to point to the new commit hash.

### Why?
If you commit inside `tofi-core` but don't commit the change in the parent `tofi` repo, other developers (or CI/CD) pulling the parent repo will still see the *old* version of the core code.

## Workflow

### Option A: Manual (Standard)
1. Make changes in `tofi-core/`.
2. `cd tofi-core` -> `git add .` -> `git commit` -> `git push`.
3. `cd ..` (Back to root).
4. `git add tofi-core` (Stage the new pointer).
5. `git commit -m "chore: update core submodule"`.

### Option B: Automated (Recommended)
Use the provided helper script which handles submodules and the parent update in one go.

```bash
chmod +x scripts/git-sync.sh
./scripts/git-sync.sh "feat: implemented login logic"
```

## Checklist for AI Agents
When asking an AI to perform git operations:
- [ ] Check if the change involves `tofi-core` or `tofi-ui`.
- [ ] If yes, verify if the submodule commit was successful.
- [ ] **Crucial:** Always navigate back to root and `git add <submodule_path>` to lock in the version change.
