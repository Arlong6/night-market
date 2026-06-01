# Review Log — vignette-state-machine.md

## Review — 2026-05-30 — Verdict: APPROVED (lean inline)
Scope signal: M
Specialists consulted at authoring: none (orchestrator direct draft from established contracts)
Blocking items: 0 | Recommended: 2

Summary: State machine spec is clean, 6-state lifecycle per NPC, 14 ACs. Cross-system contracts cleanly defer to the right systems (#19 owns validation, #10 owns cascade animation, #11 owns dialogue rendering). Edge case AC-9 (bind during ACTION defers cascade) correctly aligns with #10 EC-10 notebook-closed gate. The replay mechanic (re-click restarts at INTRO) is a deliberate Discovery affordance — player can re-listen with newly-decoded words.

### Recommended Revisions
1. OQ-1 (auto-advance ACTION vs require player advance) is a real playtest question. Default auto-on-signal may feel hurried; consider testing both.
2. OQ-3 (visual distinction for COMPLETE_PENDING) is worth implementing if playtest shows players forgetting which NPCs they've engaged.

### Verdict: APPROVED (lean)
Ready for implementation when #7, #11, #13 are in place.
