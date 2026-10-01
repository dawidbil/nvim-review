-- Harness integration: a per-root RPC socket (driven by `nvim-review open|diff|status`)
-- and the Claude Code IDE link (claudecode.nvim, Claude runs in a separate terminal).
local ctx = require("review.context")
local diff = require("review.diff")
local M = {}

---A directory only we can use: $XDG_RUNTIME_DIR when it is ours and 0700, else
---/tmp/nvim-review-<uid> (created 0700). Anything else (other owner, group/world access,
---symlink) is refused, because Neovim's RPC lets whoever can connect run Lua in the editor.
function M.runtime_dir()
  local uid = vim.uv.os_get_passwd().uid
  local function private(d)
    local st = vim.uv.fs_lstat(d)
    return st and st.type == "directory" and st.uid == uid and bit.band(st.mode, 63) == 0
  end
  local xdg = vim.env.XDG_RUNTIME_DIR
  -- unix socket paths are limited to ~108 bytes
  if xdg and xdg ~= "" and #xdg < 70 and private(xdg) then return xdg end
  local dir = ("/tmp/nvim-review-%d"):format(uid)
  if not vim.uv.fs_lstat(dir) then vim.uv.fs_mkdir(dir, tonumber("700", 8)) end
  if private(dir) then return dir end
  return nil, "refusing unsafe socket directory " .. dir .. " (must be a real directory owned by you, mode 0700)"
end

---Deterministic socket path for a root dir (nil, err when no safe directory exists).
function M.socket_path(root)
  local dir, err = M.runtime_dir()
  if not dir then return nil, err end
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
    if not (args.first and diff.open_first(wt)) then
      diff.pick(wt)
    end
  end
  vim.cmd("redraw!")
  return { ok = true, active = wt.path }
end

function M.setup()
  -- RPC socket per root. Bind first; only when that fails do we look at what is in the way:
  -- a live socket belongs to another instance (leave it alone), a dead one is stale (replace).
  local sock, err = M.socket_path(ctx.root)
  if not sock then
    vim.notify("nvim-review: " .. err .. "; `nvim-review open|diff` disabled", vim.log.levels.WARN)
  else
    local function start()
      local ok, res = pcall(vim.fn.serverstart, sock)
      return ok and res ~= ""
    end
    if not start() and not alive(sock) then
      pcall(os.remove, sock)
      if not start() then
        vim.notify("nvim-review: could not start RPC socket " .. sock, vim.log.levels.WARN)
      end
    end
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
  local function refresh_lock()
    local okc, cc = pcall(require, "claudecode")
    if okc and ok_lock and cc.state and cc.state.port and cc.state.auth_token then
      pcall(lockfile.create, cc.state.port, cc.state.auth_token) -- same port + token, new folder list
    end
  end
  vim.api.nvim_create_autocmd("User", { pattern = "ReviewWorktreesChanged", callback = refresh_lock })
  local ok = pcall(require("claudecode").setup, {
    auto_start = true,
    terminal = { provider = "none" },
    track_selection = true,
  })
  if not ok then vim.notify("claudecode.nvim failed to start", vim.log.levels.WARN) end
end

return M
