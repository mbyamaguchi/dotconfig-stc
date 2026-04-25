vim.lsp.config.nimlsp = {
    cmd = { "nimlsp" },

    root_markers = { ".git", "*.nimble", "nim.cfg" },

    on_attach = function(client, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }

        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)      -- 定義へジャンプ
        vim.keymap.set('n', 'K',  vim.lsp.buf.hover, opts)           -- ドキュメント表示
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)  -- 実装へジャンプ
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)      -- 参照一覧
        vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)   -- 名前変更
    end,

    settings = {},
}

vim.lsp.enable("nimlsp")
