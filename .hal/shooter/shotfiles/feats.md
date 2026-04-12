# feats

## x shot 1 HalShooterFixTitles (2026-04-12 11:58:07)
I want you to create a command that systematically goes through every single shot file of a repo and fixes the title of the shot file.
the title should follow the following pattern:

when in a subfolder of .hal/shooter/shotfiles
```markdown
# <path_to_shot_file> / <shot_file_name>
```

when in the root folder of .hal/shooter/shotfiles
```markdown
# <shot_file_name>
```

please also go through the whole source code and check, that ALL commands, which create shotfiles, follow this pattern when creating the shotfile.
for example when in the shotfile picker and i enter some/test/shotfile, the title should be `# some/test/shotfile` and not `# shotfile` or `# some/test/shotfile.md` or any other variation.
