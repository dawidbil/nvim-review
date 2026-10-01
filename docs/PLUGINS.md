# Plugin vetting results

Checked: **2026-10-01**. Method: GitHub REST API (stars, `pushed_at`, open issue+PR count, archived flag), GitHub `releases.atom` / `commits.atom` feeds (the API hit the unauthenticated rate limit mid-run), and READMEs / Neovim runtime docs fetched from raw.githubusercontent.com and github.com.

Caveats, honestly:
- "Last commit" is the repo `pushed_at` (any branch), so it can be slightly later than the last commit on the default branch.
- "Last release" comes from the Atom feed; `-` means no tagged releases (the plugin is meant to be tracked from the default branch). Release feeds were parsed crudely; treat dates as +/- a few days.
- "Min nvim" is what each README states. Where I could not fetch it, it is marked `?`. Several READMEs are stale about their real floor, so we should target Neovim 0.12.x anyway.
- "Issues" = open issues + PRs as reported by the API. Raw counts mean little for big projects.
- Nothing was installed or run. Claims about runtime behaviour (especially claudecode.nvim with a separate terminal) come from docs/source, not tests. Test before relying on them.
- Stars of `mini.*` sub-repos are read-only mirrors of `nvim-mini/mini.nvim`; judge by the monorepo.

Neovim itself: latest stable is **0.12.5 (2026-08-23)**, 0.12.0 was 2026-03-29, 0.11.7 on 2026-03-28. Plan: require 0.12.x.
Source: https://github.com/neovim/neovim/releases

---

## 1. Plugin manager

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| folke/lazy.nvim | 21.6k | 2026-06-29 | v11.17.5 (2025-11-06) | 0.8 | PASS | De facto standard, lockfile, lazy loading, UI, fine docs. Commits slower than before but healthy. |
| built-in `vim.pack` | n/a | n/a | shipped in Nvim 0.12 | 0.12 | PASS (CAUTION: experimental label) | Docs still say "experimental, yet stable enough for daily use". Git-based, lockfile `nvim-pack-lock.json`, `vim.pack.add/update/del/get`, interactive update buffer, `PackChanged` hooks. No lazy-loading: plugins load on `add()`. |

Notes:
- With a handful of plugins, lack of lazy loading is irrelevant (startup is cheap). `vim.pack` means zero external code for plugin management, matching the "factory Neovim plus few plugins" goal.
- Build steps (e.g. `:TSUpdate`) need a `PackChanged` autocmd; a few lines.
- Plugins' own READMEs now list `vim.pack` install snippets (e.g. gruvbox.nvim does), so ecosystem support is real.
- Recommendation: **vim.pack**. Fall back to lazy.nvim if the experimental API breaks on us (it is the safe, mainstream option).

Sources: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/pack.txt , https://github.com/folke/lazy.nvim

## 2. Scoped picker

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| folke/snacks.nvim (picker) | 8.1k | 2026-05-25 | v2.31.0 (2026-03-20) | ~0.9+ (picker wants 0.10+; verify) | PASS | `Snacks.picker.pick{ items=..., finder=..., cwd=..., preview="diff"/"file", confirm=... }`: custom item list with `text/file/preview` fields is first-class. Also has explorer, colorschemes, git_diff/git_status, projects. Caveat: last push is ~4 months old, ahead-of-trend issue count 141. |
| ibhagwan/fzf-lua | 4.5k | 2026-09-30 | tags old (0.7, 2025-04) | 0.9 | PASS | Most actively committed (12 open issues). `fzf_exec` with arbitrary list plus builtin previewer; `cwd` on every picker; git_status/git_diff/colorschemes. Requires `fzf` binary (>0.36). |
| nvim-telescope/telescope.nvim | 19.8k | 2026-08-17 | v0.2.1 (2025-12-31) | 0.10 (verify) | CAUTION | Most popular and has the best custom-picker docs, but 465 open issues, heavier, slower on big repos; no advantage here. Needs plenary. |
| nvim-mini/mini.pick | mini.nvim 9.6k | 2026-09-07 (sub-repo mirror) | v0.18.0 (2026-06-21) | 0.9-0.10 (verify) | PASS (second choice) | Tiny, no binaries needed beyond rg/git; `MiniPick.start{ source={items=..., cwd=..., choose=...}}` is very easy. Previews are DIY, UI is plain. |

Required binaries: `rg` (grep, all), `fd` (snacks files/fzf-lua files; falls back to `find`/`rg --files`/`git ls-files`, but fd is faster and respects .gitignore), `fzf` (fzf-lua only; snacks/mini/telescope have a built-in Lua matcher). `bat`/`delta` optional for previews (fzf-lua).

Verdict for the worktree switcher: snacks.nvim is the best fit (one plugin covers picker + explorer + colorscheme picker + diff preview; items carry arbitrary metadata for formatting). fzf-lua is the strongest alternative if you want maximal speed and the freshest maintenance. Choose one, not both.

Sources: https://raw.githubusercontent.com/folke/snacks.nvim/main/docs/picker.md , https://raw.githubusercontent.com/ibhagwan/fzf-lua/main/README.md , https://github.com/nvim-mini/mini.pick

## 3. File explorer

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| snacks explorer | (snacks) 8.1k | 2026-05-25 | v2.31.0 | see snacks | PASS | "A picker in disguise": tree sidebar with git status indicators, replaces netrw, uses the picker's cwd. Zero extra dependency if snacks is adopted. |
| stevearc/oil.nvim | 6.9k | 2026-06-02 | v2.16.0 (2026-05-24) | 0.10 | PASS (complement) | Edit directory as a buffer. Not a tree. Great for small edits/moves, but review mostly needs reading, not file ops. |
| nvim-neo-tree/neo-tree.nvim | 5.6k | 2026-09-27 | 3.42.0 (2026-09-01) | 0.10+ | CAUTION | Active but needs plenary+nui+icons; heavy for a read-mostly use. |
| nvim-tree/nvim-tree.lua | 8.7k | 2026-10-01 | v1.18.0 (2026-07-01) | 0.10+ (verify) | PASS | Most actively committed lightweight tree; git decorations, own `:cd` handling. Good alternative if not using snacks. |
| nvim-mini/mini.files | mini.nvim 9.6k | 2026-09-13 | v0.18.0 | ~0.9 | PASS | Miller-columns browser, minimal; no tree sidebar. |

Verdict: snacks explorer (if snacks), else nvim-tree. Built-in netrw is the fallback.

Sources: https://raw.githubusercontent.com/folke/snacks.nvim/main/docs/explorer.md , https://raw.githubusercontent.com/stevearc/oil.nvim/master/README.md

## 4. Diff review UI

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| sindrets/diffview.nvim | 5.8k | **2024-06/08** (feeds disagree; either way ~2 years) | none | 0.7 | **FAIL** | Dormant for about two years, 131 open issues+PRs; users publicly migrating off it in 2026. No deprecation banner, but treat as unmaintained. |
| esmuellert/codediff.nvim | 1.6k | 2026-09-15 | v4.0.6 (2026-09-15) | 0.7 stated, 0.10+ recommended | PASS (CAUTION: young, 1.6k stars) | Explicitly built for "live review while background agents work": file watching, side-by-side and inline, VSCode diff algorithm (C library), explorer panel, merge-base comparisons documented, PR review without local branch. Downloads a prebuilt binary from GitHub releases on first use (needs curl/wget; no compiler). 73 open issues+PRs. Also offers stage/discard (we won't use them). |
| lewis6991/gitsigns.nvim | 7.1k | 2026-09-22 | v2.1.0 (2026-03-26) | 0.10 (verify) | PASS | Gutter signs, hunk nav (`]c`/`[c`), hunk preview, inline word diff, `change_base` to diff vs any ref (e.g. merge-base). 35 open items. |
| nvim-mini/mini.diff | mini.nvim 9.6k | 2026-07-30 | v0.18.0 | ~0.9 | PASS (alternative) | Lightweight signs/overlay; reference text can be set to any git ref. Redundant with gitsigns. |
| built-in `diffopt` + `:DiffTool` | n/a | n/a | Nvim 0.12 | 0.12 | PASS | 0.12 adds `inline:char` and `indent-heuristic` to default diffopt (character-level highlights inside changed lines), `linematch` and `algorithm:histogram`. 0.12 also adds `:DiffTool` (compare two dirs/files). No changed-file list for a git worktree, no merge-base logic: that part we would script ourselves (`git diff --name-only <base>...HEAD`). |
| s1n7ax/nvim-diff | small | ? | ? | ? | FAIL | Self-described vibe-coded diffview replacement; too small to meet the popularity bar. |

Verdict: **codediff.nvim** is the only maintained full diffview replacement; confirm in a spike that it handles (a) whole-worktree changed-file list, (b) vs HEAD and vs merge-base, (c) editing the right-hand buffer in place, (d) file watching with agents writing. Fallback plan: our own thin module (snacks `git_diff`/changed-file picker + native `:diffthis` with `inline:char`) plus gitsigns. Uncertainty: I did not run codediff; its README claim of "edit in place" for working-tree side should be verified.

Sources: https://github.com/sindrets/diffview.nvim , https://github.com/esmuellert/codediff.nvim , https://raw.githubusercontent.com/neovim/neovim/v0.12.5/runtime/doc/news.txt , web search "diffview.nvim unmaintained alternative codediff.nvim 2026"

## 5. Markdown rendering

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| MeanderingProgrammer/render-markdown.nvim | 5.1k | 2026-09-15 | v8.14.0 (2026-09-15) | 0.9 (0.10 recommended) | PASS | Active, 21 open issues, thorough docs. Headings, tables, checkboxes, callouts, code blocks; renders only the visible range; anti-conceal on cursor line. Needs `markdown`+`markdown_inline` parsers; LaTeX needs external converter. |
| OXY2DEV/markview.nvim | 3.7k | 2026-09-17 | v28.3.0 (2026-05-16) | 0.10+ (verify) | PASS (CAUTION) | Very feature-rich (also HTML, LaTeX, Typst); 5 open issues. Heavier, more config, many majors. Second choice. |

Images/mermaid: neither renders images or mermaid natively. `folke/snacks.nvim` has an `image` module (kitty graphics protocol; also renders LaTeX/mermaid through `mmdc`/ImageMagick/ghostscript) which fits kitty, but under WSL2 + kitty this is untested and adds binaries. Recommendation: skip for now, evaluate later. I did not verify snacks image requirements in detail.

Source: https://raw.githubusercontent.com/MeanderingProgrammer/render-markdown.nvim/main/README.md

## 6. nvim-treesitter

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| nvim-treesitter/nvim-treesitter (`main`) | 14.4k | 2026-09-30 | latest tag v0.10.0 (2025-05) is the OLD master era | **0.12.0** (latest stable or nightly only) | PASS (CAUTION: needs toolchain) | `main` is a full incompatible rewrite; `master` is locked, kept for 0.11 compat. Needs `tree-sitter-cli` >= 0.26.1, a C compiler, `tar`, `curl`. Does not support lazy-loading. |

Highlight-only usage: install parsers with `require('nvim-treesitter').install{...}` then enable per filetype via `vim.treesitter.start()` in a `FileType` autocmd. Highlighting itself is in Neovim core; the plugin is only a parser installer plus queries. 269 open items. Parsers need the CLI to compile grammars: that is the main cost for a "small distro". Neovim bundles only c, lua, vim, vimdoc, query, markdown, markdown_inline parsers (and a `diff` parser in recent versions).
Alternative if you want to avoid the CLI/compiler: bundled parsers only plus a short list manually (not recommended; markdown/json/yaml/toml/bash/python/ts parsers are needed).

Source: https://raw.githubusercontent.com/nvim-treesitter/nvim-treesitter/main/README.md

## 7. Claude Code and other harness integration

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| coder/claudecode.nvim | 3.1k | 2026-09-13 | v0.3.0 (2026-04-28) | 0.8 | CAUTION | Real protocol implementation (same WebSocket MCP as VS Code), pure Lua, no deps, actively maintained by Coder. Works headless/external, but see workspace-matching risk below. 95 open items. |
| nickjvandyke/opencode.nvim (moved from NickvanDyke) | 3.9k | 2026-09-24 | v1.0.2 (2026-09-14) | ? | PASS (only if opencode is used) | Connects to opencode's local server; not relevant for Claude Code. |
| sudo-tee/opencode.nvim | 957 | 2026-10-01 | ? | ? | CAUTION | Separate opencode UI; small. |

How claudecode.nvim works (from README and `lockfile.lua`):
- On start (`auto_start`), it opens a WebSocket server on a random port in `port_range` (10000-65535) and writes `~/.claude/ide/<port>.lock` (or `$CLAUDE_CONFIG_DIR/ide/`) containing `pid`, `workspaceFolders`, `ideName="Neovim"`, `transport="ws"`, `authToken`. It also sets `CLAUDE_CODE_SSE_PORT` / `ENABLE_IDE_INTEGRATION` in nvim's own env (only helps terminals started from nvim).
- **Separate terminal**: supported by design. `terminal.provider = "none"` means "Claude runs completely outside Neovim"; you attach with `claude --ide` or `/ide` inside Claude. `"external"` launches Claude in another terminal app via a template such as `"kitty -e %s"`.
- Selection/context: `track_selection = true` pushes current buffer/selection live; `:ClaudeCodeSend` (visual), `:ClaudeCodeAdd <path> [lines]`, `:ClaudeCodeTreeAdd`.
- Diffs: Claude's proposed edits open as native Neovim diff (vertical default, horizontal, or unified); accept with `:w` / `<leader>aa`, reject with `:q` / `<leader>ad`; auto-closes if resolved on the Claude side. Autosave plugins can auto-accept (we won't have any).
- Multiple nvim instances: each gets its own port and lock file, so several can coexist.

**Risks for our use case (not tested, inferred from source):**
1. `workspaceFolders` is built from `vim.fn.getcwd()` at lock-file creation (plus LSP workspace folders, which we won't have). There is no automatic update on `:cd`/`:tcd`; `M.update(port)` must be called manually. The Claude CLI picks IDEs by matching its cwd against those folders (my understanding of the client behaviour, not verified here). Our design: Claude runs at `marcus/` root, nvim `:tcd`s into worktrees. Fix: start nvim with cwd = root (matches), do not rely on global `:cd`, or call the lockfile update after context switches.
2. Several nvim instances for different roots, plus several Claude sessions in separate terminals in different worktrees: only those whose cwd is inside an nvim's `workspaceFolders` will see it; `/ide` lists the candidates. Agents running in worktrees that live outside root will not match.
3. Diff handling assumes Claude waits for the user to accept in nvim. For autonomous agents (acceptEdits mode) this never fires, so the diff feature mainly matters for interactive sessions. Selection sharing (`@file#L1-5` mentions) is the high-value part for review.
4. v0.3.0 is 5 months old although main is current; "Native Binary" Claude installs are flagged alpha in the README (set `terminal_cmd` explicitly).

Alternative that we already planned: a custom `mnvim` CLI over `nvim --listen` RPC (no plugin). It is complementary: claudecode.nvim for selection to Claude, `mnvim` for agent-to-nvim control.

Sources: https://raw.githubusercontent.com/coder/claudecode.nvim/main/README.md , https://raw.githubusercontent.com/coder/claudecode.nvim/main/lua/claudecode/lockfile.lua , https://github.com/nickjvandyke/opencode.nvim

## 8. Keybind help, statusline, mini.nvim modules, icons

| Plugin | Stars | Last commit | Last release | Min nvim | Verdict | Reason |
|---|---|---|---|---|---|---|
| folke/which-key.nvim | 7.3k | 2025-10-28 | v3.17.0 (2025-02-22) | 0.9+ | CAUTION | Standard, great docs, but quiet for 11 months (stable and feature complete; few issues: 40). Acceptable. Alternative: mini.clue (part of mini.nvim, maintained). |
| nvim-mini/mini.nvim (statusline, surround, pairs, icons, clue, ...) | 9.6k | 2026-09-26 | v0.18.0 (2026-06-21) | 0.9-0.10 | PASS | One actively maintained author, excellent help docs, modules are independent. mini.statusline is small and easy to extend with a custom `repo | worktree | branch` section. |
| nvim-lualine/lualine.nvim | 8.1k | 2026-05-31 | none since 2023 tag | 0.7 | CAUTION | Popular and capable, but heavier; no real releases; 272 open items. Not needed. |
| nvim-mini/mini.icons | in mini.nvim | 2026-09-22 | v0.18.0 | 0.9 | PASS | Nerd-font icons with no extra repo; can mock nvim-web-devicons for plugins that require it. |
| nvim-tree/nvim-web-devicons | 2.7k | 2026-09-21 | tags 2024 | 0.8 | PASS (fallback) | Only if a chosen plugin hard-requires it. |

Verdict: mini.nvim (use `mini.statusline`, `mini.icons`, `mini.surround`, `mini.pairs` only if wanted; built-in `gc` handles comments) plus which-key (or `mini.clue` to stay in one dependency). Note: for a reviewing distro, surround and pairs are optional.

Sources: https://github.com/nvim-mini/mini.nvim , https://github.com/folke/which-key.nvim

## 9. Colorschemes and switching

| Plugin | Stars | Last commit | Last release | Verdict | Reason |
|---|---|---|---|---|---|
| ellisonleao/gruvbox.nvim | 2.6k | 2026-04-15 | 2.0.0 (2023-10) | PASS (CAUTION: slower cadence) | Still the maintained Lua gruvbox with treesitter+semantic groups, no known successor/fork superseding it; min 0.8; README shows vim.pack install. 25-30 open issues. |
| sainnhe/gruvbox-material | 2.7k | 2026-04-15 | v1.2.5 (2022) | PASS | Softer gruvbox variant (vimscript) with wide plugin coverage; tags old but active. |
| morhetz/gruvbox | 15.8k | 2026-09-18 | n/a | CAUTION | Original vimscript; no real treesitter groups. Pick gruvbox.nvim instead. |
| catppuccin/nvim | 7.6k | 2026-08-09 | v2.0.0 (2026-04-02) | PASS | Very actively maintained, 10 open issues, broad integration list. |
| folke/tokyonight.nvim | 8.2k | 2026-03-24 | v4.14.1 (2025-10-23) | PASS | Popular, well documented; cadence slowed (6 months). |
| rebelot/kanagawa.nvim | 6.4k | 2026-05-10 | tags only | PASS | Popular; 91 open issues. |
| EdenEast/nightfox.nvim | 4.1k | 2026-07-04 | v3.10.0 (2024-07) | PASS | Many variants; maintained at low cadence. |
| rose-pine/neovim | 3.1k | 2026-05-15 | v3.0.2 (2025-02) | PASS | Active, 5 open issues. |
| navarasu/onedark.nvim | 2.0k | 2026-04-13 | v1.0.3 (2025-11) | PASS | Classic Atom One; ok. |
| Mofiqul/vscode.nvim | 1.0k | 2026-09-03 | tags | CAUTION | Under the stars bar; ok if you want VS Code look. |
| sainnhe/everforest | 4.2k | 2026-06-08 | ? | PASS | Green/low-contrast, viml. |
| projekt0n/github-nvim-theme | 2.5k | **2024-12-31** | v1.1.2 (2024-08) | FAIL | ~9 months idle. |
| dgox16/oldworld.nvim | 474 | 2025-12-30 | ? | FAIL | Below popularity bar. |

Suggested set (8): gruvbox.nvim, catppuccin, tokyonight, kanagawa, rose-pine, nightfox, everforest, onedark. Ship them as extra plugins only if Dawid really wants variety; each is another dependency. Alternatively ship two (gruvbox + one dark/one light) and add more later.

Note: Neovim 0.10+ ships `default` (new dark/light), 0.11 includes more built-in colorschemes? Not verified; do not rely.

### Dynamic theme switching with persistence

Options researched:
- **snacks.nvim `Snacks.picker.colorschemes()`**: picker with live preview over installed schemes, no persistence in docs (snacks docs do not mention it). Persistence is easy to add ourselves: a `ColorScheme` autocmd writing the name to `stdpath("state").."/colorscheme"` and reading it at startup (about 10 lines). **Recommended.**
- fzf-lua `colorschemes`: also live preview; same DIY persistence.
- telescope `:Telescope colorscheme enable_preview=true`: works, but needs telescope.
- Small plugins: `zaldih/themery.nvim` (live preview + persistence, no deps), `propet/colorscheme-persist.nvim`, `raddari/last-color.nvim`, `danhat1020/colorscheme-picker.nvim`. I did not collect stars/commit data (API rate-limited), but they are niche; per Dawid's popularity rule they are likely FAIL/unverified. Prefer DIY.

Sources: https://github.com/ellisonleao/gruvbox.nvim , https://github.com/zaldih/themery.nvim , https://github.com/raddari/last-color.nvim

---

## Recommended shortlist

| Role | Pick | Why |
|---|---|---|
| Neovim | 0.12.5 stable | vim.pack, `diffopt inline:char`, `:DiffTool`, OSC52, nvim-treesitter main needs 0.12 |
| Plugin manager | `vim.pack` (fallback lazy.nvim) | no extra code, lockfile, enough for ~8 plugins |
| Picker + explorer + colorscheme preview | snacks.nvim (alt: fzf-lua) | custom item lists with preview/metadata, cwd option, explorer and colorschemes in one |
| Diff review | codediff.nvim + gitsigns.nvim (+ native diffopt) | only maintained diffview replacement; spike required; own thin fallback |
| Markdown | render-markdown.nvim | active, documented, light |
| Syntax | nvim-treesitter `main`, highlight only | needs tree-sitter CLI + C compiler |
| Claude link | claudecode.nvim with `terminal.provider="none"` | verify workspaceFolders matching in a spike; pair with own `mnvim` RPC CLI |
| Keys/statusline/icons | which-key (or mini.clue), mini.statusline, mini.icons | minimal |
| Colors | gruvbox.nvim default plus catppuccin, tokyonight, kanagawa, rose-pine; snacks colorscheme picker + DIY persistence | all treesitter-aware, maintained |

Rejected: diffview.nvim (dormant ~2 yrs), github-nvim-theme (idle), telescope (heavy, 465 issues), neo-tree (heavy deps), lualine (unneeded), small theme-switcher plugins (not popular enough), nvim-diff (AI-written, tiny).

## External binaries

| Binary | Needed by | Why |
|---|---|---|
| `git` (2.30+; present) | everything, vim.pack, worktree list | `git worktree list --porcelain`, diffs, merge-base |
| `rg` (present) | snacks/fzf-lua grep | live grep |
| `fd` (missing) | snacks/fzf-lua files | fast file listing respecting .gitignore (fallbacks exist) |
| `fzf` (missing) | fzf-lua only | not needed with snacks |
| `tree-sitter` CLI >= 0.26.1 (missing) | nvim-treesitter main | compile parsers |
| C compiler (gcc/cc), `tar`, `curl` | nvim-treesitter main, codediff (curl/wget downloads binary) | build parsers; fetch binary |
| `delta` (missing) | optional | fzf-lua/snacks diff preview; not required by codediff |
| Nerd Font in kitty | render-markdown, icons, explorer | glyphs |
| `claude` CLI | claudecode.nvim | the harness |
| ImageMagick, `mmdc`, ghostscript | only if snacks image / mermaid is adopted later | optional, deferred |
| `xclip`/`wl-copy` | none required | OSC52 provider built into 0.12 |

## Open items to verify before committing
1. codediff.nvim: whole-worktree list, merge-base compare, in-place editing, behaviour with files changed by agents.
2. claudecode.nvim: Claude CLI auto-connect/`/ide` listing when nvim cwd is root but worktree is elsewhere; whether the lock file needs a manual update after `:tcd`.
3. snacks.nvim minimum Neovim version and the freshness of the 4-month-old last push versus issue backlog.
4. Whether `vim.pack` handles plugin-manifest `build` hooks adequately for nvim-treesitter's `:TSUpdate`.


## Addendum 2026-10-01: extra colorschemes

Checked via the GitHub API (stars, last push). All load lazily (`packadd` on selection).

| Plugin | Stars | Last push | Variants offered | Verdict |
|--------|-------|-----------|------------------|---------|
| EdenEast/nightfox.nvim | 4.1k | 2026-07 | nightfox, carbonfox, dayfox | PASS |
| sainnhe/everforest | 4.2k | 2026-06 | dark, light | PASS |
| navarasu/onedark.nvim | 2.0k | 2026-04 | onedark | PASS |
| sainnhe/sonokai | 2.0k | 2026-01 | sonokai | PASS |
| nyoom-engineering/oxocarbon.nvim | 1.6k | 2026-09 | dark, light | PASS |
| bluz71/vim-moonfly-colors | 1.3k | 2026-09 | moonfly | PASS |
| marko-cerovac/material.nvim | 1.1k | 2026-02 | material | PASS |
| AlexvZyl/nordic.nvim | 1.1k | 2026-05 | nordic (nord-style) | PASS |
| Mofiqul/vscode.nvim | 1.0k | 2026-09 | dark, light | PASS |
| loctvl842/monokai-pro.nvim | 720 | 2026-05 | monokai-pro | PASS |
| projekt0n/github-nvim-theme | 2.5k | 2024-12 | - | FAIL (idle) |
| shaunsingh/nord.nvim | 1.0k | 2024-06 | - | FAIL (idle; nordic used instead) |
| Mofiqul/dracula.nvim | 784 | 2025-11 | - | skipped (~11 months idle) |
