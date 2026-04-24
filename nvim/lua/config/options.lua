local opt = vim.opt

-- 外観・視覚効果
opt.termguicolors = true   -- 24bitカラーを有効化
opt.number = true          -- 行番号を表示
opt.relativenumber = true  -- 相対行番号（ジャンプ移動に便利）
opt.cursorline = true      -- カーソル行を強調
opt.signcolumn = "yes"     -- 常にサインカラムを表示（LSPエラー時のガタつき防止）

-- インデント・空白
opt.expandtab = true       -- タブをスペースに変換
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true

-- 検索設定
opt.ignorecase = true      -- 大文字小文字を区別しない
opt.smartcase = true       -- 大文字が含まれる場合は区別する
opt.hlsearch = true        -- 検索結果をハイライト

-- 0.12の新機能・最適化
opt.smoothscroll = true    -- 滑らかなスクロール
opt.pumblend = 10          -- ポップアップメニューを少し透過
opt.laststatus = 3         -- グローバルステータスライン（画面下部をスッキリさせる）


opt.clipboard = "unnamedplus"

