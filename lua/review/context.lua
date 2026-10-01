-- The "context": root dir -> repos -> worktrees, plus the single ACTIVE worktree.
-- Everything else (pickers, explorer, diffs, statusline, harness) reads from here.
local M = {}

local uv = vim.uv
local SKIP = { node_modules = true, scratch = true, state = true, vendor = true }

M.root = nil ---@type string?
M.worktrees = {} ---@type review.Worktree[]
M.active = nil ---@type review.Worktree?
M.base_mode = "head" ---@type "head"|"merge-base"
M.view_mode = "split" ---@type "split"|"inline" (persisted)
M.meta = { dirty = 0, base_label = "HEAD" }

---@class review.Worktree
---@field repo string repo display name
---@field repo_path string
---@field path string
---@field branch string?
---@field head string?
---@field main boolean true for the repo's main checkout
---@field name string worktree label ("(main)" or directory name)

local function realpath(p) return uv.fs_realpath(p) or p end

---Run git in `path`. Returns stdout (or nil on failure), stderr, exit code.
---Status notification that replaces itself instead of stacking.
function M.notify(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = "review", id = "review-status" })
end

function M.git(path, args, allow_fail)
  local cmd = vim.list_extend({ "git", "-C", path }, args)
  local r = vim.system(cmd, { text = true }):wait()
  if r.code ~= 0 and not allow_fail then return nil, r.stderr, r.code end
  return r.stdout, r.stderr, r.code
end

---@return "repo"|"linked"|nil
local function repo_kind(p)
  local st = uv.fs_stat(p .. "/.git")
  if not st then return nil end
  return st.type == "directory" and "repo" or "linked"
end

local function is_hidden(name) return name:sub(1, 1) == "." end

---Repos directly under `dir` (depth 1 and 2), plus `dir` itself when it is a repo.
local function scan(dir)
  local repos = {}
  if repo_kind(dir) == "repo" then repos[#repos + 1] = dir end
  for name, t in vim.fs.dir(dir) do
    if not is_hidden(name) and not SKIP[name] and (t == "directory" or t == "link") then
      local p = dir .. "/" .. name
      local kind = repo_kind(p)
      if kind == "repo" then
        repos[#repos + 1] = p
      elseif not kind then
        for n2, t2 in vim.fs.dir(p) do
          if not is_hidden(n2) and not SKIP[n2] and (t2 == "directory" or t2 == "link") then
            local p2 = p .. "/" .. n2
            if repo_kind(p2) == "repo" then repos[#repos + 1] = p2 end
          end
        end
      end
    end
  end
  return repos
end

local function has_child_repos(dir)
  for _, r in ipairs(scan(dir)) do
    if r ~= dir then return true end
  end
  return false
end

---Find the root: $MARCUS_ROOT, else the nearest ancestor that is a git repo AND contains
---other repos, else the nearest ancestor containing repos, else the git toplevel / start.
function M.find_root(start)
  local env = vim.env.MARCUS_ROOT
  if env and env ~= "" and uv.fs_stat(env) then return realpath(env) end
  start = realpath(start or uv.cwd())
  local home = realpath(uv.os_homedir())
  local nearest_any
  local p = start
  while p and p ~= "/" and p ~= home do
    if has_child_repos(p) then
      if repo_kind(p) == "repo" then return p end
      nearest_any = nearest_any or p
    end
    p = vim.fs.dirname(p)
  end
  if nearest_any then return nearest_any end
  local top = M.git(start, { "rev-parse", "--show-toplevel" })
  return top and realpath(vim.trim(top)) or start
end

local function list_worktrees(repo_path)
  local out = M.git(repo_path, { "worktree", "list", "--porcelain" })
  if not out then return {} end
  local repo = vim.fs.basename(repo_path)
  local wts, cur = {}, nil
  for line in (out .. "\n"):gmatch("(.-)\n") do
    if line:sub(1, 9) == "worktree " then
      cur = { path = realpath(line:sub(10)), repo = repo, repo_path = repo_path, main = #wts == 0 }
      wts[#wts + 1] = cur
    elseif cur then
      if line:sub(1, 5) == "HEAD " then
        cur.head = line:sub(6, 12)
      elseif line:sub(1, 7) == "branch " then
        cur.branch = (line:sub(8):gsub("^refs/heads/", ""))
      elseif line == "bare" then
        cur.bare = true
      end
    end
  end
  local res = {}
  for _, wt in ipairs(wts) do
    if not wt.bare and uv.fs_stat(wt.path) then
      wt.name = wt.main and "(main)" or vim.fs.basename(wt.path)
      wt.branch = wt.branch or (wt.head and ("detached@" .. wt.head)) or "?"
      res[#res + 1] = wt
    end
  end
  return res
end

-- ── state persistence ────────────────────────────────────────────────────────

local function state_file() return vim.fn.stdpath("state") .. "/review-context.json" end

local function read_state()
  local f = io.open(state_file(), "r")
  if not f then return {} end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(data) == "table" and data or {}
end

local function write_state(mutate)
  local data = read_state()
  mutate(data)
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  local f = io.open(state_file(), "w")
  if f then
    f:write(vim.json.encode(data))
    f:close()
  end
end

-- ── queries ──────────────────────────────────────────────────────────────────

function M.rescan()
  M.worktrees = {}
  for _, repo in ipairs(scan(M.root)) do
    vim.list_extend(M.worktrees, list_worktrees(repo))
  end
  -- keep ad-hoc worktrees (added via harness, outside root) alive across rescans
  for _, wt in ipairs(M.extra or {}) do
    M.worktrees[#M.worktrees + 1] = wt
  end
  if M.active then
    M.active = M.find(M.active.path) or M.active
  end
end

---Longest-prefix match of `path` against known worktrees.
function M.find(path)
  path = realpath(path)
  local best
  for _, wt in ipairs(M.worktrees) do
    if path == wt.path or path:sub(1, #wt.path + 1) == wt.path .. "/" then
      if not best or #wt.path > #best.path then best = wt end
    end
  end
  return best
end

---Like find(), but registers worktrees outside the root (e.g. an agent worktree elsewhere).
function M.resolve(path)
  local found = M.find(path)
  if found then return found end
  local dir = uv.fs_stat(path) and uv.fs_stat(path).type == "directory" and path or vim.fs.dirname(path)
  local top = M.git(dir, { "rev-parse", "--show-toplevel" })
  if not top then return nil end
  top = realpath(vim.trim(top))
  local common = M.git(dir, { "rev-parse", "--path-format=absolute", "--git-common-dir" })
  local repo_path = common and vim.fs.dirname(vim.trim(common)) or top
  M.extra = M.extra or {}
  for _, wt in ipairs(list_worktrees(repo_path)) do
    if not M.find(wt.path) then
      M.extra[#M.extra + 1] = wt
      M.worktrees[#M.worktrees + 1] = wt
    end
  end
  return M.find(path)
end

function M.repos()
  local names, seen = {}, {}
  for _, wt in ipairs(M.worktrees) do
    if not seen[wt.repo_path] then
      seen[wt.repo_path] = true
      names[#names + 1] = { name = wt.repo, path = wt.repo_path }
    end
  end
  return names
end

function M.worktrees_of(repo_path)
  return vim.tbl_filter(function(wt) return wt.repo_path == repo_path end, M.worktrees)
end

---Number of changed/untracked entries in a worktree.
function M.dirty_count(wt)
  local out = M.git(wt.path, { "status", "--porcelain" })
  if not out or out == "" then return 0 end
  return #vim.split(vim.trim(out), "\n")
end

function M.current_branch(wt)
  local out = M.git(wt.path, { "branch", "--show-current" })
  out = out and vim.trim(out) or ""
  return out ~= "" and out or wt.branch
end

function M.default_branch(wt)
  local out = M.git(wt.path, { "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
  if out and vim.trim(out) ~= "" then return vim.trim(out) end
  for _, b in ipairs({ "main", "master", "trunk", "develop" }) do
    if M.git(wt.path, { "rev-parse", "--verify", "--quiet", b }) then return b end
  end
end

---The ref the review diff is computed against for this worktree.
---@return string ref, string label
function M.base_ref(wt)
  wt = wt or M.active
  if M.base_mode == "merge-base" and wt then
    local def = M.default_branch(wt)
    local mb = def and M.git(wt.path, { "merge-base", "HEAD", def })
    if mb and vim.trim(mb) ~= "" then return vim.trim(mb), "merge-base(" .. def .. ")" end
  end
  return "HEAD", "HEAD"
end

function M.refresh_meta()
  if not M.active then return end
  M.active.branch = M.current_branch(M.active)
  M.meta.dirty = M.dirty_count(M.active)
  M.meta.base_label = select(2, M.base_ref(M.active))
  vim.cmd("redrawstatus")
end

function M.statusline()
  local wt = M.active
  if not wt then return "no worktree" end
  local s = ("%s · %s · %s"):format(wt.repo, wt.name, wt.branch or "?")
  if M.meta.dirty > 0 then s = s .. (" ●%d"):format(M.meta.dirty) end
  return s
end

-- ── mutation ─────────────────────────────────────────────────────────────────

---Make `wt` the active worktree: cd into it and notify listeners.
function M.set_active(wt, opts)
  opts = opts or {}
  if not wt then return end
  M.active = wt
  vim.cmd.cd(vim.fn.fnameescape(wt.path))
  write_state(function(d)
    d[M.root] = d[M.root] or {}
    d[M.root].active = wt.path
    d[M.root].last = d[M.root].last or {}
    d[M.root].last[wt.repo_path] = wt.path
  end)
  M.refresh_meta()
  vim.api.nvim_exec_autocmds("User", { pattern = "ReviewContextChanged", modeline = false })
  if not opts.silent then
    M.notify(("Worktree: %s"):format(M.statusline()))
  end
end

function M.set_repo(repo_path)
  local last = (read_state()[M.root] or {}).last or {}
  local wt = last[repo_path] and M.find(last[repo_path])
  wt = wt or M.worktrees_of(repo_path)[1]
  M.set_active(wt)
end

function M.cycle(dir)
  if not M.active then return end
  local list = M.worktrees_of(M.active.repo_path)
  for i, wt in ipairs(list) do
    if wt.path == M.active.path then
      M.set_active(list[(i - 1 + dir) % #list + 1])
      return
    end
  end
end

function M.toggle_base()
  M.base_mode = M.base_mode == "head" and "merge-base" or "head"
  M.refresh_meta()
  vim.api.nvim_exec_autocmds("User", { pattern = "ReviewBaseChanged", modeline = false })
  M.notify("Review base: " .. M.meta.base_label)
end

function M.toggle_view()
  M.view_mode = M.view_mode == "split" and "inline" or "split"
  write_state(function(d) d.view = M.view_mode end)
  vim.cmd("redrawstatus")
  vim.api.nvim_exec_autocmds("User", { pattern = "ReviewViewChanged", modeline = false })
  M.notify("Review view: " .. M.view_mode)
end

function M.setup()
  M.root = M.find_root(uv.cwd())
  M.rescan()
  local st = read_state()
  M.base_mode = "head" -- always start against HEAD; toggle with <leader>dB
  M.view_mode = st.view == "inline" and "inline" or "split"
  local cwd_wt = M.find(uv.cwd())
  local saved = st[M.root] and st[M.root].active and M.find(st[M.root].active)
  local first_arg = vim.fn.argv(0)
  local arg_wt = first_arg ~= "" and M.find(vim.fn.fnamemodify(first_arg, ":p")) or nil
  M.set_active(arg_wt or cwd_wt or saved or M.worktrees[1], { silent = true })

  local aug = vim.api.nvim_create_augroup("review_context", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufWritePost", "FileChangedShellPost" }, {
    group = aug,
    callback = function() M.refresh_meta() end,
  })
end

return M
