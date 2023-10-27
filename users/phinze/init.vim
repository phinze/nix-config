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
Plug 'airblade/vim-gitgutter'
Plug 'b4b4r07/vim-hcl'
Plug 'benmills/vimux'
Plug 'christoomey/vim-tmux-navigator'
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'dsawardekar/ember.vim'
Plug 'elixir-lang/vim-elixir'
Plug 'elzr/vim-json'
Plug 'fatih/vim-hclfmt'
Plug 'godlygeek/tabular'
Plug 'google/vim-jsonnet'
Plug 'hashivim/vim-hashicorp-tools'
Plug 'hrsh7th/cmp-nvim-lsp', {'commit': 'f93a6cf9761b096ff2c28a4f0defe941a6ffffb5'}
Plug 'hrsh7th/nvim-cmp', {'commit': 'c2a9e0ccaa5c441821f320675c559d723df70f3d'}
Plug 'hrsh7th/vim-vsnip', {'commit': '9ac8044206d32bea4dba34e77b6a3b7b87f65df6'}
" Plug 'janko-m/vim-test'
" Use my fork until I can upstream subtest support
Plug 'phinze/vim-test', { 'branch': 'support-go-subtests' }
Plug 'juliosueiras/vim-terraform-completion'
Plug 'junegunn/goyo.vim'
Plug 'kchmck/vim-coffee-script'
Plug 'neovim/nvim-lspconfig',
Plug 'ntpeters/vim-better-whitespace'
Plug 'ojroques/vim-oscyank'
Plug 'onsails/lspkind-nvim'
Plug 'p00f/nvim-ts-rainbow'
Plug 'pangloss/vim-javascript'
Plug 'ray-x/lsp_signature.nvim'
Plug 'rizzatti/dash.vim'
Plug 'rking/ag.vim'
Plug 'rodjek/vim-puppet'
Plug 'rust-lang/rust.vim'
Plug 'scrooloose/syntastic'
Plug 'sheerun/vim-polyglot'
Plug 'simrat39/symbols-outline.nvim'
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

" telescope things
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' } " we suggest you install a native sorter to improve performance
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}  " We recommend updating the parsers on update
call plug#end()


let g:rspec_command = "Dispatch bundle exec rspec {spec}"

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

" enter reruns last command...
nmap <CR> :wa<CR> :VimuxRunLastCommand<CR>

" ...but does normal thing in quickfix window
autocmd BufReadPost quickfix nnoremap <buffer> <CR> <CR>

" tagbar
nmap <silent> <Leader>t :SymbolsOutline<CR>

" vim-test
nmap <silent> <Leader>n :TestNearest<CR>
nmap <silent> <Leader>f :TestFile<CR>
nmap <silent> <Leader>s :TestSuite<CR>   " t Ctrl+s
nmap <silent> <Leader>l :TestLast<CR>    " t Ctrl+l
nmap <silent> <Leader>V :TestVisit<CR>   " t Ctrl+g
let test#strategy = "vimux"
let test#go#gotest#options = "-v"

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

au BufRead,BufNewFile *.job set filetype=hcl

" ==>  plugin/clipboard.vim
set clipboard=unnamedplus


" ==>  plugin/syntastic.vim
let g:syntastic_puppet_puppetlint_args = '--no-documentation-check --no-80chars-check --no-class_parameter_defaults-check'
let syntastic_mode_map = { 'passive_filetypes': ['html', 'hbs', 'handlebars'] }

let g:syntastic_javascript_checkers = ['jshint']
let g:syntastic_ruby_checkers = ['mri']
let g:syntastic_yaml_checkers = ['jsyaml']

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
colorscheme catppuccin
let g:airline_powerline_fonts = 1
let g:airline_theme = 'catppuccin'

" lsp time!
lua << EOF
-- Setup language servers.
local lspconfig = require('lspconfig')
lspconfig.solargraph.setup {
  cmd = { 'bundle', 'exec', 'solargraph', 'stdio' }
}
lspconfig.standardrb.setup {
  cmd = { 'bundle', 'exec', 'standardrb', '--lsp' }
}
lspconfig.tsserver.setup {}
lspconfig.rust_analyzer.setup {}

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

-- code formatting ala goimports
function organize_go_imports()
    local enc = vim.lsp.util._get_offset_encoding()
		local params = vim.lsp.util.make_range_params(nil, enc)
		params.context = { only = { "source.organizeImports" } }

		local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 5000)
		for _, res in pairs(result or {}) do
			for _, r in pairs(res.result or {}) do
				if r.edit then
					vim.lsp.util.apply_workspace_edit(r.edit, enc)
				else
					vim.lsp.buf.execute_command(r.command)
				end
			end
		end
end


-- code formatting ala goimports
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*.go" },
	callback = organize_go_imports
})

-- code formatting ala gofmt
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*.go" },
	callback = vim.lsp.buf.format
})


require'nvim-treesitter.configs'.setup {
  ensure_installed = {
    "bash",
    "go",
    "gomod",
    "hcl",
    "json",
    "lua",
    "make",
    "nix",
    "proto",
    "python",
    "ruby",
    "rust",
    "typescript",
    "vim",
  }, -- one of "all", or a list of languages
  sync_install = false, -- install languages synchronously (only applied to `ensure_installed`)
  ignore_install = { "javascript" }, -- List of parsers to ignore installing
  highlight = {
    enable = true,              -- false will disable the whole extension
    disable = { "c", "rust" },  -- list of language that will be disabled
    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
  rainbow = {
    enable = true,
    extended_mode = true,
    max_file_lines = 10000,
  },
}

require('telescope').setup {
  defaults = {
    preview = {
      -- Disable treesitter to try and fix hitches during live grep see https://github.com/nvim-telescope/telescope.nvim/issues/1616
      treesitter = false
    }
  }
}

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require('telescope').load_extension('fzf')

-- symbols-outline.vim
local symbols_outline_opts = {
    highlight_hovered_item = true,
    show_guides = true,
    auto_preview = true,
    position = 'right',
    relative_width = true,
    width = 25,
    auto_close = false,
    show_numbers = false,
    show_relative_numbers = false,
    show_symbol_details = true,
    preview_bg_highlight = 'Pmenu',
    keymaps = { -- These keymaps can be a string or a table for multiple keys
        close = {"<Esc>", "q"},
        goto_location = "<Cr>",
        focus_location = "o",
        hover_symbol = "<C-space>",
        toggle_preview = "K",
        rename_symbol = "r",
        code_actions = "a",
    },
    lsp_blacklist = {},
    symbol_blacklist = {},
    symbols = {
        File = {icon = "", hl = "TSURI"},
        Module = {icon = "", hl = "TSNamespace"},
        Namespace = {icon = "", hl = "TSNamespace"},
        Package = {icon = "", hl = "TSNamespace"},
        Class = {icon = "𝓒", hl = "TSType"},
        Method = {icon = "ƒ", hl = "TSMethod"},
        Property = {icon = "", hl = "TSMethod"},
        Field = {icon = "", hl = "TSField"},
        Constructor = {icon = "", hl = "TSConstructor"},
        Enum = {icon = "ℰ", hl = "TSType"},
        Interface = {icon = "ﰮ", hl = "TSType"},
        Function = {icon = "", hl = "TSFunction"},
        Variable = {icon = "", hl = "TSConstant"},
        Constant = {icon = "", hl = "TSConstant"},
        String = {icon = "𝓐", hl = "TSString"},
        Number = {icon = "#", hl = "TSNumber"},
        Boolean = {icon = "⊨", hl = "TSBoolean"},
        Array = {icon = "", hl = "TSConstant"},
        Object = {icon = "⦿", hl = "TSType"},
        Key = {icon = "🔐", hl = "TSType"},
        Null = {icon = "NULL", hl = "TSType"},
        EnumMember = {icon = "", hl = "TSField"},
        Struct = {icon = "𝓢", hl = "TSType"},
        Event = {icon = "🗲", hl = "TSType"},
        Operator = {icon = "+", hl = "TSOperator"},
        TypeParameter = {icon = "𝙏", hl = "TSParameter"}
    }
}
require("symbols-outline").setup(symbols_outline_opts)
EOF

autocmd BufWritePre *.tf lua vim.lsp.buf.formatting()

map <leader>i <cmd>lua vim.lsp.buf.hover()<CR>
map <leader>T <cmd>lua vim.lsp.buf.type_definition()<CR>
map <leader>C <cmd>lua vim.lsp.buf.incoming_calls()<CR>
map <leader>rn <cmd>lua vim.lsp.buf.rename()<CR>
map <leader>l <cmd>lua vim.lsp.diagnostic.goto_next()<CR>
map <leader>e <cmd>lua vim.diagnostic.open_float()<CR>

nnoremap <leader>o <cmd>lua require('telescope.builtin').git_files()<cr>
nnoremap <leader>g <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>be <cmd>lua require('telescope.builtin').buffers({sort_lastused=true, ignore_current_buffer=true})<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>
nnoremap <leader>R <cmd>lua require('telescope.builtin').lsp_references()<cr>
nnoremap <leader>S <cmd>lua require('telescope.builtin').lsp_document_symbols()<cr>

" Use opener and oscyank when on a remote connection
if exists('$SSH_CONNECTION')
  let g:netrw_browsex_viewer = "xdg-open"
  autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | execute 'OSCYankReg "' | endif
endif

function! VimTestForceRspec()
  let g:test#ruby#rspec#file_pattern = '\v(((^|/)test_.+)|_test)(spec)@<!\.rb$'
  let g:test#ruby#minitest#file_pattern = 'nothanks'
endfunction

command! VimTestForceRspec call VimTestForceRspec()

" Wrapped line navigation
noremap <expr> k (v:count == 0 ? 'gk' : 'k')
noremap <expr> j (v:count == 0 ? 'gj' : 'j')
