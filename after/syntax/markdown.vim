" Shooter.nvim syntax extensions for markdown files
" Highlights shot headers differently based on status

" Only apply to files in plans/prompts directory
if expand('%:p') !~# 'plans/prompts'
  finish
endif

" Open shot header: ## shot N
syntax match shooterOpenShot /^##\s\+shot\s\+\d\+.*$/ containedin=ALL

" Done shot header: ## x shot N (date)
syntax match shooterDoneShot /^##\s\+x\s\+shot\s\+\d\+.*$/ containedin=ALL

" Define highlight groups with fallback colors
highlight default ShooterOpenShot guibg=#3d3d00 guifg=#ffff00 ctermbg=58 ctermfg=226
highlight default ShooterDoneShot guibg=#1a3d1a guifg=#88aa88 ctermbg=22 ctermfg=108

" Link syntax groups to highlight groups
highlight link shooterOpenShot ShooterOpenShot
highlight link shooterDoneShot ShooterDoneShot
