-- nvim-for-reviewing: review-first Neovim distribution. Requires Neovim >= 0.12.
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("nvim-for-reviewing needs Neovim >= 0.12", vim.log.levels.ERROR)
  return
end
vim.loader.enable()
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("review.options")
require("review.plugins")
require("review.context").setup()
require("review.theme").setup()
require("review.keymaps")
require("review.harness").setup()
