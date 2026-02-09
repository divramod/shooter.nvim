# cfg

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
