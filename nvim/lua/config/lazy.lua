local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
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
      require("monokai-pro").setup({
        transparent_background = false,
        terminal_colors = true,
        devicons = true,
        styles = {
          comment = { italic = true },
          keyword = { italic = true },
          type = { italic = true },
          storageclass = { italic = true },
          structure = { italic = true },
          parameter = { italic = true },
          annotation = { italic = true },
          tag_attribute = { italic = true },
        },
        filter = "pro", --classic | octagon | pro | machine | ristretto | spectrum
        day_night = {
          enable = false,
          day_filter = "pro",
          night_filter = "spectrum",
        },
        inc_search = "background", -- underline | background
        background_clear = {
          "toggleterm",
          "telescope",
          "renamer",
          "notify",
        },
        plugins = {
          bufferline = {
            underline_selected = false,
            underline_visible = false,
            underline_fill = false,
            bold = true,
          },
          indent_blankline = {
            context_hightlight = "default",
            context_start_undeline = false,
          },
        },
        override = function(scheme)
          return {}
        end,
        override_palette = function(filter)
          return {}
        end,
        override_scheme = function(scheme, palette, colors)
          return {}
        end,
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
              if #clients == 0 then return "" end
              local names = vim.tbl_map(function(c) return c.name end, clients)
              return " " .. table.concat(names, ", ")
            end,
            color = { fg = "#7aa2f7" },
          },
          "encoding", "fileformat", "filetype",
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
    event = "BufReadPost",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "typescript", "tsx", "javascript",
          "json", "jsonc", "yaml", "toml",
          "html", "css", "graphql",
          "lua", "vim", "vimdoc",
          "markdown", "markdown_inline",
          "c", "cpp",
          "rust",
          "python",
        },
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
            goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
          },
        },
      })
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
      { "s", function() require("flash").jump() end, mode = { "n", "x", "o" }, desc = "Flash" },
      { "S", function() require("flash").treesitter() end, mode = { "n", "x", "o" }, desc = "Flash Treesitter" },
    },
    opts = {},
  },
}, {
  -- options for lazy.nvim
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "matchit", "matchparen",
        "netrwPlugin", "tarPlugin",
        "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
