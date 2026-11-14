---
name: run-experiment
description: Use when planning, configuring, launching, resuming or summarizing a research experiment, reproducing published work, or writing an experiment's README, TOML config, launcher, figures or tables.
---

# Running experiments

**I must be able to run, debug and interpret any experiment without the agent.** If this repository
already has an experiment runner, use it and apply these rules through it rather than writing a
second launcher.

Use this only when the result will be evidence for a claim. A quick check is a probe (`probe` skill).

## Question gate

Before any code, the README opens with this block. I write the prediction; never fill it in for me.
If I haven't written it, ask. If both outcomes lead to the same next step, say so and stop.

```
Serves: <open question or claim in RESEARCH.md>
I predict: <one line, rough confidence>
If yes → <next step>. If no → <next step>.
```

## Before the run

- Write the plan and README first: the question, what is fixed and what is varied, the commands,
  the expected runtime and the success criteria.
- List the planned figures and tables: what each shows, its axes or rows and columns, and the
  question it answers. This is the minimum; more can be added after the run.
- When reproducing published work, compare against both the paper and the authors' code, and list
  every difference in the README. Don't add choices neither makes without a stated reason.
- When methods are compared, ask me how to tune them fairly.
- Confirm the exact launch command with me before starting a long run.

## The config file

- One TOML file per experiment, next to its launcher, holds every setting. Change settings there,
  not in code. Group it into tables by purpose, e.g. `[inputs]`, `[data]`, `[run]`, `[criteria]`,
  and the published values being compared against.
- If the repository's runner fixes the config format, keep its format and put the remaining settings
  and success criteria at the top of the script instead.
- A short comment on each value says where it comes from: the paper (page or figure), the authors'
  code, or our own choice with the reason.
- Pin every input file by path and sha256; a `check` stage verifies them before anything runs.
- Success criteria live in the file as numbers, written before any run.
- Code reads only the keys the file defines and fails on missing or unknown keys. No defaults
  hidden in code.
- The launcher expands the file into a `plan.csv` with one row per run and its exact command. A
  restart whose plan or code version differs from the existing `plan.csv` stops and says to move
  the old results aside.

## The launcher

- One readable launcher per experiment, with named stages. Finished runs are skipped, so a rerun
  resumes. Devices can be added or removed while a stage runs.
- Each run directory records its settings, code version, input hashes and hardware.
- Error messages say what went wrong and what to do next.
- The launcher builds the planned figures and tables from the run directories; rerunning the
  summarize stage rebuilds them.
- If the project uses an experiment tracker, the launcher syncs results to it without being asked:
  in the background as runs finish and once more when a stage ends; one tracker run per run
  directory plus a summary run per stage with the figures and tables. A failed sync keeps results
  on disk, prints the command that redoes it, and makes the stage exit non-zero.

## Results

- The results directory on disk is the only source of truth. The tracker mirrors it; nothing reads
  results back from the tracker.
- The README explains every output column and how to view the results.
- `RESULTS.md` next to the README is where I look at results; I should never need to open the
  output files. One section per question. Embed each current figure (`![](<outputs>/...)`) with
  two lines: `Read:` the axes and encodings, `Shows:` the takeaway.
- Link only the current output version. Older `_vN` folders stay on disk, unmentioned.
- Keep final model weights, if any. Resume state from finished runs can be deleted.

## Verdict

When results are in, put this at the top of `RESULTS.md`:

```
Answer: <one line>
Prediction: held / failed / surprise
Changes RESEARCH.md: <belief and new confidence, or new open question>
```

Draft it from the results and propose the RESEARCH.md edit; I confirm both. If the result fills
an evidence slot in the outline, link it there.

## Writing

Keep READMEs and summaries short: the answer first, then only what I need to check it.
