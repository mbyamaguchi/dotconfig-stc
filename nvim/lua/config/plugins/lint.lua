-- =============================================================================
-- config/plugins/lint.lua
-- nvim-lint を使った ESLint 診断
-- NOTE: LSP の eslint サーバーと併用可能。
--       LSP 側で EslintFixAll を実行し、nvim-lint 側でリアルタイム診断を補完。
-- =============================================================================

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
      }

      -- eslint_d の設定（プロジェクトの .eslintrc を自動検出）
      lint.linters.eslint_d = vim.tbl_extend("force", lint.linters.eslint_d or {}, {
        -- ESLint 設定ファイルが見つからない場合はスキップ
        condition = function(ctx)
          local config_files = {
            ".eslintrc",
            ".eslintrc.js",
            ".eslintrc.cjs",
            ".eslintrc.json",
            ".eslintrc.yaml",
            ".eslintrc.yml",
            "eslint.config.js",
            "eslint.config.cjs",
            "eslint.config.mjs",
          }
          for _, file in ipairs(config_files) do
            if vim.fn.findfile(file, ctx.dirname .. ";") ~= "" then
              return true
            end
          end
          -- package.json の "eslintConfig" フィールドもチェック
          local pkg = vim.fn.findfile("package.json", ctx.dirname .. ";")
          if pkg ~= "" then
            local ok, content = pcall(vim.fn.readfile, pkg)
            if ok then
              local text = table.concat(content, "\n")
              if text:find('"eslintConfig"') then
                return true
              end
            end
          end
          return false
        end,
      })

      -- トリガー: 保存時・InsertLeave 時にリント実行
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufReadPost" }, {
        callback = function()
          -- TypeScript / JavaScript ファイルのみ
          local ft = vim.bo.filetype
          if vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, ft) then
            lint.try_lint()
          end
        end,
      })
    end,
  },
}
