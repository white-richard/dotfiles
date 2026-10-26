---
name: ambitious-range
description: >-
  Improve a task with practical methods borrowed from other disciplines, not expert role-play. Use for 'fresh angles', 'cross-disciplinary', 'outside the box', or /ambitious-range.
---

# Ambitious Range

Expand the **set of methods available to the task**, not the number of ornamental perspectives. Find what adjacent and surprising fields can *do* to improve the result, then apply those techniques.

This skill covers *Range* only. It does not automatically change the underlying goal (Altitude) or require an exhaustive expert-grade investigation (Depth).

## Decide what you were given

- **A task to complete:** Select useful cross-disciplinary methods, then use them in the actual deliverable where feasible.
- **A prompt to improve:** Produce a rewritten prompt that assigns concrete jobs to disciplines; stop before execution.
- **No identifiable task:** Use the most recent substantive user request. If none exists, ask for the task in one sentence.
- **Ambiguous task versus prompt:** Return the rewritten prompt and stop.

Keep the original audience, deliverable, budget, and other constraints unless the user authorizes a change.

## Workflow

1. **Turn nouns into verbs.** Replace the artifact label with a description of what must happen. For example, “make a quarterly business review deck” becomes “help time-constrained leaders understand cause and effect, decide under uncertainty, and commit to action.” Identify the audience, actions, and constraints.
2. **Assemble a small, purposeful crew.** Identify 2–4 fields with genuinely different strengths. Include an adjacent field, a field connected to the audience or medium, and—when useful—a surprising or adversarial field. Do not recruit experts merely to make the list impressive.
3. **Translate each discipline into a job and instrument.** For every chosen field, specify:
   - **Field:** Which discipline lends the method?
   - **Job:** What distinct problem will its practitioners solve?
   - **Technique/tool:** What do they actually do—interviews, story editing, threat modeling, behavioral experiments, 3D simulation, forensic reconciliation, etc.?
   - **Contribution:** What tangible improvement will appear in the requested result?
4. **Test the transfer.** Explain why each borrowed technique fits this task, what evidence or access it needs, and its likely cost or tradeoff. Drop decorative additions that don't improve the outcome.
5. **Execute and synthesize.** Apply the selected methods, reconcile conflicting findings, and return one coherent deliverable—not separate role-play monologues. Parallel agents may help if actually available; never imply you ran specialists or tools you didn't use.
6. **Validate outside the conversation.** Choose a test matching the deliverable: audience comprehension, usability sessions, a red-team challenge, a real prototype, comparison against an alternative, or observable decisions and actions. Report actual findings separately from proposals.

## Response shape

Use a compact format appropriate to the task:

1. **The verbs, not the noun:** the real action the deliverable needs to cause.
2. **The crew:** a table or concise bullets with **field → concrete method → contribution**.
3. **The synthesis:** how the methods combine, including one unexpectedly valuable connection and any conflicts or costs.
4. **Outside test and access:** what would verify the result; which tools and data are available or missing.
5. **Rewritten prompt** in one copyable fenced block.
6. **Execution or next action:** Execute if the user requested the task and access permits it; otherwise stop after the rewrite.

A field's vocabulary is not a technique. Don't “write as a forensic accountant”; perform reconciliation and anomaly checks if those methods fit. Avoid claims that fictional experts, simulated agents, or unsupervised subagents actually reviewed the work.

## Example

**Input:** `/ambitious-range make the quarterly business review more compelling`

- **Verbs:** Enable busy leaders to understand a causal story, challenge it, and make a confident decision in 30 minutes.
- **Data analyst →** Build a contribution or driver analysis for the highest-impact changes; contributes an evidence-backed explanation, with causality claims tested or clearly qualified.
- **Investigative journalist →** Structure the narrative around the strongest supported claim and trace it back to primary sources; contributes a clear, evidence-backed story.
- **Information designer →** Prototype visuals and run a comprehension check with representative readers; contributes faster understanding.
- **Forensic accountant →** Reconcile surprising financial movements and probe unexplained discrepancies; contributes adversarial checks.
- **Synthesis:** A decision-ready narrative with explicit uncertainty and a short set of contested decisions, not four separate reports.
- **Outside test:** Can representative stakeholders accurately state the key tradeoffs and decide what happens next?

## Attribution

Adapted from Felix Rieseberg's [*How to be more ambitious: A tutorial for humans with models*](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/), with the combined [RoboNuggets *be-ambitious* skill](https://github.com/robonuggets/be-ambitious/blob/main/SKILL.md) as a structural reference.
