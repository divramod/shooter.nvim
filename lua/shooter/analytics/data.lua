-- Back-compat shim — `require('shooter.analytics.data')` now resolves to
-- analytics/data/init.lua. The old monolithic file was split during plan 0001
-- phase 004 T007 into analytics/data/{parse,repo,sources,stats,init}.lua.
return require('shooter.analytics.data.init')
