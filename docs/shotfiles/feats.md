# feats

## shot 32 move improvements into new followup plan

## shot 31 < >pa
i want you to add a new plan command < >pa, which archives a plan.
when in the masterplan.md file, 

## x shot 30 < >v shotfile picker (2026-04-25 05:54:52)
should sort by alphabet, when two files have the same change age
/Users/mod/a/shooter.nvim/.shooter/tmp/image-pastes/clipboard_20260425_055415.png
in the picture, there are many shotfiles 30s old. i want them to be sorted alphabetically, when they have the same age in parentheses

## x shot 29 move shotfiles folder to docs/shotfiles (2026-04-25 04:31:18)
i want to have the shotfiles folder in a different directory.
it should be in docs/shotfiles instead of .hal/util/shooter/shotfiles
please do the following:
1. check the whole codebase for any pointers to the old shotfiles path and adapt them to the new path
2. move through all repos in ~/a and move the shotfiles folder to the new location (do a git add, commit and push for this change, so that the history of the shotfiles is preserved in every repo)
go into plan mode to not miss anything

## x shot 28 path completion in < >fmm (2026-04-25 03:22:46)
when i run the < >fmm command, i want to have the path autocompletion like in < >v

## x shot 27 < >pf improvements (2026-04-24 16:08:23)
i have thes next plans
```md
## next plans
- 0007-rust-refactoring
- 0008-fix-envfile
- 0009-secrets-ports-envs
- 0010-hal-cli-command-structure
- 0011-hal-cfg-local-refactoring
- 0012-hal-cfg-global-refactoring
- 0013-hal-log-and-tracing-refactoring
- 0014-context-agent-md-memory-decisions-instructions
```

i want to rename 0011-hal-cfg-local-refactoring to 0011-hal-cfg-refactoring, because i want to do both local and global refactoring in one plan, because they are closely related and should be done together.
how will < >pf handle this?
can it somehow remember it, that 0011 was another one before and will rename it?
this is not trivial, but i need a solution, to rename/remove old plans
please think deeply about this and go into plan mode and think about the best/most stabel way to implement this.

## x shot 26 < >pf improvements (2026-04-24 09:23:47)
sometimes, an ai agent also creates a follow up plan in docs/plans and takes the next free number.
in ~/a/hal for example docs/plans/0006-...
i want the plan fix command to add these plans from docs/plans, which are neither in `## done`, nor in `## in progress` (so not existant in the masterplan) to be added to the `## in progress` list alphabetically. the in progress list should be sorted alphabetically, so that the new plan is added to the correct position in the list

## x shot 25 cleanup .shooter folder (2026-04-24 07:58:32)
can you look through the whole codebase and check, if there are any pointers to <reporoot>/.shooter left?
i want to move all the shooter files and folders to .hal/util/shooter
please give me a list of all the pointers if you find any

## x shot 24 < >pf (2026-04-24 06:58:02)
after running the < >pf command, i want you to git add and commit the folders docs/plans and .hal/util/shooter/shotfiles/plans with a senseful commit message, so that i can easily track the changes in the plans and the masterplan in git. no git push here please

## x shot 23 HalShooterShotfileLast (2026-04-24 06:44:57)
should also open the docs/plans/masterplan.md file, if it was the last one opened.

## x shot 22 < >pn (2026-04-24 06:24:18)
add a new command < >pn, which creates a new plan file in the docs/plans folder with the name of the plan (similar to the < >N new shotfile command)
it should find out the next free number from the existing plan files in the docs/plans folder and create a new plan file with the name of the plan and the number as prefix, for example 0005-new-plan.md

## x shot 21 plan remappings (2026-04-24 05:23:44)
i want to be more systematic now regarding the shoot plan functionality
please do the following remappings
< >pc --> < >pC
< >pp --> < >pP
< >ps --> < >pS
< >mc --> < >pc
< >mp --> < >pp
< >ms --> < >ps
< >mf --> < >pf
< >mm --> < >pm

also, merge all the masterplan and plan functionality under one umbrella in the code, to stay structured and clean.
i may add additional functionality there in the future.

independent from the plan functionality, please also map < >H to the help for the hal plugin and ensure, that all functionality for all commands is explained in the hal help.

## x shot 20 < >pe < >mf improvements (2026-04-24 05:13:29)
the pe command worked correctly, except for the fact, that it put the plan to .hal/util/shooter/shotfiles/plans, instead of to .../shotfiles/docs/plans. please adapt this for both commands

## x shot 19 < >ms < >mc < >mp (2026-04-24 05:13:29)
create the commands to open the following files, when the cursor is on a line with a plan in the masterplan
< >ms opens the docs/plans/NNNN-.../spec.md file for the plan in the line under the cursor (writes a message if there is no plan or spec file)
< >mc opens the docs/plans/NNNN-.../context.md file for the plan in the line under the cursor (writes a message if there is no plan or context file)
< >mp opens the docs/plans/NNNN-.../plan.md file for the plan in the line under the cursor (writes a message if there is no plan or plan file)

## x shot 18 < >mf improvements (2026-04-24 05:05:32)
i want to extend the functionality of the masterplan fix command.
when renumbering, what it should acutally do is the following:
- look in the docs/plans list, what the next free number of a plan is, for example the highest used plan number right now in ~/a/hal/docs/plans is 0004,
then when renumbering, the first plan number in next plans can be 0005. now the first number under `## next plans` is 0006-..., so this first one should be renumbered to 0005-..., the next one should be 0006-..., and so on, so that there are no gaps in the numbering, but the order of the plans is preserved.
- the second important thing is then, that the masterplan fix command ensures that the plan files in .hal/util/shooter/shotfiles/plans are also, generated, if not present and renamed, if the numbers drifted, so that the plan files in .hal/sutil/shooter/shotfiles/plans are always in sync with the plans in the masterplan, so that when i open a plan from the masterplan, i always have the correct file with the correct name and number.
- also the shotfile title should be always in sync/fixed, when a plan file is generated or renamed, so that the title of the plan file also follows the pattern and has the correct name and number.

## x shot 17 < >pe (2026-04-24 04:56:02)
i want you to create HalShooterPlanEdit
what it does is, when beeing in the file docs/plans/masterplan.md it looks, if in the line under the cursor, there is a plan contained.
for example, 0005-merge-hal-skills.
then it looks into the folder .hal/util/shooter/shotfiles/plans for a file with the name of the plan, in this case 0005-merge-hal-skills.md
if so, then it opens this file, if not, it looks in the shotfiles/plans folder for a file which has the same name as the plan, but with a different number, for example 0003-merge-hal-skills.md, if it finds such a file, it moves this file to the new name and opens it, if not, it creates a new file with the name of the plan and opens it.
be aware, when renaming a shooter/plans/ plan file, the title also needs to be adapted to the new name, regarding to the shotfile title pattern/conventions. you have that already implemented in in different areas, where we have the feat to rename a shotfile.
it would be best, to reuse this function

## x shot 16 masterplan improvements (2026-04-23 09:25:37)
- on fix, when there is a plan like this:
```- some plan (some description)```
everything in parantheses should stay in the parentheses. only the things in front of the parentheses should be slugified and numbered, so that the numbering is correct, but the descriptions stay as they are.

for the following case
```md
- some plan (some description)
  - some notes for the plan
    - some subnotes for the plan
```
the same applies, only the first part should be slugified and numbered, but the description in parantheses and the notes should stay as they are, so that the notes are not lost when the plan gets renumbered.


## x shot 15 remove < >p subproject functionality (2026-04-23 08:56:48)
I want you to remove the subproject functionality. I’ve never used it, and I want to keep the plugin clean.

Instead, I want you to introduce a plan sub-area.
< >pp should open a telescope picker with the following files listed
- all docs/plans/**/**/**/... plan.md files recursively
< >pc should open a telescope picker with the following files listed
- all docs/plans/**/**/**/... context.md files recursively
< >ps should open a telescope picker with the following files listed
- all docs/plans/**/**/**/... spec.md files recursively

## x shot 14 masterplan feats (2026-04-23 08:40:59)
i am in the beginning of introducing a new feature.
its my masterplan feat
i always have a masterplan file now in every repo in docs/plans/masterplan.md
i want you to add the following commands

HalShooterMasterplanOpen currently mapped to < >m (remap to < >mm
HalShooterMasterplanOpen should also call the Fix command, so that i always have a clean and up to date masterplan when i open it
HalShooterMasterplanFix map to < >ms
- it should do different things
- as you see in `## next plans` there are different plans i plan to tackle next
- the numbering is broken and should be fixed with the command, i want to keep the order of the plans, like i write them, but the numbering should be fixed by you (the first next plan should always be the start for incremental renumbering, in this case 0005, all the following lines should be renumbered incrementally, so that there are no gaps in the numbering, and the order is preserved), ????- neeed to be replaced with a number
- `dev (worktrees, databases, common tools) \` slugify all special signs
- the title: should be `masterplan <repo-name> (repo alias)`, the repo name should be taken from the folder name, the alias from the .hal/ALIAS file
- the subheaders: ensure (in that order)
```md
## in progress

## next plans

## backlog

## done
```
- empty lines between the plans, but no more than one empty line

```md
# masterplan <repo-name> (repo alias)

## in progress
- 0004-repo-root-cleanup

## next plans
- 0005-merge-hal-skills
- 0005-rs-app-fix
- 0006-ts-lib-fix
- 0007-ts-app-fix
- 0008-swift-lib-fix
- 0009-swift-app-fix
- 0010-kt-lib-fix
- 0011-kt-app-fix
- 0012-js-lib-fix
- 0013-js-app-fix
- 0014-bash-lib-fix
- 0015-bash-app-fix
- 0016-md-lib-fix
- 0017-md-app-fix
- 0018-hal-cli-command-structure
- 0019-hal-cfg-local-refactoring
- 0020-hal-cfg-global-refactoring
- 0021-hal-log-refactoring
- 0022-fix-envfile
- 0023-fix-docker-compose
- 0025-context (agent.md, memory, decisions, instructions)
- artifacts as own topic
- ????-conformity
- dev (worktrees, databases, common tools)
- secrets / ports / envs
- templates
- fix all app and lib commands.md
- codebase
- security
- tui shortcuts (every tui functionality needs to be reachable via a keyboard shortcut)
- feature parity (every feature needs to be implemented in api, tui, swift, kotlin, next)
- deployment
- performance
- error handling systematics
- graph database
- vector database
- memory system
- gap handling (gap closure plans should be approvable, when they have been moved into a own plan phase or spec, so that plans can be closed)
- llm finetuning
- project- and planmanagement
- shotfile management
- inbox
- _generated folder
- testing
- shotfile folder restructuring
- cli test commands (every cli command should have a test command that can be used in CI and locally to verify functionality)
- util init commands like (redis init, mongo init, postgres init, mysql init, ... -> how does that combine with dev init?)

## backlog
- 0003-ios-improvements

## done
- 0002-refactore-general-folder-structure
- 0001-refactoring-04 (2026-04-23 06:12:00)
```

HalShooterMasterplanMarkDone map to < >md
when i run this on a line with a plan, it should move the plan from where it is to the `## done` section at the top and add in parentheses the moment, when it was moved to done (2026-04-23 06:12:00)

## x shot 13 < >m should open docs/plans/masterplan.md (2026-04-23 08:11:19)

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
