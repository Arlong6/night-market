# Story 001: Project Skeleton

> **Status**: Done (smoke check passed 2026-04-22)
> **Type**: Config/Data
> **Estimated**: 2h
> **Depends on**: —
> **Unlocks**: 002, 007

## Goal

Create a clean Godot 4.6 project at `src/` (not `prototypes/`) with all the
pixel-art-correct settings from art-bible §8 pre-baked. Project must open
in Godot 4.6 and run an empty main scene at 320×180 without warnings.

## References
- `design/art/art-bible.md` §8G — Import preset `pixel_art_standard`
- `design/art/art-bible.md` §8H — project.godot pixel-perfect settings
- `design/art/art-bible.md` §8C — File organization
- `.claude/docs/technical-preferences.md` — snake_case file naming
- `prototypes/night-market-runner/project.godot` — reference (steal settings from here)

## Acceptance Criteria

- [ ] `src/project.godot` exists with:
  - [ ] Viewport 320×180, stretch mode `viewport`, aspect `keep`, scale mode `integer`
  - [ ] Renderer `gl_compatibility` (both default and `.web` override)
  - [ ] Default texture filter = 0 (Nearest)
  - [ ] `snap_2d_transforms_to_pixel` = true
  - [ ] `snap_2d_vertices_to_pixel` = true
  - [ ] Window size override 1280×720 (4× for development)
- [ ] Input map has these actions mapped:
  - [ ] `move_left` → Left Arrow + A
  - [ ] `move_right` → Right Arrow + D
  - [ ] `jump` → Space + Up Arrow + W
  - [ ] `duck` → Down Arrow + S
  - [ ] `restart` → R
- [ ] Import preset `pixel_art_standard` defined (saved to `.godot/imported/` or as project-wide default texture filter)
- [ ] Directory tree created (even if empty):
  - [ ] `src/scenes/` (for .tscn files)
  - [ ] `src/scripts/` (for .gd files)
  - [ ] `src/autoloads/` (for singleton scripts; populated in Story 007)
  - [ ] `assets/art/` + subdirectories per art-bible §8C
  - [ ] `assets/audio/music/`, `assets/audio/sfx/`
- [ ] Main scene `src/scenes/main.tscn` exists as empty Node2D — opens in editor without errors
- [ ] Pressing F5 runs the empty scene at 1280×720 window showing default_clear_color
- [ ] `default_clear_color` set to near-black Shilin night tone (`#1A0A00`)

## Implementation Notes

- Copy + clean from `prototypes/night-market-runner/project.godot` — physics constants are NOT in project.godot; they live in player.gd.
- Input map: Godot 4.6 stores this in `project.godot` under `[input]`. Use the editor (Project → Project Settings → Input Map) to avoid hand-writing serialized `InputEventKey` blobs.
- Do NOT import from `prototypes/` — production is a fresh implementation per skill contract.
- Verify `stretch/scale_mode = integer` in Project Settings → Display → Window → Stretch (flagged knowledge gap in art-bible §8H — confirm it exists with that exact name in 4.6; if UI shows `Scale Mode` dropdown, that's it).

## Out of Scope

- Player scene / script → Story 002
- Game state autoload → Story 007
- Actual level content → Story 009
- HUD → Story 008

## Test Evidence (Config/Data)

- [ ] Smoke check: launch editor, open project, press F5, verify 1280×720 window opens with `#1A0A00` background, no console errors.
- [ ] Record in `production/qa/smoke-2026-04-XX.md`.
