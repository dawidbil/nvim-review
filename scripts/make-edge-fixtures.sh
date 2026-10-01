#!/usr/bin/env bash
set -e
E=/home/toothless/marcus/scratch/edge-root
rm -rf $E; mkdir -p $E; cd $E; git init -q -b main .; git config user.email t@t; git config user.name t
echo root > README.md; git add -A; git commit -qm init
# repo with awkward names
mkdir edge && cd edge && git init -q -b main . && git config user.email t@t && git config user.name t
mkdir -p "x b"; echo a > HEAD; echo a > "café.txt"; echo a > "x b/y.txt"; echo a > staged.txt; echo a > old.txt; printf 'a\nb\nc\nd\n' > big.txt
git add -A && git commit -qm base
echo changed >> HEAD; echo changed >> "café.txt"; echo changed >> "x b/y.txt"
echo staged >> staged.txt; git add staged.txt        # staged-only change
git mv old.txt renamed.txt; printf '\x00\x01bin' > blob.bin; git add blob.bin
cd ..
# fsmonitor trap
mkdir trap && cd trap && git init -q -b main . && git config user.email t@t && git config user.name t
echo a > f.txt && git add -A && git commit -qm i && echo b >> f.txt
git config core.fsmonitor "touch $E/FSMON_RAN"
cd ..
# bare repo + worktree
git init -q --bare -b main nvr.git
git clone -q nvr.git seed 2>/dev/null; cd seed; git config user.email t@t; git config user.name t; echo a > a.txt; git add -A; git commit -qm i; git push -q origin main; cd ..; rm -rf seed
git -C nvr.git worktree add -q ../nvr-wt -b feat 2>&1 | tail -1
echo changed >> nvr-wt/a.txt
echo built
