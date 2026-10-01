local ctx = require("review.context"); local diff = require("review.diff")
local function find(name) for _, w in ipairs(ctx.worktrees) do if w.repo == name and w.main then return w end end end
local ok = true
local function check(label, cond, extra) print((cond and "PASS " or "FAIL ") .. label .. (extra and ("  " .. extra) or "")); if not cond then ok = false end end
print("root", ctx.root)
-- F4/F5: awkward names
local wt = find("edge"); local files = diff.changed_files(wt, "HEAD")
local by = {}; for _, f in ipairs(files) do by[f.file] = f end
check("F4 file named HEAD listed as modified", by["HEAD"] and by["HEAD"].status == "M")
check("F5 unicode name has preview", by["café.txt"] and #by["café.txt"].diff > 20)
check("F5 'x b/y.txt' has correct preview", by["x b/y.txt"] and by["x b/y.txt"].diff:find("changed", 1, true) ~= nil)
check("F5 rename detected", by["renamed.txt"] and by["renamed.txt"].status == "R" and by["renamed.txt"].old == "old.txt")
check("F5 binary detected", by["blob.bin"] and by["blob.bin"].binary == true)
check("F3 staged-only change listed", by["staged.txt"] ~= nil)
-- F8: first non-binary
local opened = diff.open_first(wt); check("F8 open_first opens a non-binary file", opened and diff.session and not by[diff.session.file].binary, diff.session and diff.session.file)
diff.dismiss()
-- F6: bare repo worktree
local r = ctx.resolve(ctx.root .. "/nvr-wt")
check("F6 bare-repo worktree resolves to itself", r and r.path == ctx.root .. "/nvr-wt", r and r.path)
check("F6 repo name from bare dir", r and r.repo == "nvr", r and r.repo)
-- S2: fsmonitor trap must not run
local trap = find("trap"); ctx.git(trap.path, { "status", "--porcelain" }); diff.changed_files(trap, "HEAD")
check("S2 repo-local core.fsmonitor did not execute", vim.uv.fs_stat(ctx.root .. "/FSMON_RAN") == nil)
-- F1: last file survives a base with no changes
ctx.set_active(wt, { silent = true })
diff.open(wt, "HEAD", by["HEAD"])
check("F1 last remembered", diff.last and diff.last.file == "HEAD")
diff.close()
check("F1 last survives close()", diff.last ~= nil)
diff.dismiss(); check("F1 dismiss forgets", diff.last == nil)
vim.cmd("qa!")
