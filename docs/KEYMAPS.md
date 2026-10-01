# Keymaps

Leader = `Space`. Press it and wait: which-key shows every group. `<leader>?` lists buffer keymaps,
`<leader>fk` searches all keymaps.

| Group | Key | Action |
|-------|-----|--------|
| **worktree** | `<leader>ww` | Switch worktree (all repos; shows branch + dirty count, preview of status/log) |
| | `<leader>wr` | Switch repo (returns to its last-used worktree) |
| | `<leader>ws` | Switch worktree within the current repo |
| | `<leader>wn` / `wp` | Next / previous worktree of the current repo |
| | `<leader>wi` / `wR` | Context info / rescan repos+worktrees |
| **find** (scoped to active worktree) | `<leader><space>`, `ff` | Files |
| | `<leader>/`, `fg` | Grep |
| | `fw` | Grep word under cursor / selection |
| | `fb` `,` / `fr` / `fl` / `fj` / `fm` | Buffers / recent / buffer lines / jumps / marks |
| | `fh` `fk` `fR` | Help / keymaps / resume last picker |
| | `<leader>e` | File explorer at the worktree |
| **diff / review** | `<leader>dd` | Changed files vs base (preview + open side-by-side) |
| | `<leader>dc` | Diff the current file |
| | `]f` / `[f` | Next / previous changed file |
| | `]c` / `[c` | Next / previous hunk (native in diff view, gitsigns otherwise) |
| | `<leader>dB` | Toggle base: HEAD (default) ↔ merge-base with the default branch |
| | `<leader>dq` | Close the diff view |
| | `<leader>dh` `di` `dw` | Preview hunk / inline hunk / word diff |
| | `<leader>dr` | Revert hunk (normal) or selected lines (visual) |
| | `<leader>dl` `dL` | Blame line / git log |
| **claude** | `<leader>cs` (visual) | Send selection to the connected Claude Code |
| | `<leader>ca` | Add current file to Claude's context |
| | `<leader>cc` | Connection status |
| **yank path** | `<leader>yp` `yP` | Relative / absolute path |
| | `<leader>yl` | `path:line` (visual: `path:from-to`) |
| **buffers/windows** | `Shift-h` / `Shift-l` | Previous / next buffer |
| | `<leader>bd` `bo` | Delete buffer / others |
| | `Ctrl-h/j/k/l` | Move between windows |
| | `<leader>\|` `-` | Split vertical / horizontal |
| **markdown** | `<leader>mm` | Toggle rendering |
| **ui** | `<leader>ut` | Theme picker (live preview, remembered) |
| | `<leader>uw` `un` `ur` | Toggle wrap / numbers / relative numbers |
| **general** | `jk` | Escape (insert mode) |
| | `Ctrl-s`, `<leader>s` `S` | Save / save all |
| | `<leader>q` `Q` | Quit window / quit all |
| | `Alt-j` / `Alt-k` | Move line or selection |
| | `gc` / `gcc` | Comment (built-in) |

Mouse: drag-select copies to the system clipboard automatically (OSC52, works in kitty/SSH).
Right-click extends the selection.
