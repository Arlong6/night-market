# Active Session State

> **Last Updated**: 2026-06-26 (session: portfolio analysis → Night Market ship-prep + word-suika juice/title)
> **Purpose**: Living checkpoint. Read this first after compaction or new session.

## Direction (user, 2026-06-26)

"夜市完成 其他繼續做" — **finish Night Market (priority), keep advancing the others.**

## Three games in flight

- **Night Market (夜市採購大作戰)** — now the BOOT game, ~ship-ready. Was 88%; this session did the ship-prep pass.
- **word-suika / 一字一句** — Suika merge (雨→露→川→江→海→雲→月→詩). Juiced + has a title screen now.
- **Lexicon Village (字典村莊)** — shelved; core loop triple-broken (notebook BAKER-lock, glyph mismatch from hard-coded seed 12345, green/red feedback deletes deduction). Renders correctly now via runtime stretch override in lv_main.gd. NEXT CYCLE: fix the 3 core blockers before content.

## What shipped this session (commits)

| Commit | Delivery |
|---|---|
| d823040 | lexicon WIP preserved (web-reliable click + SFX + CJK theme) |
| c5f9cf7 | word-suika merge prototype committed |
| 82f7cbe | word-suika juice: procedural audio (pitch rises ladder), high-score, goal ladder, onboarding (21/21 smoke) |
| e554ab7 | **v0.59 Night Market = boot game + ship-prep**: main_scene flip + config/name; stretch back to viewport/integer (Lexicon overrides at runtime); bargain audio; first-stall nudge; economy balance |
| f709a2f | word-suika title/start screen (one-tap = Web audio-unlock) |
| 7674918 | uid housekeeping |

Foundation verified on Godot 4.6.2 (`~/Downloads/godot-4.6.2/Godot.app`): **553 tests green** (496 unit + 57 integration); NM title + word-suika title boot clean headless.

## Night Market — remaining to ship (mostly USER-dependent)

1. **PLAYTEST the economy balance** — I tuned free money down (guaranteed 40→25/run, lottery from money-pump to real gamble) by ANALYSIS, not playtest. Knobs marked `[BALANCE: needs playtest]` in shilin_market.gd, lottery_booth.gd. Confirm the squeeze feels right; tell me to adjust.
2. **Web build** — src/ shipped a web build at v0.53 but has no committed export_presets.cfg now; needs export templates (4.6.2) + an HTML5 preset.
3. **Screenshots/GIF** — bargain meter mid-swing, green-zone hit, plated dishes, cat following home → fill `production/release/itch-page-draft.md` + cover.
4. **itch upload** — user account.

## word-suika — next

- Web export config (export_presets.cfg + HTML5 preset); GUT setup for real tests; daily-seed challenge mode.
- Open question: theme is currently cosmetic — a real word-building mechanic raises the ceiling but is a redesign.

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates auto-skipped.

## How to run (interactive — audio/feel need a real run)

```
GODOT=~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot
"$GODOT" --path src           # Night Market (boots title)
"$GODOT" --path word-suika    # 一字一句 (boots title)
```
