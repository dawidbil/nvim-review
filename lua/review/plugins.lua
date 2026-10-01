local gh = function(path, name) return { src = "https://github.com/" .. path, name = name } end

vim.pack.add({
  gh("folke/snacks.nvim"),
  gh("lewis6991/gitsigns.nvim"),
  gh("MeanderingProgrammer/render-markdown.nvim"),
  gh("folke/which-key.nvim"),
  gh("nvim-mini/mini.icons"),
  gh("nvim-mini/mini.statusline"),
  gh("coder/claudecode.nvim"),
  -- colorschemes (switchable at runtime, see review.theme)
  gh("ellisonleao/gruvbox.nvim"),
  gh("catppuccin/nvim", "catppuccin"),
  gh("folke/tokyonight.nvim"),
  gh("rebelot/kanagawa.nvim"),
  gh("rose-pine/neovim", "rose-pine"),
}, { confirm = false })

require("mini.icons").setup()
require("snacks").setup({
  picker = { enabled = true },
  explorer = { enabled = true },
  notifier = { enabled = true },
  input = { enabled = true },
  bigfile = { enabled = true },
  quickfile = { enabled = true },
})
require("gitsigns").setup({})
require("render-markdown").setup({})
require("which-key").setup({})

require("mini.statusline").setup({
  use_icons = true,
  content = {
    active = function()
      local sl = MiniStatusline
      local mode, mode_hl = sl.section_mode({ trunc_width = 120 })
      local ctx = require("review.context")
      return sl.combine_groups({
        { hl = mode_hl, strings = { mode } },
        { hl = "MiniStatuslineDevinfo", strings = { ctx.statusline() } },
        "%<",
        { hl = "MiniStatuslineFilename", strings = { vim.fn.expand("%:.") .. "%m%r" } },
        "%=",
        { hl = "MiniStatuslineFileinfo", strings = { "vs " .. ctx.meta.base_label, vim.bo.filetype } },
        { hl = mode_hl, strings = { sl.section_location({ trunc_width = 75 }) } },
      })
    end,
  },
})

require("review.diff").setup()
