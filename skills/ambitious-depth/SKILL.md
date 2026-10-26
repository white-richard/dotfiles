---
name: ambitious-depth
description: >-
  Deepen a task with primary evidence, expert methods, adversarial tests, stretch targets, and independent validation. Use for 'go deeper', 'expert-level', 'test this assumption', or /ambitious-depth.
---

# Ambitious Depth

Raise the **standard of the work**, not its size. The goal is to perform the task as a strong specialist would: with primary evidence, real methods, ambitious standards, and independent tests.

This skill covers *Depth* only. Do not broaden the business objective or assemble unrelated disciplines unless independently requested.

## Decide what you were given

- **A task to complete:** Make a concise deep-work plan, then execute what is feasible using actual tools and data.
- **A prompt to improve:** Return the stronger prompt; do not perform the underlying task.
- **No identifiable task:** Use the most recent substantive user request, or ask for one sentence of context if none exists.
- **Ambiguous task versus prompt:** Return the rewritten prompt and stop.

Honor the user's original scope and constraints. Depth is not permission to add deliverables, spend money, access private data, or expand the project indefinitely.

## The deep-work diagnostic

Before rewriting or acting, answer these four questions concretely:

1. **What would an excellent practitioner do that isn't currently being requested?** Name specific practices, not status words such as “world-class” or “rigorous.”
2. **What is the rawest useful material?** Prefer logs, source records, primary documents, actual observations, experiments, source code, or first-hand measurements over digests and unsupported summaries. Use only data that is relevant and accessible with permission.
3. **What methods and instruments would they use?** Name the statistical methods, tests, profilers, simulators, research methods, analytical tools, or field-specific workflows and why they fit. Do not pretend to have used tools you did not run.
4. **What independent evidence would show the result is right?** Prefer executable tests, held-out data, out-of-sample predictions, reproductions, benchmarks, audits, instrument readings, or real-world feedback. Self-critique is useful but is **not** an outside judge.

## Workflow

1. **Establish the present claim or baseline.** Record what is known, assumed, and missing; separate observations from hypotheses.
2. **Go one layer down.** Obtain or specify the raw material and recreate the current result before attempting a better one. If access is unavailable, state the limitation and the exact input needed; do not fabricate analysis.
3. **Apply the field's real techniques.** Choose methods appropriate to the evidence and stakes. Use tools when available; don't substitute polished prose for actual measurement or analysis.
4. **Challenge the premise.** Test competing explanations, counterexamples, confounders, bias, data leakage, edge cases, or failure modes. Try to falsify the favored story.
5. **Set a stretch target.** State a specific, demanding improvement target and how it will be measured. Treat ambitious goals as worth investigating, **not** as guaranteed achievable; never conceal costs, physical limits, or failed experiments.
6. **Look for genuinely new insight when supported.** Once the baseline is reproduced, inspect residuals and blind spots. Treat any novel discovery as a candidate until it passes an independent check.
7. **Use an outside judge and iterate.** Run available tests or measurements, report their actual results and limitations, and revise the work. If no suitable judge exists, propose one and mark conclusions provisional.

## Response shape

For prompts or scoped task plans, include:

1. **What deeper means here:** one sentence, explicitly without expanding scope.
2. **Expert gap:** techniques a strong practitioner would add.
3. **Raw inputs and methods:** exact evidence, tools, and access status.
4. **Stretch target and outside judge:** testable criteria, not a self-awarded grade.
5. **Rewritten prompt** in one copyable fenced block.
6. **Work performed and results** if execution was requested and possible; distinguish observations from hypotheses, and list blockers precisely.

Be concise for small tasks. If the task is creative or subjective, use appropriate external critique or audience tests rather than inventing quantitative certainty.

## Example

**Input:** `/ambitious-depth determine whether onboarding causes customer churn`

- **Expert gap:** A top analyst would not accept a slide claiming that poor onboarding causes churn; they would define churn precisely, inspect competing explanations, and test causality where feasible.
- **Raw materials:** Event-level usage, acquisition source, onboarding exposure, customer cohorts, support activity, and cancellation timestamps, subject to legitimate access and privacy constraints.
- **Instruments:** Reproducible data queries, cohort and survival analyses, sensitivity checks, and, if practical, a controlled experiment. A predictive model alone cannot prove causation.
- **Stretch target:** Discover an actionable signal or intervention that materially improves a predefined churn metric; treat the size of improvement as an experimental goal.
- **Outside judge:** Holdout cohorts, a prospective test, and reproducible code or calculations. Report null results honestly.

## Attribution

Adapted from Felix Rieseberg's [*How to be more ambitious: A tutorial for humans with models*](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/), with the combined [RoboNuggets *be-ambitious* skill](https://github.com/robonuggets/be-ambitious/blob/main/SKILL.md) as a structural reference.
