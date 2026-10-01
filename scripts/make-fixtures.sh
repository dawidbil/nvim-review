#!/usr/bin/env bash
# Generate reproducible git fixtures for testing the Neovim review tool.
set -euo pipefail

DEFAULT_OUT="/home/toothless/marcus/scratch/review-fixtures"
MARKER=".review-fixtures"

usage() {
  cat <<USAGE
Usage: make-fixtures.sh [OUTPUT_DIR]
       make-fixtures.sh --help

Wipes and recreates a fixture tree: a ROOT git repo containing sub-repos
(pyapp, tsapp, luacfg, docs), each with a main branch (3-5 commits) and
2-3 git worktrees at <repo>.worktrees/<name> on feature branches.

  OUTPUT_DIR   default: $DEFAULT_OUT
               Existing contents are deleted ONLY if OUTPUT_DIR contains a
               '$MARKER' marker file (or is missing/empty).

Only local git config is set (user.name/email per repo); global config is
never touched. Layout is documented in docs/FIXTURES.md.
USAGE
}

case "${1:-}" in -h|--help) usage; exit 0;; esac

OUT="${1:-$DEFAULT_OUT}"
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

case "$OUT" in /|"$HOME"|/home|/tmp|/usr|/etc) echo "refusing unsafe path: $OUT" >&2; exit 1;; esac
if [[ -e "$OUT" ]]; then
  if [[ ! -d "$OUT" ]]; then echo "not a directory: $OUT" >&2; exit 1; fi
  if [[ ! -f "$OUT/$MARKER" && -n "$(ls -A "$OUT")" ]]; then
    echo "refusing to wipe $OUT: no $MARKER marker file" >&2; exit 1
  fi
  rm -rf "$OUT"
fi
mkdir -p "$OUT"
echo "fixture generator; safe to delete" > "$OUT/$MARKER"

export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_DATE="2026-01-01T12:00:00" GIT_COMMITTER_DATE="2026-01-01T12:00:00"

# ---------- helpers ----------
init_repo() { # dir
  mkdir -p "$1"; cd "$1"
  git init -q -b main
  git config user.name "Fixture Bot"
  git config user.email "fixtures@example.invalid"
  git config commit.gpgsign false
}
put() { # path  (content on stdin)
  mkdir -p "$(dirname "$1")"; cat > "$1"
}
commit() { # message
  git add -A; git commit -q -m "$1"
}
tick=0
bump() { tick=$((tick+1)); export GIT_AUTHOR_DATE="2026-01-0${tick}T12:00:00" GIT_COMMITTER_DATE="2026-01-0${tick}T12:00:00"; }
wt() { # repo name branch   (creates ../repo.worktrees/name)
  mkdir -p "$OUT/$1.worktrees"
  git -C "$OUT/$1" worktree add -q -b "$3" "$OUT/$1.worktrees/$2" main
  git -C "$OUT/$1.worktrees/$2" config user.name "Fixture Bot" 2>/dev/null || true
}
bin_png() { printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0aIDAT\x78\x9c\x63\x00\x01\x00\x00\x05\x00\x01%s' "$1"; }
many_lines() { # n prefix
  for i in $(seq 1 "$1"); do echo "$2 $i: value = $((i*7 % 13))"; done
}

# ---------- ROOT repo ----------
init_repo "$OUT"
put .gitignore <<'X'
/pyapp/
/tsapp/
/luacfg/
/docs/
*.worktrees/
X
put CLAUDE.md <<'X'
# Root workspace

Sub-repos live next to this file. Worktrees are `<repo>.worktrees/<name>`.
- pyapp: small Flask-like python app
- tsapp: TypeScript CLI
- luacfg: Neovim lua config
- docs: markdown handbook
X
put notes/todo.md <<'X'
# Todo

- [ ] review pyapp feat-auth
- [x] write fixtures
- [ ] try scoped search
X
put notes/ideas.md <<'X'
# Ideas

1. Scope file search to a worktree
2. Diff against merge-base
   - not just HEAD
   - include untracked
X
bump; commit "root: initial notes"

# ---------- pyapp ----------
init_repo "$OUT/pyapp"
put README.md <<'X'
# pyapp
Tiny task API.
X
put src/main.py <<'X'
"""pyapp entry point."""
from src.utils import slugify


def main():
    print(slugify("Hello World"))


if __name__ == "__main__":
    main()
X
put src/utils.py <<'X'
import re


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
X
put tests/test_utils.py <<'X'
from src.utils import slugify


def test_slugify():
    assert slugify("A b") == "a-b"
X
bump; commit "initial pyapp"
put src/models.py <<'X'
class Task:
    def __init__(self, title):
        self.title = title
X
bump; commit "add Task model"
put src/legacy.py <<'X'
# legacy helpers, to be removed
def old():
    return 1
X
put src/config.py <<'X'
DEBUG = False
X
bump; commit "add config and legacy"
bin_png A > assets_logo.png
mkdir -p assets; mv assets_logo.png assets/logo.png
many_lines 120 "row" > src/data.txt
bump; commit "add logo and data"
wt pyapp auth feat/auth
wt pyapp cleanup chore/cleanup
wt pyapp clean feat/clean
# main advances AFTER branching (feat/auth merge-base != main HEAD)
cd "$OUT/pyapp"
put src/utils.py <<'X'
import re


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def truncate(s, n=20):
    return s if len(s) <= n else s[: n - 1] + "…"
X
bump; commit "main: add truncate"

# pyapp/auth: committed + staged + modified + untracked
cd "$OUT/pyapp.worktrees/auth"
put src/auth.py <<'X'
import hashlib


def hash_pw(pw):
    return hashlib.sha256(pw.encode()).hexdigest()
X
put src/main.py <<'X'
"""pyapp entry point."""
from src.utils import slugify
from src.auth import hash_pw


def main():
    print(slugify("Hello World"))
    print(hash_pw("secret"))


if __name__ == "__main__":
    main()
X
bump; commit "feat: password hashing"
echo 'SECRET_KEY = "dev"' >> src/config.py; git add src/config.py   # staged
echo '# TODO: rate limit' >> src/auth.py                            # modified unstaged
echo 'wip' > notes.txt                                              # untracked
put src/session.py <<'X'
def new_session(user):
    return {"user": user}
X

# pyapp/cleanup: deleted, large diff, binary modified, renamed
cd "$OUT/pyapp.worktrees/cleanup"
rm src/legacy.py                                       # deleted (unstaged)
many_lines 260 "newrow" > src/data.txt                 # large diff (~380 lines)
bin_png B > assets/logo.png                            # binary modified
git mv src/models.py src/entities.py                   # renamed (staged)

# ---------- tsapp ----------
init_repo "$OUT/tsapp"
put README.md <<'X'
# tsapp
TypeScript CLI.
X
put package.json <<'X'
{ "name": "tsapp", "version": "0.1.0", "scripts": { "build": "tsc" } }
X
put src/main.ts <<'X'
import { greet } from "./utils";

console.log(greet(process.argv[2] ?? "world"));
X
put src/utils.ts <<'X'
export function greet(name: string): string {
  return `hello, ${name}`;
}
X
put src/main.py <<'X'
"""codegen helper (shares its name with pyapp/src/main.py on purpose)."""
print("codegen")
X
put src/utils.py <<'X'
def header():
    return "// generated"
X
bump; commit "initial tsapp"
put src/parse.ts <<'X'
export function parse(s: string): string[] {
  return s.split(",").map((x) => x.trim());
}
X
bump; commit "add parser"
put src/old-cli.js <<'X'
module.exports = function () { return 1; };
X
bump; commit "add old cli"
bump; echo "More docs." >> README.md; commit "readme tweak"
wt tsapp ui feat/ui
wt tsapp parsefix fix/parse
wt tsapp clean chore/clean

cd "$OUT/tsapp.worktrees/ui"
put src/ui.ts <<'X'
export const render = (t: string) => `<b>${t}</b>`;
X
bump; commit "feat: ui render"
git mv src/utils.ts src/helpers.ts            # renamed, staged
echo "export const x = 1;" >> src/helpers.ts  # modified after rename
put src/new-thing.ts <<'X'
export {};
X
bin_png C > src/icon.png                      # untracked binary

cd "$OUT/tsapp.worktrees/parsefix"
sed -i 's#split(",")#split(/[,;]/)#' src/parse.ts   # modified unstaged
git rm -q src/old-cli.js                            # deleted + staged
echo 'console.log("debug")' >> src/main.ts
git add src/main.ts
echo 'more' >> src/main.ts                          # staged + further unstaged

# ---------- luacfg ----------
init_repo "$OUT/luacfg"
put README.md <<'X'
# luacfg
Neovim config.
X
put init.lua <<'X'
require("options")
require("keys")
X
put lua/options.lua <<'X'
vim.opt.number = true
vim.opt.tabstop = 2
X
put lua/keys.lua <<'X'
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")
X
put lua/utils.lua <<'X'
local M = {}
function M.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
return M
X
put src/main.py <<'X'
print("bootstrap installer")
X
bump; commit "initial luacfg"
put lua/plugins.lua <<'X'
return { "folke/lazy.nvim" }
X
bump; commit "add plugins"
bump; echo 'vim.opt.wrap = false' >> lua/options.lua; commit "no wrap"
wt luacfg keys feat/keys
wt luacfg wip wip/theme

cd "$OUT/luacfg.worktrees/keys"
put lua/keys.lua <<'X'
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>")
vim.keymap.set("n", "<leader>e", "<cmd>Explore<cr>")
X
bump; commit "feat: more keymaps"
echo 'vim.opt.cursorline = true' >> lua/options.lua   # modified unstaged

cd "$OUT/luacfg.worktrees/wip"
mv lua/utils.lua lua/helpers.lua                       # rename (unstaged: D + ??)
put lua/theme.lua <<'X'
vim.cmd.colorscheme("habamax")
X
git add lua/theme.lua                                  # staged new

# ---------- docs ----------
init_repo "$OUT/docs"
put README.md <<'X'
# Handbook

Welcome. See [guide](guide/intro.md).
X
put guide/intro.md <<'X'
# Intro

A paragraph with `inline code` and a very long line that keeps going and going so that wrapping behaviour in the review buffer can be exercised: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua, ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

## Checklist

- [x] install
- [ ] configure
- [ ] profit

## Nested

- level 1
  - level 2
    - level 3
      - level 4
1. first
   1. sub-first
   2. sub-second
2. second
X
put guide/reference.md <<'X'
# Reference

| Command | Description        | Default |
|---------|--------------------|---------|
| `run`   | Run the thing      | no      |
| `build` | Build, then deploy | yes     |

```python
def hello():
    print("hi")
```

```lua
print("hi")
```
X
put src/main.py <<'X'
# snippet used by docs examples (same name as in other repos)
print("example")
X
put src/utils.md <<'X'
# Utils
Notes about helpers.
X
bump; commit "initial docs"
bump; echo "More intro text." >> guide/intro.md; commit "extend intro"
bump; put guide/faq.md <<'X'
# FAQ

**Q:** Why?
**A:** Because.
X
commit "add faq"
wt docs restructure docs/restructure
wt docs clean docs/clean

cd "$OUT/docs.worktrees/restructure"
mkdir -p guide/advanced
git mv guide/reference.md guide/advanced/reference.md
bump; commit "docs: move reference"
echo "- [ ] new checklist item" >> guide/intro.md
many_lines 40 "line" >> guide/faq.md
put guide/draft.md <<'X'
# Draft
TBD
X

# ---------- summary ----------
cd "$OUT"
echo "Fixtures ready in $OUT"
for r in pyapp tsapp luacfg docs; do
  echo "== $r"; git -C "$OUT/$r" worktree list
done
