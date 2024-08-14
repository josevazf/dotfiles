-- Set up tree list on file explorer
vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

-- Numbers in the buffer
opt.relativenumber = true -- show relative numbers
opt.number = true -- show absolute line number

-- Tabs & indentation
opt.tabstop = 4 -- 4 spaces for tabs (prettier default)
opt.shiftwidth = 4 -- 4 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

opt.wrap = false -- disable line wrapping

-- Search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- when including mixed case in the search, assumes to be case-sensitive

opt.cursorline = true -- show cursor line

-- Turn on guicolors
opt.termguicolors = true
opt.background = "dark"

-- Backspace
opt.backspace = "indent,eol,start" -- allow backspace indent, end of line or insert mode start position

-- Clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- Split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

