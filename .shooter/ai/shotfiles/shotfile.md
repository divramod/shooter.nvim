# shotfile

## shot 24
when in a shotfile, i want to be able to have autocompletion for my shooter commands when inserting /shoc, it should propose /shoc:build
when inserting /sh, it should propose all commands starting with /sh like /sho:... /shoc:...

## shot 23
dd does nothing now in the shotfile picker.
please acivate it and 

## x shot 22 HalShooterShotfileLast always opens test-2 shotfile in ~/a/hal (2026-04-06 19:22:02) @shotfile_20260406_192202_shot-22
but its not the last shotfile i edited.

## x shot 21 fix create shotfile (2026-04-06 11:29:04) @shotfile_20260406_112904_shot-21
< >N is failing, please fix it.
i refactored everything in the codebase to use the hal shooter command
after that, the command is failing.
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260406_112859.png

## x shot 20 new shotfile (2026-04-04 07:57:46) @shotfile_20260404_075746_shot-20
when i run < >N to create a new shotfile, i want the cursor to be placed in the title line like how it works, when i create a new shot with < >n

## x shot 19 (2026-02-09 05:06:46) @shot-19-20260209_050646
i have a problem in the ShoLast command.
it is not reliably opening the last edited shotfile
sometimes it opens another one, which i am quite sure, i have not changed as last one.
can you fix it?

## x shot 18 (2026-02-08 16:48:21) @shot-18-20260208_164821
test

## x shot 17 (2026-02-08 16:45:23)
ok, the folder of the shotfiles changed back to .shooter/shotfiles
please reverse it back through the whole codebase

## x shot 16 (2026-02-08 12:37:56) @shot-16-20260208_123756
the shotfiles are now living in the .shooter/project-shotfiles/ folder
please adapt the whole codebase to take this into account

## x shot 15 (2026-02-08 10:20:02) @shot-15-20260208_102002
for the shots coloring.
the first shot of every day in the history of the solved shot should be colored with really light brown.
that way i can easier navigate to old shots.

## x shot 14 (2026-02-08 08:20:18) @shot-14-20260208_082018
create a ShoFileStats command, which lists some interesting stats for the current shotfile like:
- total shots in the file
- open shots in the file
- closed shots in the file
this should be the command < >fs

## x shot 13 (2026-02-08 06:42:18) @shot-13-20260208_064218
it jumps over to the pane in the right file but does this:
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260208_064216.png

## x shot 12 (2026-02-08 06:35:33) @shot-12-20260208_063533
when i press ctrl+g in claude, nvim is opening with the current text of the claude cmd line.
i like to have a command ShoShotCreateFromClaude, which cuts the complete text from the temp file opened by claude, closes it and goes over to the right pane in tmux (nvim is running there) and creates a new shot at the top and pastes the text there. this way i can quickly move text from claude to nvim without having to copy and paste manually.

## x shot 11 (2026-02-08 06:06:52) @shot-11-20260208_060652
please adapt the shotfile notification to show the notification for 3 seconds

## x shot 10 (2026-02-08 06:01:59) @shot-10-20260208_060159
when opening a shotfile, i want a short notification on the top right corner, with the name of the repo and the name of the shotfile and the amount of <open>/<total> shots in the file.

## x shot 9 (2026-02-07 03:24:11)
he pastes something from the image copy clipbaord, as it looks like.

## x shot 8 (2026-02-07 02:57:28)
test

## x shot 7 (2026-02-07 02:52:08)
test

## x shot 6 (2026-02-07 02:47:38)
test

## x shot 5 (2026-02-03 01:19:11)
when a shotfile is empty, and does not have a shot created yes, and only the header is there and i press < >s to create a shot, i want one empty line to be created between the tile header (line 0) and the first shot header (line 3).
the cursor should be placed on line 4 in insert mode as usual.
currently in that case, there is no empty line between the title and the first shot, which looks odd.
also there are two empty lines created after the shot header, which is not necessary.

## x shot 4 (2026-01-29 07:44:12)
the renaming of shotfiles is not working properly.
when i try to rename a shotfile, it creates a new shotfile instead of renaming the existing one.
the bad thing, the content of the file gets lost with renaming.

## x shot 3 (2026-01-24 22:38:15)
can you create the mapping < >l to load the last shotfile which was worked on in the current repo?

## x shot 2 (2026-01-24 12:40:57)
i want to be able to delete a shotfile. what was the command again?

## x shot 1 (2026-01-24 12:27:47)
when i run < >n in the shotfile picker this error happens, after i inserted a shotfile title and entered.
/Users/mod/cod/shooter.nvim/.shooter/shotfiles/images/clipboard_20260124_122744.png
