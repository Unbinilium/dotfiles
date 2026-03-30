" set history size
set history=500

" enable true color support
set termguicolors

" set splits to open below and to the right
set splitbelow
set splitright

" set transparent background
augroup TransparentBackground
  autocmd!
  autocmd ColorScheme * hi Normal guibg=NONE ctermbg=NONE
  autocmd ColorScheme * hi NonText guibg=NONE ctermbg=NONE
augroup END

" enable filetype detection
filetype plugin on
filetype indent on

" use system clipboard
set clipboard=unnamedplus

" enable auto-reload of files changed outside
set autoread
autocmd FocusGained,BufEnter * silent! checktime

" auto-save all files when focus is lost or switching buffers
autocmd FocusLost * silent! wall

" auto-escape mouse when leaving vim
autocmd VimLeave * set mouse=

" use W to save file as root
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" auto-hide tab line
set showtabline=1

" set scrolloff when using j/k
set so=7

" use wildmenu for command-line completion
set wildmenu

" enable case-insensitive searching
set ignorecase
set smartcase

" enable highlighting of search results
set hlsearch

" enable incremental search
set incsearch

" enable redrawing only when needed
set lazyredraw

" enable magic mode
set magic

" enable matching parentheses highlighting
set showmatch

" enable syntax highlighting
syntax on

" enable command-line display
set showcmd

" enable auto-indentation
set autoindent

" enable line numbers
set number
set relativenumber

" enable mouse support
set mouse=a

" default to UTF-8 encoding
set encoding=utf8

" default to Unix line endings
set ffs=unix,dos,mac

" disable backup files
set nobackup
set nowb
set noswapfile

" use spaces instead of tabs, enable smart tabbing
set expandtab
set smarttab
set shiftwidth=4
set tabstop=4

" enable auto-indentation
set ai
set si
set wrap

" netrw options
let g:netrw_altv = 1
let g:netrw_fastbrowse = 0
let g:netrw_keepdir = 0
let g:netrw_liststyle = 3

" newrw keymap
inoremap <M-e> <C-\><C-N>:Lexplore<CR>
nnoremap <M-e> :Lexplore<CR>

" tab management keymaps
nnoremap <leader>tn :tabnew<CR>
nnoremap <leader>to :tabonly<CR>
nnoremap <leader>tc :tabclose<CR>
nnoremap <leader>tl :tablast<CR>
nnoremap <leader>tf :tabfirst<CR>
nnoremap <leader>tt :tabnext<CR>
nnoremap <leader>tp :tabprevious<CR>

" clear search highlight keymap
nnoremap <silent> <Esc> :nohlsearch<CR>

" tab management keymaps
nnoremap <M-Tab> :tabs<CR>
nnoremap <M-n> :tabnew<CR>
nnoremap <M-w> :if tabpagenr('$') == 1 \| quit \| else \| tabclose \| endif<CR>

" move selected lines up and down
nnoremap <M-j> mz:m .+1<CR>==`z
nnoremap <M-k> mz:m .-2<CR>==`z
vnoremap <M-j> :m '>+1<CR>gv=gv`>
vnoremap <M-k> :m '<-2<CR>gv=gv`<

" command-line mode keymaps
" navigation
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
cnoremap <C-b> <Left>
cnoremap <C-f> <Right>
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
" word-wise navigation and deletion
cnoremap <M-b> <C-Left>
cnoremap <M-f> <C-Right>
cnoremap <M-d> <C-Right><Del>
cnoremap <M-Backspace> <C-w>

" terminal mode keymaps
nnoremap <M-t> :sp \| term<CR>
tnoremap <M-w> <C-\><C-n>:q!<CR>
tnoremap <Esc> <C-\><C-n>
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" status line style
function! VisualSelectionSize()
    if mode() =~ '^[vV\x16]'
        let l:counts = wordcount()
        if has_key(l:counts, 'visual_chars') && l:counts.visual_chars > 1
            return printf(' (%d)', l:counts.visual_chars)
        endif
    endif
    return ''
endfunction
set laststatus=2
set statusline=\[%{mode()}\]
set statusline+=\ %F
set statusline+=\ %y
set statusline+=\ %m%r%w
set statusline+=\ %=
set statusline+=\ %l\/%L
set statusline+=\ %v%{VisualSelectionSize()}
set statusline+=\ 0x%04B
set statusline+=\ \[%{&fileencoding}\]

" tab line style
function! MyTabLine()
  let s = ''
  for i in range(tabpagenr('$'))
    let s .= i + 1 == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#'
    let s .= '%' . (i + 1) . 'T'
    let s .= '[' . (i + 1) . ':%{MyTabLabel(' . (i + 1) . ')}] '
  endfor
  let s .= '%#TabLineFill#%T'
  return s
endfunction
function! MyTabLabel(n)
  let buflist = tabpagebuflist(a:n)
  let winnr = tabpagewinnr(a:n)
  let bufnr = buflist[winnr - 1]
  let name = bufname(bufnr)
  let label = empty(name) ? 'No Name' : fnamemodify(name, ':t')
  if getbufvar(bufnr, '&modified')
    let label .= '+'
  endif
  return label
endfunction
set tabline=%!MyTabLine()
