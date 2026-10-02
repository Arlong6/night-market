---
name: arlong-gdd-style
description: arlong's dense, citation-heavy GDD authoring style — inline dated decisions, causal-chain reasoning over prose
metadata:
  type: user
---

arlong (creative director / sole decision-maker on Night Shift) writes and expects extremely
dense, information-per-character-optimized design docs. Observed throughout
`design/gdd/machine-interaction.md` and its siblings:

- Decisions are dated and inline, e.g. "（2026-09-28 arlong 裁決）" — traceable to a specific
  moment, not buried in prose or left implicit.
- Reasoning is compressed to short causal chains that cite rule/edge-case IDs (C1-C19, E0-E6,
  判準1-6, F1-F9, ADR-000x) rather than re-explaining mechanics already established elsewhere
  in the same doc or an upstream one.
- Open items are explicitly flagged with symbols rather than left as vague TODOs: 🔬 (needs
  playtest/measurement before the value can be trusted), ⏳ (pending formal registration in a
  forward-obligation/levy table), 🔴 (unresolved risk or blocker, highest urgency).
- Docs explicitly distinguish "已定" (settled elsewhere, just being surfaced here) vs. "新定"
  (newly decided in this pass) vs. provisional/stub — never lets settled and new decisions
  blur together.

**How to apply**: When drafting audio-director content for this project (GDD sections,
cross-system requirement reports), match this register — terse, table-first, cite existing
IDs instead of restating their reasoning, and flag unresolved/measurement-dependent values
explicitly (using the same 🔬/⏳/🔴 convention where it fits) rather than presenting them as
settled. Avoid padding with atmosphere-setting prose; arlong's docs almost never carry
unnecessary framing sentences — get to the table/rule as fast as possible.
