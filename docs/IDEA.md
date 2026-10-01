# Idea: a review-first Neovim distribution

Written 2026-10-01. Original brief from Dawid, lightly structured.

## Why

AI agents now write nearly all the code. Dawid's job is reviewing it and making small edits.
Out-of-the-box git diff tooling is not satisfying. The goal is a small Neovim distribution
(start from factory Neovim, add few plugins and customizations) built for reviewing agent
output, not for authoring code.

## File-structure model

- A **root directory** where Claude Code always runs (e.g. `marcus`). The root is itself a git repo.
- Subdirectories are **other repositories** (`workspaces/*`).
- Each repository can have **multiple worktrees** where agents work in parallel.

## Problems to solve first

1. Review code across different worktrees and repositories.
2. Open code across different worktrees and repositories.
3. Strong integration with Claude Code and other harnesses.
4. Good support for non-code files (markdown first).

## Requirements

- Navigate repos and worktrees with keybinds; one "active" worktree at a time.
- File search is scoped to the active worktree (never five copies of the same file).
- Git diffs of the selected worktree/repo are one keybind away. No git write operations needed (agents do that); the use is viewing changes and making simple edits.
- Harnesses can open Neovim at a specific worktree / repo / diff (e.g. after finishing an implementation).
- No LSP, formatters or linters (the agent handles it). Clean, nice-looking code; popular filetypes (markdown etc.) rendered nicely.
- Mouse-select text copies to the system clipboard automatically (like Claude Code does).
- Every external plugin must be actively developed, well documented, popular in the community. Verified before adoption.
- Keybind-heavy: all common functionality should have a thoughtfully chosen binding.
