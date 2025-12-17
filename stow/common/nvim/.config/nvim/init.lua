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

-- Set netrw to use tree-style listing
vim.g.netrw_liststyle = 3

-- Remap Emacs-style keybindings in insert and command modes
-- Navigation
vim.keymap.set({ 'i', 'c' }, '<C-a>', '<Home>')
vim.keymap.set({ 'i', 'c' }, '<C-e>', '<End>')
vim.keymap.set({ 'i', 'c' }, '<C-b>', '<Left>')
vim.keymap.set({ 'i', 'c' }, '<C-f>', '<Right>')
vim.keymap.set({ 'i', 'c' }, '<C-p>', '<Up>')
vim.keymap.set({ 'i', 'c' }, '<C-n>', '<Down>')
-- Word-wise navigation
vim.keymap.set({ 'i', 'c' }, '<M-b>', '<C-Left>')
vim.keymap.set({ 'i', 'c' }, '<M-f>', '<C-Right>')
-- Killing and deleting
vim.keymap.set('i', '<C-k>', '<C-o>D')
vim.keymap.set('c', '<C-k>', '<C-u>')
-- Word-wise deleting
vim.keymap.set({ 'i', 'c' }, '<M-BS>', '<C-w>')
vim.keymap.set('i', '<M-d>', '<C-o>dw')
vim.keymap.set('c', '<M-d>', '<C-w>')

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
