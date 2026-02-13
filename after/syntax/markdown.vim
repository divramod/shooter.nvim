" Shooter.nvim syntax extensions for markdown files
" Highlights open shot headers (done shots not highlighted)

" Only apply to files in .shooter/ai/shotfiles directory
if expand('%:p') !~# '.shooter/ai/shotfiles'
  finish
endif

" Open shot header number: ## shot N (done shots not highlighted)
syntax match shoOpenShot /^##\s\+shot\s\+\d\+/ containedin=ALL
" Open shot header title: text after ## shot N
syntax match ShoOpenShotTitle /\(^##\s\+shot\s\+\d\+\s\+\)\@<=.\+$/ containedin=ALL

" Define highlight group with fallback colors (black on light orange to avoid search highlight confusion)
" Note: These are overridden by Lua config in shooter.syntax when setup() is called
highlight default ShoOpenShot guibg=#ffb347 guifg=#000000 gui=bold ctermbg=215 ctermfg=16
highlight default ShoOpenShotTitle guibg=#ffe0a3 guifg=#333333 ctermbg=229 ctermfg=236

" Link syntax group to highlight group
highlight link shoOpenShot ShoOpenShot
