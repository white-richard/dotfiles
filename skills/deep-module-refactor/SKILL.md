---
name: deep-module-refactor
description: Use when refactoring a research repository into deep modules with typed interfaces: audit the repo, write a staged refactor plan for approval, then execute it stage by stage.
---

# Deep-module refactor of a research repository

Goal: every part of the system sits behind a small typed interface the person reviews, so code
behind it can be rewritten freely. The person reviews interfaces and tests, not every line.

Plan first. Change no code until the person approves `docs/refactor-plan.md`.

## 1. Baseline

- Run the test suite, the type checker and the linter. Record exactly which tests fail and why
  (missing data, sandbox, GPU, network vs real bugs). This failing set must never grow.
- Commit or note the starting revision so every later stage can be diffed against it.

## 2. Audit (read, don't edit)

Report findings in these terms:
- **Two kinds of code.** Experiment code (one question, one script, read top to bottom) vs
  maintained code (shared or adopted, used by more than one experiment). Only maintained code gets
  interfaces; experiment folders stay flat scripts.
- **Records vs code.** Records are frozen: built products, outputs cited by reports, review
  records, preregistrations and dated decisions. Code is never frozen just because a record was made
  with it; git keeps the old revision. Flag any hash pin or 'do not edit' rule on code and ask
  whether it protects a record or just blocks fixes.
- **Untyped boundaries.** Count `dict[str, Any]` / untyped rows passed between modules. Name the
  central record types that have no type (a source, a row, a passage, a run record).
- **Validate-then-dict.** Places that check data carefully and then return a dict, so downstream
  code re-checks it.
- **Duplicates.** The same concept implemented twice (CSV readers, hash helpers, access or leakage
  rules, ID patterns). Rules that protect scientific validity count double: two copies can drift.
- **Shallow or god functions.** Functions over ~100 lines doing several jobs; wrappers that only
  rename.
- **Untestable seams.** Code that needs a GPU, network, sandbox or data bundle with no Protocol in
  front of it, so its logic can't be tested.
- **Stale docs** that point at files or behaviour that no longer exist (agents read these).

## 3. Write docs/refactor-plan.md

Sections: Goal; Constraints (isolated modules, records that are frozen, the scientific safeguard);
Verify command for every stage; Target layout; one section per stage.

Each stage: the problem, the interface (signatures and frozen dataclasses in a code block), numbered
steps, and how to verify. Typical order:
1. Shared vocabulary (enums for labels, hash/ID types, one strict CSV reader) plus the single
   implementation of the repository's key scientific rule (e.g. leakage or access).
2+. One stage per area of maintained code: parse its records at the boundary into frozen
   dataclasses; split god functions into named steps; put GPU/network/sandbox behind a Protocol with
   a fake for tests.
Last-but-one: tooling (strict type checking on maintained code, pytest markers that skip with a
reason when data/GPU/sandbox are missing, import rules so modules depend only downward, hooks that
block edits to frozen record folders).

Leave scientific redesign (what an evaluation measures, how a pipeline should work) as open
questions for the person. Refactoring makes it easier; it does not decide it.

Ask the person only about decisions that change the plan (e.g. how to treat a pinned or frozen
folder, whether to archive unused code, scope). Then stop for approval.

## 4. Execute, one stage at a time

- Each commit is either a **refactor** or a **fix**, never both.
  - Refactor: outputs are unchanged. Prove it with snapshot outputs saved before the change (scores,
    passages, CSVs) reproduced exactly, on real data where available and a small synthetic case
    that runs anywhere.
  - Fix: outputs change on purpose. A test reproduces the error first; the commit updates the snapshot
    and says what moved and why.
- Snapshots are not gold. A snapshot holds whatever the code produced, errors included; it
  detects change. Correctness comes from a fix's test, with the expected value checked by the
  person against the source (e.g. the rendered page), and from human-checked reference data.
- Parse, don't validate: once a value is parsed into a type, downstream code trusts it; delete the
  re-checks.
- On-disk formats stay compatible unless the person approves a change.
- After each stage: the verify command, the failing set compared to baseline, the diffstat, and the
  plan's status line updated with any recorded differences from the plan.
- Never edit frozen records. New builds and new scores go to new folders; re-running an old
  evaluation with fixed code is a new result, not a correction of the old one.

## 5. Hand-off notes

Keep `docs/refactor-plan.md` current so any session can continue with "Continue the refactor in
docs/refactor-plan.md from Stage N". Keep AGENTS.md's "This project" section in sync: maintained
vs experiment folders, frozen records, the key scientific rule, the verify command.
