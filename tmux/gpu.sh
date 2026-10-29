#!/usr/bin/env bash
# Per-GPU utilization and VRAM as one bar each for the tmux status bar, e.g. "gpu ▃▁▁█ vram ▅▁▁▇"
# Prints nothing on machines without nvidia-smi.
command -v nvidia-smi >/dev/null || exit 0
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null |
  awk -F', ' '
    BEGIN { split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", bar, " ") }
    function b(p) { return bar[int(p / 100 * 7.99) + 1] }
    { util = util b($1); vram = vram b($2 / $3 * 100) }
    END { if (NR) printf "gpu %s vram %s  ", util, vram }'
