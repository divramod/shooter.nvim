-- Back-compat shim — `require('shooter.syntax')` now resolves to syntax/init.lua.
-- The old monolithic file was split during plan 0001 phase 004 T005 into
-- syntax/{highlights,detect,apply,info,autocmds,overrides,init}.lua.
return require('shooter.syntax.init')
