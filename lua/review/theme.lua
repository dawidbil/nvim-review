-- Switchable colorschemes (gruvbox default), persisted across restarts.
local M = {}

M.list = {
  { label = "gruvbox (dark)", cs = "gruvbox", bg = "dark" },
  { label = "gruvbox (light)", cs = "gruvbox", bg = "light" },
  { label = "catppuccin mocha", cs = "catppuccin-mocha", bg = "dark" },
  { label = "catppuccin latte", cs = "catppuccin-latte", bg = "light" },
  { label = "tokyonight night", cs = "tokyonight-night", bg = "dark" },
  { label = "tokyonight day", cs = "tokyonight-day", bg = "light" },
  { label = "kanagawa wave", cs = "kanagawa-wave", bg = "dark" },
  { label = "kanagawa dragon", cs = "kanagawa-dragon", bg = "dark" },
  { label = "rose-pine moon", cs = "rose-pine-moon", bg = "dark" },
  { label = "rose-pine dawn", cs = "rose-pine-dawn", bg = "light" },
}

local function file() return vim.fn.stdpath("state") .. "/review-theme.txt" end

function M.apply(entry)
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
