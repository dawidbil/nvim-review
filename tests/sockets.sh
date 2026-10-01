#!/usr/bin/env bash
export MARCUS_ROOT=/home/toothless/marcus/scratch/edge-root
cd $MARCUS_ROOT
U=$(id -u); D=/tmp/nvim-review-$U
rm -rf $D
echo "== S1: XDG unset -> private /tmp dir"
env -u XDG_RUNTIME_DIR nvim-review --headless +"lua vim.defer_fn(function() vim.cmd('qa!') end, 6000)" >/tmp/s1.out 2>&1 &
sleep 2.5
stat -c '%a %U %n' $D; ls $D
env -u XDG_RUNTIME_DIR nvim-review status >/dev/null; echo "ctl status rc=$? (0 expected)"
wait
echo "== S1: fake server planted in world-writable /tmp must be ignored"
python3 - <<'PY' &
import socket,os,time
h=__import__('hashlib').sha256(b'/home/toothless/marcus/scratch/edge-root').hexdigest()[:10]
p=f'/tmp/nvim-review-{h}.sock'
try: os.remove(p)
except: pass
s=socket.socket(socket.AF_UNIX); s.bind(p); s.listen(1); s.settimeout(5)
try:
    c,_=s.accept(); print("FAKE SERVER GOT A CONNECTION (BAD)")
except Exception: print("fake server: no connection (good)")
os.remove(p)
PY
sleep 0.5
env -u XDG_RUNTIME_DIR nvim-review status >/dev/null 2>&1; echo "ctl rc=$? (3 = no instance, did not touch fake)"
wait
echo "== S1: unsafe dir (mode 755) refused"
chmod 755 $D
env -u XDG_RUNTIME_DIR nvim-review status 2>&1 | head -2; echo "rc=${PIPESTATUS[0]}"
env -u XDG_RUNTIME_DIR nvim-review --headless +"lua print(require('review.harness').socket); vim.cmd('qa!')" 2>&1 | grep -i "refusing\|nil" | head -2
chmod 700 $D
echo "== S3: two simultaneous starts, same root"
X=/tmp/rvx; mkdir -p $X; chmod 700 $X; rm -f $X/*
for i in 1 2; do XDG_RUNTIME_DIR=$X nvim-review --headless +"lua vim.defer_fn(function() vim.cmd('qa!') end, 8000)" >/tmp/s3_$i.out 2>&1 & done
sleep 3
ls $X | grep sock
XDG_RUNTIME_DIR=$X nvim-review status >/dev/null; echo "ctl rc=$? (0 = socket alive)"
wait
cat /tmp/s3_1.out /tmp/s3_2.out | grep -i "could not\|refus" || echo "no startup warnings"
rm -rf $X /tmp/s1.out /tmp/s3_*.out
