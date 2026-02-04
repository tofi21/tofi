# RULESET: GIT & SUBMODULE WORKFLOW

## REPO STRUCTURE

```
tofi/                    # Parent repo (aggregator)
  tofi-core/             # Submodule — Go backend engine
  tofi-ui/               # Submodule — React frontend
  docs/                  # Shared documentation (skills, progress)
```

## THE SUBMODULE UPDATE RULE

When you commit inside `tofi-core/` or `tofi-ui/`, the **parent repo must be updated** to point to the new commit hash. Otherwise other developers pulling the parent will see the old version.

### Workflow

1. Make changes in submodule (e.g. `tofi-core/`)
2. `cd tofi-core` → `git add` → `git commit` → `git push`
3. `cd ..` (back to root)
4. `git add tofi-core` (stage the new pointer)
5. `git commit -m "chore: update core submodule"`

### Helper Script
```bash
chmod +x scripts/git-sync.sh
./scripts/git-sync.sh "feat: implemented login logic"
```

## COMMIT CONVENTIONS

Follow conventional commits:
- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code restructuring
- `docs:` — documentation only
- `chore:` — maintenance, submodule updates

## CHECKLIST FOR AI AGENTS

When performing git operations:
- [ ] Check if the change is in `tofi-core` or `tofi-ui` (submodule)
- [ ] If submodule: commit inside submodule first, then update parent
- [ ] If docs only (in root `docs/`): commit directly in parent repo
- [ ] Never force-push to main/master
- [ ] Use `git add -f` for files in `.gitignore` directories (e.g. `tofi-core/docs/`)

## GOTCHA: GITIGNORED DOCS IN TOFI-CORE

`tofi-core/.gitignore` includes `docs/`. To commit documentation files there, use:
```bash
git -C tofi-core add -f docs/NODE_REFERENCE.md docs/nodes/
```
