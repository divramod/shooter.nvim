# fix

## x shot 7 HalShooterShotfileLast opens a shotfile from a worktree, when ran on startup in ~/a/hal (2026-04-22 17:25:16)
this is maybe from before the fix.
please have a look, that HalShooterShotfileLast always opens the last shotfile from the main branch, even when ran from a worktree.

## x shot 6 edit shotfiles only in main (2026-04-22 17:11:42)
I want to edit shotfiles only in the main branch. So regardless of where I call Space+v to open the last shotfile, it should always show me the last shotfile from the main branch. I don’t want to work with shotfiles inside worktrees.

I just ran Space+v and it opened a shotfile inside the worktree I was in at that moment. Do you understand what I mean? This is really important so I don’t get conflicts with shotfiles.

Please adapt that across the whole shooter codebase so that all commands that open shotfiles, edit shotfiles, or rename them are aware of that. 

## x shot 5 < >v should also switch the cwd to main (2026-04-22 16:50:33)

## x shot 4 < >n not working after running < >l from a non main worktree (2026-04-22 16:50:33)

## x shot 3 < >l from worktree not working (2026-04-22 16:37:59)
running < >l from a worktree (cwd) is not opening the last shotfile in main right now. it should do it. please fix it

## x shot 2 < >l (2026-04-22 15:55:37)
running < >l from a worktree directory opens the shotfile in the main branch.
this is right, but its not changing back the cwd to the main branch. 
can you implement this?

## x shot 1 remove notifications from the top right (2026-04-11 05:08:27)
I want you to go through the whole code and remove all the notifications from the top right.
