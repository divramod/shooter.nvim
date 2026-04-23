# feats

## x shot 12 < >gp should also include all <reporoot>/docs files in the commit (2026-04-23 07:37:35)

## x shot 11 < >y should also copy the header of the shot (2026-04-15 02:23:01)

## x shot 10 the base path for the shooter files is now .hal/util/shooter/shotfiles (2026-04-15 00:58:09)
it changed, please adapt all commands to this new path 

## x shot 9 < >X improvements (2026-04-14 23:42:21)
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260414_234035.png
for the links in the tmux link picker, do they only take the ones from the current screen?
or do they use the tmux history?

## x shot 8 < >x improvements (2026-04-14 23:39:47)
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260414_233820.png
i want that the picker takes 100 % of the width, when the window is small
also, can we add a new thing?
i would like to have the last changed date of the link/file in the picker
like in the shotfile picker (5min, 2h 5m, 3d 2h, etc.)

## x shot 7 < >x improvements (2026-04-14 23:33:05)
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260414_233115.png
i want the line number:pos in parantheses behind the link
instead of [dir] [file] i want icons for the filetype and folder.
i think i have nerd font icons installed or something like this

result
<icon> <link> (line:pos)

## x shot 6 < >fff improvement (2026-04-14 13:04:58)
The command does not delete the last line when it is empty. I never want to have an empty line at the end of a file. Please adapt this command to also remove whitespace from the end.

## x shot 5 HalShooterShotfileFix (2026-04-14 06:04:44)
map it to < >fff
1. fixes the title (reuse fix title)
2. ensures, that above every `## shot` header is only one empty line until the next text
3. ensures, that there are no empty shots. a empty shot looks like this
```markdown
## shot 5
...
## shot 4
some content

## shot 3 hello
```
shot five is the empty one, neither have a title, nor content.
4. renumbers all shots (reuse renumber functionality), so that the numbering is correct
5. git adds and commits the file with a senseful commit message

## x shot 4 HalShooterGitPush (2026-04-12 19:45:09)
I want a command that git adds, commits, and pushes the `.shooter` folder. 
map it to < >gp

## x shot 3 < >fmm improvements (2026-04-12 13:36:47)
also, when a file is moved from a subfolder, which only contains this one file, to another folder, the empty folder should be deleted.

## x shot 2 < >fmm improvements (2026-04-12 13:16:44)
i want to move a shotfile
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260412_131237.png
this is the file from where i start the command.
.../shotfiles/apps/next.md
i want to be able to insert the following in the telescope picker input field, with the following results
```txt
# case 1: input apps/next/domain
- moves the file to .../shotfiles/apps/next/domain.md and adapts the title accordingly to `# apps/next/domain`

# case 2: input apps/next/
- moves the file to .../shotfiles/apps/next/next.md and adapts the title accordingly to `# apps/next/next`

in general, when the last sign is a /, the file should just be moved and the folder should be created if it does not exist, the name stays the same

if the last sign is not a /, the file should be moved and renamed to the name of the last part of the path, and the title should be adapted accordingly

in every case, the title should be adapted to the new path and name of the file, following the pattern described in the first command (HalShooterFixTitles)
```

## x shot 1 HalShooterFixTitles (2026-04-12 11:58:07)
I want you to create a command that systematically goes through every single shot file of a repo and fixes the title of the shot file.
the title should follow the following pattern:

when in a subfolder of .hal/shooter/shotfiles
```markdown
# <path_to_shot_file> / <shot_file_name>
```

when in the root folder of .hal/shooter/shotfiles
```markdown
# <shot_file_name>
```

please also go through the whole source code and check, that ALL commands, which create shotfiles, follow this pattern when creating the shotfile.
for example when in the shotfile picker and i enter some/test/shotfile, the title should be `# some/test/shotfile` and not `# shotfile` or `# some/test/shotfile.md` or any other variation.
