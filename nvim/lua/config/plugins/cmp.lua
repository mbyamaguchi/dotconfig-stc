-- =============================================================================
-- config/plugins/cmp.lua
-- nvim-cmp 補完エンジン設定
-- =============================================================================

return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      -- ソース
      "hrsh7th/cmp-nvim-lsp",       -- LSP
      "hrsh7th/cmp-buffer",          -- バッファ内テキスト
      "hrsh7th/cmp-path",            -- ファイルパス
      "hrsh7th/cmp-cmdline",         -- コマンドライン
      "hrsh7th/cmp-nvim-lsp-signature-help", -- シグネチャヘルプ

      -- スニペット
      {
        "L3MON4D3/LuaSnip",
        build = "make install_jsregexp",  -- 正規表現サポートをビルド
        dependencies = {
          "rafamadriz/friendly-snippets",  -- VSCode 互換スニペット集
        },
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
          -- TypeScript / JavaScript 専用スニペットを追加でロード
          require("luasnip.loaders.from_vscode").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
      "saadparwaiz1/cmp_luasnip",   -- LuaSnip を cmp に接続

      -- アイコン
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },

        -- ウィンドウのボーダー
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },

        -- キーマップ
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),

          -- Enter で確定（スニペットが展開中でなければ）
          ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select   = false,  -- 明示的に選択した項目のみ確定
          }),

          -- Tab / S-Tab でスニペット展開・補完候補移動
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        -- 補完ソースの優先順位
        sources = cmp.config.sources({
          { name = "nvim_lsp",               priority = 1000 },
          { name = "nvim_lsp_signature_help", priority = 800 },
          { name = "luasnip",                priority = 750 },
          { name = "path",                   priority = 500 },
        }, {
          { name = "buffer", keyword_length = 3, priority = 100 },
        }),

        -- アイテムの表示フォーマット（lspkind でアイコン付き）
        formatting = {
          format = lspkind.cmp_format({
            mode   = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            -- TypeScript 固有の型情報を末尾に表示
            before = function(entry, vim_item)
              if entry.source.name == "nvim_lsp" then
                vim_item.menu = "[LSP]"
              elseif entry.source.name == "luasnip" then
                vim_item.menu = "[Snip]"
              elseif entry.source.name == "buffer" then
                vim_item.menu = "[Buf]"
              elseif entry.source.name == "path" then
                vim_item.menu = "[Path]"
              end
              return vim_item
            end,
          }),
        },

        -- 実験的機能
        experimental = {
          ghost_text = {
            hl_group = "LspCodeLens",  -- インライングーストテキスト
          },
        },
      })

      -- コマンドライン補完（/ 検索）
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      -- コマンドライン補完（: コマンド）
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline" } }
        ),
        matching = { disallow_symbol_nonprefix_matching = false },
      })
    end,
  },
}
