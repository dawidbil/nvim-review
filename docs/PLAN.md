# Plan

Status: draft for Dawid's review (2026-10-01). Nothing here is built yet.

## Findings from the current setup

- Installed Neovim is **0.9.4**. Too old for what we want (built-in OSC52 clipboard, modern
  treesitter, `vim.pack`, better diff options). Step 0 is installing a current stable release to `~/.local`.
- Current config is kickstart-based (lazy.nvim, gruvbox, telescope, LSP, cmp, conform). Most of that is deleted in the new distro.
- Tools present: git, rg, xclip. Missing: fd, fzf, delta, gh, lazygit. Terminal is kitty on WSL2/i3.
- No worktrees in use yet and no nvim `--listen` server anywhere.

## Core design: the "context"

One small Lua module is the heart of the distro. Everything else reads from it.

```
root      = directory the harness runs from (marcus/)       <- $MARCUS_ROOT or nearest ancestor with workspaces marker, else cwd
repo      = a git repo directly under root (+ root itself)  <- scanned, cached
worktree  = entry from `git worktree list --porcelain`      <- per repo
active    = {repo, worktree}                                 <- persisted in stdpath("state")
```

- Selecting a worktree sets the active context and `:tcd`s to it.
- Every file finder, grep, file tree and diff command takes its cwd from the active worktree. This is what solves "five copies of the same file".
- Statusline shows `repo · worktree · branch` always, so you never wonder where you are.
- Worktrees also show agent-useful metadata in the picker: branch, dirty/clean, ahead/behind, changed-file count.

## Components and candidate plugins

Every plugin below is a **candidate only**. Step 1 verifies each one (last commit, release cadence, stars, docs, open-issue health, Neovim-version support) and I report a verdict table before anything gets installed. Anything that fails is replaced by built-in Neovim features or a small custom module.

| Need | Approach | Candidates to verify |
|------|----------|----------------------|
| Plugin manager | lazy.nvim, or built-in `vim.pack` if the installed version makes it solid | lazy.nvim, vim.pack |
| Repo/worktree switcher + file/grep scoped to active worktree | Custom module on top of a picker | snacks.nvim picker, fzf-lua, telescope.nvim |
| File tree (scoped to worktree) | Picker-based explorer or tree plugin | snacks explorer, oil.nvim, neo-tree |
| Diff review (whole-worktree changed files, side-by-side, vs base branch or HEAD) | Changed-file list + side-by-side/inline diff | diffview.nvim, codediff-style plugins, gitsigns, built-in `diffopt` inline diff |
| Inline change markers | Gutter signs + hunk preview | gitsigns.nvim, mini.diff |
| Markdown rendering | In-buffer rendering of headings, tables, code blocks, checkboxes | render-markdown.nvim, markview.nvim |
| Syntax highlighting | Treesitter, highlight only (no LSP) | nvim-treesitter |
| Claude Code IDE link | Claude Code connects to nvim over its IDE protocol (selection context, diffs) | claudecode.nvim |
| Keybind discovery | Popup of available keys | which-key.nvim |
| Statusline / tabline | Minimal, shows context | mini.statusline, lualine |
| Colors | Keep gruvbox, or switch | gruvbox.nvim, catppuccin, tokyonight, kanagawa |
| Small editing helpers | Surround, autopairs, comment | mini.nvim modules (built-in `gc` commenting already exists) |

Deliberately excluded: LSP, mason, completion, snippets, formatters, linters, DAP.

## Harness integration (problem 3)

Two layers, no heavy plugin required for the first one.

1. **Remote control via Neovim's native RPC.** The distro starts with a deterministic socket per root (`nvim --listen $XDG_RUNTIME_DIR/marcus-nvim-<hash>.sock`, wrapped by a launcher). A CLI in `bin/` (e.g. `mnvim`) talks to it:
   - `mnvim open <worktree> [file[:line]]` - activate worktree, open file
   - `mnvim diff <worktree> [--base main]` - open the review view for that worktree
   - `mnvim review` - open the diff for whichever worktree the calling agent is in (resolved from `$PWD`)
   - If no instance is running, it launches one (new kitty window) and then sends the command.
2. **Triggers for agents.** A Claude Code skill/instruction ("when done, run `mnvim review`") and optionally a `Stop` hook, so the diff is just there when the agent finishes. Same CLI works for other harnesses since it's just a shell command.
3. **Optional: Claude Code IDE protocol** (claudecode.nvim, if it passes verification): sends your visual selection and open file to Claude as context, and lets Claude Code show its proposed diffs in nvim.
4. **Stretch: review comments.** Visual-select lines, write a short comment, and it's sent to the running agent's terminal ("in file X lines Y-Z: ..."). This is the natural "reviewer" feature; scoped after the core works.

## Keybinds (draft, leader = Space, Esc-friendly `jk` kept from current config)

Groups are mnemonic and show up in which-key.

| Group | Keys | Action |
|-------|------|--------|
| `<leader>w` worktrees | `ww` switch repo+worktree, `wr` switch repo, `wn`/`wp` next/prev worktree of repo, `wi` info | context control |
| `<leader>f` find | `ff` files (active worktree), `fg` grep, `fb` buffers, `fr` recent, `fw` word under cursor, `fh` help | scoped search |
| `<leader>e` | toggle file tree at active worktree | explorer |
| `<leader>d` diff/review | `dd` changed files vs HEAD, `db` vs base branch, `dc` current file diff, `dq` close review, `]c`/`[c` next/prev hunk, `]f`/`[f` next/prev changed file | review |
| `<leader>c` claude | `cs` send selection/file to harness, `cc` focus agent terminal, `co` open in review (for agents) | harness |
| `<leader>b` buffers | switch, close, close others | |
| `<leader>s` | save, save all, quit | |
| `<leader>m` markdown | toggle rendering | |
| window/tabs | `Ctrl-h/j/k/l` move windows (kept), `<leader>v`/`<leader>h` splits | |
| misc | `<leader>?` keymap search, `gc` comment, `gr`-style jumps stay built-in | |

## Quality-of-life defaults

- **Mouse select = copy.** Mouse on, and releasing a visual selection yanks to the system clipboard. Use Neovim's built-in OSC52 provider (works through kitty, over SSH, and on WSL2 without xclip/win32yank); keep xclip as fallback.
- Relative numbers off by default (you read more than you navigate by count); can toggle.
- Smartcase search, persistent undo, autoread (files changed by agents reload automatically, with a visible notice), `scrolloff`, no swapfiles.
- Autoread matters: agents edit files under you constantly. Add `checktime` on focus/idle plus fs-watch refresh of the diff view.

## Repo layout

```
nvim/
  init.lua                     -- minimal, loads modules
  lua/<name>/
    options.lua  keymaps.lua  plugins.lua
    context/     -- repo/worktree discovery, active state, statusline component
    pickers/     -- scoped find/grep/switcher
    review/      -- diff entrypoints, changed-file navigation
    harness/     -- RPC handlers behind `mnvim`, send-to-agent
  bin/mnvim                    -- harness-facing CLI (+ mnvim.md doc)
  docs/  IDEA.md  PLAN.md  PLUGINS.md (verification results)  KEYMAPS.md
  lazy-lock.json
```

Runs side by side with the current config via `NVIM_APPNAME`, so nothing breaks while we build.

## Phases

0. **Foundation** - install a current Neovim; scaffold repo; `NVIM_APPNAME` launcher; base options, clipboard, theme, treesitter.
1. **Plugin vetting** - verify every candidate, write `docs/PLUGINS.md`, you pick from the shortlist.
2. **Context module** - discovery, switcher, scoped find/grep/tree, statusline. (Problems 1 and 2.)
3. **Review view** - changed-file list + diffs for the active worktree, hunk navigation, edit in place. (Problem 1.)
4. **Harness CLI** - `--listen` launcher, `mnvim open/diff/review`, agent instruction/hook, wiki + `bin/index.md` docs. (Problem 3.)
5. **Filetypes** - markdown rendering and others (json, yaml, toml, html). (Problem 4.)
6. **Polish and stretch** - keymap audit, which-key groups, Claude IDE protocol, review comments.

## Decisions (2026-10-01)

1. **Name:** repo `nvim-for-reviewing`; `NVIM_APPNAME` and launcher are `nvim-review`; the harness CLI becomes subcommands of the same launcher (`nvim-review open|diff|review`) rather than a separate `mnvim`.
2. **Root detection:** automatic (nearest ancestor containing sub-repos), `$MARCUS_ROOT` overrides.
3. **Windows:** nvim and the agent always run in separate windows; Dawid manages windows (i3 can park nvim). No embedded agent terminal. So harness -> nvim communication must work across processes/terminals (RPC socket, IDE lock files).
4. **Colors:** gruvbox default plus 5-10 of the most popular maintained colorschemes, switchable at runtime with persistence.
5. **Diff baseline:** both HEAD (default) and merge-base with a base branch, switchable.
6. **Coexistence:** two configs side by side via `NVIM_APPNAME`; old kickstart config and old nvim 0.9.4 untouched. New Neovim 0.12.5 lives at `~/.local/opt/nvim-linux-x86_64`, linked as `nvim-0.12`.
7. **Claude Code plugin:** claudecode.nvim is acceptable if it works with Claude Code running in a different terminal (being verified in `docs/PLUGINS.md`).
8. **Dependencies** are tracked in `README.md`.
9. **Testing:** fake repos/worktrees with varied diffs generated by `scripts/make-fixtures.sh` (see `docs/FIXTURES.md`), since this machine has no real worktrees.
