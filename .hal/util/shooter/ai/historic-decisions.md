## tmux pane variables for provider detection (2026-04-01 18:30)

**Theme:** shooter.nvim
**Decision:** Use tmux per-pane user variables (`@shooter_provider`) instead of `ps aux` grep for detecting which AI provider runs in a tmux pane. hal sets the variable before launching an agent and clears it on exit. shooter.nvim reads it first, falling back to ps-based TTY detection for direct (non-hal) launches.
**Reason:** When hal wraps all agent launches, `ps aux` shows `hal` as the foreground process for every pane, making provider-specific detection impossible. tmux `@`-prefixed pane variables are isolated per-pane, instantly queryable, and don't require process tree inspection.
**Implementation:** hal `launch_agent()` calls `tmux set -p -t $TMUX_PANE @shooter_provider <agent>` before spawning and clears it after exit. shooter.nvim's `get_all_pane_providers()` batch-reads all panes in one `tmux list-panes -a` call. Detection cascade: tmux variable -> ps-based TTY matching.
**Bead:** shov-t18.2
