-- Harness integration: a per-root RPC socket (driven by `nvim-review open|diff|status`)
-- and the Claude Code IDE link (claudecode.nvim, Claude runs in a separate terminal).
local ctx = require("review.context")
local diff = require("review.diff")
local M = {}

---Deterministic socket path for a root dir.
function M.socket_path(root)
  local dir = vim.env.XDG_RUNTIME_DIR
  if not dir or dir == "" or vim.fn.isdirectory(dir) == 0 then dir = "/tmp" end
  return ("%s/nvim-review-%s.sock"):format(dir, vim.fn.sha256(root):sub(1, 10))
end

local function alive(path)
  if vim.uv.fs_stat(path) == nil then return false end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", path, { rpc = true })
  if ok and chan > 0 then
    pcall(vim.fn.chanclose, chan)
    return true
  end
  return false
end

-- ── commands (invoked over RPC) ──────────────────────────────────────────────

local function focus_main_window()
  -- leave pickers/explorers; land in a normal window
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

---@param cmd "open"|"diff"|"status"|"ping"
---@param args table
function M.handle(cmd, args)
  args = args or {}
  if cmd == "ping" then return "pong" end
  if cmd == "status" then
    ctx.rescan()
    return {
      root = ctx.root,
      active = ctx.active and ctx.active.path,
      base = ctx.meta.base_label,
      worktrees = vim.tbl_map(function(w) return { repo = w.repo, name = w.name, path = w.path, branch = w.branch } end, ctx.worktrees),
    }
  end

  local path = args.path
  local wt = path and ctx.resolve(path)
  if not wt then return { error = "not inside a git worktree: " .. tostring(path) } end
  if not ctx.active or ctx.active.path ~= wt.path then ctx.set_active(wt, { silent = true }) end
  if args.base == "merge-base" or args.base == "head" then
    if ctx.base_mode ~= args.base then ctx.toggle_base() end
  end

  focus_main_window()
  if cmd == "open" then
    if args.file then
      vim.cmd.edit(vim.fn.fnameescape(args.file))
      if args.line then pcall(vim.api.nvim_win_set_cursor, 0, { args.line, 0 }) end
    end
  elseif cmd == "diff" then
    if args.first then
      diff.open_first(wt)
    else
      diff.pick(wt)
    end
  end
  vim.cmd("redraw!")
  return { ok = true, active = wt.path }
end

function M.setup()
  -- RPC socket per root (first instance for a root owns it)
  local sock = M.socket_path(ctx.root)
  if not alive(sock) then
    pcall(os.remove, sock)
    pcall(vim.fn.serverstart, sock)
  end
  M.socket = sock

  -- Claude Code IDE link: Claude runs elsewhere; advertise the root AND every worktree
  -- as workspace folders so a Claude started in any of them can find this nvim.
  local ok_lock, lockfile = pcall(require, "claudecode.lockfile")
  if ok_lock then
    lockfile.get_workspace_folders = function()
      local folders, seen = { ctx.root }, { [ctx.root] = true }
      for _, wt in ipairs(ctx.worktrees) do
        if not seen[wt.path] then
          seen[wt.path] = true
          folders[#folders + 1] = wt.path
        end
      end
      return folders
    end
  end
  local ok = pcall(require("claudecode").setup, {
    auto_start = true,
    terminal = { provider = "none" },
    track_selection = true,
  })
  if not ok then vim.notify("claudecode.nvim failed to start", vim.log.levels.WARN) end
end

return M
