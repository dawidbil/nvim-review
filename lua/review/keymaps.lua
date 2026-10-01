local ctx = require("review.context")
local diff = require("review.diff")
local pick = require("review.pickers")

local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true }) end

-- ── basics ───────────────────────────────────────────────────────────────────
map("i", "jk", "<Esc>", "Escape")
map("n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")
map({ "n", "i", "x" }, "<C-s>", "<cmd>write<CR><Esc>", "Save")
map("n", "<leader>s", "<cmd>write<CR>", "Save")
map("n", "<leader>S", "<cmd>wall<CR>", "Save all")
map("n", "<leader>q", "<cmd>quit<CR>", "Quit window")
map("n", "<leader>Q", "<cmd>qall<CR>", "Quit all")
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map("x", "<", "<gv", "Indent left (keep selection)")
map("x", ">", ">gv", "Indent right (keep selection)")
map("n", "<A-j>", "<cmd>m .+1<CR>==", "Move line down")
map("n", "<A-k>", "<cmd>m .-2<CR>==", "Move line up")
map("x", "<A-j>", ":m '>+1<CR>gv=gv", "Move selection down")
map("x", "<A-k>", ":m '<-2<CR>gv=gv", "Move selection up")

-- ── windows & buffers ────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", "Window left")
map("n", "<C-j>", "<C-w>j", "Window down")
map("n", "<C-k>", "<C-w>k", "Window up")
map("n", "<C-l>", "<C-w>l", "Window right")
map("n", "<leader>|", "<cmd>vsplit<CR>", "Split vertical")
map("n", "<leader>-", "<cmd>split<CR>", "Split horizontal")
map("n", "<leader>wc", "<C-w>c", "Close window")
map("n", "<S-h>", "<cmd>bprevious<CR>", "Previous buffer")
map("n", "<S-l>", "<cmd>bnext<CR>", "Next buffer")
map("n", "<leader>bd", function() Snacks.bufdelete() end, "Delete buffer")
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, "Delete other buffers")
map("n", "<leader>,", function() Snacks.picker.buffers() end, "Buffers")

-- ── worktrees (w) ────────────────────────────────────────────────────────────
map("n", "<leader>ww", pick.worktrees, "Switch worktree (all repos)")
map("n", "<leader>wr", pick.repos, "Switch repo")
map("n", "<leader>ws", pick.sibling_worktrees, "Switch worktree (this repo)")
map("n", "<leader>wn", function() ctx.cycle(1) end, "Next worktree of repo")
map("n", "<leader>wp", function() ctx.cycle(-1) end, "Previous worktree of repo")
map("n", "<leader>wi", function()
  ctx.refresh_meta()
  vim.notify(("root: %s\nactive: %s\nbase: %s"):format(ctx.root, ctx.active and ctx.active.path or "-", ctx.meta.base_label), vim.log.levels.INFO, { title = "review" })
end, "Context info")
map("n", "<leader>wR", function() ctx.rescan(); vim.notify("Rescanned worktrees") end, "Rescan repos/worktrees")

-- ── find (f) — always scoped to the active worktree ──────────────────────────
map("n", "<leader><space>", pick.files, "Find files")
map("n", "<leader>ff", pick.files, "Find files")
map("n", "<leader>fg", pick.grep, "Grep")
map("n", "<leader>/", pick.grep, "Grep")
map({ "n", "x" }, "<leader>fw", pick.grep_word, "Grep word / selection")
map("n", "<leader>fb", function() Snacks.picker.buffers() end, "Buffers")
map("n", "<leader>fr", pick.recent, "Recent files")
map("n", "<leader>fh", function() Snacks.picker.help() end, "Help")
map("n", "<leader>fk", function() Snacks.picker.keymaps() end, "Keymaps")
map("n", "<leader>fl", function() Snacks.picker.lines() end, "Lines in buffer")
map("n", "<leader>fj", function() Snacks.picker.jumps() end, "Jumplist")
map("n", "<leader>fm", function() Snacks.picker.marks() end, "Marks")
map("n", "<leader>fR", function() Snacks.picker.resume() end, "Resume last picker")
map("n", "<leader>e", pick.explorer, "File explorer")

-- ── diff / review (d) ────────────────────────────────────────────────────────
map("n", "<leader>dd", function() diff.pick() end, "Changed files (review)")
map("n", "<leader>dc", function() diff.current() end, "Diff current file")
map("n", "<leader>dB", function() ctx.toggle_base() end, "Toggle base: HEAD ↔ merge-base")
map("n", "<leader>dv", function() ctx.toggle_view() end, "Toggle view: side-by-side ↔ inline")
map("n", "<leader>dq", function() diff.close() end, "Close diff")
map("n", "]f", function() diff.step(1) end, "Next changed file")
map("n", "[f", function() diff.step(-1) end, "Previous changed file")
map("n", "<leader>dh", function() require("gitsigns").preview_hunk() end, "Preview hunk")
map("n", "<leader>di", function() require("gitsigns").preview_hunk_inline() end, "Inline hunk")
map("n", "<leader>dr", function() require("gitsigns").reset_hunk() end, "Revert hunk")
map("x", "<leader>dr", function() require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Revert selected lines")
map("n", "<leader>dw", function() require("gitsigns").toggle_word_diff() end, "Toggle word diff")
map("n", "<leader>dl", function() require("gitsigns").blame_line({ full = true }) end, "Blame line")
map("n", "<leader>dL", function() Snacks.picker.git_log({ cwd = ctx.active and ctx.active.path }) end, "Git log")
map("n", "]c", function()
  if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else require("gitsigns").nav_hunk("next") end
end, "Next hunk")
map("n", "[c", function()
  if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else require("gitsigns").nav_hunk("prev") end
end, "Previous hunk")

-- ── Claude Code (c) — Claude runs in another window; these talk over the IDE link ──
map("x", "<leader>cs", "<cmd>ClaudeCodeSend<CR>", "Send selection to Claude")
map("n", "<leader>ca", "<cmd>ClaudeCodeAdd %<CR>", "Add file to Claude context")
map("n", "<leader>cc", "<cmd>ClaudeCodeStatus<CR>", "Claude connection status")

-- ── yank paths (y) — handy for pasting into the agent ────────────────────────
local function relpath()
  local abs = vim.api.nvim_buf_get_name(0)
  local base = ctx.active and ctx.active.path or vim.uv.cwd()
  return abs:sub(1, #base + 1) == base .. "/" and abs:sub(#base + 2) or vim.fn.fnamemodify(abs, ":~")
end
map("n", "<leader>yp", function() vim.fn.setreg("+", relpath()); vim.notify("Copied " .. relpath()) end, "Copy relative path")
map("n", "<leader>yP", function() vim.fn.setreg("+", vim.api.nvim_buf_get_name(0)); vim.notify("Copied absolute path") end, "Copy absolute path")
map("n", "<leader>yl", function()
  local s = relpath() .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", s); vim.notify("Copied " .. s)
end, "Copy path:line")
map("x", "<leader>yl", function()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  local s = ("%s:%d-%d"):format(relpath(), math.min(a, b), math.max(a, b))
  vim.fn.setreg("+", s); vim.notify("Copied " .. s)
end, "Copy path:lines")

-- ── markdown / UI toggles (m, u) ─────────────────────────────────────────────
map("n", "<leader>mm", "<cmd>RenderMarkdown toggle<CR>", "Toggle markdown rendering")
map("n", "<leader>ut", function() require("review.theme").pick() end, "Theme")
map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, "Toggle wrap")
map("n", "<leader>un", function() vim.wo.number = not vim.wo.number end, "Toggle line numbers")
map("n", "<leader>ur", function() vim.wo.relativenumber = not vim.wo.relativenumber end, "Toggle relative numbers")
map("n", "<leader>?", function() require("which-key").show({ global = false }) end, "Buffer keymaps")

require("which-key").add({
  { "<leader>w", group = "worktree" },
  { "<leader>f", group = "find" },
  { "<leader>d", group = "diff / review" },
  { "<leader>c", group = "claude" },
  { "<leader>y", group = "yank path" },
  { "<leader>b", group = "buffer" },
  { "<leader>m", group = "markdown" },
  { "<leader>u", group = "ui" },
})
