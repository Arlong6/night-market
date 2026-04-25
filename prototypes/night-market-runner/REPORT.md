# Prototype Report: Night Market Runner

> **PROTOTYPE — NOT FOR PRODUCTION**
> Date: 2026-04-22
> Scope: Core feel validation — jump/collect/dodge + camera mode comparison

## Hypothesis

Two open questions parked in `design/gdd/game-concept.md`:
1. Auto-scroll or player-paced scroll? (Core feel question)
2. Do art-bible sizes (24×40 player, 20×24 collectible, 32×32 tile) work in-game?
3. Does a color-pop pickup feel juicy enough, or does it need particles/SFX/shake?

## Approach

Built two parallel prototypes:
- **Godot 4.6 version** (`main.gd`, `player.gd`, `collectible.gd`, `enemy.gd`) — canonical target stack
- **Web Canvas version** (`web-prototype.html`) — zero-install fallback after user declined Godot install

User playtested only the web version (Godot 4.6 not installed). Web version uses
the same physics constants (`MOVE_SPEED=110`, `GRAVITY=800`), locked art-bible
palette, and canonical sprite sizes as the Godot version.

Mid-playtest scope adjustment:
- User hit a 24×24 ground obstacle they couldn't jump (math confirmed 0.75px margin, effectively impossible with frame timing)
- User intuitively expected a **duck** mechanic ("不能變低")
- Duck added mid-prototype: ↓/S halves player height 40→20, 60% move speed while ducking, auto-stand when clear above
- Two hanging sign obstacles added to validate duck mechanic
- `JUMP_VELOCITY` bumped from -230 to -250 to give ~4px clearance on ground obstacles

## Result

User played through with jump + duck + collect. After scope adjustment, feedback was:
- **"OK 完美"** (overall feel)
- **Mode preference**: Mode 1 (player-paced, camera follows) over Mode 2 (auto-scroll 80 px/s)

The player-paced preference is consistent with the game's pillars:
- **Snackable joy** is served better when the player controls pace — miss a collectible, turn around, grab it, no stress
- **Taste of home** (exploration/appreciation of the market) benefits from non-forced pacing
- Auto-scroll tension conflicts with "explore every stall" framing

No bugs reported after duck patch.

## Metrics

- **Jump clearance after tune**: ~4px margin on 24h obstacles (up from 0.75px — lethal)
- **Scope additions during prototype**: duck input + hanging sign obstacle type + visual duck state feedback
- **Iterations**: 1 tune cycle (jump velocity + duck added as one patch)
- **Player feel after tune**: "完美" (verbatim)

## Recommendation: **PROCEED**

Core loop works. Mode decision locked (player-paced). Duck mechanic survived
playtest as a natural extension — the user reached for it intuitively before
being told it existed, which is a strong signal it should be in the final game.

## If Proceeding — Changes Required

**Update `design/gdd/game-concept.md`:**
- Controls section: add `↓ / S` (Duck)
- MVP scope: add "duck action" to "In" list
- Obstacle list: split into **jump-over** (scooter, trash bag, crate) and **duck-under** (hanging sign, low banner) types
- Resolve open question: "Auto-scroll vs. player-paced scroll?" → **Player-paced locked**

**Update `design/art/art-bible.md`:**
- Section 3A (Pole Rule): add duck-state player silhouette rule (half-height, straw still visible)
- Section 3C: hanging sign obstacle type — confirmed in prototype, spec pixel placement (~y=115, 22h)

**Production physics baseline (port to Godot directly):**
- `MOVE_SPEED = 110` px/s
- `JUMP_VELOCITY = -250` px/s
- `GRAVITY = 800` px/s²
- `JUMP_CUT_MULT = 0.5`
- `COYOTE = 0.10s`
- `JUMP_BUFFER = 0.10s`
- `DUCK_MOVE_MULT = 0.6`
- `STAND_H = 40` / `DUCK_H = 20`

**Juice investment** (not explicitly tested but flagged for production):
- Current pickup = color disappear + score tick. Needs validation with production art — likely wants particle burst + pitched SFX + tiny +100 pop text.

## Production Scope Impact

The duck addition is small but real:
- +1 input action
- +1 obstacle type per level (hanging signs)
- Player sprite set needs duck pose (was 1 stand + 3 jump = 4 poses; now add 1 duck = 5 poses)
- Art-bible Section 3A needs silhouette rule update (minor)
- Still within weekend scope

## Lessons Learned

1. **Math the jump arc before shipping a prototype.** 0.75px margin was a predictable failure — I should have calculated and tuned before user testing.
2. **Players reach for the obvious missing verb.** User went for duck without being told; the art-bible had quietly predicted this ("hanging sign to duck under" was in Section 3C). Listen to the art-bible.
3. **Web fallback was worth it.** Zero-install got us to feel validation in minutes vs. hours of engine install. Keep the web prototype pattern in the toolkit for future concept validation.

## Solo Mode Note

Per `production/review-mode.txt` = `solo`, CD-PLAYTEST creative-director review
is skipped. This report's **PROCEED** recommendation is final.
