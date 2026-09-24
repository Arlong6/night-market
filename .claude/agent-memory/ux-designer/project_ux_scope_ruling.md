---
name: project-ux-scope-ruling
description: Creative-director ruling on what a non-UI GDD owes the UI layer — constraints on pixels, not pixels; use it as the standard for UX scope disputes
metadata:
  type: project
---

Standing ruling from creative-director (2026-09-20, product-database r1):
a system GDD that "has no UI of its own" still owes the UI layer **constraints on
pixels, not pixels** — the split is valid for *graphic assets*, invalid for
*granularity / semantic load on a shared channel*.

**Why:** the product-database GDD disguised an information-architecture decision
(adding a second semantic axis to the existing above-customer icon channel) as a data
decision and pushed it to system #11 HUD, which has no GDD and no owner. The ruling
came out of that dispute; it is the general standard now, not a one-off.

**How to apply:** whenever a GDD says "圖形／排版歸 #11 與美術", check that it still
authored: (a) the budget (how many distinct symbols may coexist), (b) the negative
space (what the downstream system may NOT use — hues, shapes, regions already
allocated elsewhere in the art bible), (c) the trigger and population for any
readability test it invokes, (d) behaviour when the channel's existing state encoding
(e.g. 紅蓋黃 urgency override) collides with the new axis. A deferral that names none
of these is a re-park, not a constraint.

Related: [[feedback-review-stance]]
