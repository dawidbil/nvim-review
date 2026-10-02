-- Review view: changed files of the active worktree vs a base ref (HEAD or merge-base),
-- opened as a native side-by-side diff. The right side is the REAL file (editable),
-- the left side is a read-only snapshot of the base.
local ctx = require("review.context")
local M = {}

M.session = nil ---@type {wt: review.Worktree, ref: string, file: string, lwin: integer, rwin: integer, lbuf: integer}?
M.files = {} ---@type table[] last computed changed-file list, for ]f / [f
M.last = nil ---@type {path: string, file: string}? file under review; survives "no changes under this base"

local STATUS_HL = { M = "DiffChange", A = "DiffAdd", ["?"] = "DiffAdd", D = "DiffDelete", R = "DiffText", C = "DiffAdd" }

-- ── changed files ────────────────────────────────────────────────────────────

local function parse_name_status(out)
  local files, toks = {}, vim.split(out, "\0", { plain = true })
  local i = 1
  while i <= #toks do
    local st = toks[i]
    if st == "" then break end
    local letter = st:sub(1, 1)
    if letter == "R" or letter == "C" then
      files[#files + 1] = { status = letter, old = toks[i + 1], file = toks[i + 2] }
      i = i + 3
    else
      files[#files + 1] = { status = letter, old = toks[i + 1], file = toks[i + 1] }
      i = i + 2
    end
  end
  return files
end

---Split a multi-file unified diff into one text block per file, in git's output order.
---(Content lines always start with " ", "+" or "-", so "diff --git " only ever starts a header.)
local function split_blocks(text)
  local blocks, cur = {}, nil
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line:sub(1, 11) == "diff --git " or line:sub(1, 8) == "diff --cc" then
      cur = {}
      blocks[#blocks + 1] = cur
    end
    if cur then cur[#cur + 1] = line end
  end
  for i, b in ipairs(blocks) do blocks[i] = table.concat(b, "\n") end
  return blocks
end

---`git diff --numstat -z`: binary files report "-" for both counts. Renames carry two extra tokens.
local function parse_binary(out)
  local binary, toks = {}, vim.split(out, "\0", { plain = true })
  local i = 1
  while i <= #toks do
    local rec = toks[i]
    if rec == "" then break end
    local added, _, path = rec:match("^(%-?%d*)\t(%-?%d*)\t(.*)$")
    if path == "" then -- rename/copy: "<a>\t<d>\t" NUL old NUL new
      path = toks[i + 2]
      i = i + 3
    else
      i = i + 1
    end
    if added == "-" and path then binary[path] = true end
  end
  return binary
end

-- Never run external diff drivers / textconv from a repo's own config; `--` ends revisions so
-- a file named like a ref (e.g. "HEAD") cannot be mistaken for one.
local SAFE = { "--no-ext-diff", "--no-textconv" }

local function git_diff(wt, ref, extra, paths)
  local args = { "-c", "core.quotePath=false", "diff" }
  vim.list_extend(args, SAFE)
  vim.list_extend(args, extra)
  args[#args + 1] = ref
  args[#args + 1] = "--"
  if paths then vim.list_extend(args, paths) end
  return ctx.git(wt.path, args) or ""
end

---@param wt review.Worktree
---@param ref string
function M.changed_files(wt, ref)
  local files = parse_name_status(git_diff(wt, ref, { "--name-status", "-M", "-z" }))
  local tracked = #files
  local seen = {}
  for _, f in ipairs(files) do seen[f.file] = true end

  local untracked = ctx.git(wt.path, { "ls-files", "--others", "--exclude-standard", "-z" }) or ""
  for _, path in ipairs(vim.split(untracked, "\0", { plain = true })) do
    if path ~= "" and not seen[path] then
      files[#files + 1] = { status = "?", file = path, old = path }
    end
  end

  -- diff text for previews: same order as --name-status, so match blocks by position.
  -- If the counts ever disagree, fall back to one `git diff` per file.
  local blocks = split_blocks(git_diff(wt, ref, { "-M" }))
  local by_index = #blocks == tracked
  local binary = parse_binary(git_diff(wt, ref, { "--numstat", "-M", "-z" }))

  for i, f in ipairs(files) do
    f.binary = binary[f.file] or false
    if f.status == "?" then
      local abs = wt.path .. "/" .. f.file
      local lst = vim.uv.fs_lstat(abs)
      local fh = not (lst and lst.type == "link") and io.open(abs, "rb") or nil
      local data = fh and fh:read(64 * 1024) or ""
      if fh then fh:close() end
      if lst and lst.type == "link" then
        f.diff = ("new symlink -> %s"):format(vim.uv.fs_readlink(abs) or "?")
      elseif data:find("\0", 1, true) then
        f.binary = true
        f.diff = ("new binary file %s"):format(f.file)
      else
        local lines = vim.split(data, "\n", { plain = true })
        for i, l in ipairs(lines) do lines[i] = "+" .. l end
        f.diff = ("diff --git a/%s b/%s\nnew file\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1,%d @@\n%s"):format(
          f.file, f.file, f.file, #lines, table.concat(lines, "\n"))
      end
    elseif f.binary then
      f.diff = ("Binary file %s differs"):format(f.file)
    elseif by_index then
      f.diff = blocks[i] -- tracked entries come first, in git's order
    else
      local paths = { f.file }
      if f.old and f.old ~= f.file then paths[#paths + 1] = f.old end
      f.diff = git_diff(wt, ref, { "-M" }, paths)
    end
  end
  table.sort(files, function(a, b) return a.file < b.file end)
  return files
end

-- ── side-by-side view ────────────────────────────────────────────────────────

local function scratch(name, lines, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if ft and ft ~= "" then vim.bo[buf].filetype = ft end
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, name)
  return buf
end

local function inline_off()
  local ok, gs = pcall(require, "gitsigns")
  if ok then
    pcall(gs.toggle_linehl, false)
    pcall(gs.toggle_word_diff, false)
    pcall(gs.toggle_deleted, false)
  end
end

---Close the diff and forget the file (explicit dismissal, `<leader>dq`).
function M.dismiss()
  M.close()
  M.last = nil
end

function M.close()
  local s = M.session
  M.session = nil
  if not s then return end
  if s.inline then inline_off() end
  if vim.api.nvim_win_is_valid(s.rwin) then
    vim.api.nvim_win_call(s.rwin, function() vim.cmd("diffoff") end)
  end
  if vim.api.nvim_win_is_valid(s.lwin) then
    vim.api.nvim_win_close(s.lwin, true)
  end
  if vim.api.nvim_buf_is_valid(s.lbuf) then
    pcall(vim.api.nvim_buf_delete, s.lbuf, { force = true })
  end
end

---Open the side-by-side diff of one changed-file entry.
function M.open(wt, ref, item)
  M.close()
  M.last = { path = wt.path, file = item.file }
  if item.binary then
    vim.notify(("Binary file changed: %s"):format(item.file), vim.log.levels.WARN, { title = "review" })
    return
  end
  local abs = wt.path .. "/" .. item.file
  if ctx.view_mode == "inline" and item.status ~= "D" then
    -- Inline (unified) view: the real file, with removed lines shown as virtual lines
    -- and changed lines/words highlighted by gitsigns against the review base.
    vim.cmd.edit(vim.fn.fnameescape(abs))
    local gs = require("gitsigns")
    gs.toggle_linehl(true)
    gs.toggle_word_diff(true)
    gs.toggle_deleted(true)
    M.session = { wt = wt, ref = ref, file = item.file, inline = true, lwin = -1, rwin = vim.api.nvim_get_current_win(), lbuf = -1 }
    -- gitsigns computes hunks asynchronously: wait until they exist, then jump to the first
    local buf, tries = vim.api.nvim_get_current_buf(), 0
    local function jump()
      tries = tries + 1
      if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then return end
      local hunks = gs.get_hunks(buf)
      if hunks and #hunks > 0 then
        pcall(gs.nav_hunk, "first", { navigation_message = false })
      elseif tries < 15 then
        vim.defer_fn(jump, 100)
      end
    end
    vim.defer_fn(jump, 100)
    return
  end
  local base_lines = {}
  if item.status ~= "A" and item.status ~= "?" then
    local out = ctx.git(wt.path, { "show", ref .. ":" .. item.old }) or ""
    base_lines = vim.split(out, "\n", { plain = true })
    if base_lines[#base_lines] == "" then table.remove(base_lines) end
  end

  if item.status == "D" then
    vim.cmd.enew()
    vim.bo.bufhidden = "wipe"
    vim.bo.buftype = "nofile"
    pcall(vim.api.nvim_buf_set_name, 0, "[deleted] " .. item.file)
  else
    vim.cmd.edit(vim.fn.fnameescape(abs))
  end
  local rwin = vim.api.nvim_get_current_win()
  local ft = vim.bo.filetype
  if ft == "" then ft = vim.filetype.match({ filename = item.file }) or "" end

  vim.cmd("leftabove vertical split")
  local lwin = vim.api.nvim_get_current_win()
  local lbuf = scratch(("%s:%s"):format(ref:sub(1, 8), item.old), base_lines, ft)
  vim.api.nvim_win_set_buf(lwin, lbuf)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(rwin)
  vim.cmd("diffthis")
  vim.api.nvim_win_set_cursor(rwin, { 1, 0 })
  vim.cmd("silent! normal! ]c") -- jump to the first change

  M.session = { wt = wt, ref = ref, file = item.file, lwin = lwin, rwin = rwin, lbuf = lbuf }
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(lwin),
    once = true,
    callback = function()
      if M.session and M.session.lwin == lwin then
        local s = M.session
        M.session = nil
        if vim.api.nvim_win_is_valid(s.rwin) then
          vim.api.nvim_win_call(s.rwin, function() vim.cmd("diffoff") end)
        end
      end
    end,
  })
end

-- ── entry points ─────────────────────────────────────────────────────────────

local function refresh(wt)
  local ref, label = ctx.base_ref(wt)
  M.files = M.changed_files(wt, ref)
  return ref, label
end

---Picker of changed files for the active worktree.
function M.pick(wt)
  wt = wt or ctx.active
  if not wt then return end
  local ref, label = refresh(wt)
  if #M.files == 0 then
    vim.notify(("No changes in %s vs %s"):format(wt.name, label), vim.log.levels.INFO, { title = "review" })
    return
  end
  local items = {}
  for i, f in ipairs(M.files) do
    items[i] = vim.tbl_extend("force", f, { text = f.file, cwd = wt.path, idx = i })
  end
  Snacks.picker({
    title = ("Changes: %s/%s vs %s"):format(wt.repo, wt.name, label),
    items = items,
    cwd = wt.path,
    preview = "diff",
    format = function(item, picker)
      local ret = { { item.status, STATUS_HL[item.status] or "Normal" }, { "  " } }
      vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
      if item.status == "R" then ret[#ret + 1] = { "  ← " .. item.old, "Comment" } end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function() M.open(wt, ref, item) end)
      end
    end,
  })
end

---Diff the file in the current buffer vs the base.
function M.current()
  local wt = ctx.active
  if not wt then return end
  local abs = vim.api.nvim_buf_get_name(0)
  local rel = abs:sub(1, #wt.path + 1) == wt.path .. "/" and abs:sub(#wt.path + 2) or nil
  if not rel then
    vim.notify("Current file is not inside the active worktree", vim.log.levels.WARN, { title = "review" })
    return
  end
  local ref, label = refresh(wt)
  for _, f in ipairs(M.files) do
    if f.file == rel then return M.open(wt, ref, f) end
  end
  vim.notify(("No changes in this file vs %s"):format(label), vim.log.levels.INFO, { title = "review" })
end

---Jump to the next/previous changed file (relative to the file currently shown).
function M.step(dir)
  local wt = ctx.active
  if not wt then return end
  local ref = refresh(wt)
  if #M.files == 0 then
    vim.notify("No changes", vim.log.levels.INFO, { title = "review" })
    return
  end
  local cur = M.session and M.session.file
  if not cur then
    local abs = vim.api.nvim_buf_get_name(0)
    if abs:sub(1, #wt.path + 1) == wt.path .. "/" then cur = abs:sub(#wt.path + 2) end
  end
  local idx = 0
  for i, f in ipairs(M.files) do
    if f.file == cur then idx = i end
  end
  local n = #M.files
  local nxt = idx == 0 and (dir > 0 and 1 or n) or ((idx - 1 + dir) % n + 1)
  M.open(wt, ref, M.files[nxt])
end

---Open the review of a worktree directly on its first non-binary changed file.
---@return boolean opened
function M.open_first(wt)
  local ref = refresh(wt)
  for _, f in ipairs(M.files) do
    if not f.binary then
      M.open(wt, ref, f)
      return true
    end
  end
  return false
end

-- Keep gitsigns' base in sync with the review base. change_base() is async and two calls can
-- finish out of order, so only one runs at a time and we re-check the wanted base afterwards.
-- "HEAD" is passed explicitly: nil would mean the index and hide staged changes.
local gs_inflight = false
local gs_waiters = {} ---@type function[] run once gitsigns is on the wanted base
local function sync_gitsigns(cb)
  if cb then gs_waiters[#gs_waiters + 1] = cb end
  local ok, gs = pcall(require, "gitsigns")
  local function flush()
    local ws = gs_waiters
    gs_waiters = {}
    for _, w in ipairs(ws) do w() end
  end
  if not ok or not ctx.active then return flush() end
  if gs_inflight then return end
  local want = ctx.meta.base_ref or "HEAD"
  gs_inflight = true
  local done = false
  local function finish()
    if done then return end
    done = true
    gs_inflight = false
    if (ctx.meta.base_ref or "HEAD") ~= want then sync_gitsigns() else vim.schedule(flush) end
  end
  local started = pcall(gs.change_base, want, true, finish)
  if not started then finish() else vim.defer_fn(finish, 2000) end -- never stay "in flight" forever
end

---Re-open the file currently under review (after the base or the view mode changed).
function M.reopen()
  local file = M.session and M.session.file or (M.last and M.last.file)
  M.close()
  -- Open only after gitsigns finished re-basing: change_base() detaches/re-attaches buffers,
  -- and editing the file meanwhile leaves it detached (no inline hunks).
  sync_gitsigns(function()
    local wt = ctx.active
    if not file or not wt or (M.last and M.last.path ~= wt.path) then return end
    local ref, label = refresh(wt)
    for _, f in ipairs(M.files) do
      if f.file == file then return M.open(wt, ref, f) end
    end
    -- Not changed under this base: keep showing the file (plain) and remember it, so the next
    -- toggle brings its diff back.
    local abs = wt.path .. "/" .. file
    if vim.uv.fs_stat(abs) then vim.cmd.edit(vim.fn.fnameescape(abs)) end
    vim.notify(("No changes in %s vs %s (toggle again to see its diff)"):format(file, label), vim.log.levels.INFO, { title = "review" })
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("User", {
    pattern = "ReviewContextChanged",
    callback = function()
      M.close()
      M.last = nil
      sync_gitsigns()
    end,
  })
  -- Terminal resized (e.g. i3 tiling change): re-center the cursor line in the split diff.
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      local s = M.session
      if not s or s.inline or not vim.api.nvim_win_is_valid(s.rwin) then return end
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(s.rwin) then return end
        vim.cmd("wincmd =")
        vim.api.nvim_win_call(s.rwin, function() vim.cmd("normal! zz") end)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = { "ReviewBaseChanged", "ReviewViewChanged" },
    callback = function() M.reopen() end,
  })
end

return M
