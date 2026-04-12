# _project

## shot 20


## shot 19
add functionality to add a file or directory path, relative to the repo root into a shot)
i often explain with pathes, this could save me a lot of time

## shot 18
i have the command ShoOpen last shotfile.
i want the cursor at the place of the last change, when reopens

## x shot 17 (2026-02-10 05:42:01)
this is a test shot, do nothing with it

## x shot 16 (2026-02-10 05:40:35)
now it paste's but not entering at the end?
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260210_054029.png

## x shot 15 (2026-02-10 05:37:45)
i just realized, that the gemini send command only works, when gemini is already in vim insert mode.
in normal mode its not working.
please fix this too.

## x shot 14 (2026-02-10 05:27:51)
seems to work.
can we fix the cannot read out of workspace error?
maybe tell gemini directly to read with cat?

## x shot 13 (2026-02-10 05:26:10)
still the same.
why have you ignored my idea
maybe instead of sending @...
we should send 
read file /.../... for instructions?

## x shot 12 (2026-02-10 05:16:10)
claude code, opencode, codex are working.
gemini produces this.
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260210_051546.png

so gemini is the last one i need to get working for now.

## x shot 11 (2026-02-10 05:05:06)
i want you to also add codex and gemini as possible agent clis which i can send shot too also.
can you analyze the code, research the web and find out how to send the shots to codex and gemini too from the nvim shotfiles, so that i can implement it in the shooter.nvim plugin?
i want all 4 major agents supported by shooter.nvim

## x shot 10 (2026-02-09 20:44:46)
for gemini it does not work.
please also make it work for gemini, so that i have it working for all the 4 major agents.
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260209_204430.png

## x shot 9 (2026-02-09 20:44:01)
test

## x shot 8 (2026-02-09 20:43:41)
test

## x shot 7 (2026-02-09 20:42:45)
test

## x shot 6 (2026-02-09 19:03:49)
the problem is not, that the file is outside of the repo, the problem is, that the file has the @ in front. i tested it without the @ and it works in codex then.
so there needs to be a mechanism, to check if codex is running inside the tmux pane/terminal, where the shot is tent to, right?

## x shot 5 (2026-02-09 19:00:34)
ok, but the path inside the repo should be .shooter/bullets and the nvim plugin should always ensure, that this directory exists and is gitignored.

## x shot 4 (2026-02-09 18:47:58)
i sent a shotfile to codex, but its loading forever, not doing anything
/Users/mod/a/shooter.nvim/.shooter.nvim/images/clipboard_20260209_184653.png
enter is doing nothing, except adding the loading comment.
can you fix it?

## x shot 3 (2026-02-09 18:45:29)
test

## x shot 2 (2026-02-09 18:37:39)
i also want to support codex and gemini as possible targets for sending shots.
both are not supported when running < >1, even if the are open in the tmux pane.

## x shot 1 (2026-02-09 07:54:43) @shot-1-20260209_075444
i want you to change the prefix of the shooter commands to Sho from Shooter
go through the whole codebase and change all commands to the new prefix.
search for every occurence of the old prefix everywhere.
