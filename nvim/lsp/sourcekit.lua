return {
    cmd = { "$HOME/.local/share/swiftly/bin/sourcekit-lsp" },
    filetypes = { "swift", "objective-c", "objective-cpp" },
    root_dir = function(filename)
        local util = require("lspconfig.util")
        return util.root_pattern("buildServer.json", "Package.swift", ".git")(filename)
    end,
    on_attach = function(client, bufnr)
        if client.supports_method("textDocument/codeLens") then
            vim.lsp.codelens.refresh()
            vim.keymap.set("n", "grx", vim.lsp.codelens.run, { buffer = bufnr, desc = "LSP CodeLens Action" })
        end
    end,
}
