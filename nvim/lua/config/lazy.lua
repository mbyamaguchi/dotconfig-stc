local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  -- lazy-lock.json pins lazy.nvim along with everything else, so clone that
  -- exact commit instead of whatever the `stable` tag points at today.
  -- 一致させないと、新規マシンでは lazy.nvim 自身だけがロックファイルと
  -- 違う版になり、起動時に lazy が lazy-lock.json を書き換えてしまう。
  local pinned
  do
    local f = io.open(vim.fn.stdpath("config") .. "/lazy-lock.json", "r")
    if f then
      local ok, lock = pcall(vim.json.decode, f:read("*a"))
      f:close()
      if ok and type(lock) == "table" and lock["lazy.nvim"] then
        pinned = lock["lazy.nvim"].commit
      end
    end
  end

  local args = { "git", "clone", "--filter=blob:none", lazyrepo, lazypath }
  if not pinned then
    -- ロックファイルが無いとき（まったく新規の環境）だけ stable にフォールバック
    table.insert(args, 5, "--branch=stable")
  end

  local out = vim.fn.system(args)
  if vim.v.shell_error == 0 and pinned then
    out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", pinned })
  end
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- <leader> key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lazy").setup({
  -- color scheme
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- デフォルト値と異なる設定のみ指定する
      require("monokai-pro").setup({
        devicons = true,
        filter = "pro", --classic | octagon | pro | machine | ristretto | spectrum
      })
      vim.cmd.colorscheme("monokai-pro")
    end,
  },
  -- UI enhancement
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "monokai-pro",
        globalstatus = true,
      },
      sections = {
        lualine_c = {
          { "filename", path = 1 }, -- relative path
        },
        lualine_x = {
          -- LSP server name
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              if #clients == 0 then
                return ""
              end
              local names = vim.tbl_map(function(c)
                return c.name
              end, clients)
              return " " .. table.concat(names, ", ")
            end,
            color = { fg = "#7aa2f7" },
          },
          "encoding",
          "fileformat",
          "filetype",
        },
      },
    },
  },

  -- indent guide
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPost",
    main = "ibl",
    opts = {
      indent = { char = "|" },
      scope = { enabled = true },
    },
  },

  -- file tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "FileTree" } },
    opts = {
      filters = { dotfiles = false },
      renderer = { group_empty = true },
    },
  },

  -- TreeSitter : syntax highlighting, text objects

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false, -- new rewrite does not support lazy-loading
    config = function()
      require("nvim-treesitter").setup()
      -- リストは config/treesitter-parsers.lua に置いている。bootstrap も
      -- 同じものを読んで install() の完了を待つため（install() は非同期で、
      -- headless nvim はビルド完了前に終了してしまう）。
      require("nvim-treesitter").install(require("config.treesitter-parsers"))
      -- main ブランチはハイライトを自動で有効にしないため、
      -- パーサーのあるバッファで明示的に有効化する
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })
      local sel = require("nvim-treesitter-textobjects.select")
      vim.keymap.set({ "x", "o" }, "af", function()
        sel.select_textobject("@function.outer", "textobjects")
      end)
      vim.keymap.set({ "x", "o" }, "if", function()
        sel.select_textobject("@function.inner", "textobjects")
      end)
      vim.keymap.set({ "x", "o" }, "ac", function()
        sel.select_textobject("@class.outer", "textobjects")
      end)
      vim.keymap.set({ "x", "o" }, "ic", function()
        sel.select_textobject("@class.inner", "textobjects")
      end)
      local mov = require("nvim-treesitter-textobjects.move")
      vim.keymap.set("n", "]f", function()
        mov.goto_next_start("@function.outer", "textobjects")
      end)
      vim.keymap.set("n", "]c", function()
        mov.goto_next_start("@class.outer", "textobjects")
      end)
      vim.keymap.set("n", "[f", function()
        mov.goto_previous_start("@function.outer", "textobjects")
      end)
      vim.keymap.set("n", "[c", function()
        mov.goto_previous_start("@class.outer", "textobjects")
      end)
    end,
  },

  -- LSP
  { import = "config.plugins.lsp" },

  -- autocopmletion
  { import = "config.plugins.cmp" },

  -- formatter
  { import = "config.plugins.conform" },

  -- ESLint
  { import = "config.plugins.lint" },

  -- Telescope
  { import = "config.plugins.telescope" },

  -- Others

  -- Auto Pairing
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true },
  },

  -- comment out
  {
    "numToStr/Comment.nvim",
    keys = { "gc", "gb" },
    opts = {},
  },

  -- surround
  {
    "kylechui/nvim-surround",
    keys = { "ys", "ds", "cs" },
    version = "*",
    opts = {},
  },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- todo-comments
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- flash.nvim
  {
    "folke/flash.nvim",
    keys = {
      {
        "s",
        function()
          require("flash").jump()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash",
      },
      {
        "S",
        function()
          require("flash").treesitter()
        end,
        mode = { "n", "x", "o" },
        desc = "Flash Treesitter",
      },
    },
    opts = {},
  },
}, {
  -- options for lazy.nvim
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
