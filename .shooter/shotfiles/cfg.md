# cfg

## shot 7
running shooter cfg local behaves weird, when running it

after running the command ask question:


after a change:
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260209_062626.png

## shot 6
sometimes, when the debounce time is to high, after i edited a shot file, and then open oil, some of the files in oil are colored in organge like in the shotfile, which was opened before.
this needs to be solved in general.

## shot 5
i said to you to delete the old shooter.nvim config dir, after implementing the new config system.
why is it still there?
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260209_055207.png
have you adapted all the pathes in the whole codebase to the new config path?
maybe you check what is still there and find out, why its still there?
i want to get rid of the old config dir and only use the new one, so please fix that.

## x shot 4 (2026-02-09 06:19:56) @shot-4-20260209_061956
i want you to add a command ShooterCfgFix, which is running on bufenter for ~/.config/shooter/nvim/config.yaml and ~/<path to repo>/.shooter/cfg/nvim/config.yaml, and checks, if there are any config values inside the config file, which are not part of the values, which can be configured at all for shooter.nvim
- it should automatically remove any config values, which are not part of the possible config values for shooter.nvim

the second thing for the fix command is, that if the global config file is opened, on buf enter, it should add all missing config values, which are possible to configure for shooter.nvim, but are not yet set in the global config file, with the default values.

i want to use this as kind of a reference, to never forget which config values can be set

## x shot 3 (2026-02-09 06:14:31) @shot-3-20260209_061432
i want to change the configuration file value names and structure:
```yaml
file:
  first_shot_debounce_in_ms: 300
  first_shot_color: "#FF0000"
```

to 

```yaml
file:
  first_shot_of_the_day:
    debounce_in_ms: 300
    color_bg: "#FF0000" # keep the standard value
    color_fg: "#FF0011" # keep the standard value
```

also add functionalities for

```yaml
file:
  open_shots:
    debounce_in_ms: 300
    color_bg: "#FF0000" # keep the standard value
    color_fg: "#FF0011" # keep the standard value
  closed_shots:
    debounce_in_ms: 300
    color_bg: "#FF0000" # keep the standard value
    color_fg: "#FF0011" # keep the standard value
```

## x shot 2 (2026-02-09 06:06:30) @shot-2-20260209_060630
when quitting the file after ShooterCfgEditLocal, i get this message.
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260209_060628.png

## x shot 1 (2026-02-09 05:28:05) @shot-1-20260209_052806
i want to update the configuration system of the shooter.nvim plugin.
please create a core module config.
i want you to walk through the whole codebase look, where config files are read.
also, until now, all the global configuration for shooter.nvim goes to ~/.config/shooter.nvim
i want to change that to ~/.config/nvim/shooter/nvim
so in the first step, please adapt the whole codebase to use the new path
after that, move the currentlty existing glocal config files one by one to the new path
after that, delete the old config dir ~/.config/shooter.nvim
also, i want now to have a global and a project local config file, where if the same value is set in both, the project local config file overwrites the global one.
the global config should be places in ~/.config/shooter/nvim/config.yaml
the repo local config should be places in ~/<path to repo>/.shooter/cfg/nvim/config.yaml
now i want you to create a config for the coloring of the first shot of the day in ~/.config/shooter/nvim/config.yaml

```yaml
file:
  first_shot_color: "#FF0000" # Brown color, the one you have hardcoded until now
  first_shot_debounce_in_ms: 500
```

this should be the default config.
i always want to have all possible config values in the global config file.
please add this inside to the shooter context.md, so that you know it next time.
how is the most performat way to read that config file?
lazy load it, when first opening a shot file?

later i want to be able to override this for example in the shooter.nvim repo at ~/<path to repo>/.shooter/cfg/nvim/config.yaml

```yaml
file:
  first_shot_color: "GREEN HEX COLOR" # here add a green hex color.
```

then, only the color should be overridden, the debounce time should still be 500ms.

i will have many more things to configure.
so please think deeply, about how to implement this configuration functionality.

also wnite a command ShooterCfgReload, which reloads the config files and applies the new config values to all open shot files.

also write a command ShooterCfgEditGlobal, which opens the global config file in a new buffer for editing.

also write a command ShooterCfgEditLocal, which opens repos local config file in a new buffer for editing. if there is no local config file yet, it should create one with the default values from the global config file.

for both edit commands, the changes should then be applied to all open shot files after saving the config file.

in general, all cfg changes should be applied instantly
