# Review Log — npc-sprite-tableau.md

## Review — 2026-05-30 — Verdict: APPROVED (lean inline)
Scope signal: S (MVP scope: baker only)
Specialists consulted: none (S effort)
Blocking items: 0 | Recommended: 1

Summary: Simple per-NPC sprite + tableau system. 10 ACs. Elder special case (no animation, immediate `tableau_complete`) cleanly handled. AC-8 enforces the Pillar 1 "shimmer is the only motion" contract — no breathing/swaying. Cross-system contracts to #2 (click routing), #8 (tableau orchestration), and #6 (spatial placement) all consistent.

### Recommended Revisions
1. OQ-1 (POST_CASCADE_IDLE differentiation) is a real player-experience question worth playtest. Default "identical to IDLE" is minimum viable; visual differentiation could reward returning players.

### Verdict: APPROVED (lean)
Ready for baker sprite art creation + tableau animation authoring (art bible blocking).
