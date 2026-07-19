-- =============================================================================
-- config/plugins/telescope.lua
-- telescope.nvim - ファジーファインダー
-- =============================================================================

return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false, -- 最新 HEAD を使用
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- fzf ネイティブソーター（高速化）
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        enabled = vim.fn.executable("make") == 1,
      },
      -- LSP シンボルをファジー検索
      "nvim-telescope/telescope-ui-select.nvim",
    },
    keys = {
      -- ファイル系
      { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "ファイル検索" },
      { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "テキスト検索 (grep)" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "バッファ一覧" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "最近開いたファイル" },
      { "<leader>fc", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "バッファ内検索" },

      -- LSP 連携
      { "<leader>ls", "<cmd>Telescope lsp_document_symbols<cr>", desc = "ドキュメントシンボル" },
      { "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "ワークスペースシンボル" },
      { "<leader>lr", "<cmd>Telescope lsp_references<cr>", desc = "参照一覧" },
      { "<leader>ld", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>lD", "<cmd>Telescope diagnostics<cr>", desc = "全 Diagnostics" },

      -- Git
      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git コミット" },
      { "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "Git ブランチ" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Git ステータス" },

      -- ヘルプ・設定
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "ヘルプタグ" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "キーマップ" },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = " ",
          entry_prefix = "  ",
          sorting_strategy = "ascending",
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.55,
              results_width = 0.8,
            },
            width = 0.87,
            height = 0.80,
          },
          -- 検索から除外するパターン
          file_ignore_patterns = {
            "node_modules",
            ".git/",
            "dist/",
            "build/",
            "%.lock",
            "package%-lock%.json",
          },
          mappings = {
            i = {
              ["<C-n>"] = actions.cycle_history_next,
              ["<C-p>"] = actions.cycle_history_prev,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<Esc>"] = actions.close,
              ["<C-u>"] = false, -- プロンプトクリア
              ["<C-d>"] = false,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true, -- ドットファイルも表示
            -- find_command は指定しない（fd → rg の順に自動検出される）
          },
          live_grep = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })

      -- 拡張機能のロード
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },
}
