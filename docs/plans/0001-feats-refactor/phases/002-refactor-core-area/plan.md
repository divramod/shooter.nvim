---
name: refactor-core-area
description: core/ refactor — split commands.lua, shot_actions.lua, files.lua, ext_config.lua, shotfile_fix.lua; harden core shell-outs.
status: approved
phase_id: 002
depends_on: ["000"]
wave: 2
created: 2026-04-26
tier: large
tier_source: deterministic
---

# Phase 002 — Refactor `core/` Area

## Overview

The largest area by both LOC and security-surface. Files at risk of split:

| file                          | LOC  | likely seam                                     |
|-------------------------------|------|-------------------------------------------------|
| `lua/shooter/commands.lua`    | 1190 | per sub-area: plans / shotfile / git / tmux     |
| `lua/shooter/core/shot_actions.lua` | 795  | per action class: copy / move / fix / send |
| `lua/shooter/core/files.lua`  | 456  | git-detect / path-ops / repo-walk               |
| `lua/shooter/core/ext_config.lua` | 416 | parse / validate / merge                        |
| `lua/shooter/core/shotfile_fix.lua` | 312 | already at threshold; review-only       |

`commands.lua` may earn an `ALLOWED_LARGE_FILES` exception if Phase 000's read shows it's a flat dispatcher table. Resolve in T001.

## Architecture

Conditional layouts (decided in T001):

**If split:**
```
lua/shooter/commands/
  init.lua            # registers all user commands; calls submodule setup() in order
  plans.lua           # plan-related commands
  shotfile.lua        # shot-related commands
  git.lua             # git commands
  tmux.lua            # tmux commands
  view.lua            # picker / open / link
```

```
lua/shooter/core/shot_actions/
  init.lua
  copy.lua
  move.lua
  fix.lua
  send.lua
```

```
lua/shooter/core/files/
  init.lua
  git.lua             # repo-root detection, worktree list
  path.lua            # join / canonicalize / reject
  walk.lua            # recursive enumeration
```

`ext_config.lua` → split into `core/ext_config/{init,parse,validate,merge}.lua`.

## Approach

1. Read each split-candidate file once; produce per-file seam plan + `ALLOWED_LARGE_FILES` decision in T001.
2. Tests-first across all of `core/` — combined coverage ≥ 80% before any split.
3. Split in dependency order: `files.lua` first (others depend on it), then `commands.lua`, then `shot_actions.lua`, then `ext_config.lua`.
4. Apply core/-area security fixes — `core/files.lua` shell-outs to git, `shot_actions.lua` tmux send-keys, any `core/project.lua` interpolated `ls` calls.
5. Verify smoke loader, full test suite, coverage.

## Tasks

- [x] **T001** — Read & seam-map each split-candidate
  - **Acceptance:** `seams.md` lists per-file seam plan and an `ALLOWED_LARGE_FILES` decision (split / exception) with rationale for each of the five files. `commands.lua` decision documented explicitly.
  - **Verify:** `phases/002-refactor-core-area/seams.md` exists with all five files listed.
  - **Files:** `docs/plans/0001-feats-refactor/phases/002-refactor-core-area/seams.md`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T002** — Characterization tests for `core/files.lua` + `core/ext_config.lua`
  - **Acceptance:** Coverage of the two files ≥ 80%; existing tests in `tests/core/` not duplicated; new tests use tmpdir fixtures.
  - **Verify:** Tests green; relevant lines in `luacov.report.out` ≥ 80%.
  - **Files:** `tests/core/files_*_spec.lua`, `tests/core/ext_config_*_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T003** — Characterization tests for `commands.lua` + `shot_actions.lua` + `shotfile_fix.lua`
  - **Acceptance:** Coverage of the three files ≥ 80%.
  - **Verify:** Tests green; `awk '/lua\/shooter\/(commands|core\/(shot_actions|shotfile_fix))/' luacov.report.out` ≥ 80%.
  - **Files:** `tests/core/shot_actions_*_spec.lua`, `tests/core/shotfile_fix_spec.lua`, `tests/commands_*_spec.lua`
  - **Size:** XL
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T004** — Split `core/files.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module; existing callers see no change.
  - **Verify:** `find lua/shooter/core/files -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/core/files/*.lua`, `lua/shooter/core/files.lua`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T005** — Split `core/ext_config.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module.
  - **Verify:** `find lua/shooter/core/ext_config -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/core/ext_config/*.lua`, `lua/shooter/core/ext_config.lua`
  - **Size:** M
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T006** — Resolve `commands.lua` (split or exception)
  - **Acceptance:** Per T001's decision: either split into `commands/` sub-modules with registration order preserved, OR add `ALLOWED_LARGE_FILES: lua/shooter/commands.lua` with rationale to `baseline.md`. User command registration must still work after T006 — every existing `:HalShooter…` command resolves on a fresh Neovim.
  - **Verify:** Smoke loader passes; a new test `tests/commands_registration_spec.lua` enumerates expected user commands and asserts all are registered post-setup.
  - **Files:** Either `lua/shooter/commands/*.lua` + shim, or only `docs/plans/0001-feats-refactor/baseline.md`; plus `tests/commands_registration_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T007** — Split `core/shot_actions.lua`
  - **Acceptance:** Per T001's seam plan; ≤ 350 LOC per sub-module.
  - **Verify:** `find lua/shooter/core/shot_actions -name '*.lua' -exec wc -l {} + | awk '$1>350{exit 1}'`; tests + smoke green.
  - **Files:** `lua/shooter/core/shot_actions/*.lua`, `lua/shooter/core/shot_actions.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [x] **T008** — Core/-area security fixes
  - **Acceptance:** Every core/ finding from `baseline.md` fixed or deferred. Specific known issues to address:
    - `lua/shooter/core/shot_actions.lua:768-779` — tmux send-keys with interpolated pane id; verify pane id is sanitized.
    - `lua/shooter/core/project.lua:45` — `io.popen('ls -1 "' .. projects_dir .. '" 2>/dev/null')` — replace with `vim.fn.readdir` or shellescape.
    - `lua/shooter/core/files.lua:104,111,120,133` — git invocations; ensure paths are shellescaped.
    - `lua/shooter/utils.lua:128,139,204` — generic shell-out helpers; make table-form-by-default.
  - **Verify:** Targeted tests (`tests/core/security_spec.lua`) cover canonical-path-rejection and shell-injection-resistance for the listed sites.
  - **Files:** Listed sites + `tests/core/security_spec.lua`
  - **Size:** L
  - **State:**
    - [x] built
    - [x] tested
    - [x] reviewed
    - [x] shipped

- [ ] **T009** — Verify final state
  - **Acceptance:** Full suite green; coverage of `lua/shooter/core/**` + `lua/shooter/commands*` ≥ 80%; smoke loader green; user-command registration test green.
  - **Verify:** `:PlenaryBustedDirectory tests/` green; `awk '/lua\/shooter\/core/||/lua\/shooter\/commands/' luacov.report.out` ≥ 80%.
  - **Files:** —
  - **Size:** S
  - **State:**
    - [ ] built
    - [ ] tested
    - [ ] reviewed
    - [ ] shipped

## Risks

- `commands.lua` registration order matters; a refactor can silently change command availability. Mitigation: T006's registration test enumerates expected commands.
- `shot_actions.lua` interacts with tmux on the live session (the test suite under headless nvim has no tmux). Tests must `pending()` when `$TMUX` is unset.
- Many existing tests already in `tests/core/` — duplication risk. T002/T003 reads existing first.

## Open Questions

1. Are user commands defined in `commands.lua` or in a setup function called from a plugin entrypoint? Determines whether splitting requires changing `lua/shooter/init.lua`.
2. `utils.lua` (root, not `core/`) hosts shell-out helpers used by core. Touched in T008 — does it warrant its own phase? Default: include in 002 since it's a core dependency.
