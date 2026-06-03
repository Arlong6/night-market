# itch.io Page Draft — Two Games Collection

> **Status**: Draft for user review before upload
> **Page title (English)**: Night Market & Lexicon Village — Two Small Games
> **Page title (中文)**: 夜市採購 + 字典村莊 — 兩款小遊戲合輯
> **Slug suggestion**: `nm-lex` or `night-market-lexicon`
> **Tags**: `narrative`, `puzzle`, `2d`, `pixel-art`, `slice-of-life`, `procedural-generation`, `chinese`, `taiwan`, `language-learning`, `cozy`

---

## Short tagline (Display under title)

**EN**: Two small games in one cartridge: a Taiwan night market errand sim, and a village where the language is invented every time you play.

**中**: 一個卡帶兩款遊戲：台灣夜市跑腿散步、和每次玩語言都不同的字典村莊。

---

## Description (Page body, ~200 字 EN + 中)

### English

Two small, deliberately quiet games packed into one browser cartridge.

**🌃 Night Market** — Walk through a Taiwanese night market at dusk. Mom gave you a shopping list. Stalls haggle, rain comes and goes, a stray cat might follow you home. 5-10 minutes per run. Replay for new requests, weather, and lottery luck.

**📜 Lexicon Village** — Walk into a village where you don't speak the language. Seven villagers each act out three foreign words. Drag meaning-icons onto the words you've decoded. When you get it right, the words shimmer outward across the screen and the world becomes legible. The elder waits at the center with one question — can you read it? 30-60 minutes. Every run regenerates a new language; share your seed-code so a friend can play yours.

Both games run in-browser. No download. Touch-friendly on mobile (some UI not yet optimized for small screens).

**Built solo with Godot 4.6 + the [Claude Code Game Studios](https://github.com/anthropics/claude-code) agent framework.**

### 中文

兩個刻意做得安靜的小遊戲，包在同一個瀏覽器卡帶裡。

**🌃 夜市採購** — 黃昏走進台灣夜市。媽媽給你一張食材清單。攤販會討價、雨會下會停、流浪貓可能跟你回家。每次 5-10 分鐘。重玩會遇到新的清單、新的天氣、新的抽獎運氣。

**📜 字典村莊** — 走進一個你不認識的語言的村莊。七個村民各演三個陌生字。把意義圖示拖到你猜對的字上。猜對整段對話的時候，文字會從那個村民身上一波波擴散到全村莊，世界突然變得可讀。村莊中央的長老等你回答一個問題 — 你能不能讀懂？每次 30-60 分鐘。每次玩語言都不同，可以把 share-code 給朋友玩同一套語言。

兩款都在瀏覽器即玩。免下載。手機觸控可玩（部分 UI 尚未為小螢幕優化）。

**Godot 4.6 + Claude Code Game Studios agent framework solo 製作。**

---

## Screenshots needed (L-003 placeholder list)

Before upload, capture these:

### Night Market (4-5 frames)
1. **Hero**: 夜市攤位 in 黃昏 with lanterns just starting to glow (yellow-orange palette)
2. Mom giving the shopping list (close-up of dialogue)
3. Discount haggling mini-game in action (the moving bar)
4. Rainy night with umbrellas + puddle splash
5. The cat following the player home (final scene)

### Lexicon Village (4-5 frames)
1. **Hero**: Village wide shot with all 7 NPCs visible + dialogue box showing foreign glyphs (mura, tola, ven)
2. Notebook open mid-puzzle (3 icons being arranged)
3. **Mid-cascade**: caught during shimmer wave spreading across screen (this is THE money shot)
4. Resolved dialogue showing Chinese text (麵包 給 暖)
5. Elder asking the final question

### Gallery cover image (630×500)
Both games' hero scenes side-by-side, with title text overlay. Stylized in pixel-art frame.

---

## itch.io page settings

| Setting | Value |
|---|---|
| Pricing | **Free** (initial release) — option to add tips |
| Platforms | Web (HTML5) |
| Genre | Puzzle / Adventure |
| Tags | (see top of doc) |
| Languages | Chinese (Traditional), English |
| Content rating | General audiences |
| Embed dimensions | 1024 × 600 (preserve aspect for both games) |
| Fullscreen button | YES |
| Mobile-friendly | YES (with caveat note in description) |

## Devlog post #1 (L-011, ship after release)

Title suggestion: "雙作品上架 — 從一個 prototype 走到兩個遊戲"

Outline:
- Why two games? (Originally one — NM. Then experimented with Lexicon Village concept during pre-production, it stuck)
- The cascade shimmer "spread vs flash" design problem (SPIKE 1 story)
- Procedural language generation: every player gets their own language (with share-codes)
- Open source agent framework powered this — link to Claude Code Game Studios template

---

## Upload checklist (user actions, L-007 gate)

- [ ] Build fresh from clean clone: `godot --headless --export-release "Web" "dist/index.html"`
- [ ] Verify total gzipped size < 20 MB
- [ ] Zip the `dist/` directory (or upload as files via itch.io's "uploads" panel)
- [ ] Set "This file will be played in the browser" on the HTML upload
- [ ] Upload screenshots (≥ 4 per game)
- [ ] Upload cover image (630×500)
- [ ] Paste description (use either EN or 中 + the other in the body)
- [ ] Set tags, pricing, content rating per table above
- [ ] **Save as draft first**; test in your own browser via the itch.io preview URL
- [ ] Walk both games end-to-end in the preview iframe
- [ ] Publish

After publish:
- [ ] Update README.md (L-004) with the live itch.io URL
- [ ] Git tag v1.0 (L-007)
- [ ] Push tag (user, manual)
- [ ] Post devlog #1 (L-011)
