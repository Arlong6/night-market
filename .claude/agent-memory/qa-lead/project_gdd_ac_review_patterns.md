---
name: project-gdd-ac-review-patterns
description: Recurring gap patterns found when drafting AC coverage matrices for Night Shift GDDs — ADR-status gate, formula range-endpoint checking, forward-obligation registration lag. Not netcode-specific.
metadata:
  type: project
---

Found while drafting `machine-interaction.md`（機台互動組 #5）Section H AC coverage
matrix (2026-09-29). Generalize to any future Night Shift GDD AC review, not just
netcode — check these three before signing off a coverage matrix or gate-check:

1. **ADR lifecycle gate.** Check every ADR an AC's THEN depends on. `docs/CLAUDE.md`
   rule: "Never skip Accepted — stories referencing a Proposed ADR are auto-blocked."
   As of 2026-09-29, ADR-0001/0002/0003 are all still `Proposed`. Machine-interaction's
   entire validation model (six ADR-0002 predicates, `RejectReason` enum, ADR-0003
   `PassThrough` mask) rests on two Proposed ADRs — a well-written, T0-passable AC can
   still be sprint-blocked for a reason invisible in the AC text itself. **"AC is
   testable" and "story is unblocked" are two different verdicts — don't conflate them.**

2. **Range-endpoint formula checking.** When a Formulas section states an input as a
   *range* (not a point value) and justifies a tuned constant via a narrative
   point-example inside that range, re-derive the inequality at the range's *stated
   endpoints*, not just the example's point. Caught in F3 of machine-interaction.md:
   `crossing_time_sec T ∈ [11,15]`, narrative example implicitly uses T≈13 to justify
   `grace_sec=16 ≥ T+B` (B=2). At the range's own stated upper bound T=15:
   `16 < 17` — the formula fails its own inequality by 1s at a value the GDD itself
   says is in scope. The point-example silently picked a T that passes.

3. **Forward-obligation registration lag.** `design/gdd/systems-index.md`
   §"跨系統前向義務" is the sole source of truth for cross-system obligations — its own
   text: "在義務被登記到本節之前，它等於不存在。" A source GDD can mark new obligations
   `⏳` (pending Phase 5 registration) inside its own body; check the actual table for
   whether they've landed before treating a cross-system AC as validated against a
   contract the downstream author can actually see. As of 2026-09-29,
   machine-interaction's `⏳`-tagged additions (E0.3's 4th claim-interrupt trigger +
   `NothingToTake` for ADR-0002; #7's checkout judgment-moment consistency; #15's
   shift-end leftover-instance settlement; #11's interactable-overlap ban) are not yet
   in that table — only items dated 2026-09-28 are. #7/#11/#15's own authors currently
   have zero visibility into these four requirements.

**How to apply**: run all three checks before finalizing any AC coverage matrix or
`/gate-check` verdict for a Night Shift GDD. Re-verify item 1 by re-reading each ADR's
`## Status` line — it decays fast (ADRs move to Accepted). Related:
[[project-night-shift]] (netcode/session-specific recurring gap categories from the
earlier review pass — a narrower sibling of this same habit).
