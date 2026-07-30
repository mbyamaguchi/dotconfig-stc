-- Treesitter パーサーの一覧。
--
-- lazy.lua が起動時に install() へ渡すのと、bootstrap が
-- `install(...):wait()` で完了を待つのに同じリストを使うため、
-- ここを唯一の定義場所にしている。
-- （bootstrap/steps/60-neovim.sh 参照。起動時の install() は非同期なので、
--   headless nvim はパーサーのビルドが終わる前に終了してしまう。）
return {
  "typescript",
  "tsx",
  "javascript",
  "json",
  "yaml",
  "toml",
  "html",
  "css",
  "graphql",
  "lua",
  "vim",
  "vimdoc",
  "markdown",
  "markdown_inline",
  "c",
  "cpp",
  "rust",
  "python",
}
