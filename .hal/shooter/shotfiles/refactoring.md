# refactoring 

## shot 8 

## shot 7 

## x shot 6 fix renumbering (2026-04-10 10:15:42) @refactoring_20260410_101542_shot-6
when i run < >sr, it runs the sorting in the wrong direction.
can you fix that?

## x shot 5 fix new shot (2026-04-10 10:13:31) @refactoring_20260410_101331_shot-5
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260410_101126.png
i ran < >n in this file.
as you see, there are gaps in the shot numbers.
i want you to renumber the shot numbers so that they are no gaps, before you insert the new shot

## x shot 4  add shot 4 to new files (2026-04-10 09:57:18) @refactoring_20260410_095719_shot-4
when running < >N, before the refactoring, it would also add a shot 1 and jump to it in insert mode ad `## shot _`
this does not work anymore.
can you fix it?

## x shot 3 its still showing the shotfile from the worktree (2026-04-10 09:49:14) @refactoring_20260410_094914_shot-3
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260410_094911.png

## x shot 2 worktree available commands (2026-04-10 09:42:55) @refactoring_20260410_094255_shot-2
when i run < >v, i want to see the list of shotfiles only from the main.
i only write shotfiles into main.
this should also work, when i switched to a different worktree with < >gw2 for example to another branch

## x shot 1 (2026-04-10 06:36:34) @refactoring_20260410_063635_shot-1
a while ago, i refactored the whole code to use calls of a cli instead of doing things directly with lua for the plugin.
i now realized, that the cli is too slow for some things.
i want you to undo these refactoring changes and go back to the old code, where we did things directly with lua for the plugin.
