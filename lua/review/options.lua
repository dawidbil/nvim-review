local o = vim.opt

o.termguicolors = true
o.number = true
o.relativenumber = false
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.splitright = true
o.splitbelow = true
o.confirm = true
o.showmode = false -- statusline shows it
o.laststatus = 3

-- Reading comfort: soft-wrap at word boundaries, keep indent.
o.wrap = true
o.linebreak = true
o.breakindent = true

o.ignorecase = true
o.smartcase = true
o.undofile = true
o.swapfile = false
o.updatetime = 400
o.timeoutlen = 400

-- Mouse: select with the mouse, right-click extends (no popup menu).
o.mouse = "a"
o.mousemodel = "extend"

-- Diff: char-level highlights inside changed lines, better alignment.
o.diffopt:append({ "inline:char", "linematch:60", "algorithm:histogram" })
o.fillchars:append({ diff = " " })

-- Agents edit files under us: reload on change, notify when it happens.
o.autoread = true
local aug = vim.api.nvim_create_augroup("review_autoread", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = aug,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("silent! checktime")
    end
  end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = aug,
  callback = function(ev)
    vim.notify("Reloaded (changed on disk): " .. vim.fn.fnamemodify(ev.file, ":~:."), vim.log.levels.INFO)
  end,
})

-- Clipboard: copy through OSC52 (kitty, works over SSH/WSL); paste from xclip when available.
do
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    local function paste(reg)
      return function()
        if vim.fn.executable("xclip") == 1 and vim.env.DISPLAY then
          local sel = reg == "+" and "clipboard" or "primary"
          local out = vim.fn.systemlist({ "xclip", "-o", "-selection", sel })
          if vim.v.shell_error == 0 then
            return { out, vim.fn.getregtype(reg) }
          end
        end
        return { vim.fn.split(vim.fn.getreg(reg), "\n"), vim.fn.getregtype(reg) }
      end
    end
    vim.g.clipboard = {
      name = "osc52-copy",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste("+"), ["*"] = paste("*") },
    }
  end
  o.clipboard = "unnamedplus"

  -- Select with the mouse => copied (and the selection stays visible), like Claude Code.
  vim.keymap.set("x", "<LeftRelease>", '"+ygv', { desc = "Copy mouse selection" })
end

-- Highlight yanked text briefly.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})
