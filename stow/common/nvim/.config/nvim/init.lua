-- Load vimrc file for compatibility with vim plugins
vim.cmd([[
  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/.vimrc
]])

-- Remap Emacs-style keybindings in insert and command modes
-- Navigation
vim.keymap.set('i', '<C-a>', '<Home>')
vim.keymap.set('c', '<C-a>', '<Home>')
vim.keymap.set('i', '<C-e>', '<End>')
vim.keymap.set('c', '<C-e>', '<End>')
vim.keymap.set('i', '<C-b>', '<Left>')
vim.keymap.set('c', '<C-b>', '<Left>')
vim.keymap.set('i', '<C-f>', '<Right>')
vim.keymap.set('c', '<C-f>', '<Right>')
vim.keymap.set('i', '<C-p>', '<Up>')
vim.keymap.set('c', '<C-p>', '<Up>')
vim.keymap.set('i', '<C-n>', '<Down>')
vim.keymap.set('c', '<C-n>', '<Down>')
-- Word-wise navigation
vim.keymap.set('i', '<M-b>', '<C-Left>')
vim.keymap.set('c', '<M-b>', '<C-Left>')
vim.keymap.set('i', '<M-f>', '<C-Right>')
vim.keymap.set('c', '<M-f>', '<C-Right>')
-- Killing and deleting
vim.keymap.set('i', '<C-k>', '<C-o>D')
vim.keymap.set('c', '<C-k>', '<C-u>')
-- Word-wise deleting
vim.keymap.set('i', '<M-BS>', '<C-w>')
vim.keymap.set('c', '<M-BS>', '<C-w>')
vim.keymap.set('i', '<M-d>', '<C-o>dw')
vim.keymap.set('c', '<M-d>', '<C-w>')

-- Make background transparent
local transparent_highlights = { 'Normal', 'NormalFloat', 'FloatBorder', 'Pmenu' }
for _, group in ipairs(transparent_highlights) do
  vim.api.nvim_set_hl(0, group, { bg = 'none' })
end

-- Enable LSP servers
vim.lsp.enable({
  'clangd',
  'ruff',
  'rust_analyzer'
})

-- Configure nvim treesitter to install parsers
require('nvim-treesitter').install({
  'asm',
  'c',
  'cmake',
  'cpp',
  'css',
  'csv',
  'diff',
  'glsl',
  'html',
  'javascript',
  'json',
  'latex',
  'llvm',
  'lua',
  'make',
  'mlir',
  'rust',
  'ssh_config',
  'strace',
  'svelte',
  'swift',
  'tmux',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'xml',
  'yaml',
  'zsh'
})
