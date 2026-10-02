---
name: night-shift-audio-director-workflow
description: How audio-director is invoked in Night Shift's multi-agent GDD workflow — requirements-only reports vs. sound-designer's #14 ownership
metadata:
  type: project
---

Night Shift's GDDs (e.g. `design/gdd/machine-interaction.md`) are assembled by an orchestrating
skill/agent that pulls domain-specific input from multiple leads and slots it into the owning
system's document (see that GDD's "Interactions with Other Systems" table — #7, #11, and #14
each already have entries contributed this way). audio-director's role in this flow is
narrower than the general question-first collaboration protocol: when invoked as a subagent
to answer one section of another system's GDD (e.g. a "Visual/Audio Requirements" section
owned by system #5, not by audio's own #14), the task is to **report requirements and
constraints only** — no file writes, no AskUserQuestion round-trip. The calling
agent/orchestrator has already gathered context and owns the actual write + user approval
step.

The actual sound content — event lists, SFX asset specs, naming, per-sound design — belongs
to **#14 音效系統**, owned downstream by `sound-designer`, per `design/gdd/systems-index.md`.
audio-director's contribution to *other* systems' GDDs is limited to: event→cue mapping, mix
priority/ducking rules, palette/tone direction, and "must not" constraints — never the actual
sound assets or a per-sound spec sheet (that's #14's job once it's designed).

**Why**: Keeps a clean separation between "what must the audio do / not do" (audio-director,
embedded in the owning system's GDD) and "what specific sounds implement that" (#14,
sound-designer's own GDD later). Mirrors the existing pattern for #7/#11 in this project.

**How to apply**: When asked to contribute an audio section to a non-#14 GDD in this project,
keep the report terse, table-driven, and cross-referenced by the source GDD's existing rule/
edge-case IDs (C#, E#, 判準#, F#, ADR-000x) rather than re-deriving reasoning already settled
elsewhere — this matches the project's dense, citation-heavy documentation register (see
[[arlong-gdd-style]]). Respect any explicit format/length caps given in the task — this
project's skills sometimes impose a hard character limit on structured cross-system reports.
