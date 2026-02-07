# namespacing

## shot 5


## shot 4
there are other standards. for example always when you create a picker:
- q, c-c, c-n, c-p should always work to quit, create new, go to next, go to previous
- select should always be the same

## x shot 3 (2026-01-24 13:29:15)
another thing is code reuse.
when you act in the different contexts of a namespace, you will often do the same thing.
so it you should always call the same function that implements the logic.
only maybe the entrypoint is different.

so think about and plan code reuse as well.
for example the help command in the shot picker looks completely different than the help command in the shotfile picker.

there should be standards for that as well.

please add that to your plan and your instructions in the claude.md at the end of the implementation phase.

## x shot 2 (2026-01-24 13:24:56)
what i also want to take into consideration is the following:
i just see different contexts inside the namespaces.

### shot namespace
for example lets take the shot namespace.
i can manipulate a shot in different contexts:
- in the shot picker
- being in the shotfile itself inside a shot

for the mappings that would mean, that i want to run the same command in the shotfile in the shot as in the shotpicker on the shot currently under the cursor. 

so as for example < >1 sends the shot under the cursor to claude in pane 1, 
when i press < >1 in the shotfile picker, it should send the shot under the cursor to claude in pane 1 as well.

the same would go for all shot related commands.

### shotfile namespace
for the shotfile namespace, i have three different contexts:
1. beeing in the shotfile itself
2. being in the shotfile picker
3. beeing in the oilfile picker

here, i want to have the same commands available in all three contexts

### project namespace
it will be similar in the project namespace, as it also copes with folder pickers and project files.

please put that into your plan and also at the end of the implementation phase to the claude.md, so that you are always aware of the fact, that if you implement a new command in a namespace, you need to think about the different contexts as well and that all mapping behave the same in all contexts of a namespace.

will that thought change your current plan?

## x shot 1 (2026-01-24 12:49:48)
i am realizing, that i already added so much functionality, that it is getting hard to keep track of all commands and mappings.
i want to start namespacing commands and mappings.
please walk through the whole codebase and analyze all commands and mappings.
then analyze which areas can be grouped together into namespaces.
my current feeling is that we have the following areas:
- shotfile
- shot
- health / audit
- project

are there others in your view?
if so, which ones?

suggest me namespace and go into plan/explore mode.
