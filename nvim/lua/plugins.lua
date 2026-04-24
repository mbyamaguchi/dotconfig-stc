-- ~/.config/nvim/lua/plugins.lua


vim.pack.add({
	'https://github.com/nvim-lua/popup.nvim',
	'https://github.com/nvim-lua/plenary.nvim',

	{ src = 'https://github.com/nvim-tree/nvim-web-devicons', name = 'nvim-web-devicons' },
	'https://github.com/rcarriga/nvim-notify',

	{ src = 'https://github.com/MunifTanjim/nui.nvim' },
	
	'https://github.com/saghen/blink.lib',

	'https://github.com/astral-sh/ruff',
	'https://github.com/p00f/clangd_extensions.nvim',
	'https://github.com/mfussenegger/nvim-dap',
	'https://github.com/rcarriga/nvim-dap-ui',

    'https://github.com/catppuccin/nvim',
})
vim.pack.add({
	{ src = 'https://github.com/folke/tokyonight.nvim' },
	{ src = 'https://github.com/hoob3rt/lualine.nvim' },
	{ src = 'https://github.com/nvim-neo-tree/neo-tree.nvim' },
	
	{ src = 'https://github.com/neovim/nvim-lspconfig' },
	{ src = 'https://github.com/nvim-telescope/telescope.nvim' },
	{ src = 'https://github.com/saghen/blink.cmp' },
})

