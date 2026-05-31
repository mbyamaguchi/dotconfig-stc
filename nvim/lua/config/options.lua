local opt = vim.opt

-- file encoding
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

-- appearance
opt.number = true   -- line number
opt.relativenumber = true   -- relative line number
opt.signcolumn = "yes"  -- for LSP diagnostics
opt.cursorline = true   -- cursor highlight
opt.wrap = false    -- disable line wrap
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true    -- True Color

-- indentation
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- spliting
opt.splitright = true
opt.splitbelow = true

-- disable backup/swap
opt.backup = false
opt.swapfile = false
opt.undofile = true -- permanent undo
opt.undodir = vim.fn.stdpath("data") .. "/undodir"

-- autocompletion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 10  -- popup maximum num of lines

-- others
opt.updatetime = 250    -- CursorHold event to be lazy
opt.timeoutlen = 300    -- key sequence timeout
opt.clipboard = "unnamedplus"   -- system clipboard
opt.mouse = "a"
opt.showmode = false    -- disable for status line
opt.laststatus = 3  -- global status line

