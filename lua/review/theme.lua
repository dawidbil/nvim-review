-- Switchable colorschemes (gruvbox default), persisted across restarts.
local M = {}

M.list = {
  { label = "gruvbox (dark)", cs = "gruvbox", bg = "dark", plugin = "gruvbox.nvim" },
  { label = "gruvbox (light)", cs = "gruvbox", bg = "light", plugin = "gruvbox.nvim" },
  { label = "catppuccin mocha", cs = "catppuccin-mocha", bg = "dark", plugin = "catppuccin" },
  { label = "catppuccin latte", cs = "catppuccin-latte", bg = "light", plugin = "catppuccin" },
  { label = "tokyonight night", cs = "tokyonight-night", bg = "dark", plugin = "tokyonight.nvim" },
  { label = "tokyonight day", cs = "tokyonight-day", bg = "light", plugin = "tokyonight.nvim" },
  { label = "kanagawa wave", cs = "kanagawa-wave", bg = "dark", plugin = "kanagawa.nvim" },
  { label = "kanagawa dragon", cs = "kanagawa-dragon", bg = "dark", plugin = "kanagawa.nvim" },
  { label = "rose-pine moon", cs = "rose-pine-moon", bg = "dark", plugin = "rose-pine" },
  { label = "rose-pine dawn", cs = "rose-pine-dawn", bg = "light", plugin = "rose-pine" },
  { label = "nightfox", cs = "nightfox", bg = "dark", plugin = "nightfox.nvim" },
  { label = "carbonfox", cs = "carbonfox", bg = "dark", plugin = "nightfox.nvim" },
  { label = "dayfox", cs = "dayfox", bg = "light", plugin = "nightfox.nvim" },
  { label = "onedark", cs = "onedark", bg = "dark", plugin = "onedark.nvim" },
  { label = "everforest (dark)", cs = "everforest", bg = "dark", plugin = "everforest" },
  { label = "everforest (light)", cs = "everforest", bg = "light", plugin = "everforest" },
  { label = "nordic", cs = "nordic", bg = "dark", plugin = "nordic.nvim" },
  { label = "vscode (dark)", cs = "vscode", bg = "dark", plugin = "vscode.nvim" },
  { label = "vscode (light)", cs = "vscode", bg = "light", plugin = "vscode.nvim" },
  { label = "oxocarbon (dark)", cs = "oxocarbon", bg = "dark", plugin = "oxocarbon.nvim" },
  { label = "oxocarbon (light)", cs = "oxocarbon", bg = "light", plugin = "oxocarbon.nvim" },
  { label = "moonfly", cs = "moonfly", bg = "dark", plugin = "moonfly" },
  { label = "monokai-pro", cs = "monokai-pro", bg = "dark", plugin = "monokai-pro.nvim" },
  { label = "sonokai", cs = "sonokai", bg = "dark", plugin = "sonokai" },
  { label = "material", cs = "material", bg = "dark", plugin = "material.nvim" },
}

local function file() return vim.fn.stdpath("state") .. "/review-theme.txt" end

function M.apply(entry)
  if entry.plugin then pcall(vim.cmd.packadd, entry.plugin) end -- themes load lazily
  vim.o.background = entry.bg
  return pcall(vim.cmd.colorscheme, entry.cs)
end

local function save(entry)
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  local f = io.open(file(), "w")
  if f then
    f:write(entry.label)
    f:close()
  end
end

local function current_entry()
  local f = io.open(file(), "r")
  local label = f and vim.trim(f:read("*a")) or nil
  if f then f:close() end
  for _, e in ipairs(M.list) do
    if e.label == label then return e end
  end
  return M.list[1]
end

function M.pick()
  local before = current_entry()
  local confirmed = false
  local items = {}
  for i, e in ipairs(M.list) do
    items[i] = { text = e.label, entry = e, idx = i }
  end
  Snacks.picker({
    title = "Theme",
    items = items,
    layout = { preset = "select" },
    preview = "none",
    format = function(item) return { { item.text } } end,
    on_change = function(_, item)
      if item then M.apply(item.entry) end
    end,
    confirm = function(picker, item)
      confirmed = true
      picker:close()
      if item then
        M.apply(item.entry)
        save(item.entry)
      end
    end,
    on_close = function()
      if not confirmed then M.apply(before) end
    end,
  })
end

function M.setup()
  if not M.apply(current_entry()) then pcall(vim.cmd.colorscheme, "habamax") end
end

return M
