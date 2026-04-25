# Game Concept — 夜市採購大作戰 (Night Market Shopping)

> **Project status**: Active. Replaces the v0.1 platformer concept (preserved at git tag `v0.1-platformer`).
>
> **Scope**: Weekend slice. 1 area, 4–5 NPCs, no combat, no save/load.
>
> **Engine**: Godot 4.6 / GDScript (unchanged from platformer). Web HTML5 export target.

---

## 1. Overview

A top-down 2D grid-snap RPG in the visual idiom of Pokémon GBA. The player
controls **小杰**, a Taiwanese kid sent to **士林夜市 (Shilin Night Market)**
by his mother to buy ingredients for tonight's dinner. He starts with **NT$200**
and a list of **5 ingredients** to gather. The market is alive with vendors
(stall NPCs that sell ingredients) and customers (chatter NPCs that may drop
hints, jokes, or local colour). When he has all 5, he walks back to mum at
the home tile and triggers the win screen. No combat, no death state — only
exploration, dialogue, and a small shopping budget puzzle.

## 2. Player Fantasy

You are a kid trusted with a real grown-up errand. The market is loud, warm,
slightly overwhelming — strangers shout greetings, vendors hawk their goods,
the smell of fried rice cake hangs in the air (implied; no audio in this slice).
You wander, eavesdrop on conversations, talk to vendors, weigh prices against
your fixed wallet, and feel the small triumph of bringing the bag home full.
Pokémon Route 1 energy: nothing is dangerous, but everything is unfamiliar
and a little exciting.

## 3. Detailed Rules

### Movement
- **Grid**: 16×16 px cells. Viewport 320×180 → playable area is 20×11 cells.
- **Input**: `ui_up` / `ui_down` / `ui_left` / `ui_right`. One press = one cell.
- **Step duration**: 180 ms tween from current cell → target cell. While
  tweening, additional input is buffered (only the most recent direction is
  remembered).
- **Held input**: If the direction is still held when the tween completes,
  immediately start the next step in that direction. Pokémon GBA-style
  continuous walk.
- **Walkable check**: Before starting any step, query the level's walkable
  array. If the target cell is `false` or out-of-bounds, do **not** move
  (but still trigger the bump check — see NPC).
- **Turn-on-spot**: A direction press into a wall changes facing direction
  even though no movement occurs.

### NPCs
- **Bump-to-talk**: Stepping (or attempting to step) into an NPC's cell
  triggers their dialogue. NPC's cell is unwalkable.
- **Two NPC types**:
  - **Chatter**: speaks one or more lines, no shop interaction.
  - **Stall**: speaks intro line(s), then offers `買 [食材] NT$XX？` choice.
    Choice = `是 / 否`. `是` deducts money + adds ingredient. `否` ends.
- **Dialogue advance**: Press any input (jump/interact key — call it `interact`)
  to skip typewriter or advance to next line. While dialogue is open, movement
  input is locked.
- **Talked-once flag**: After a stall sells its item, future bump shows a
  "再來啊" type closing line; no further purchases.

### Inventory & money
- **Starting money**: NT$200 (data-driven; see Tuning Knobs).
- **Ingredient list (5 fixed for slice)**:
  - 蔥 (scallions) — NT$20
  - 蛋 (eggs) — NT$30
  - 高麗菜 (cabbage) — NT$40
  - 雞肉 (chicken) — NT$50
  - 醬油 (soy sauce) — NT$50
  - **Total NT$190**, leaving NT$10 buffer. No puzzle on first pass; future
    tuning can tighten the budget for a v0.2 challenge.
- **Cannot buy**: If money < price, the choice prompt shows the price greyed
  out; selecting `是` is a no-op with a "錢不夠..." line.

### Win / lose
- **Win**: Walk to the **mum NPC** at the home tile with all 5 ingredients
  → end scene with score breakdown (money left + time taken).
- **No lose state** in this slice. Player can wander indefinitely. If they
  reach mum without all 5, mum says "還沒買齊喔，再去看看" and the player
  resumes.

## 4. Formulas

| Quantity | Formula | Notes |
|---|---|---|
| Step duration | `STEP_DURATION = 0.18 s` | Per-cell tween time |
| Effective walk speed | `16 px / 0.18 s ≈ 89 px/s` | Comparable to Pokémon GBA |
| Money after purchase | `money_new = money_old - ingredient.price` | Fixed prices |
| Win condition | `inventory.size() == REQUIRED_INGREDIENTS.size() AND on_mum_cell` | |
| Money buffer | `STARTING_MONEY - sum(ingredient.price for all)` = `200 - 190` = NT$10 | |
| Typewriter rate | `CHARS_PER_SECOND = 30.0` | Skip-on-key shows full line |

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Player presses direction into wall / NPC | Turn-on-spot only; no movement; if NPC, open dialogue |
| Player presses opposite direction mid-tween | Buffer it; current tween completes; reverse step starts |
| Two direction keys held simultaneously | Use last-pressed (track via edge-detection like platformer) |
| Player walks into mum without all 5 ingredients | Mum says "還沒買齊"; no scene transition |
| Player buys same ingredient twice | Impossible — stall flips to "再來啊" after first sale |
| Player runs out of money before 5 ingredients | Stuck state acknowledged; mum's dialogue can hint to keep trying. v0.2 may add a "give-back" NPC |
| Window resized / DPI weird | Project stretch_mode = `viewport`, aspect `keep`, scale `integer` (same as platformer) |
| Dialogue triggered while another dialogue active | Ignored (re-entrancy guard via `Game.in_dialogue: bool`) |
| Player tries to move during dialogue | Input ignored at PlayerGrid level (checks `Game.in_dialogue`) |
| Tween finishes but key released same frame | Last step completes; no new step starts; player rests on cell |

## 6. Dependencies

### Internal systems (within this project)
- **`Game` autoload** — shared state: `current_area`, `in_dialogue`, `goto_level()`
- **`Inventory` autoload** — `money: int`, `ingredients: Dictionary[String, bool]`,
  `signal money_changed`, `signal ingredient_added`
- **`Dialogue` autoload** — `show(lines: Array[String], on_done: Callable)`
- **`GridWorld` utility** — `cell_to_px(cell: Vector2i) -> Vector2`, `px_to_cell(px: Vector2) -> Vector2i`,
  `in_bounds(cell, w, h) -> bool`
- **`PlayerGrid`** — depends on `Game`, `GridWorld`, walkable callback
- **`NPC` / `StallNPC` / `MomNPC`** — depend on `Dialogue`, `Inventory`
- **`DialogueBox`** — depends on `Game.in_dialogue`
- **`Hud`** — depends on `Inventory.money_changed`, `Inventory.ingredient_added`
- **`ShilinMarket` level** — orchestrates all of the above

### External dependencies
- Godot 4.6 stable (per `docs/engine-reference/godot/VERSION.md`)
- GUT 9.6 (test framework — vendored at `src/addons/gut/`)
- SystemFont with explicit CJK chain (PingFang TC / Heiti TC / Noto Sans CJK TC)
  — pattern proven in platformer's menus

### What this concept does **not** depend on
- TileMapLayer (deliberately avoided — see plan)
- CharacterBody2D (grid-snap means no physics body needed for player)
- AudioStreamPlayer (no audio this slice)
- Sprite2D (ColorRect placeholders only)
- AStarGrid2D / pathfinding (NPCs are static or trivial bob-only)

## 7. Tuning Knobs

| Knob | Default | Range | Notes |
|---|---|---|---|
| `STEP_DURATION` | 0.18 s | 0.10–0.30 | Slower = more deliberate; 0.18 tested as Pokémon-feeling |
| `STARTING_MONEY` | NT$200 | NT$100–NT$500 | Reduce for tighter budget puzzle |
| Ingredient prices | 20 / 30 / 40 / 50 / 50 | per item | Sum must be ≤ STARTING_MONEY for soft start |
| `CHARS_PER_SECOND` | 30.0 | 15–60 | Faster typewriter for impatient players |
| Tile size | 16 px | 8 / 16 / 32 | Locked to 16 (matches viewport math) |
| Number of stalls | 5 | 3–8 | One per ingredient |
| Number of chatter NPCs | 2–3 | 0–6 | World-flavour only, no required interaction |
| Map dimensions (cells) | 20 × 11 | 20×11–40×22 | Single-screen for slice; multi-screen needs camera follow |

## 8. Acceptance Criteria

A demo of this slice is **DONE** when all of the following are observably true:

- [ ] Title screen shows "夜市採購大作戰" and START button; pressing START enters Shilin market
- [ ] Player spawns on the `home` tile facing south (towards mum)
- [ ] Pressing any of 4 direction keys moves the player exactly 1 cell in that direction within 180 ms
- [ ] Holding a direction continues stepping at 180 ms/cell until the key is released or a wall/NPC is hit
- [ ] Bumping a wall produces no movement but does change facing direction
- [ ] Bumping any of the 5 stall NPCs opens a dialogue box with at least one intro line
- [ ] Stall NPC offers `買 [食材] NT$XX？ 是 / 否` after intro line
- [ ] Selecting `是` decrements `Inventory.money` by the price and adds the ingredient
- [ ] Selecting `否` closes the dialogue with no state change
- [ ] HUD always displays current money (top-left) and `N/5` ingredient progress (top-right)
- [ ] Walking into mum NPC with `Inventory.ingredients.size() == 5` triggers the win scene
- [ ] Walking into mum NPC with fewer than 5 shows the "還沒買齊" line and resumes play
- [ ] Win scene shows: "謝謝，今晚加菜！" + remaining money + total elapsed time
- [ ] Pressing any key on the win scene returns to the title screen
- [ ] Movement input is fully ignored while a dialogue is open (no walking through NPCs by spamming direction keys mid-dialogue)
- [ ] All R-002 (player), R-005 (inventory), R-008 (win condition) acceptance criteria are covered by ≥1 GUT unit test, and the suite passes headlessly
- [ ] HTML5 export builds and runs in a desktop browser without console errors
