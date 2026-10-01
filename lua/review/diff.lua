-- Review view: changed files of the active worktree vs a base ref (HEAD or merge-base),
-- opened as a native side-by-side diff. The right side is the REAL file (editable),
-- the left side is a read-only snapshot of the base.
local ctx = require("review.context")
local M = {}

M.session = nil ---@type {wt: review.Worktree, ref: string, file: string, lwin: integer, rwin: integer, lbuf: integer}?
M.files = {} ---@type table[] last computed changed-file list, for ]f / [f

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

---Split a multi-file unified diff into { [path] = text }.
local function split_diff(text)
  local blocks, cur, cur_file = {}, nil, nil
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local b = line:match("^diff %-%-git a/.- b/(.*)$")
    if b then
      cur_file, cur = b, {}
      blocks[cur_file] = cur
    end
    if cur then cur[#cur + 1] = line end
  end
  for k, v in pairs(blocks) do
    blocks[k] = table.concat(v, "\n")
  end
  return blocks
end

---@param wt review.Worktree
---@param ref string
function M.changed_files(wt, ref)
  local out = ctx.git(wt.path, { "diff", "--name-status", "-M", "-z", ref }) or ""
  local files = parse_name_status(out)
  local seen = {}
  for _, f in ipairs(files) do seen[f.file] = true end

  local untracked = ctx.git(wt.path, { "ls-files", "--others", "--exclude-standard", "-z" }) or ""
  for _, path in ipairs(vim.split(untracked, "\0", { plain = true })) do
    if path ~= "" and not seen[path] then
      files[#files + 1] = { status = "?", file = path, old = path }
    end
  end

  -- diff text (for previews) + binary detection
  local diff_text = ctx.git(wt.path, { "diff", "-M", ref }) or ""
  local blocks = split_diff(diff_text)
  local numstat = ctx.git(wt.path, { "diff", "--numstat", "-M", ref }) or ""
  local binary = {}
  for line in numstat:gmatch("[^\n]+") do
    local path = line:match("^%-\t%-\t(.*)$")
    if path then binary[path] = true end
  end

  for _, f in ipairs(files) do
    f.binary = binary[f.file] or false
    if f.status == "?" then
      local abs = wt.path .. "/" .. f.file
      local fh = io.open(abs, "rb")
      local data = fh and fh:read(64 * 1024) or ""
      if fh then fh:close() end
      if data:find("\0", 1, true) then
        f.binary = true
        f.diff = ("new binary file %s"):format(f.file)
      else
        local lines = vim.split(data, "\n", { plain = true })
        for i, l in ipairs(lines) do lines[i] = "+" .. l end
        f.diff = ("diff --git a/%s b/%s\nnew file\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1,%d @@\n%s"):format(
          f.file, f.file, f.file, #lines, table.concat(lines, "\n"))
      end
    else
      f.diff = blocks[f.file] or (f.binary and ("Binary file %s differs"):format(f.file) or "")
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

---Open the review of a worktree directly on its first changed file (used by the harness).
function M.open_first(wt)
  local ref = refresh(wt)
  if #M.files > 0 then M.open(wt, ref, M.files[1]) end
end

-- keep gitsigns' gutter in sync with the review base
local function sync_gitsigns()
  local ok, gs = pcall(require, "gitsigns")
  if not ok or not ctx.active then return end
  local ref = ctx.base_ref(ctx.active)
  pcall(gs.change_base, ref ~= "HEAD" and ref or nil, true)
end

---Re-open the file currently under review (after the base or the view mode changed).
function M.reopen()
  local file = M.session and M.session.file
  M.close()
  sync_gitsigns()
  if not file or not ctx.active then return end
  local ref, label = refresh(ctx.active)
  for _, f in ipairs(M.files) do
    if f.file == file then return M.open(ctx.active, ref, f) end
  end
  vim.notify(("No changes in %s vs %s"):format(file, label), vim.log.levels.INFO, { title = "review" })
end

function M.setup()
  vim.api.nvim_create_autocmd("User", {
    pattern = "ReviewContextChanged",
    callback = function()
      M.close()
      sync_gitsigns()
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = { "ReviewBaseChanged", "ReviewViewChanged" },
    callback = function() M.reopen() end,
  })
end

return M
