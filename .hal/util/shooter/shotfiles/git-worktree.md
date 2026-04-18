# git-worktree

## x shot 3 add last worktree command (2026-04-04 05:42:53) @git-worktree_20260404_054253_shot-3
i want you to add a new ShooterGitWorktreeLast command, which switches to last git worktree i was in
the worktree folder name should be saved in the file <repo>/.hal/git/worktree/LAST and it should be ensured, that there is a <repo>/.hal/git/worktree/.gitignore, which has the file LAST inside it.
if the gitignore is not existant, it should be created and a git commit should be created to add this file.
if it exists already, it should be ensured, that it has the LAST file in it.
if the gitignore is changed in that process, a git commit should also be done.
the command should be callable with < >gwl

## x shot 2 no worktrees found in picker (2026-04-04 05:17:41) @git-worktree_20260404_051742_shot-2
the picker shows no worktrees found
/Users/mod/a/shooter.nvim/.hal/shooter/tmp/image-pastes/clipboard_20260404_051705.png

but there are 5
/Users/mod/a/shooter.nvim/.hal/shooter/tmp/image-pastes/clipboard_20260404_051733.png

plese fix it

## x shot 1 (2026-04-04 04:50:10) @git-worktree_20260404_045011_shot-1
i want a ShooterGitWorktreeSwitchTo [N] command, that will allow me to switch to a git worktree by number if given or if not given, there should be a telescope picker that shows the possible worktrees to switch to.
the git worktrees are located under ~/.hal/git/worktree/
in that folder, there are subfolders for each git repository with the git repo name, and inside those subfolders, there are the worktree folders with the worktree name.
the command should open the same file, which is currently open in the main git repo in nvim but in the worktree instead. if the file is not present in the worktree, it should open the README.md file in the root of the choosen worktree. the command should also update the current working directory to the root of the chosen worktree.
there should be another cmd ShooterGitWorktreeToMain that will switch back to the main git repo worktree and open the same file there, if it exists, or the README.md file if it doesn't. it should also update the current working directory to the root of the main git repo, which could be anywhere, so there needs to be a way to find it.
when switching to a worktree or back to the main repo, all files except the current one should be closed and the current file should then be the file in the new worktree or main.

i want you to create also the following shortcuts
< >gw0 to switch to the worktree number 0
< >gw1 to switch to the worktree number 1
< >gw2 to switch to the worktree number 2
< >gw3 to switch to the worktree number 3
< >gw4 to switch to the worktree number 4
< >gw5 to switch to the worktree number 5
< >gw6 to switch to the worktree number 6
< >gw7 to switch to the worktree number 7
< >gw8 to switch to the worktree number 8
< >gw9 to switch to the worktree number 9
< >gwm to switch to the main branch