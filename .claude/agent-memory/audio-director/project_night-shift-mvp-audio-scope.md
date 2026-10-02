---
name: night-shift-mvp-audio-scope
description: Night Shift (大夜班) MVP audio scope is machine/station SFX only, no music
metadata:
  type: project
---

Night Shift's MVP explicitly excludes music. Per `design/gdd/game-concept-night-shift.md`
("Explicitly NOT in MVP" and Technical Considerations → Audio Needs): MVP audio = machine/
station SFX only (叮咚、微波叫、刷條碼嗶等), scope rated "Moderate". The concept doc's own
framing: **音效是手感，音樂是氣氛** — SFX is Sensation (MDA), music is atmosphere. Music
is deferred to Vertical Slice tier ("音效全套" — full audio suite, still doesn't explicitly
promise music even at VS, only implies fuller SFX coverage including character footsteps).

**Why**: Pillar 1 (「忙得有節奏」busy-with-rhythm) and the MVP core hypothesis are validated
through SFX-driven feedback and the two-phase rhythm (靜/爆), not through a music system —
cutting music protected the 4-6 week MVP timeline during a new-engine (Unity) ramp-up
(concept doc Technical Risks: new engine is the biggest risk).

**How to apply**: Never propose a dynamic music system, adaptive score, or BGM layer as part
of Night Shift MVP audio requirements. If asked about mood/atmosphere for MVP scenes, redirect
to lighting (art bible owns mood via light — see [[night-shift-art-bible]]) and to
machine/station SFX (owned downstream by sound-designer, system #14 — see
[[night-shift-audio-director-workflow]]). Music direction work only becomes relevant at
Vertical Slice or later; verify this is still current by re-reading the concept doc's MVP
Definition section before committing to it, since scope tiers can shift.
