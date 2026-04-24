local servers = { "sourcekit", "basedpyright", "ruff", "clangd" }

for _, server in ipairs(servers) do
	vim.lsp.enable(server)
end
