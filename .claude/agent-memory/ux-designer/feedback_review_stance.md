---
name: feedback-review-stance
description: How GDD reviews are run in this project — adversarial, verify-don't-trust, no padding; reviewer's job is to find problems, not to validate
metadata:
  type: feedback
---

When asked to review a GDD, the job is to **find problems**, not to validate the design.
Deliver a numbered findings list: severity (BLOCKING / RECOMMENDED / NICE-TO-HAVE), the
exact quote being attacked, what is wrong, and a concrete fix. No padding, no summary of
what the doc does well.

**Why:** the creative-director's standing critique of this project's docs is that
"a well-written disclosure standing next to a larger undisclosed gap" lets disclosure
density do reputational work it has not earned. A review that praises the disclosures
reinforces exactly that failure mode.

**How to apply:**
- Every citation in the doc under review must be checked against the cited source file.
  Cross-document citations here have been wrong in ways that changed the argument
  (a spec attributed to the wrong art-bible section, where the two sections say
  different things).
- Never accept "deferred to system X" at face value — check whether system X has a GDD,
  whether the choice it is being handed is actually free, and whether any AC covers it.
- "An AC exists" is not "the AC checks this" — trace the AC text to the claim.
- Second-round reviews must judge whether the revision delivered the thing, or re-parked it.
- **From r3 onward the test is bidirectional.** A revised doc is full of ⚠ self-critique
  paragraphs; those are author claims, not facts. Check both (a) did the *assertion* change,
  or is there just a confession next to an unchanged assertion, and (b) is the confessed
  defect actually a defect? Flagging an over-read — a normal design choice written up as a
  flaw, or a low-probability risk bought at high cost — counts the same as finding a gap,
  and its fix is deletion. Reason: each review round's residual bias is the mirror of the
  last one's (r1 = "absence of unfavourable synthesis", r2 = "absence of favourable
  synthesis"), so a review that only adds findings drifts the doc into noise.

Related: [[project-ux-scope-ruling]]
