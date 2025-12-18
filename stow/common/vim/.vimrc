" set history size
set history=500

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

" use W to save file as root
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" disable tab line
set showtabline=0

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

" enable true color support
set termguicolors

" enable command-line display
set showcmd

" enable auto-indentation
set autoindent

" enable line numbers
set number

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

" tab management command maps
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
map <leader>t<leader> :tabnext<cr>

" move selected lines up and down
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

" always show the status line
set laststatus=3
set statusline=\[%{mode()}\]\ %F\ %y\ %m%r%w\ %=\ %l\/%L\ %v\ 0x%04B\ \[%{&fileencoding}\]\ %{tabpagenr()}\#%{tabpagenr('$')}
