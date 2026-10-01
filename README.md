# nvim-for-reviewing

Personal review-first Neovim distribution for an agentic workflow: review and lightly edit
agent-written code across repositories and git worktrees. See `docs/IDEA.md` (brief),
`docs/PLAN.md` (plan and decisions), `docs/PLUGINS.md` (plugin vetting).
Status: planning / foundation.

## Install

```sh
git clone <this repo> ~/nvim-for-reviewing && cd ~/nvim-for-reviewing
./install.sh        # links ~/.config/nvim-review and ~/.local/bin/nvim-review
nvim-review         # runs with NVIM_APPNAME=nvim-review, coexists with any other nvim config
```

## Dependencies (install on every machine)

Provisional until `docs/PLUGINS.md` finalises the plugin set; update this list whenever a
plugin adds a requirement.

| Dependency | Why | Notes |
|------------|-----|-------|
| Neovim **>= 0.12** | Base editor (OSC52 clipboard, treesitter, diff options) | Tarball from GitHub releases; installed here to `~/.local/opt/`, linked as `nvim-0.12` |
| git (with `worktree` support) | Repo/worktree discovery, diffs | |
| ripgrep (`rg`) | Live grep | |
| fd | Fast file finding | Not in default WSL; `apt install fd-find` (binary `fdfind`, link to `fd`) |
| fzf | Only if the chosen picker needs it | TBD |
| delta | Optional, nicer diff rendering | TBD |
| C compiler (`gcc`/`cc`) + `tree-sitter` CLI | Build treesitter parsers | TBD per vetting |
| A Nerd Font in the terminal | Icons | |
| Terminal with OSC52 support (kitty) | Mouse-select copies to system clipboard, also over SSH | `xclip`/`wl-clipboard` as fallback |
| Claude Code CLI | Harness integration | Runs in a separate terminal, not inside nvim |

## Layout

```
bin/nvim-review   launcher (sets NVIM_APPNAME, checks version)
install.sh        symlinks config + launcher
scripts/          dev helpers (e.g. fixture generator)
docs/             idea, plan, plugin vetting, fixtures
```
