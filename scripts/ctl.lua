-- Harness-facing control client. Run via:  nvim --headless -l scripts/ctl.lua <cmd> [args]
-- Exit codes: 0 ok, 1 error, 2 usage, 3 no running nvim-review for this root.
local ctx = require("review.context")
local harness = require("review.harness")

local function usage(code)
  io.stderr:write([==[
usage: nvim-review <command> [args]
  open [path[:line]]        activate the worktree containing path (default: $PWD), open the file
  diff [dir] [--base head|merge-base] [--first]
                            show changed files of the worktree (--first: jump straight into the first diff)
  status                    print root, active worktree and all known worktrees as JSON
  root                      print the detected root
env: MARCUS_ROOT overrides root detection.
]==])
  os.exit(code)
end

local cmd = arg[1]
if not cmd or cmd == "-h" or cmd == "--help" then usage(cmd and 0 or 2) end

local cwd = vim.uv.cwd()
ctx.root = ctx.find_root(cwd)
if cmd == "root" then
  io.write(ctx.root, "\n")
  os.exit(0)
end

local function abs(p) return vim.fn.fnamemodify(p, ":p"):gsub("/$", "") end

local args = {}
local positional = {}
local i = 2
while i <= #arg do
  local a = arg[i]
  if a == "--base" then
    args.base = arg[i + 1]
    i = i + 1
  elseif a == "--first" then
    args.first = true
  else
    positional[#positional + 1] = a
  end
  i = i + 1
end

if cmd == "open" then
  local target = positional[1] or cwd
  local file, line = target:match("^(.-):(%d+)$")
  if file and vim.uv.fs_stat(file) then target = file else line = nil end
  target = abs(target)
  args.path = target
  if vim.uv.fs_stat(target) and vim.uv.fs_stat(target).type == "file" then
    args.file = target
    args.line = line and tonumber(line)
  end
elseif cmd == "diff" then
  args.path = abs(positional[1] or cwd)
elseif cmd ~= "status" and cmd ~= "ping" then
  usage(2)
end

-- find a live server: this root's socket, else the only live nvim-review socket
local sock = harness.socket_path(ctx.root)
local function connect(path)
  if not vim.uv.fs_stat(path) then return nil end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", path, { rpc = true })
  return ok and chan > 0 and chan or nil
end
local chan = connect(sock)
if not chan then
  local dir = vim.env.XDG_RUNTIME_DIR
  if not dir or dir == "" then dir = "/tmp" end
  local live = {}
  for _, p in ipairs(vim.fn.glob(dir .. "/nvim-review-*.sock", false, true)) do
    local c = connect(p)
    if c then live[#live + 1] = c end
  end
  if #live == 1 then chan = live[1] end
end
if not chan then
  io.stderr:write("no running nvim-review for root " .. ctx.root .. "\n")
  os.exit(3)
end

local ok, res = pcall(vim.rpcrequest, chan, "nvim_exec_lua",
  "return require('review.harness').handle(...)", { cmd, args })
if not ok then
  io.stderr:write("rpc failed: " .. tostring(res) .. "\n")
  os.exit(1)
end
if type(res) == "table" and res.error then
  io.stderr:write(res.error .. "\n")
  os.exit(1)
end
if cmd == "status" then
  io.write(vim.json.encode(res), "\n")
elseif type(res) == "table" and res.active then
  io.write("ok: ", res.active, "\n")
end
os.exit(0)
