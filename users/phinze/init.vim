"
" vim-plug
"
"

set runtimepath+=~/.vim/

if empty(glob('~/.vim/autoload/plug.vim'))
  silent call system('mkdir -p ~/.vim/{autoload,bundle,cache,undo,backups,swaps}')
  silent call system('curl -fLo ~/.vim/autoload/plug.vim https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
  execute 'source  ~/.vim/autoload/plug.vim'
  augroup plugsetup
    au!
    autocmd VimEnter * PlugInstall
  augroup end
endif

call plug#begin('~/.vim/plugged')
" my fork until https://github.com/benmills/vimux-golang/pull/5 is merged
Plug 'airblade/vim-gitgutter'
Plug 'b4b4r07/vim-hcl'
Plug 'benmills/vimux'
Plug 'christoomey/vim-tmux-navigator'
Plug 'dsawardekar/ember.vim'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'elixir-lang/vim-elixir'
Plug 'elzr/vim-json'
Plug 'fatih/vim-hclfmt'
Plug 'godlygeek/tabular'
Plug 'google/vim-jsonnet'
Plug 'hashivim/vim-hashicorp-tools'
Plug 'hrsh7th/cmp-nvim-lsp', {'commit': 'f93a6cf9761b096ff2c28a4f0defe941a6ffffb5'}
Plug 'hrsh7th/nvim-cmp', {'commit': 'c2a9e0ccaa5c441821f320675c559d723df70f3d'}
Plug 'hrsh7th/vim-vsnip', {'commit': '9ac8044206d32bea4dba34e77b6a3b7b87f65df6'}
Plug 'janko-m/vim-test'
Plug 'juliosueiras/vim-terraform-completion'
Plug 'kchmck/vim-coffee-script'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'kien/rainbow_parentheses.vim'
Plug 'majutsushi/tagbar'
Plug 'neovim/nvim-lspconfig', {'commit': '25841e38e9c70279ee1d7153097c9e66a88d4fa5'}
Plug 'ntpeters/vim-better-whitespace'
Plug 'pangloss/vim-javascript'
Plug 'rizzatti/dash.vim'
Plug 'rking/ag.vim'
Plug 'rodjek/vim-puppet'
Plug 'rust-lang/rust.vim'
Plug 'scrooloose/syntastic'
Plug 'sheerun/vim-polyglot'
Plug 'slashmili/alchemist.vim'
Plug 'terryma/vim-expand-region'
Plug 'tomtom/tcomment_vim'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-fireplace'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-vinegar'
Plug 'vim-airline/vim-airline'
Plug 'vim-ruby/vim-ruby'
Plug 'vim-scripts/netrw.vim'
Plug 'zerowidth/vim-copy-as-rtf'
call plug#end()


let g:rspec_command = "Dispatch bundle exec rspec {spec}"

" run terraform fmt on save of all *.tf or *.tfvars files
let g:terraform_fmt_on_save = 1

" ## Display

" don't break words in middle
set linebreak
" show incomplete paragraphs even when they don't fit on screen (avoid @'s)
set display+=lastline
" always show ruler
set ruler
" turn on syntax hilighting
syntax on
" show line numbers
set number
" allow buffers to be open in the background
set hidden
" keep 5 lines of context on the screen while scrolling, instead of scrolling when cursor is at very bottom
set scrolloff=5

" ## Indentation and Tabs

" two spaces pleases
set ts=2
set shiftwidth=2
" 2018 - year of the tab?!!?!?!?!
" " and no tab characters!
set expandtab
" round to nearest 2, don't just move 2
set shiftround

" `smartindent` is an obsolete option for C-like syntax. It has been replaced with `cindent`,
" and setting `cindent` also overrides `smartindent`. Vim has indentation
" support for many languages out-of-the-box, and setting `smartindent`
" (or `cindent`, for that matter) in your .vimrc might interfere with this. Use `filetype indent on` and be happy.
set noautoindent
set nosmartindent
filetype plugin indent on

" ## Code Folding

" turn off folding by default
set nofoldenable
" fold by indentation level
set foldmethod=indent
" start out with folds for all but really deep nesting expanded
set foldlevel=9

" ## Backup / Swap file storage

" pull everything together in one place; don't write swap files in cwd
set nobackup
set backupdir=~/.vim-tmp/
set directory=~/.vim-tmp//

" ## Keybindings

" make up, down, home and end keys work intuitively for long paragraphs
map <up> gk
imap <up> <C-o>gk
map <down> gj
imap <down> <C-o>gj
map <home> g<home>
imap <home> <C-o>g<home>
map <end> g<end>
imap <end> <C-o>g<end>

" fat fingers: map f1 to escape instead of help
map <F1> <Esc>
imap <F1> <Esc>

" complete in command mode with tab
cnoremap <Tab> <C-L><C-D>

" ## Searching

" Highligh found search results, can be turned off with `:noh`
set hlsearch

" This will have searches ignore case unless I use a capital letter
set ignorecase
set smartcase

" Start searching right away instead of waiting for `<CR>`
set incsearch

" fix backspace in insert mode
set backspace=indent,eol,start

map <silent> <LocalLeader>nh :nohls<CR>
map <silent> <LocalLeader>cc :TComment<CR>
map <silent> <LocalLeader>rt :!ctags -R --exclude=".git\|.svn\|log\|tmp\|db\|pkg" --extra=+f<CR>

if has('nvim')
  nmap <bs> :<c-u>TmuxNavigateLeft<cr>
endif

" MORE NATURAL SPLIT OPENING
" Open new split panes to right and bottom, which feels more natural than
" Vim’s default:
set splitbelow
set splitright

" Don't give attention message when existing swapfile is found
set shortmess+=A

" Space Leader OMG
let mapleader = "\<Space>"

" <Space>w to write a file
nnoremap <Leader>w :w<CR>

" <Space>q to close a file
nnoremap <Leader>q :q<CR>

" <Space>Q to force close a file
nnoremap <Leader>Q :q!<CR>

" <Space>B to git blame
nnoremap <Leader>B :!tig blame % +<C-r>=line('.')<CR><CR>

" <Space>v to open vimux prompt
nnoremap <Leader>v :VimuxPromptCommand<CR>

" Copy & paste to system clipboard with <Space>p and <Space>y
vmap <Leader>y "+y
vmap <Leader>d "+d
nmap <Leader>p "+p
nmap <Leader>P "+P
vmap <Leader>p "+p
vmap <Leader>P "+P

" Enter visual line mode with <Space><Space>:
nmap <Leader><Leader> V

" enter reruns last test...
nmap <CR> :wa<CR> :TestLast<CR>

" ...but does normal thing in quickfix window
autocmd BufReadPost quickfix nnoremap <buffer> <CR> <CR>

if executable('ag')
  set grepprg=ag\ --nogroup\ --nocolor
endif

" grep for word/Word under cursor with leader-g/G
nnoremap <Leader>g :grep! "\b<C-R><C-W>\b"<CR>:cw<CR>
nnoremap <Leader>G :grep! "\b<C-R><C-A>\b"<CR>:cw<CR>

" tagbar
nmap <silent> <Leader>t :TagbarToggle<CR>

" ctrl-p
nnoremap <Leader>o :CtrlP<CR>

" vim-test
nmap <silent> <Leader>n :TestNearest<CR>
nmap <silent> <Leader>f :TestFile<CR>
nmap <silent> <Leader>s :TestSuite<CR>   " t Ctrl+s
nmap <silent> <Leader>l :TestLast<CR>    " t Ctrl+l
nmap <silent> <Leader>v :TestVisit<CR>   " t Ctrl+g
let test#strategy = "vimux"
let test#go#gotest#options = "-v"

let g:go_fmt_command = "goimports"

if exists('+colorcolumn')
  set colorcolumn=80
else
  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
endif

" disable auto hclfmt for now, editing too many wonky old files :)
let g:hcl_fmt_autosave = 0
let g:tf_fmt_autosave = 0
let g:nomad_fmt_autosave = 0

let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] }

" Ignore shellcheck directives:
"   - SC1091: where it checks to make sure `source` files are accessible; we osudifhsdfgdsfugsdudg
"     edit lots of scripts that are destined for other filesystems
let g:syntastic_sh_shellcheck_args = "-e SC1091"

let g:go_term_enabled = 1
let g:go_term_mode = "vsplit"

au BufRead,BufNewFile *.job set filetype=hcl

" ==>  plugin/clipboard.vim
set clipboard=unnamed

" ==>  plugin/ctrlp.vim
let g:ctrlp_working_path_mode = 'ra'

" Use rg (ripgrep) for ctrlp indexing
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --files --hidden --color=never --glob ""'
  " rg is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

" ==>  plugin/rainbow_parentheses.vim
au VimEnter * RainbowParenthesesToggle
au Syntax * RainbowParenthesesLoadRound
au Syntax * RainbowParenthesesLoadSquare
au Syntax * RainbowParenthesesLoadBraces

" ==>  plugin/syntastic.vim
let g:syntastic_puppet_puppetlint_args = '--no-documentation-check --no-80chars-check --no-class_parameter_defaults-check'
let syntastic_mode_map = { 'passive_filetypes': ['html', 'hbs', 'handlebars'] }

let g:syntastic_javascript_checkers = ['jshint']
let g:syntastic_ruby_checkers = ['mri']
let g:syntastic_yaml_checkers = ['jsyaml']

" ==>  plugin/tagbar.vim
nmap <silent> <Leader>tb :TagbarToggle<CR>
let g:tagbar_autofocus = 1

" ==>  plugin/tcomment.vim
map <silent> <LocalLeader>cc :TComment<CR>

" ==>  plugin/vim-expand-region.vim
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

" ==>  plugin/vimclojure.vim
" prevent plugin from mapping all over the place
" which collides with vimux test bindings
let vimclojure#SetupKeyMap = 0

" ==>  plugin/vimux.vim
" Prompt for a command to run
map <Leader>rp :VimuxPromptCommand<CR>

" Run last command executed by RunVimTmuxCommand
map <Leader>rl :VimuxRunLastCommand<CR>

" Inspect runner pane
map <Leader>ri :VimuxInspectRunner<CR>

" Close all other tmux panes in current window
map <Leader>rx :VimuxCloseRunner<CR>

" Interrupt any command running in the runner pane
map <Leader>rs :VimuxInspectRunner<CR>

let g:VimuxOrientation = "h"
let g:VimuxHeight = 40
let g:VimuxUseNearestPane = 1

" ==>  plugin/vroom.vim
let g:vroom_use_vimux = 1
let g:vroom_use_bundle_exec = 1

" Disable mouse
set mouse=

" Rust
let g:rustfmt_autosave = 1

" Go doesn't want expandtab
au filetype go set noexpandtab tabstop=4 softtabstop=4

" re-override ember.vim syntax highlighting
" see https://github.com/dsawardekar/ember.vim/issues/8
autocmd BufNewFile,BufRead *.hbs,*.hbt set filetype=html.handlebars

" theme
colorscheme dracula
let g:airline_powerline_fonts = 1
let g:airline_theme = 'dracula'

" lsp time!
lua << EOF
_G.nvim_lsp = require('lspconfig')

function _G.lsp_on_attach(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  local opts = { noremap=true, silent=true }

  buf_set_keymap('n', '<C-]>', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', '<LocalLeader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', '<LocalLeader>cl', '<cmd>lua vim.lsp.codelens.refresh()<CR>', opts)
  buf_set_keymap('n', '<LocalLeader>cr', '<cmd>lua vim.lsp.codelens.run()<CR>', opts)
  buf_set_keymap('n', '<LocalLeader>cd', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)

  vim.api.nvim_command([[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()]])

  local cmp = require 'cmp'

  cmp.setup {
    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
      ['<C-y>'] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Replace,
        select = true,
      },
      ['<C-X><C-O>'] = cmp.mapping.complete(),
    },
    snippet = {
      expand = function(args)
        vim.fn['vsnip#anonymous'](args.body)
      end,
    },
    sources = {
      { name = 'nvim_lsp' },
      { name = 'buffer' },
    },
    completion = {
      autocomplete = false,
    },
  }
end

_G.lsp_capabilities = vim.lsp.protocol.make_client_capabilities()
_G.lsp_capabilities = require('cmp_nvim_lsp').update_capabilities(_G.lsp_capabilities)

local vanilla_servers = {
  'dhall_lsp_server',
  'elmls',
  'gopls',
  'intelephense',
  'ocamllsp',
  'rust_analyzer',
  'tsserver',
}

for _, lsp in ipairs(vanilla_servers) do
  _G.nvim_lsp[lsp].setup {
    on_attach = _G.lsp_on_attach,
    capabilities = _G.lsp_capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end
  -- …

  function goimports(timeout_ms)
    local context = { only = { "source.organizeImports" } }
    vim.validate { context = { context, "t", true } }

    local params = vim.lsp.util.make_range_params()
    params.context = context

    -- See the implementation of the textDocument/codeAction callback
    -- (lua/vim/lsp/handler.lua) for how to do this properly.
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
    if not result or next(result) == nil then return end
    local actions = result[1].result
    if not actions then return end
    local action = actions[1]

    -- textDocument/codeAction can return either Command[] or CodeAction[]. If it
    -- is a CodeAction, it can have either an edit, a command or both. Edits
    -- should be executed first.
    if action.edit or type(action.command) == "table" then
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit)
      end
      if type(action.command) == "table" then
        vim.lsp.buf.execute_command(action.command)
      end
    else
      vim.lsp.buf.execute_command(action)
    end
  end
EOF

autocmd BufWritePre *.go lua goimports(1000)
