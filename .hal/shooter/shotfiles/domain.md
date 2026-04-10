# domain

## x shot 4 < >dmf emptied the file? (2026-04-10 14:08:53)
this command emptied a formerly full file

## x shot 3 add domain rename functionality (2026-04-10 13:59:49)

## x shot 2 wrong folder (2026-04-10 11:52:44)
shooter created the domain in plans/prompts
so path is long obsolete
all shotfiles are under .hal/shooter/shotfiles
please research the whole codebase for the old folders and remove them, and make sure that the domain module creates subfolders under .hal/shooter/shotfiles for the domains
also <repo>/.shooter should appear nowhere

## x shot 1 init domain module (2026-04-10 11:03:49)
i want you to introduce a new module called domain.
Basically, I want to be able to categorize or collect shotfiles into domains. That means creating subfolders in the shotfiles folder, where subdomains live under a parent domain. 
commands (HalShooterDomain*):
< >dn HalShooterDomainNew to create a new domain (Create, be consistent with the other commands in using create new or add)
< >dmf HalShooterDomainMoveShotfileToDomain: opens a telescope picer for the existing domains and moves the current shotfile to the selected domain
< >v should then show all the shotfiles also from the domains

go into plan mode, and implement it
