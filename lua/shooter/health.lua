-- Back-compat shim — `require('shooter.health')` resolves to health/init.lua.
-- The old monolithic file was split during plan 0001 phase 004 T006 into
-- health/{plugins,system,context,shotfile,tools,init}.lua.
return require('shooter.health.init')
