local ctx = require("review.context")
local function check(label, cond, extra) print((cond and "PASS " or "FAIL ") .. label .. (extra and ("  " .. extra) or "")) end
local edge; for _, w in ipairs(ctx.worktrees) do if w.repo == "edge" and w.main then edge = w end end
ctx.set_active(edge, { silent = true })
-- F3: staged-only change must produce hunks in HEAD mode
vim.cmd.edit(edge.path .. "/staged.txt")
local gs = require("gitsigns")
local got = vim.wait(3000, function() local h = gs.get_hunks(0); return h and #h > 0 end, 100)
check("F3 staged-only change visible to gitsigns in HEAD mode", got)
-- F2: two toggles in the same tick must end with gitsigns on the base the context wants
ctx.toggle_base(); ctx.toggle_base()
vim.wait(2500, function() return false end, 100)
local base = require("gitsigns.config").config.base
check("F2 gitsigns base matches ctx after double toggle", ctx.base_mode == "head" and base == "HEAD", tostring(base))
ctx.toggle_base(); vim.wait(1500, function() return false end, 100)
check("F2 and after single toggle", ctx.base_mode == "merge-base" and base ~= (require("gitsigns.config").config.base), tostring(require("gitsigns.config").config.base):sub(1, 10))
ctx.toggle_base(); vim.wait(800, function() return false end, 100)
-- F7: new worktree gets advertised in the Claude lock file
local cc = require("claudecode")
local lock = vim.fn.expand("~/.claude/ide/") .. cc.state.port .. ".lock"
local function folders() return vim.json.decode(table.concat(vim.fn.readfile(lock), "\n")).workspaceFolders end
local before = #folders()
vim.fn.system({ "git", "-C", edge.path, "worktree", "add", "-q", "../edge-wt2", "-b", "wt2" })
ctx.rescan()
local after = folders()
check("F7 lock file lists the new worktree", #after == before + 1 and vim.tbl_contains(after, ctx.root .. "/edge-wt2"), before .. " -> " .. #after)
local tok = vim.json.decode(table.concat(vim.fn.readfile(lock), "\n")).authToken
check("F7 auth token unchanged (same server)", tok == cc.state.auth_token)
vim.fn.system({ "git", "-C", edge.path, "worktree", "remove", "--force", "../edge-wt2" }); vim.fn.system({ "git", "-C", edge.path, "branch", "-q", "-D", "wt2" })
vim.cmd("qa!")
