-- Load vimrc file for compatibility with vim plugins
vim.cmd([[
  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/.vimrc
]])

-- Make background transparent
local transparent_highlights = { 'Normal', 'NormalFloat', 'FloatBorder', 'Pmenu' }
for _, group in ipairs(transparent_highlights) do
  vim.api.nvim_set_hl(0, group, { bg = 'none' })
end

-- Set status line colors
vim.api.nvim_set_hl(0, 'StatusLine', { fg = '#eeeeee', bg = 'none' })
vim.api.nvim_set_hl(0, 'StatusLineNC', { fg = '#888888', bg = 'none' })

-- Hide command line unless needed
vim.opt.cmdheight = 0

-- Set netrw lexplore keymap
vim.keymap.set('n', '<M-e>', vim.cmd.Lexplore)

-- List all tabs
vim.keymap.set('n', '<M-Tab>', ':tabs<CR>')

-- Remap Emacs-style keybindings command modes
-- Navigation
vim.keymap.set('c', '<C-a>', '<Home>')
vim.keymap.set('c', '<C-e>', '<End>')
vim.keymap.set('c', '<C-b>', '<Left>')
vim.keymap.set('c', '<C-f>', '<Right>')
vim.keymap.set('c', '<C-p>', '<Up>')
vim.keymap.set('c', '<C-n>', '<Down>')
-- Word-wise navigation
vim.keymap.set('c', '<M-b>', '<C-Left>')
vim.keymap.set('c', '<M-f>', '<C-Right>')
-- Killing and deleting
vim.keymap.set('c', '<C-k>', '<C-u>')
-- Word-wise deleting
vim.keymap.set('c', '<M-BS>', '<C-w>')
vim.keymap.set('c', '<M-d>', '<C-w>')

-- Auto close lsp document symbol window after jump
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(event)
    local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if not win_info then return end
    local close_cmd = win_info.loclist == 1 and ":lclose<CR>" or ":cclose<CR>"
    vim.keymap.set("n", "<CR>", "<CR>" .. close_cmd, { buffer = event.buf, remap = true, silent = true })
  end,
})

-- Enable LSP servers (https://github.com/neovim/nvim-lspconfig)
vim.lsp.enable({
  'clangd',
  'ruff', 'rust_analyzer',
  'svelte', 'tsgo'
})

-- Enable native autocompletion
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, {
        autotrigger = true,
      })
    end
  end,
})
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.shortmess:append("c")
vim.opt.completeopt:append("fuzzy")

-- Configure nvim treesitter to install parsers (https://github.com/nvim-treesitter/nvim-treesitter)
require('nvim-treesitter').install({
  'asm',
  'c', 'cmake', 'cpp', 'css', 'csv',
  'diff',
  'glsl',
  'html',
  'javascript', 'json',
  'latex', 'llvm', 'lua',
  'make', 'mlir',
  'rust',
  'ssh_config', 'strace', 'svelte', 'swift',
  'tmux', 'toml', 'tsx', 'typescript',
  'vim',
  'xml',
  'yaml',
  'zsh'
})
