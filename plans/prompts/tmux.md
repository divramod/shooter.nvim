# tmux

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
