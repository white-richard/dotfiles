---
name: ambitious-altitude
description: >-
  Raise a task from its requested deliverable to the underlying outcome and a measurable, durable workflow. Use for 'aim higher', 'goal beyond the goal', strategic reframing, or /ambitious-altitude.
---

# Ambitious Altitude

Raise the **level of the goal**, not the amount of work. The user's request is often their best guess at how to achieve an outcome. Investigate the outcome before committing to that guess.

This skill covers *Altitude* only. Do not silently add a deep research project or a multidisciplinary team; those are different dimensions of ambition.

## Decide what you were given

- **A task to complete:** Reframe it briefly, then complete the most ambitious *authorized and verifiable* version possible.
- **A prompt to improve:** Produce a copyable rewritten prompt, not the task's deliverable.
- **No identifiable task:** Use the most recent substantive user request. If none exists, ask for a task in one sentence.
- **Ambiguous task versus prompt:** Return the rewritten prompt and stop.

Explicit constraints in the original request remain binding. An ambitious alternative must not silently replace a specifically requested deliverable.

## Workflow

1. **Find the goal beyond the goal.** Complete this chain using available context:
   - The user asked for **[artifact/action]**.
   - That is supposed to enable **[decision/behavior/change]**.
   - The larger outcome is **[observable result]**.
   State the outcome as a hypothesis if you have to infer it; don't present an assumption as the user's stated intent.
2. **Build an altitude ladder of three options, not three mandatory projects.**
   - **Rung 1 — Make the request useful:** Deliver the requested artifact/action, but orient it toward the actual decision or outcome.
   - **Rung 2 — Own the next decision:** Analyze what should happen afterward, identify the most important choices, and propose or take authorized next steps.
   - **Rung 3 — Improve the system:** Where appropriate, replace a one-off ritual with a repeatable mechanism that notices problems, recommends action, and verifies the result.
   Make each rung more outcome-oriented, *not* merely longer or more elaborate.
3. **Define an outside measure of success.** Specify the metric or observable behavior, baseline if known, measurement window, and the independent evidence that would show progress. If the outcome can't be observed, make the proposal more concrete or descend a rung.
4. **Check enabling access.** Identify needed source data, integrations, permissions, tools, and feedback loops. Mark them **available**, **missing**, or **unknown**. Do not invent access or results.
5. **Choose the highest feasible rung.** Prefer the highest rung that can be pursued and externally checked with existing access and authorization. If a higher rung would change the user's requested deliverable, commit money, affect other people, or create an ongoing workflow, present it as an option and ask permission before acting.
6. **Follow through.** For task requests, execute the chosen authorized rung with available tools and report evidence. For prompt rewrites, write an actionable prompt with the outcome, boundaries, evidence, and authorization gates.

## Response shape

Keep the framing proportionate to the task. Include:

1. **Goal beyond the goal:** one sentence.
2. **Three-rung ladder:** a concise progression from requested work to durable outcome.
3. **Recommended rung:** why it is the highest currently testable and authorized option.
4. **Success measure and dependencies:** external evidence; access available/missing.
5. **Rewritten prompt** in one copyable fenced block.
6. **Execution or next action:** If tasked to do the work, do it rather than stopping at a plan. If asked only to rewrite, stop after the prompt.

Do not promise to monitor a workflow persistently unless an actual supported automation has been set up. Do not claim success based solely on your own assessment.

## Example

**Input:** `/ambitious-altitude update our quarterly business review deck`

- **Underlying outcome:** Leadership spots risks early and reallocates effort effectively.
- **Rung 1:** Use the real operating data to explain what changed, why, and what it implies instead of simply updating slide numbers.
- **Rung 2:** Surface the three most consequential decisions, viable alternatives, and arguments for and against each.
- **Rung 3:** Propose an ongoing early-warning and decision process; backtest it against historical data before asking to pilot it alongside the quarterly review.
- **Outside check:** Did historical signals identify consequential changes earlier, and did decision-makers make better-timed decisions?
- **Boundary:** Still produce the requested deck unless the user agrees to replace it. Do not establish ongoing monitoring without appropriate tooling and authorization.

## Attribution

Adapted from Felix Rieseberg's [*How to be more ambitious: A tutorial for humans with models*](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/), with the combined [RoboNuggets *be-ambitious* skill](https://github.com/robonuggets/be-ambitious/blob/main/SKILL.md) as a structural reference.
