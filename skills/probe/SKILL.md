---
name: probe
description: Use for a quick exploratory check (a diagnostic, a plot, "what does X look like?") that isn't yet evidence for a claim. Lighter than run-experiment.
---

# Probes

A probe gains information fast. Skip the experiment machinery.

- Ask me for one line first: what I expect to see. Never write it for me.
- One script in `experiments/<study>/probes/<name>.py`. Settings at the top of the script; no TOML,
  launcher, pinned hashes or tracker sync.
- Aim for under half a day. If it grows past that, stop and ask whether it should be an experiment.
- Small runs only. Don't use the test set.
- Output: the figure or table, plus three lines for my daily log:
  what was run, what it showed, whether it matched my expectation.
- Promote to `run-experiment` only when the result will back a claim in RESEARCH.md.
