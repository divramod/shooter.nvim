# feats

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
