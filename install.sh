#!/usr/bin/env bash
# Link this repo as the nvim-review config and put the launcher on PATH.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.config ~/.local/bin
ln -sfn "$here" ~/.config/nvim-review
ln -sfn "$here/bin/nvim-review" ~/.local/bin/nvim-review
echo "linked ~/.config/nvim-review -> $here ; launcher: ~/.local/bin/nvim-review"
