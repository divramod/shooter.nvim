" Shooter.nvim syntax extensions for markdown files
" Highlights open shot headers (done shots not highlighted)

" Only apply to files in plans/prompts directory
if expand('%:p') !~# 'plans/prompts'
  finish
endif

" Open shot header: ## shot N (done shots not highlighted)
syntax match shooterOpenShot /^##\s\+shot\s\+\d\+.*$/ containedin=ALL

" Define highlight group with fallback colors (black on light orange to avoid search highlight confusion)
" Note: These are overridden by Lua config in shooter.syntax when setup() is called
highlight default ShooterOpenShot guibg=#ffb347 guifg=#000000 gui=bold ctermbg=215 ctermfg=16

" Link syntax group to highlight group
highlight link shooterOpenShot ShooterOpenShot
