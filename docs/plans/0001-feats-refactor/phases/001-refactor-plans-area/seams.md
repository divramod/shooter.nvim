# Seam plan — `lua/shooter/plans/metaplan.lua` (1584 LOC)

Produced by Phase 001 T001. Defines the per-sub-module function placement for T004's split.

## Function inventory (49 functions)

Source: `grep -nE "^(function|local function|function M\.)" lua/shooter/plans/metaplan.lua`.

## Proposed sub-modules

Soft cap is 350 LOC per sub-module. Estimated LOC includes the function body + module-prelude (`local M = {} ... return M`).

### `metaplan/parse.lua` — markdown → AST (~150 LOC)

Parses a metaplan.md file into a structured AST: title, ordered list of (section, plans).

- `slugify(text)` — line 120 — text → kebab-case
- `strip_prefix(text)` — line 126 — pulls existing `NNNN-` prefix
- `split_at_parens(text)` — line 136 — separates "name (paren)" pairs
- `is_top_entry(line)` — line 149 — `^- `
- `is_header(line)` — line 150 — `^## `
- `is_child_line(line)` — line 151 — child note (indented `  -`)
- `is_canonical(name)` — line 198 — name format check
- `is_timestamp_paren(s)` — line 213 — date marker for done section
- `extract_description_paren(text)` — line 222 — pull paren content
- `parse(content)` — line 160 — main parse entry
- `extract_extras(entry)` — line 265 — pull description + notes from a parsed entry
- `extract_plan_name(line)` — line 1164 — convenience for command callers

### `metaplan/render.lua` — AST → markdown (~110 LOC)

Renders the parsed AST back to a normalized metaplan.md, preserving notes and parens, sorting categories, etc.

- `render_entry(entry, out)` — line 203
- `dedent_child_notes(children)` — line 251
- `render(parsed, title, opts)` — line 426 — main render entry

### `metaplan/numbering.lua` — NNNN allocation, gap-fill, classification (~180 LOC)

Plan numbering and per-plan classification across worktrees.

- `classify_plan(git_root, plan_name, worktree_roots)` — line 60
- `plan_files_in_worktree(wt_root, plan_name)` — line 108
- `list_worktree_roots(git_root)` — line 276
- `collect_used_numbers(git_root, sections, worktree_roots)` — line 309
- `next_plans_number_at(used, k)` — line 399
- `next_free_plan_number(git_root, sections)` — line 413

### `metaplan/io.lua` — file + buffer + git helpers (~80 LOC)

Low-level I/O so other sub-modules don't carry their own copies.

- `read_file(path)` — line 517
- `write_file(path, content)` — line 525
- `find_loaded_buf(path)` — line 503
- `close_buf_for(path)` — line 1450
- `flush_plans_buffers(git_root)` — line 1210
- `git(git_root, args)` — line 1251 — internal git wrapper
- `commit_plans(git_root, message)` — line 1265

### `metaplan/meta.lua` — title/path/alias + cursor open (~80 LOC)

Top-level conveniences used by command bindings.

- `get_path(git_root)` — line 23
- `get_alias(git_root)` — line 27
- `get_title(git_root)` — line 37
- `edit_plan_at_line(git_root, line)` — line 1173
- `open_plan_file(git_root, line, kind)` — line 1188

### `metaplan/idea.lua` — plan-idea ops + new-plan creation (~250 LOC)

Creates a new plan folder + idea.md, appends paren/note extras to existing idea files.

- `idea_path(git_root, plan_name)` — line 534
- `ensure_plan_idea(git_root, plan_name)` — line 543
- `apply_extras_to_idea(git_root, plan_name, paren_text, note_lines)` — line 574
- `append_to_next_plans(git_root, plan_name)` — line 684
- `new_plan(git_root, title)` — line 742

### `metaplan/rename.lua` — plan rename (path-traversal-sensitive) (~250 LOC)

Folder rename + metaplan-line rewrite + title-reference rewrite. **Security focal point — Phase 001 T005 hardens this.**

- `rename_plan_folder(git_root, old_name, new_name)` — line 773
- `rewrite_metaplan_line(git_root, old_name, new_name)` — line 1363
- `remove_metaplan_entry(git_root, name)` — line 1402
- `replace_title_reference(path, needle, replacement)` — line 1343
- `rename_plan(git_root, old_name, new_name)` — line 1464

### `metaplan/delete.lua` — plan delete + preflight (~120 LOC)

- `is_stub_file(path)` — line 1311
- `folder_has_content(dir)` — line 1326
- `delete_plan_preflight(git_root, name, force)` — line 1526
- `delete_plan(git_root, name, opts)` — line 1548

### `metaplan/mark_done.lua` — mark a plan done in the metaplan (~80 LOC)

- `mark_done(git_root, lnum)` — line 1088

### `metaplan/fix.lua` — orchestrator (~280 LOC)

The big `fix()` pipeline. Calls into parse → numbering → rename → render → io.

- `fix(git_root)` — line 821

### `metaplan/init.lua` — public surface re-exporter (~50 LOC)

Re-exports the existing public surface so `require('shooter.plans.metaplan').<fn>` keeps working unchanged. **No logic.** Import each sub-module and copy its public functions onto `M`.

## Public surface (must be preserved)

Functions on `M` callable by external requires today:

```
get_path, get_alias, get_title, classify_plan, plan_files_in_worktree,
slugify, parse, extract_extras, list_worktree_roots, collect_used_numbers,
next_plans_number_at, next_free_plan_number, render, idea_path,
ensure_plan_idea, apply_extras_to_idea, new_plan, fix, mark_done,
extract_plan_name, edit_plan_at_line, open_plan_file, commit_plans,
is_stub_file, folder_has_content, rewrite_metaplan_line,
remove_metaplan_entry, rename_plan, delete_plan_preflight, delete_plan
```

Total: 30 public functions. The `init.lua` shim must re-export all 30. A test (Phase 001 T002 or T003) enumerates the expected surface and asserts each is callable post-split.

## Dep graph

```
parse  ─────────────┐
                    ├──▶ numbering ─┬─▶ idea ─────┐
io ────┬──▶ render ─┘                │             │
       │                              ├─▶ rename ──┤
       └──▶ delete ─────────────────  │             ├──▶ fix ──▶ init
       └──▶ mark_done ────────────────┘             │
       └──▶ meta ─────────────────────────────────┘
```

No cycles. `parse`, `render`, `io` are leaves (no shooter.plans.metaplan deps); `numbering` uses `parse`; `idea`/`rename`/`delete`/`mark_done` use `parse + render + io + numbering`; `fix` orchestrates everything; `init` re-exports.

## Risks

- `fix()` is 280 LOC and may itself benefit from internal extraction (sub-passes for renumber / sync-stubs / commit). Defer that to Phase 001 T004 — the seam plan deliberately keeps `fix.lua` as one file to limit churn.
- The `meta.lua` sub-module is a thin wrapper. Could be folded into `init.lua` but kept separate so `init.lua` stays logic-free.
- Public-surface count (30) is high; the smoke test must enumerate them explicitly.
