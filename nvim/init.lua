-- init.lua
require("plugins")

require("config.options")

require("config/keymaps")

require("config.lsp")

vim.cmd("syntax on")
vim.cmd("filetype plugin indent on")

local cmp = require('blink.cmp')
cmp.build():wait(60000)
cmp.setup({
	sources = {
		default = { 'lsp', 'path', 'snippets', 'buffer' },
	},
	completion = {
		menu = { border = 'rounded' },
		ghost_text = { enabled = true },
	},
})

vim.lsp.inlay_hint.enable(true)

vim.diagnostic.config({
	virtual_text = { prefix = "●" },
	float = { border = "rounded" },
	severity_sort = true,
})


vim.cmd.colorscheme("catppuccin-mocha")

