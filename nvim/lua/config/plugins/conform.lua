-- =============================================================================
-- config/plugins/conform.lua
-- conform.nvim を使った自動フォーマット（Prettier）
-- =============================================================================

return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "フォーマット",
      },
    },
    opts = {
      -- フォーマッターの定義
      formatters_by_ft = {
        typescript      = { "prettier" },
        typescriptreact = { "prettier" },
        javascript      = { "prettier" },
        javascriptreact = { "prettier" },
        json            = { "prettier" },
        jsonc           = { "prettier" },
        css             = { "prettier" },
        scss            = { "prettier" },
        html            = { "prettier" },
        markdown        = { "prettier" },
        yaml            = { "prettier" },
        lua             = { "stylua" },
        c               = { "clang_format" },
        cpp             = { "clang_format" },
        rust            = { "rustfmt" },
        python          = { "ruff_format" },
      },

      -- 保存時に自動フォーマット
      format_on_save = {
        timeout_ms   = 1000,
        lsp_fallback = true,   -- Prettier が見つからない場合は LSP の format を使用
      },

      -- フォーマッターのオプション上書き
      formatters = {
        prettier = {
          -- プロジェクトの .prettierrc を優先し、なければこのデフォルトを使用
          prepend_args = function(self, ctx)
            -- .prettierrc がプロジェクト内にあれば引数を追加しない
            local config_files = {
              ".prettierrc", ".prettierrc.js", ".prettierrc.json",
              ".prettierrc.yaml", ".prettierrc.yml",
              "prettier.config.js", "prettier.config.cjs",
            }
            for _, file in ipairs(config_files) do
              if vim.fn.findfile(file, ctx.dirname .. ";") ~= "" then
                return {}
              end
            end
            -- フォールバックデフォルト
            return {
              "--tab-width",    "2",
              "--single-quote", "true",
              "--trailing-comma", "es5",
              "--print-width",  "100",
              "--semi",         "true",
            }
          end,
        },
      },
    },
  },
}
