set nocompatible
set fileformat=unix
set encoding=utf-8
set mouse=a
set visualbell
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab
set number
set wrap
set colorcolumn=120
set showmatch
set title
set autoindent
set smartindent
set wrapscan
set noignorecase
set showtabline=2
set foldmethod=marker
set hlsearch
set laststatus=2
set t_Co=256
set noswapfile

filetype on
filetype plugin on
filetype indent on
syntax on

fun! s:SmartHome()
  if col('.') != match(getline('.'), '\S')+1
    norm ^
  else
    :call cursor(line('.'),2)
    norm h
  endif
endfun
inoremap <silent><home> <C-O>:call <SID>SmartHome()<CR>
nnoremap <silent><home> :call <SID>SmartHome()<CR>
vnoremap <silent><home> :call <SID>SmartHome()<CR>

"autocmd BufEnter * silent! :%s/\s\+$//e
"autocmd BufWritePre * silent! :%s/\s\+$//e

autocmd FileType php setlocal omnifunc=phpcomplete#CompletePHP
set completeopt=menu,longest
nnoremap <silent><C-B> :!ctags -f .tags --languages=PHP --exclude=.git --exclude=cache --totals=yes --tag-relative=yes -R<CR>
set tags=.tags
let php_sql_query=1
let php_htmlInStrings=1
let php_folding=0

set makeprg=php\ -l\ %
nnoremap <silent><C-F12> :make<ENTER>:copen<ENTER><CTRL>L

nnoremap <silent><C-T> :tabnew<ENTER>
nnoremap <silent><C-D> :tabclose<ENTER>
nnoremap <silent><C-LEFT> :tabprevious<ENTER>
nnoremap <silent><C-RIGHT> :tabnext<ENTER>
nnoremap <silent><A-up> :m.-2<ENTER>==
nnoremap <silent><A-down> :m.+1<ENTER>==
nnoremap <silent><F8> :TagbarToggle<ENTER>
inoremap <silent><A-up> <ESC>:m.-2<ENTER>==gi
inoremap <silent><A-down> <ESC>:m.+1<ENTER>==gi
vnoremap <silent><A-up> :m'<-2<ENTER>gv=gv
vnoremap <silent><A-down> :m'>+1<ENTER>gv=gv
nnoremap <silent><TAB> >>
nnoremap <silent><S-TAB> <<
vnoremap <silent><TAB> >gv
vnoremap <silent><S-TAB> <gv
inoremap <silent><C-@> <C-X><C-O>

let g:airline_powerline_fonts=1
colorscheme default
hi ColorColumn ctermbg=red

nnoremap <silent><C-N> :NERDTreeTabsToggle<ENTER>
nnoremap <silent><C-M> :NERDTreeToggle<ENTER>

autocmd BufRead /tmp/mutt-* normal }
