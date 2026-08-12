# Sprint 22 RL-HYP-01 — Adversarial Review Order (commissioning record)

| | |
|---|---|
| Status | Sprint 22 run set remains inadmissible; the observed mechanism is under independent adversarial review |
| Classification (locked) | "Sprint 22 run set is inadmissible because Gate 3b is violated. The observed mechanism is under independent adversarial review." It is NOT yet established that "the gate implementation is definitely the cause." |
| Hold | No statistics, no amendment, no rerun, no production fix until both reviews are returned and compared (2026-08-12) |

---

## 1. Narrow classification (lock-in, verbatim)

> **Sprint 22 run set is inadmissible because Gate 3b (admission-only
> invariance, protocol §11.3b) is violated.** The observed mechanism is under
> independent adversarial review.

Not yet: "the gate implementation is definitely the cause."

---

## 2. Review order (approved 2026-08-12)

1. **Claude — primary independent adversarial review** (Prompt A, §3.1).
2. **Gemini — independent replication**, blinded: must not see Claude's
   output or any summary of it before filing its own deliverable (Prompt B,
   §3.2).
3. **Compare both deliverables** against the frozen protocol and evidence
   (§4).
4. **Only then** choose the Sprint 22 branch (§5).

Both reviews use the same evidence package:
`docs\Sprint22_RL_HYP_01_Adversarial_Review_Brief.md` (the blinded brief,
already verified) + the corpus it names.

---

## 3. Commissioning prompts

### 3.1 Prompt A — Claude (primary independent adversarial review)

> You are the primary independent adversarial reviewer for Sprint 22
> RL-HYP-01. You are NOT the author of the primary investigation, and you
> must not assume its conclusions are correct.
>
> Workspace root:
> `C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X`
>
> 1. Start by reading `docs\Sprint22_RL_HYP_01_Adversarial_Review_Brief.md`
>    and follow it exactly.
> 2. Follow the reading order in §4 of the brief: derive your own hypothesis
>    from the artifacts and source code BEFORE reading
>    `docs\Sprint22_RL_HYP_01_Divergence_Investigation.md`. Treat that
>    report as a hypothesis under test.
> 3. Execute all 8 steps of the falsification protocol (§5 of the brief) and
>    consider all 9 alternative mechanisms (§6). Re-derive every number from
>    the CSVs yourself.
> 4. Return the deliverable in the exact §8 format, ending with the three
>    conclusions: (a) inadmissibility under §11.3b, (b) whether a code-level
>    isolation fix is required, (c) recommended next action per §9.
> 5. Constraints: read-only. No Strategy Tester runs, no code edits, no
>    protocol amendment, no analyzer changes. No statistics beyond the
>    brief's reproduction and structural checks.
> 6. Work alone. Do not discuss your conclusions with any other model.
>
> Verdict values: `ROOT CAUSE CONFIRMED` / `ROOT CAUSE CHALLENGED` /
> `ROOT CAUSE UNCONFIRMED - ALTERNATIVE(S) PROPOSED`.

### 3.2 Prompt B — Gemini (blinded independent replication)

> You are an independent second reviewer for Sprint 22 RL-HYP-01. A parallel
> review is being conducted by another model. To preserve independence you
> must NOT see or reference that model's output. You will receive only the
> raw evidence.
>
> Workspace root:
> `C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X`
>
> Blinding rules (mandatory):
> - Do not read `docs\Sprint22_RL_HYP_01_Divergence_Investigation.md` until
>   after you have completed your own derivation and written your draft
>   deliverable.
> - Do not seek or accept any summary of the other reviewer's conclusions.
> - In your deliverable, record: (a) your independently derived mechanism
>   and evidence, written BEFORE reading the report; (b) your claim-by-claim
>   audit of the report AFTER reading it; (c) any place where reading the
>   report changed your view, and why.
>
> Task:
> 1. Read `docs\Sprint22_RL_HYP_01_Adversarial_Review_Brief.md` and follow
>    §4 (reading order), §5 (falsification protocol), §6 (alternative
>    mechanisms), §7 (what "explained" looks like), §8 (deliverable format).
> 2. Re-derive all counts and the structural checks from the CSVs yourself.
>    The scripts listed in §3.7 of the brief are untrusted reference
>    material — flag any logic you believe is wrong rather than reusing it.
> 3. Constraints: read-only. No tester runs, no code edits, no statistics
>    beyond the brief's checks.
>
> Verdict values: `ROOT CAUSE CONFIRMED` / `ROOT CAUSE CHALLENGED` /
> `ROOT CAUSE UNCONFIRMED - ALTERNATIVE(S) PROPOSED`.

---

## 4. Comparison protocol (post-review, against the frozen protocol and evidence)

1. **Tabulate both deliverables side-by-side** across the brief's §5 steps
   (pass / fail / inconclusive per step) and §6 alternatives (ruled out /
   not ruled out, with evidence).
2. **Flag every disagreement.** For each: re-check the frozen artifacts,
   source lines, and protocol text. A disagreement that cannot be resolved
   by evidence keeps the mechanism in the `UNCONFIRMED` state until it is
   resolved.
3. **Verify the numbers.** Both deliverables' counts must match the frozen
   CSVs (12,329 admitted, 58 diverging, per-arm distribution) and the
   structural bijection of the brief §5 step 2.
4. **Check isolation.** Gemini's (a) section must predate exposure to
   Claude's output; if isolation failed, note the contamination and weigh
   Gemini's pre-reading derivation separately.
5. **Record the comparison** as a decision input; only then open §5.

---

## 5. Sprint 22 branch mapping (post-comparison)

```
Both reviews compared against frozen protocol + evidence
   |
   |-- ROOT CAUSE CONFIRMED (both)      -> investigate/fix settlement coupling
   |        |                                (isolation fix design)
   |        v                                TDD RED -> GREEN
   |    TT01
   |        v
   |    Decide whether a rerun of the affected experiment arms is required
   |
   |-- ROOT CAUSE CHALLENGED (either)   -> investigate the alternative
   |        |                                mechanism BEFORE changing anything
   |        v
   |    Further investigation
   |
   `-- ROOT CAUSE UNCONFIRMED           -> preserve the failed gate; do not
            |                                manufacture an explanation
            v
       Further investigation (no experiment change)
```

No branch is chosen before both deliverables are compared.

---

## 6. Non-actions (hold in force)

- No A3 amendment. No M15 exclusion. No statistics. No rerun. No production
  fix. No protocol or production-code change of any kind.
- The frozen protocol and the primary investigation report remain
  untouched.
- Sprint 22 stays inadmissible under §11.3b regardless of branch outcome.

