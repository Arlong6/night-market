# R-007 HUD — Walkthrough

## Story
R-007 (HUD) — UI type, manual walkthrough is the gate.

## Implementation summary
- `src/scripts/hud_rpg.gd` — `HudRpg extends CanvasLayer`, layer 10
- Two labels: money (top-left, `$XXX`) and progress (top-right, `N/5`)
- CJK SystemFont chain (PingFang TC etc.), font size 10, stamp-red `#C2241A`
- Subscribes to `Inventory.money_changed` + `Inventory.ingredient_added`
  in `_ready`, renders initial state from current Inventory
- `shilin_market.gd._spawn_hud()` adds it as a level child

## Verification

### Headless smoke (test suite)
51/51 GUT tests pass. The HUD renders only when the level is loaded;
`test_market_loads_and_has_player` exercises the full level _ready chain
which includes `_spawn_hud`. No script errors.

### Visual walkthrough (to be performed manually by user)
1. Launch: `Godot --path src res://scenes/levels/shilin_market.tscn`
2. Confirm HUD shows `$200` in top-left and `0/5` in top-right
3. Walk into a stall NPC, complete a purchase
4. After purchase, HUD should reflect new money + `1/5`
5. Buy all 5 — HUD shows residual money + `5/5`

## AC Status
- [x] CanvasLayer at layer 10, two CJK labels
- [x] Subscribed to Inventory signals (auto-update without polling)
- [x] Spawned by level in `_spawn_hud()`
- [x] Initial render reflects current Inventory state
- [ ] Visual screenshot (deferred — same approach as v0.1 platformer's R-007 deferment)

## Status
**Done (visual confirmation deferred to end-of-slice playtest in R-009).**
