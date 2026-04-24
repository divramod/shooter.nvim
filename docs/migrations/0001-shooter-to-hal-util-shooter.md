# 0001 — `.shooter/` → `.hal/util/shooter/`

Every runtime path that shooter.nvim reads or writes is now rooted
under `hal/util/shooter/`. Nothing in the codebase points at the old
`.shooter/` folder or at `~/.config/shooter/nvim/` / `~/.config/shooter.nvim/`
anymore.

## Why

A single namespace (`hal/util/shooter/`) for everything the plugin
manages — project data under `<repo>/.hal/util/shooter/`, machine data
under `~/.config/hal/util/shooter/`. Keeps all "hal" plugin state
colocated.

## What changed in the code

See commits:
- `refactor(hal): move shooter paths under hal/util/shooter`
- `docs: update every .shooter / ~/.config/shooter reference to hal/util/shooter`

Runtime path-constants, regex matchers, help text, and `.planning` docs
are all rehomed. No fallback to the old paths — the migration below
must be run once per repo and once per machine.

## How to migrate

### 1. Per repo (anywhere you used `.shooter/`)

```sh
cd <your-repo>
[ -d .shooter/ai ]          && git mv .shooter/ai          .hal/util/shooter/ai
[ -d .shooter/tmp ]         && git mv .shooter/tmp         .hal/util/shooter/tmp
[ -e .shooter/themes.json ] && git mv .shooter/themes.json .hal/util/shooter/themes.json
[ -d .shooter/codebase ]    && git mv .shooter/codebase    .hal/util/shooter/codebase
[ -d .shooter/config/nvim ] && mkdir -p .hal/util/shooter/config \
    && git mv .shooter/config/nvim .hal/util/shooter/config/nvim
[ -d .shooter/cfg/nvim ]    && mkdir -p .hal/util/shooter/cfg \
    && git mv .shooter/cfg/nvim    .hal/util/shooter/cfg/nvim
rmdir .shooter/config .shooter/cfg .shooter 2>/dev/null || true
git add -A -- .shooter .hal/util/shooter
git commit -m "chore(hal): move .shooter config to .hal/util/shooter"
```

If a sub-tree already exists on both sides (e.g. you already started
using `.hal/util/shooter/ai/` in parallel), skip that `git mv` and
merge by hand:

```sh
rsync -a --ignore-existing .shooter/ai/ .hal/util/shooter/ai/
diff -rq .shooter/ai .hal/util/shooter/ai   # hand-inspect
rm -rf .shooter/ai
```

### 2. Global (once per machine)

```sh
mkdir -p ~/.config/hal/util/shooter
[ -d ~/.config/shooter/nvim ] && mv ~/.config/shooter/nvim ~/.config/hal/util/shooter/nvim
rmdir ~/.config/shooter 2>/dev/null || true

# Legacy dotted path (some machines still have it):
if [ -d ~/.config/shooter.nvim ]; then
  rsync -a --ignore-existing ~/.config/shooter.nvim/ ~/.config/hal/util/shooter/nvim/
  diff -rq ~/.config/shooter.nvim ~/.config/hal/util/shooter/nvim   # hand-inspect
  rm -rf ~/.config/shooter.nvim
fi
```

`rsync --ignore-existing` never overwrites files already present in
the destination, so anything you've already updated in the new
location is safe.

## Verify

After migration these commands should print nothing:

```sh
# In every repo:
find . -name .shooter -type d

# On the machine:
find ~/.config/shooter ~/.config/shooter.nvim -maxdepth 0 -type d 2>/dev/null
```
