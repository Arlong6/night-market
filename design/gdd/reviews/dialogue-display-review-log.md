# Review Log — dialogue-display.md

---

## Review — 2026-05-30 — Verdict: APPROVED (lean inline, with one cross-doc correction)
Scope signal: M
Specialists consulted at authoring: ui-programmer (deep)
Inline review: orchestrator (lean, single-session — limited independence)
Blocking items: 0 | Recommended: 4

Summary: Bottleneck system, shimmer-aware contract is rigorously spec'd. 14 GIVEN/WHEN/THEN ACs. Token data structure (LEXICON_SLOT / UI_TEXT / PUNCTUATION) cleanly decouples dialogue content from language seed. Implementation choice (HBoxContainer-of-Labels) honestly marked as provisional pending SPIKE 1. The "freed history renders directly" rule is correctly aligned with GDD concept Shimmer Spec performance bounds.

### Cross-doc correction applied during authoring

#11 GDD reads `confirmed_slots` directly from #19 Session State. #19 GDD's "Explicitly NOT dependent" table previously listed #11 as going through intermediaries. **Corrected**: #19 GDD updated to move #11 to direct dependent (read-only).

### Required Before Implementation
None blocking.

### Recommended Revisions
1. **OQ-2 (FlowContainer wrap on Web)** is an implementation risk — should be folded into SPIKE 1's acceptance criteria (verify multi-line wrap works alongside per-character animation).
2. **Token authoring tooling (OQ-6)** is undecided — affects how `/design-system vignette-content-baker` (#13) actually authors content. Worth pre-deciding before #13 begins.
3. **EC-1 (panel close mid-cascade)** depends on `is_instance_valid` guards in `_on_slot_resolved`. Add a defensive coding rule to the control manifest if/when that's authored.
4. **AC-14 (phase guard during ENDING)** is a small but easy-to-miss invariant. Recommend explicit test coverage at unit-test level when implementation begins.

### Specialist Disagreements
None.

### Scope Signal
**M** — bottleneck, complex shimmer contract, but spec is internally consistent. 1-3 design sessions equivalent. Implementation will likely be 2-3 days solo.

### Verdict: APPROVED (lean)

Ready for ADR-TBD-input-routing (which #9 also needs) + SPIKE 1 result before implementation. The shimmer contract (5 rules) is the load-bearing API surface between #11 and #10 — both GDDs must honor it.

### Note on review independence

Single-session inline. Fresh-session independent review recommended before MVP code begins, particularly to challenge the shimmer contract rules from #10's perspective.
