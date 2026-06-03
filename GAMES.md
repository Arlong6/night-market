# Games Built with This Framework

> Two small games developed using the Claude Code Game Studios template.
> Both are playable in-browser, no download required.

---

## 🌃 夜市採購 (Night Market)

Walk through a Taiwanese night market at dusk. Mom gave you a shopping list.
Stalls haggle, rain comes and goes, a stray cat might follow you home.
5-10 minutes per run.

**Features**
- Mom's special weekly requests + umbrella vendor for rainy days
- Time-of-day system: dusk → night with lanterns
- Weather: predictable rainy days + occasional typhoons
- Street musician, fortune teller, lottery booth
- Cats you rescue follow you home as pets

**Controls**
- Mouse left-click: walk (grid movement)
- Click a stall to start haggling (drag the bar to land in the green zone)
- **N**: recipe notebook
- Complete mom's list → walk home → cook → score

---

## 📜 字典村莊 (Lexicon Village)

Walk into a village where you don't speak the language. Seven villagers each
act out three foreign words. Decode their meanings by watching what they do.
When you get a vignette right, the words shimmer outward and the world
becomes legible. 30-60 minutes.

**Features**
- 7 NPC vignettes (baker, smith, fisher, weaver, child, traveler, storyteller)
- Procedural language generator: every run regenerates the lexicon
- Share-codes: send your seed to a friend so they play your language
- Cascade shimmer: per-glyph wavefront on comprehension moments
- Elder asks one final question at the village center

**Controls**
- Mouse left-click NPCs to engage dialogue
- **N**: open the notebook
- Drag meaning-icons onto the foreign words to bind them
- Correct binding → cascade shimmer fires
- All NPCs done → click elder → ending

---

## How to play

🔗 **itch.io page**: (link to be added after L-007 release)

Or build from source:

```bash
git clone https://github.com/[your-username]/claude-code-game-studios
cd claude-code-game-studios/src
godot --headless --export-release "Web" "../dist/index.html"
# Then serve dist/ with any static server, e.g.:
cd ../dist && python3 -m http.server 8000
# Visit http://localhost:8000
```

Both games require **Godot 4.6** (engine + matching export templates).

---

## Tech notes

- **Engine**: Godot 4.6.2.stable
- **Language**: GDScript only
- **Total tests**: 535+ unit + integration (NM 326 + Lexicon ~210)
- **Web build size**: ~12.5 MB gzipped
- **Source code**: see `src/` (lexicon village in `src/lexicon/`, NM in `src/scripts/` and `src/scenes/`)

## Credits

- **Design / Programming / Pixel font / Audio**: solo dev with the
  [Claude Code Game Studios](README.md) framework
- **CJK font**: jf-openhuninn 2.1 (Justfont)
- **Engine**: [Godot Engine](https://godotengine.org)

## License

MIT — same as the framework. See [LICENSE](LICENSE).
