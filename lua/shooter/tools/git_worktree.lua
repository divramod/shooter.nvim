-- Back-compat shim — `require('shooter.tools.git_worktree')` resolves to
-- git_worktree/init.lua. The old monolithic file was split during plan 0001
-- phase 004 T007 into git_worktree/{repo,list,state,switch,picker,init}.lua.
return require('shooter.tools.git_worktree.init')
