# shot

## shot 15
think about shot titles.
think about shot priorities.
think about shot metadata in general. hide/show them

## x shot 14 (2026-01-26 06:53:34)
test shot

## x shot 13 (2026-01-26 06:34:01)
for ShooterShotYank, please also mark the shot as done and add the history file for it.
for context.
there are some situations, where i cannot shoot the shot directly and have to do it manually.
for this cases, i want to the history files created anyway, so that i can track my shots properly.

## x shot 12 (2026-01-26 06:31:50)
for both extract commands, can you jump to the extracted shot after the extraction is done?
go to the end of the extracted shot into insert mode.

## x shot 11 (2026-01-26 06:29:36)
create cmd ShooterShotExtractLine and map it additionally to < >E
ShooterShotExtract should also be renamed to ShooterShotExtractBlock to be more explicit.

## x shot 10 (2026-01-26 06:24:01)
for the extract command. instead of having the extracted shot like this:
/Users/mod/cod/shooter.nvim/plans/prompts/images/clipboard_20260126_062240.png

i want it like this:
/Users/mod/cod/shooter.nvim/plans/prompts/images/clipboard_20260126_062337.png

## x shot 9 (2026-01-26 06:25:39)
when shooting a shot from inside a code block, the shot shooter needs to go out of the code block first to indentify the whole shot. i had the problem, that i had a shot inside a code block and the shooter only took the example shot i was just writing in a code block, not the whole shot.

## x shot 8 (2026-01-26 06:21:19)
please do not color the shot header, when it is inside a code block.

## x shot 7 (2026-01-26 06:20:41)
create ShooterShotExtract command.
i just realized, that i start writing big shots in my files with subtopics like this.
```markdown
## shot 2

### subtask 1
some elaborate task

### subtask 2
...
```

sometimes i relaize, damn, this is to big of a shot and i want to extract subtask 2 into its own shot. please write a command for it and also map it additionally to < >e

## x shot 6 (2026-01-26 05:51:13)
cnages my mind, please remap from < >ys to < >z

## shot 5
when answering questions from claude, can i also use the shooter?

## x shot 4 (2026-01-26 05:48:07)
please add a ShooterShotYank command and map it to namespaced commands and also to < >ys

## shot 3
i want to improve the < >o shot picker.
when i open the shot picker, it shows me the open shots from the current shotfile.
i think about having a general shot picker, that shows me all shots from all shotfiles in the repo.
for that, i need to have a way to indicate in the shot picker, from which shotfile the shots are coming from.
kind of a switch mode between "current shotfile shots" and "all shotfile shots".

## x shot 2 (2026-01-24 12:37:55)
moving worked as expected.
but as i watched the result in the file where the shot was moved to, i noticed, that the formatiing of the file was of.

/Users/mod/cod/shooter.nvim/plans/prompts/images/clipboard_20260124_123612.png

there is one rule to follow always.
there should be only one empty line above the shot header. independent of where the shot is moved from.
please enforce that formatting rule, after the shot was moved onto the new shotfile and also the current one.
in the current one i want to stay at the position i was, before i moved the shot away.

## x shot 1 (2026-01-24 12:31:08)
i want to be able to move the shot under the cursor to another shotfile.
< >ms ShooterShotfileMoveShot
