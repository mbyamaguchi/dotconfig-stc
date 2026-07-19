-- config/keymaps.lua

local map = function(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- basic

-- jk to Normal
map("i", "jk", "<Esc>", { desc = "to Normal mode" })

-- disable search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>")

-- file save
map("n", "<C-s>", "<cmd>w<cr>", { desc = "save" })
map("i", "<C-s>", "<Esc><cmd>w<cr>", { desc = "save" })

-- window
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- window resize
map("n", "<C-Up>", "<cmd>resize +2<cr>")
map("n", "<C-Down>", "<cmd>resize -2<cr>")
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>")
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>")

-- move buffer
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close Buffer" })

-- edit

-- selected lines
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Down Selected Lines" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Up Selected Lines" })

-- sustain indent
map("v", "<", "<gv")
map("v", ">", ">gv")

map("v", "p", '"_dP')

-- diagnostic
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic to loclist" })
