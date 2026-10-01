# nvim-for-reviewing

Personal review-first Neovim distribution for an agentic workflow: review and lightly edit
agent-written code across repositories and git worktrees. See `docs/IDEA.md` (brief),
`docs/PLAN.md` (plan and decisions), `docs/PLUGINS.md` (plugin vetting).
Status: working foundation (context, scoped search, diff review, harness CLI, themes, markdown).

## Install

```sh
git clone git@github.com:dawidbil/nvim-review.git ~/nvim-for-reviewing && cd ~/nvim-for-reviewing
./install.sh        # links ~/.config/nvim-review and ~/.local/bin/nvim-review
nvim-review         # runs with NVIM_APPNAME=nvim-review, coexists with any other nvim config
```

## Using it

| Command | What it does |
|---------|--------------|
| `nvim-review` | Start the editor (also takes normal nvim args). The first instance per root owns an RPC socket. |
| `nvim-review open [path[:line]]` | Activate the worktree containing `path` (default `$PWD`) and open the file |
| `nvim-review diff [dir] [--base head\|merge-base] [--first]` | Show that worktree's changed files (`--first` jumps into the first diff) |
| `nvim-review status` / `root` | JSON of root/active/worktrees, or the detected root |

If no instance is running, `open`/`diff` start a new window (`$NVIM_REVIEW_TERMINAL`, default
`kitty --class nvim-review`, so a window manager rule can park it) and then run the command.
Root = `$MARCUS_ROOT`, else the nearest ancestor that is a git repo containing other repos.
Keymaps: `docs/KEYMAPS.md`. Test data: `scripts/make-fixtures.sh` (`docs/FIXTURES.md`).

For an agent: tell it to run `nvim-review diff` (or `nvim-review open <file:line>`) from its worktree
when it finishes. It works from any harness since it is only a shell command.

Claude Code link: in the Claude Code session (separate terminal) run `/ide` and pick "Neovim".
nvim advertises the root and every worktree as workspace folders, so a Claude started in any of
them can find it. Then `<leader>cs` (visual) sends your selection.

## Dependencies (install on every machine)

| Dependency | Required | Why / notes |
|------------|----------|-------------|
| Neovim **>= 0.12** | yes | Built-in `vim.pack`, OSC52, bundled markdown parsers. Tarball from GitHub releases (here: `~/.local/opt/`, linked as `nvim-0.12`) |
| git | yes | Repo/worktree discovery, diffs; first start clones plugins over https |
| ripgrep (`rg`) | yes | Grep, and file search when `fd` is absent |
| Nerd Font in the terminal | yes | Icons |
| Terminal with OSC52 (kitty) | yes | Mouse-select copies to the system clipboard |
| fd | optional | Slightly faster file search |
| `xclip` / `wl-clipboard` | optional | Paste from system clipboard |
| Claude Code CLI | optional | Harness link (runs in a separate terminal, never inside nvim) |

Not needed: nvim-treesitter, a C compiler, the `tree-sitter` CLI, fzf, delta, LSP servers. Only the
markdown/lua/vim parsers bundled with Neovim are used; other filetypes use Vim's regex syntax.

## Security notes

- The control socket lives in a private 0700 directory; Neovim RPC lets a connecting process run Lua.
- Repos under the root are treated as untrusted: repo-local `core.fsmonitor`/hooks are overridden for all
  git calls. Residual risk: `filter.*` clean/smudge drivers in a repo's config. Do not put repos you
  do not trust under the root.

## Layout

```
init.lua, lua/review/   the config (context, pickers, diff, harness, theme, keymaps, plugins)
bin/nvim-review         launcher + harness CLI (sets NVIM_APPNAME, checks version)
scripts/ctl.lua         RPC client behind `nvim-review open|diff|status`
scripts/make-fixtures.sh  fake repos + worktrees for testing
scripts/make-edge-fixtures.sh + tests/   awkward-name/bare-repo/fsmonitor-trap repos and regression checks
install.sh              symlinks config + launcher
nvim-pack-lock.json     pinned plugin revisions (vim.pack)
docs/             idea, plan, plugin vetting, fixtures
```
