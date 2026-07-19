-- =============================================================================
-- config/plugins/lint.lua
-- nvim-lint を使った ESLint 診断
-- NOTE: LSP の eslint サーバーと併用可能。
--       LSP 側で EslintFixAll を実行し、nvim-lint 側でリアルタイム診断を補完。
-- =============================================================================

-- ESLint 設定ファイルがプロジェクト内にあるか（無ければ eslint_d を起動しない）
local function has_eslint_config(dirname)
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
    if vim.fn.findfile(file, dirname .. ";") ~= "" then
      return true
    end
  end
  -- package.json の "eslintConfig" フィールドもチェック
  local pkg = vim.fn.findfile("package.json", dirname .. ";")
  if pkg ~= "" then
    local ok, content = pcall(vim.fn.readfile, pkg)
    if ok and table.concat(content, "\n"):find('"eslintConfig"') then
      return true
    end
  end
  return false
end

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

      -- トリガー: 保存時・InsertLeave 時にリント実行
      -- NOTE: nvim-lint に linter 単位の condition オプションは無いため、
      --       ESLint 設定の有無はここで判定してから try_lint する
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "BufReadPost" }, {
        group = vim.api.nvim_create_augroup("nvim_lint_eslint", { clear = true }),
        callback = function(args)
          if lint.linters_by_ft[vim.bo[args.buf].filetype] == nil then
            return
          end
          local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf))
          if has_eslint_config(dirname) then
            lint.try_lint()
          end
        end,
      })
    end,
  },
}
