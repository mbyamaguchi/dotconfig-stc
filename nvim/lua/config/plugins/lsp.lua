-- =============================================================================
-- config/plugins/lsp.lua
-- Neovim 0.12 組み込み vim.lsp を使った LSP 設定
-- TypeScript Language Server (typescript-language-server) を中心に構成
-- =============================================================================

return {
  -- mason: LSP サーバーのインストール管理
  {
    "mason-org/mason.nvim",
    build  = ":MasonUpdate",
    opts   = {
      ui = {
        icons = {
          package_installed   = "✓",
          package_pending     = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- mason-lspconfig: mason と vim.lsp の橋渡し
  -- NOTE: Neovim 0.12 では lspconfig は不要になったが、
  --       mason-lspconfig は依然としてサーバー自動インストールに便利
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      -- 起動時に自動インストールするサーバー
      ensure_installed = {
        "ts_ls",       -- TypeScript / JavaScript
        "eslint",      -- ESLint LSP（診断のみ）
        "lua_ls",      -- Lua（Neovim 設定用）
        "jsonls",      -- JSON
        "cssls",       -- CSS
        "html",        -- HTML
        "emmet_ls",    -- Emmet 補完
        "clangd",      -- C / C++
        "rust_analyzer", -- Rust
        "pyright",     -- Python
      },
      automatic_installation = false,
    },
    config = function(_, opts)
      require("mason-lspconfig").setup(opts)

      -- nvim-lspconfig は lazy = true で読み込みトリガーが無いため、
      -- ここで明示的に require して読み込む。これにより lsp/<name>.lua の
      -- デフォルト設定（filetypes・root_markers 等）が vim.lsp.config に
      -- マージされるようになる。これを行わないと filetypes が未設定のまま
      -- となり、各 LSP サーバーが全てのファイルタイプにアタッチしてしまう
      -- （clangd が .gitignore 等を開くたびに invalid AST エラーを出す原因だった）。
      require("lspconfig")

      -- -----------------------------------------------------------------------
      -- on_attach: LSP がバッファにアタッチされたときのキーマップ・設定
      -- -----------------------------------------------------------------------
      local on_attach = function(client, bufnr)
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
        end

        -- ナビゲーション
        map("n", "gd",         vim.lsp.buf.definition,       "定義へ移動")
        map("n", "gD",         vim.lsp.buf.declaration,      "宣言へ移動")
        map("n", "gi",         vim.lsp.buf.implementation,   "実装へ移動")
        map("n", "gr",         vim.lsp.buf.references,       "参照一覧")
        map("n", "gt",         vim.lsp.buf.type_definition,  "型定義へ移動")
        map("n", "K",          vim.lsp.buf.hover,            "ホバードキュメント")
        map("n", "<C-k>",      vim.lsp.buf.signature_help,   "シグネチャヘルプ")

        -- 編集
        map("n", "<leader>rn", vim.lsp.buf.rename,           "リネーム")
        map("n", "<leader>ca", vim.lsp.buf.code_action,      "コードアクション")
        map("v", "<leader>ca", vim.lsp.buf.code_action,      "コードアクション（選択範囲）")

        -- ワークスペース
        map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder,    "ワークスペースフォルダー追加")
        map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "ワークスペースフォルダー削除")
        map("n", "<leader>wl", function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, "ワークスペースフォルダー一覧")

        -- Diagnostics
        map("n", "<leader>d",  vim.diagnostic.open_float,    "Diagnostic 詳細")
        map("n", "]d",         function() vim.diagnostic.jump({ count = 1,  float = true }) end, "次の Diagnostic")
        map("n", "[d",         function() vim.diagnostic.jump({ count = -1, float = true }) end, "前の Diagnostic")

        -- TypeScript 固有: インレイヒントの切り替え（0.10+）
        if client.server_capabilities.inlayHintProvider then
          map("n", "<leader>ih", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
          end, "インレイヒント切替")
          -- デフォルトで有効化
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end

        -- Document Highlight（カーソル下のシンボルをハイライト）
        if client.server_capabilities.documentHighlightProvider then
          local group = vim.api.nvim_create_augroup("LspDocumentHighlight_" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            group  = group,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd("CursorMoved", {
            group    = group,
            buffer   = bufnr,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end

      -- -----------------------------------------------------------------------
      -- Capabilities: nvim-cmp との統合
      -- -----------------------------------------------------------------------
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      -- nvim-cmp がロードされていれば補完能力を追加
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end
      -- 折り畳み能力（ufo.nvim などを使う場合に備えて）
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly     = true,
      }

      -- -----------------------------------------------------------------------
      -- 各 LSP サーバーの設定
      -- -----------------------------------------------------------------------

      -- TypeScript / JavaScript
      -- NOTE: Neovim 0.12 では vim.lsp.start() / vim.lsp.config() で直接起動できるが、
      --       mason-lspconfig のハンドラー経由が最もシンプル
      vim.lsp.config("ts_ls", {
        on_attach    = on_attach,
        capabilities = capabilities,
        settings = {
          typescript = {
            inlayHints = {
              includeInlayParameterNameHints         = "all",    -- "none" | "literals" | "all"
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints          = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName      = false,
              includeInlayPropertyDeclarationTypeHints              = true,
              includeInlayFunctionLikeReturnTypeHints               = true,
              includeInlayEnumMemberValueHints       = true,
            },
          },
          javascript = {
            inlayHints = {
              includeInlayParameterNameHints         = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints          = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName      = false,
              includeInlayPropertyDeclarationTypeHints              = true,
              includeInlayFunctionLikeReturnTypeHints               = true,
              includeInlayEnumMemberValueHints       = true,
            },
          },
        },
      })
      vim.lsp.enable("ts_ls")

      -- ESLint LSP（自動修正対応）
      vim.lsp.config("eslint", {
        on_attach = function(client, bufnr)
          on_attach(client, bufnr)
          -- 保存時に ESLint 自動修正を実行
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer   = bufnr,
            callback = function()
              vim.cmd("EslintFixAll")
            end,
          })
        end,
        capabilities = capabilities,
        settings = {
          workingDirectory = { mode = "auto" },
        },
      })
      vim.lsp.enable("eslint")

      -- JSON（schemastore 対応）
      vim.lsp.config("jsonls", {
        on_attach    = on_attach,
        capabilities = capabilities,
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
        -- schemastore がなければフォールバック
        on_init = function(client)
          local ok_ss = pcall(require, "schemastore")
          if not ok_ss then
            client.settings.json.schemas = {}
          end
        end,
      })
      vim.lsp.enable("jsonls")

      -- CSS
      vim.lsp.config("cssls", {
        on_attach    = on_attach,
        capabilities = capabilities,
      })
      vim.lsp.enable("cssls")

      -- HTML
      vim.lsp.config("html", {
        on_attach    = on_attach,
        capabilities = capabilities,
      })
      vim.lsp.enable("html")

      -- Emmet
      vim.lsp.config("emmet_ls", {
        on_attach    = on_attach,
        capabilities = capabilities,
        filetypes    = { "html", "css", "scss", "javascriptreact", "typescriptreact" },
      })
      vim.lsp.enable("emmet_ls")

      -- Lua（Neovim 設定ファイル向け）
      vim.lsp.config("lua_ls", {
        on_attach    = on_attach,
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime  = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library         = vim.api.nvim_get_runtime_file("", true),
            },
            diagnostics = { globals = { "vim" } },
            telemetry   = { enable = false },
          },
        },
      })
      vim.lsp.enable("lua_ls")

      -- C / C++
      vim.lsp.config("clangd", {
        on_attach    = on_attach,
        capabilities = capabilities,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders=1",
        },
        init_options = {
          usePlaceholders = true,
          completeUnimported = true,
          clangdFileStatus = true,
        },
      })
      vim.lsp.enable("clangd")

      -- Rust
      vim.lsp.config("rust_analyzer", {
        on_attach    = on_attach,
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
            },
            checkOnSave = {
              command = "clippy",
            },
            inlayHints = {
              bindingModeHints      = { enable = true },
              chainingHints         = { enable = true },
              closingBraceHints     = { enable = true, minLines = 25 },
              closureReturnTypeHints = { enable = "always" },
              lifetimeElisionHints  = { enable = "always", useParameterNames = true },
              maxLength             = 25,
              parameterHints        = { enable = true },
              reborrowHints         = { enable = "always" },
              renderColons          = true,
              typeHints             = { enable = true, hideClosureInitialization = false, hideNamedConstructor = false },
            },
            procMacro = { enable = true },
          },
        },
      })
      vim.lsp.enable("rust_analyzer")

      -- Python
      vim.lsp.config("pyright", {
        on_attach    = on_attach,
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              autoSearchPaths        = true,
              diagnosticMode         = "workspace",
              useLibraryCodeForTypes = true,
              typeCheckingMode       = "basic",
            },
          },
        },
      })
      vim.lsp.enable("pyright")

      -- Python（Ruff: Lint / Code Action 専用。Hover は pyright に任せる）
      -- uv run 経由で起動することで、プロジェクトの pyproject.toml / uv.lock に
      -- 固定された ruff のバージョンを使用する（グローバルインストール不要）。
      vim.lsp.config("ruff", {
        cmd = { "uv", "run", "ruff", "server" },
        on_attach = function(client, bufnr)
          on_attach(client, bufnr)
          -- pyright の hover と重複しないように無効化
          client.server_capabilities.hoverProvider = false
        end,
        capabilities = capabilities,
      })
      vim.lsp.enable("ruff")
    end,
  },

  -- JSON スキーマ（オプション）
  { "b0o/schemastore.nvim", lazy = true },

  -- -----------------------------------------------------------------------
  -- Diagnostic 表示設定
  -- -----------------------------------------------------------------------
  {
    -- 0.12 のネイティブ LSP では vim.lsp.start() 等で直接起動できるため lspconfig
    -- 自体は必須ではないが、各サーバーの lsp/<name>.lua（filetypes・root_markers の
    -- デフォルト）を利用するために読み込んでいる。実際の読み込みは上の
    -- mason-lspconfig 設定内の require("lspconfig") がトリガーになる。
    "neovim/nvim-lspconfig",
    lazy = true,
    config = function()
      -- Diagnostic アイコン
      local signs = {
        Error = " ",
        Warn  = " ",
        Hint  = " ",
        Info  = " ",
      }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
          source  = "if_many",  -- 複数のソースがある場合にのみ表示
        },
        float = {
          border = "rounded",
          source = "always",
        },
        signs         = true,
        underline     = true,
        update_in_insert = false,
        severity_sort    = true,
      })
    end,
  },
}
