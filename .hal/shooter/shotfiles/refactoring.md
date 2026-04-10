# refactoring 

## x shot 2 worktree available commands (2026-04-10 09:42:55) @refactoring_20260410_094255_shot-2
when i run < >v, i want to see the list of shotfiles only from the main.
i only write shotfiles into main.
this should also work, when i switched to a different worktree with < >gw2 for example to another branch

## x shot 1 (2026-04-10 06:36:34) @refactoring_20260410_063635_shot-1
a while ago, i refactored the whole code to use calls of a cli instead of doing things directly with lua for the plugin.
i now realized, that the cli is too slow for some things.
i want you to undo these refactoring changes and go back to the old code, where we did things directly with lua for the plugin.
