# Story 011: Audio (music + SFX)

> **Status**: Ready
> **Type**: Config/Data
> **Estimated**: 3h
> **Depends on**: 009, 010
> **Unlocks**: — (final MVP story)

## Goal

Add background music (one per level) and ~10 sound effects wired to gameplay
events. Stay within HTML5 export audio budget per art-bible §8I (music 96
kbps OGG stereo, SFX 64 kbps OGG mono). Audio is the last-added layer
because juice validation in the prototype (without audio) passed — this
story is about polish, not validation.

## References
- `design/gdd/game-concept.md` § Visual & Audio Direction
- `design/art/art-bible.md` §8I — HTML5 export audio budget (3–4MB music, 1MB SFX)
- `design/art/art-bible.md` §8J — OGG Vorbis format mandate (not MP3, not WAV)
- `design/art/art-bible.md` §8K — max 8 simultaneous audio streams
- `design/art/art-bible.md` §8L — do NOT use Thread for audio (HTML5 unreliable)

## Acceptance Criteria

### Audio Assets (sourced, licensed, committed)

- [ ] Three music tracks, one per market:
  - [ ] Shilin theme — "night market classic" / chiptune-ish with warm tones
  - [ ] Fengjia theme — younger / more electronic / neon energy
  - [ ] Liouho theme — slower / harbor / more melodic
  - [ ] All .ogg format, 96 kbps stereo, loopable (~30–60 seconds per loop)
  - [ ] Total music file size ≤ 4MB
  - [ ] Source: either original composition (out of scope for this story) OR sourced from a CC0/CC-BY library (opengameart.org, freemusicarchive.org, or similar). **License and source URL MUST be documented in `assets/audio/music/LICENSE.md`.**
- [ ] Sound effects (~10 total), all .ogg 64 kbps mono:
  - [ ] `sfx_jump.ogg` — short whoosh / spring
  - [ ] `sfx_duck.ogg` — quick slide / cloth sound
  - [ ] `sfx_pickup.ogg` — bright bell / coin / "ding" (the most-heard SFX — must feel good; this is the Juicy feedback pillar payoff)
  - [ ] `sfx_enemy_hit.ogg` — bump / "oof" (keep LIGHT per art-bible §2 Death mood — "oops sorry" not dramatic)
  - [ ] `sfx_level_start.ogg` — 3-2-1-GO countdown tick or single chime
  - [ ] `sfx_level_complete.ogg` — short fanfare (~1 second)
  - [ ] `sfx_button_press.ogg` — rubber-stamp thunk (menu UI)
  - [ ] `sfx_button_hover.ogg` — very subtle tick (menu UI)
  - [ ] `sfx_footstep.ogg` — soft (will play on run; volume low) — OPTIONAL; skip if scope pressure
  - [ ] `sfx_land.ogg` — small thud on ground landing after jump
  - [ ] Total SFX file size ≤ 1MB
  - [ ] `assets/audio/sfx/LICENSE.md` documents every SFX source and license

### Wiring

- [ ] Autoload `AudioManager` at `src/autoloads/audio_manager.gd` with:
  - [ ] `play_music(track_slug: String)` — crossfades current music to new track over 0.5s
  - [ ] `play_sfx(sfx_slug: String, volume_db: float = 0.0)` — plays a one-shot SFX
  - [ ] Master volume control exposed as `music_volume_db` / `sfx_volume_db` properties
  - [ ] Uses `AudioStreamPlayer` nodes internally (one persistent for music, a pool of 4 for SFX to respect §8K 8-stream cap)
- [ ] Registered in `project.godot` autoloads
- [ ] Level scenes call `AudioManager.play_music()` on `_ready()` with their market's track slug
- [ ] Player script (Story 002) calls `AudioManager.play_sfx("jump")` on jump input
- [ ] Player script calls `play_sfx("duck")` on duck state change (once per press)
- [ ] Collectible script (Story 003) calls `play_sfx("pickup")` in its `_on_body_entered`
- [ ] Enemy script (Story 005) calls `play_sfx("enemy_hit")` when `player_hit` emits
- [ ] Game singleton (Story 007) calls `play_sfx("level_complete")` on goal reached
- [ ] Menus (Story 010) call `play_sfx("button_press")` on button activation

### HTML5 export verification

- [ ] First load in Chrome: audio does NOT autoplay on page open (browser policy forbids; audio starts on first user input like a click or keypress). Verify AudioManager defers first `play_music` until a `user_activated` signal or first valid input frame.
- [ ] Total exported build size (audio + everything) stays under 20MB per art-bible §8I budget

### Accessibility

- [ ] Master volume slider in a pause / settings UI — OPTIONAL, recommended post-MVP. For MVP, a simple mute-all keybind (M) toggles `music_volume_db = -80 ↔ 0` and same for SFX.

## Implementation Notes

- The crossfade for music: simplest is two `AudioStreamPlayer` nodes (A and B), tween one's `volume_db` down to -80 while the other ramps up from -80 to 0 over 0.5s. Then stop the faded-out one.
- SFX pool of 4 streams: `AudioStreamPlayer` nodes in an array. When `play_sfx` is called, find the first non-playing one (or the oldest if all active) and use it. Prevents the 8-stream cap from being an issue.
- Browser autoplay policy: Chrome blocks `.play()` until user gesture. Godot 4 handles this internally for HTML5 (audio queues and starts on first input). Verify by testing — if it doesn't work, add explicit "click to start" gate on title screen.
- The pickup SFX is the most important single asset in the whole game — the "Juicy feedback" pillar lives or dies here. Source the best-feeling free asset available and iterate if it's flat.
- License documentation: every asset's source URL + license type + attribution requirements recorded in the LICENSE.md files. This is non-negotiable — a web release without clear licensing is a legal risk.

## Out of Scope

- Original music composition — use CC0 / CC-BY library or commission post-MVP
- Dynamic music (music changes tempo based on events) → post-MVP
- Spatial audio / per-stall ambient sounds → post-MVP
- Voice acting → the game has no dialogue in MVP scope (concept doc explicitly excludes)
- Settings UI for per-category volume — post-MVP; mute-all keybind is sufficient

## Test Evidence (Config/Data)

- [ ] Smoke check `production/qa/smoke-2026-04-XX-audio.md`:
  - [ ] Play Shilin level → music plays on load, does NOT restart when player dies + restarts (music persists across scene reload within same level slug)
  - [ ] Jump, pickup, duck, die — all SFX fire at correct events
  - [ ] Music crossfades smoothly when navigating Shilin → Level Select (music changes to title ambient or silence)
  - [ ] HTML5 export runs in Chrome; audio plays after first user click (does NOT try to autoplay on page load)
  - [ ] Build size check: exported `.pck` + HTML5 shell + audio ≤ 20MB
  - [ ] LICENSE.md files present and complete for all music and SFX assets
