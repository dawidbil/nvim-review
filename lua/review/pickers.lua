-- Pickers scoped to the ACTIVE worktree (cwd is always the active worktree).
local ctx = require("review.context")
local M = {}

local function cwd() return ctx.active and ctx.active.path or vim.uv.cwd() end

function M.files() Snacks.picker.files({ cwd = cwd(), title = "Files: " .. ctx.statusline() }) end
function M.grep() Snacks.picker.grep({ cwd = cwd(), title = "Grep: " .. ctx.statusline() }) end
function M.grep_word() Snacks.picker.grep_word({ cwd = cwd() }) end
function M.recent() Snacks.picker.recent({ filter = { cwd = cwd() } }) end
function M.explorer() Snacks.explorer({ cwd = cwd() }) end

local function worktree_items(list)
  local items, w_repo, w_name = {}, 0, 0
  for _, wt in ipairs(list) do
    w_repo = math.max(w_repo, #wt.repo)
    w_name = math.max(w_name, #wt.name)
  end
  for _, wt in ipairs(list) do
    local dirty = ctx.dirty_count(wt)
    items[#items + 1] = {
      text = table.concat({ wt.repo, wt.name, wt.branch or "" }, " "),
      wt = wt,
      dirty = dirty,
      w_repo = w_repo,
      w_name = w_name,
      file = wt.path,
      dir = true,
    }
  end
  return items
end

---Pick any worktree of any repo under the root.
function M.worktrees(list)
  ctx.rescan()
  Snacks.picker({
    title = "Worktrees — " .. vim.fs.basename(ctx.root),
    items = worktree_items(list or ctx.worktrees),
    format = function(item)
      local wt = item.wt
      local active = ctx.active and ctx.active.path == wt.path
      return {
        { active and "● " or "  ", "DiagnosticOk" },
        { ("%-" .. item.w_repo .. "s  "):format(wt.repo), "Title" },
        { ("%-" .. item.w_name .. "s  "):format(wt.name), "Normal" },
        { wt.branch or "", "Special" },
        { item.dirty > 0 and ("  ●%d"):format(item.dirty) or "  clean", item.dirty > 0 and "DiagnosticWarn" or "Comment" },
      }
    end,
    preview = function(pctx)
      local wt = pctx.item.wt
      local out = ctx.git(wt.path, { "status", "--short", "--branch" }) or ""
      local log = ctx.git(wt.path, { "log", "--oneline", "-8" }) or ""
      pctx.preview:set_lines(vim.split(out .. "\n" .. log, "\n"))
    end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() ctx.set_active(item.wt) end) end
    end,
  })
end

---Pick a repo (jumps to its last-used worktree).
function M.repos()
  ctx.rescan()
  local items = {}
  for _, r in ipairs(ctx.repos()) do
    items[#items + 1] = { text = r.name, repo = r, file = r.path, dir = true }
  end
  Snacks.picker({
    title = "Repos — " .. vim.fs.basename(ctx.root),
    items = items,
    format = function(item) return { { item.repo.name, "Title" }, { "  " .. #ctx.worktrees_of(item.repo.path) .. " worktrees", "Comment" } } end,
    preview = "none",
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() ctx.set_repo(item.repo.path) end) end
    end,
  })
end

---Pick another worktree of the active repo.
function M.sibling_worktrees()
  if ctx.active then M.worktrees(ctx.worktrees_of(ctx.active.repo_path)) end
end

return M
