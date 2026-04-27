-- Back-compat shim — `require('shooter.tmux.toggle_panes')` now resolves to
-- toggle_panes/init.lua. The old monolithic file was split during plan 0001
-- phase 004 T007 into toggle_panes/{exec,layout,marker,actions,keybinding,init}.lua.
return require('shooter.tmux.toggle_panes.init')
