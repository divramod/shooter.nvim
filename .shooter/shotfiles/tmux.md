# tmux

## x shot 16 (2026-02-03 01:14:22)
when opt+shift+A is pressed, and i am in a nvim tmux pane, the command ShoTmuxTogglePanes should be called.
when i one of the toggled panes, it should be hidden.
when i am neither in a nvim pane nor in a tmux command pane, started by ShoTmuxTogglePanes, nothing should happen.

## x shot 15 (2026-02-03 01:12:27)
how is the name of the command to start the telescope command picker, which creates the tmux panes from the tmux.yml file?

## x shot 14 (2026-02-03 01:07:34)
for the tmux panes configured in the tmux.yml file, i want to be able to set a option hidden: true/false
if hidden is true, the pane should be created but not shown, when pressing < >tt

## x shot 13 (2026-02-02 21:50:18)
somehow my nvim bindings for oil do not work anymore.
i had had <shift>H for going one folder up and it does not work anymore, since we wrote that tmux functionality and tried with opt+shift+H.
can you check the tmux.conf please and see, if there is something which blocks that binding in nvim?

## x shot 12 (2026-02-02 21:46:55)
now i want to extend the list of possible panes with some autocreated ones.
usually i have a folder scripts/shell in my projects, where i put a lot of useful shell scripts.
i want to extend the list of panes from the tmux.yml file with a auto generated list of panes, which are created from the scripts in that folder.
so every script should have the possibility to be started in a pane.

## x shot 11 (2026-02-02 21:39:42)
instead of showing the config of the yml config in the preview window.
for the case, that a pane is not existant its ok.
for the case, that it is existant, i want to see the history of the pane.

## x shot 10 (2026-02-02 21:36:06)
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260202_213537.png
i dont want to be asked here, i just want to toggle, without asking.

## x shot 9 (2026-02-02 21:31:55)
the pane is not shown, after pressing < >tt and selecting it with enter.

## x shot 8 (2026-02-02 21:27:23)
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260202_212610.png
now i need to get the pane back to the original window.

/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260202_212702.png
when i press enter on test-1 it says its visible, even though, its not in the original window.

## x shot 7 (2026-02-02 21:22:56)
i need to change the tmux shortcut for hiding the panes.
it should be opt+shift+A.
please remove the old one

## x shot 6 (2026-02-02 21:19:04)
you move the hidden pane to another window, if i see it right.
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260202_211702.png
21 shooter hidden test2
i want this window not be part of my current session.
is it possible, that you create a dedicated shoooter-hidden-panes session, where all hidden panes are moved to, when hidden?
when shown again, they should be moved back to the original session and window.
also, the windows should then be named like <folder name>-<pane name>, so i can see, where they belong to.

## x shot 5 (2026-02-02 20:49:51)
ok, in the preview window, i want to see the full code of the yaml for every tmux pane.

## x shot 4 (2026-02-02 20:44:26)
pressing opt+shift+H inserts something into tmux
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260202_204424.png

## x shot 3 (2026-02-02 20:36:55)
ok, now i want to you to also have the possibility to hide the created pane, from inside the pane, when it has focus.
i want to use opt+shift+H for that

## x shot 2 (2026-02-02 20:30:40)
nice, now it seems to work fine.
there are things i want to improve:
1. i want to add a option in the tmux.yml file, which allows me to set if the pane should be focused or not, when opened.

## x shot 1 (2026-02-02 19:20:24)
i want to extend the functionality of the tmux part of shooter in my project.
what i basically want is one or two tmux panes, which are special.
they should be hidden in normal operation and only be shown, when i want to see them.
i want to be able to have the panes configured by a tmux.yml file in the .shooter.nvim directory in the current root of the current tmux window. 
the file should look like this:
```yaml
panes:
  - name: test1
    commands:
    - echo "hell"
    - echo "world"
  - name: test2
    commands:
    - ls -la
    - pwd
```
when i press < >tt, i want to be asked, for which pane to show.
the pane should then open in a new tmux pane and run the commands from the config file.
when i press < >tt again, the pane should be hidden again, but not closed.
