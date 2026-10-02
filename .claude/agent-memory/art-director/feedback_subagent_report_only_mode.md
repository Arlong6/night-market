---
name: subagent-report-only-mode
description: How to behave when invoked as a Task subagent for a narrow GDD-content contribution, vs a direct interactive session with the user
metadata:
  type: feedback
---

When invoked as a Task subagent (not a direct interactive session with the user) and the calling prompt explicitly says "你只回報，不寫檔" / "you only report, don't write files" and hands over a fully-specified scope (files to read, exact questions to answer, exact output format with word/row limits), skip the normal Question-First / draft-approval collaboration ritual from the system prompt — no `AskUserQuestion`, no "may I write this section to [filepath]?" checkpoint, no incremental file writing, no waiting for approval between sections. There is no back-and-forth possible in this mode: `SubagentHandback` is a single-shot return to the caller, not a conversation turn.

Instead: read all cited source files fully (not just the sections the prompt names — check adjacent Edge Cases / Core Rules too, since upstream GDDs increasingly pre-bake partial answers), ground every claim in specific section/line anchors matching the calling project's own citation style (e.g. `(C3)`, `(E0.1)`, `(判準3)`), answer the exact questions asked in the exact format requested (respect hard row/word limits literally), and fold open decisions or gaps into the report text itself (clearly flagged) rather than pausing to ask.

**Why:** This project's `coordination-rules.md` Parallel Task Protocol relies on an orchestrating skill (e.g. systems-designer / design-system) gathering department input from multiple specialist subagents (art-director, technical-artist, etc.) in parallel for one section of a larger GDD. A subagent that stops to ask clarifying questions mid-delegation breaks that parallel-gather pattern — the orchestrator has no path to relay the question back to the user mid-flight, and the calling skill reads the returned text, not a live thread.

**How to apply:** Check the invocation prompt for explicit scope + "only report" language (and note whether the tool list even includes `AskUserQuestion` — its absence is itself a signal) before defaulting to the interactive Question → Options → Decision → Draft → Approval workflow. If the user (not a skill/orchestrator) addresses art-director directly in a live interactive session, the full collaborative protocol from the system prompt still applies as normal — this memory only overrides behavior in the narrow subagent/report-only case.
