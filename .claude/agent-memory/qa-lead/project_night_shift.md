---
name: project-night-shift
description: 《大夜班》(Night Shift) is a 2-4 player browser co-op game in netcode/session design QA review
metadata:
  type: project
---

Night Shift (大夜班) is a 2-4 player browser co-op game: Unity 6.3 Web, Netcode for
GameObjects + Relay over WSS, client-as-host (no migration on host loss).

Key locked design facts (as of 2026-08-25 GDD review):
- Reconnect window: 30s (slot kept; carried item drops within 2s of disconnect;
  in-progress interaction refunds to unclaimed pool)
- Late join allowed except during Settlement phase (redirected to next Lobby);
  enters via 3-5s transition screen
- Host tab close = session ends entirely, no migration, lobby UI must state this
- Join flow budget: ≤35s soft target against a 60s hard pillar cap (link with
  embedded room code, auth pre-warmed, nickname entry non-blocking)
- Player movement: 10Hz NetworkTransform; NPCs sync via milestone events only
  (not per-frame); clock sync interval 1s
- Interaction claims: host-arbitrated first-come; losing client gets an explicit
  撲空 (whiff) animation/event, never silent failure
- Host tab throttling: frame delta >500ms triggers a clock catch-up path
- RPC sequence numbers are used to reject stale/out-of-order state overwrites

**Why this matters:** the draft acceptance criteria from systems-designer initially
lacked measurable coverage for host-throttle catch-up, RPC ordering rejection,
movement-smoothness-under-latency, interaction RTT, NPC milestone sync correctness,
and settlement-phase join redirect — these are recurring gap categories to check
for in future netcode/session AC reviews on this project.

**How to apply:** when reviewing future Night Shift netcode/session stories or ACs,
re-check these six areas first, since they were the gaps found in the initial pass.
Also this is a separate active project alongside Lexicon Village — see the user's
global memory `project_active_direction` for cross-project prioritization context.
