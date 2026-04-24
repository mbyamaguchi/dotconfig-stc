vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "定義へ移動" })
vim.keymap.set('n', 'K',  vim.lsp.buf.hover,      { desc = "ドキュメント表示" })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = "参照元を検索" })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = "変数名を変更" })
