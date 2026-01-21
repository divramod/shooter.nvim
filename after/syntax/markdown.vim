" Shooter.nvim syntax extensions for markdown files
" Highlights open shot headers (done shots not highlighted)

" Only apply to files in plans/prompts directory
if expand('%:p') !~# 'plans/prompts'
  finish
endif

" Open shot header: ## shot N (done shots not highlighted)
syntax match shooterOpenShot /^##\s\+shot\s\+\d\+.*$/ containedin=ALL

" Define highlight group with fallback colors
highlight default ShooterOpenShot guibg=#3d3d00 guifg=#ffff00 ctermbg=58 ctermfg=226

" Link syntax group to highlight group
highlight link shooterOpenShot ShooterOpenShot
