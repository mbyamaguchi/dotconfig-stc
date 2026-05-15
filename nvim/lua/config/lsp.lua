local servers = { "sourcekit", "basedpyright", "ruff", "clangd", "gopls",  }

for _, server in ipairs(servers) do
	vim.lsp.enable(server)
end
