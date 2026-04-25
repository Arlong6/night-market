# Story 010: Menus (title + level select + level end)

> **Status**: Ready
> **Type**: UI
> **Estimated**: 3h
> **Depends on**: 007, 009
> **Unlocks**: 011; gameplay loop closure

## Goal

Three screens that bracket gameplay: a title screen (first thing player
sees), a level select (pick Shilin / Fengjia / Liouho), and a level-end /
game-end screen (show score, offer next action). All three use the diegetic
receipt + rubber-stamp button grammar from art-bible §3D.

## References
- `design/gdd/game-concept.md` § MVP scope "Title screen" + "Level-end screen + level select"
- `design/art/art-bible.md` §3D — diegetic UI (receipt, lunchbox, rubber-stamp buttons)
- `design/art/art-bible.md` §4D — UI palette (4 colors)
- `design/art/art-bible.md` §2 — Level End mood (warm fill intensifies, score pops like coins)
- `design/art/art-bible.md` §8A — UI stamp button canvas 64×20

## Acceptance Criteria

### Title Screen
- [ ] Scene: `src/scenes/menus/title.tscn`
- [ ] Background: near-black Shilin night (`#1A0A00`) with warm parallax-esque sign dots (for mood — static backdrop, no scrolling needed on title)
- [ ] Title text: "夜市大冒險" or "NIGHT MARKET RUNNER" (pick one — prefer Chinese since pillar is Taste of home; confirm with user during implementation)
  - [ ] Displayed in stamp-red (`#C2241A`) pixel font, centered, large
- [ ] Single button: "開始 / START" as rubber-stamp rectangle (64×20, cream background, stamp-red ink)
- [ ] Button press → loads Level Select scene
- [ ] (Optional, nice-to-have) "重置 / RESET" secondary smaller button that calls `Game.reset_run()` — for clearing session state

### Level Select Screen
- [ ] Scene: `src/scenes/menus/level_select.tscn`
- [ ] Shows three level cards in a row: Shilin (士林) / Fengjia (逢甲) / Liouho (六合)
- [ ] Each card is a rubber-stamp rectangle (larger than buttons — ~80×60 suggested) with the market name + palette swatch preview
- [ ] Shilin is always selectable
- [ ] Fengjia and Liouho are visually marked as "locked" in MVP (grayed-out stamp + lock icon or "SOON" text overlay) — they become clickable only after Story for those levels' content exists
- [ ] Pressing a card → `Game.goto_level(slug)` → loads the level scene
- [ ] Back button "返回" → returns to title

### Level End Screen
- [ ] Scene: `src/scenes/menus/level_end.tscn` — triggered at end-of-level by the Level scene (Story 009)
- [ ] Shows: level name, final score, time taken, deaths
- [ ] Score displayed with coin-drop bounce animation per art-bible §2 Level End mood (score-pop gold `#FFD966`)
- [ ] Two buttons:
  - [ ] "再玩一次 / AGAIN" → reloads same level via `Game.goto_level(Game.current_level)`
  - [ ] "下一關 / NEXT" (if next level exists) OR "回選單 / MENU" (if this was last level)
  - [ ] "MENU" → `Game.goto_level("level_select")` (level select is treated as a pseudo-level for navigation)
- [ ] Full-screen overlay with warm fill intensification per mood spec (20–30% brighter than gameplay fill)

### Shared
- [ ] All buttons support keyboard nav (Space / Enter to activate focused button; ↑↓ or Tab to change focus) — diegetic controls only, no mouse-required UI
- [ ] All UI text uses the same bitmap font as HUD (Story 008)
- [ ] All menu scenes hide the gameplay HUD (which may still be loaded but `visible = false`)

## Implementation Notes

- Menus use `Control` nodes in `CanvasLayer`. Follow the same structure pattern as HUD (Story 008).
- Godot 4 UI focus system: set `focus_mode = FOCUS_ALL` on buttons; use `grab_focus()` on scene load to pick default button.
- The coin-drop score bounce is a visual flourish — implement as a `Tween` interpolating number from 0 to final over ~1 second with a bounce easing. Low-risk, expected to feel good quickly.
- For the locked Fengjia/Liouho cards: simplest is visually dim them (50% opacity + a small "LOCKED" badge) and disable their button input (`button_disabled = true`). When those levels' content stories are done, a follow-up change unlocks them.
- Chinese + English button text: recommend showing both with Chinese primary, English smaller and below — serves Taste of home + accessibility.
- The "Title" text and palette swatches on the level select are the highest-polish elements of the menus. Allocate iteration time for these.

## Out of Scope

- Settings menu (audio volume, fullscreen toggle) → post-MVP
- Controls help / tutorial screen → post-MVP (concept doc does not list one)
- High-score table / leaderboard display → post-MVP
- Actual audio on button presses → Story 011 (button press SFX)
- Animated title screen (scrolling market background, lanterns swaying) → post-MVP juice pass
- Save/load state from disk → out per concept doc (MVP is session-only)

## Test Evidence (UI — manual)

- [ ] Walkthrough doc `production/qa/evidence/010-menus-walkthrough.md`:
  - [ ] Title → Level Select navigation works (screenshot of each)
  - [ ] Level Select → Shilin loads the level (screenshot of transition)
  - [ ] Fengjia / Liouho visibly locked and unclickable (screenshot showing disabled state)
  - [ ] Level End screen appears after reaching goal (screenshot with score bounce mid-animation)
  - [ ] "AGAIN" button reloads level; "MENU" returns to level select — verify both paths
  - [ ] Keyboard-only navigation works (no mouse required for a full run)
  - [ ] Chinese text renders correctly at pixel font size (check 士林/逢甲/六合 don't come out as boxes — BMFont must include these characters OR fall back to a fallback font for CJK)
- [ ] Self sign-off (solo mode) with verbatim "UI works, menus navigate cleanly" or specific issue notes
