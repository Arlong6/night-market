# Lexicon Village — Elder's Final Question (Keystone Artifact)

> **Status**: Draft v0.1 — 2026-05-29
> **Purpose**: CD-mandated keystone artifact (from re-review 2026-05-28). "Until this exists, every other decision is speculation."
> **Authoring scope**: One chosen final question + worked decipherment path + mini-lexicon. Does NOT supersede `game-concept-lexicon-village.md`; this is the artifact the GDD's open Finding 4 (narrative-director) and Finding 6 (game-designer) demanded.
> **Process**: This draft uses concrete phonetic strings (e.g. `mura`, `nai`) for clarity. The lexicon language is procedurally regenerated per seed (see GDD Mechanic #3); **only the SEMANTIC slots in §3 are load-bearing**. Word strings shown here are placeholder for one specific seed.

---

## 1. The Chosen Question

**Lexicon form**:

> **`Ne sun-wo nai-an ka?`**

**Gloss**: [you] [home/place-TOPIC] [come-FUTURE] [QUESTION]

**Natural translation (中)**: 「你會回到這個地方嗎？」
**Natural translation (EN)**: "Will you come back to this place?"

**Spoken context**: The elder waits at the village center from minute one (visible from the moment the player arrives). She speaks no other dialogue. When the player walks to her after completing all NPC vignettes, she looks up, pauses, and asks this one line. The player has spent 45–60 minutes learning the village; the village asks the smallest, gentlest goodbye.

---

## 2. Why This Question (Design Rationale)

Anchored to the GDD's three pillars and the design-review findings that demanded this artifact:

### Pillar alignment
- **Pillar 1 (Discovery above Mastery)** — Every word in the question is taught by ≥1 NPC vignette. The "aha" of reading it is the cumulative aha of all decipherment, condensed. No mastery curve; pure recognition.
- **Pillar 2 (Language IS the World)** — The question's emotional weight comes from the language working, not from art or audio. If the player can read it, the game has succeeded; if not, no other layer rescues it.
- **Pillar 3 (No Failure, Only Re-reading)** — Yes/no semantic core means both answers are valid emotionally. There is no "correct" answer in the human sense; the correctness lives in reading the question, not in choosing the response.

### Anti-pillar #2 reconciliation (narrative-director's blocker)
The question does NOT imply the village has noticed or changed for the player. The elder is asking what she would ask **any** outsider who passed through. The village is unchanged; the player is the one who is changing (by leaving). This preserves "the quiet world that does not change" while still delivering emotional weight.

### Climax mechanic resolution (game-designer's blocker on multiple-choice)
With a yes/no semantic core, both the multiple-choice mechanic (currently in GDD) AND the free-composition alternative work:
- **Multiple-choice (current)**: 2 answers — `tola-an` ("I will give [my return]" = yes) / `naima` ("[I will go] far" = no). 2 candidates = 50% random guess, BUT the question's emotional satisfaction is in reading it, not in choosing — so brute-force completion still requires comprehension to feel meaningful.
- **Free-composition (alternative)**: Player composes their answer from learned vocab (e.g., `Ne, nai-an` = "Yes, I will come" or `Naima` = "I go far"). More expressive, more risk.
- **Recommended interpretation**: keep multiple-choice but with only **2** candidates (not 3–4), one of which is `tola-an` ("yes/will give") and one of which is `naima` ("far/no"). Player is not eliminating decoys; player is reading the question and naming their relationship to the village.

### Voynich/Arrival reference reconciliation
- **Voynich**: the manuscript is "the text we cannot read." This game's elder question is "the text you CAN read, after 45 minutes." The arc is from Voynich-state (opening: all glyphs opaque) to Arrival-state (closing: one comprehensible question). The Voynich reference is honored as the **starting condition**, not the ending state.
- **Arrival**: the trajectory from incomprehension to comprehension IS the emotional payload. This question's "Will you come back?" delivers that trajectory in micro: every word in the question is a memory of a vignette earned. The player reads "Will you come back?" and the answer is partly "yes" because they have been somewhere worth returning to.

### Cultural neutrality (narrative-director's open concern)
A small village asking a departing guest "Will you come back?" is a near-universal human exchange — Taiwanese, Polynesian, Andean, Old-English-pastoral all do this. The question does not lock the village to any specific real culture, but it grounds the world in real human social texture. The narrative-director's "cultural neutrality risks sterility" warning is partially answered: the WORDS may be culturally neutral, but the SOCIAL ACT is universal.

---

## 3. The Mini-Lexicon (25 Semantic Slots)

> **Critical**: The phonetic strings below (`mura`, `nai`, etc.) are a SINGLE SEED's output, used here for concrete illustration. The procedural language generator (deferred to Full Vision) will produce different strings per seed. **The semantic slots, vignette assignments, and grammar particles are stable across all seeds — they are the load-bearing design.**

### Phoneme inventory (illustrative seed)
- **Consonants** (11): `p, t, k, m, n, s, l, r, v, d, g`
- **Vowels** (5): `a, e, i, o, u`
- **Syllable rule**: CV or CVC (no clusters)
- **Stress**: penultimate

= 16 unique glyphs. Within systems-designer's recommended cap of 17–20 for 8×8 px legibility.

### Content words (21) — assigned to NPC vignettes

| # | Slot ID | Seed string | Meaning | Vignette / NPC |
|---|---|---|---|---|
| 1 | NOUN_BREAD | `mura` | bread / staple food | Baker |
| 2 | VERB_GIVE | `tola` | give / offer | Baker |
| 3 | ADJ_WARM | `ven` | warm | Baker |
| 4 | NOUN_IRON | `krun` | iron / metal | Blacksmith |
| 5 | NOUN_HAMMER | `dakka` | hammer | Blacksmith |
| 6 | VERB_MAKE | `pora` | make / craft | Blacksmith |
| 7 | NOUN_WATER | `sela` | water / sea | Fisher |
| 8 | NOUN_FISH | `mira` | fish | Fisher |
| 9 | VERB_COME | `nai` | come / arrive | Fisher |
| 10 | NOUN_CLOTH | `talo` | cloth / thread | Weaver |
| 11 | VERB_WEAVE | `kove` | weave / bind | Weaver |
| 12 | ADJ_LONG | `lim` | long / enduring | Weaver |
| 13 | ADJ_SMALL | `du` | small / child | Child |
| 14 | VERB_PLAY | `ela` | play / run | Child |
| 15 | NOUN_FRIEND | `vu` | friend / companion | Child |
| 16 | NOUN_PATH | `solar` | road / path | Traveler |
| 17 | ADJ_FAR | `naima` | far / distant | Traveler |
| 18 | NOUN_STRANGER | `gel` | stranger / outsider | Traveler |
| 19 | VERB_REMEMBER | `taro` | remember / hold-in-mind | Storyteller |
| 20 | NOUN_PLACE | `sun` | place / home / here | Storyteller |
| 21 | PREFIX_PAST | `me-` | past-tense prefix | Storyteller |

### Grammar particles (4) — taught via cross-vignette context

| # | Slot ID | Seed string | Function | Where exposed |
|---|---|---|---|---|
| 22 | PRO_YOU | `ne` | 2nd person subject pronoun | NPCs addressing player ("`ne` ___?") — every NPC |
| 23 | PART_Q | `ka` | sentence-final question particle | Stall-NPC offers (`buy mura ka?`) — Baker, Blacksmith, Fisher |
| 24 | SUFFIX_FUT | `-an` | future-tense suffix on verbs | Traveler ("I will walk far" = `solar-an naima`) |
| 25 | PART_TOP | `-wo` | topic marker (optional in casual speech) | Multiple NPCs; player triangulates from frequency |

**Total: 25 semantic units** — matches GDD's "~20-25 words" target.

---

## 4. NPC Vignette Tableaux (Brief)

Each NPC has a 5-minute self-contained scene exposing 3 content words + 0–1 grammar particles. Detailed staging deferred to `/map-systems` and per-vignette GDDs; below is the essential tableau.

### 4.1 Baker — "Warm bread is given"
- Holds bread, places it on counter, says `mura`
- Hands bread to a customer NPC (silent), customer eats, says `tola mura`
- Touches warm bread, hand recoils slightly, says `ven`
- **Exposes**: `mura`, `tola`, `ven`
- **Grammar hint**: customer says `tola mura` showing VERB-NOUN order — early grammar clue

### 4.2 Blacksmith — "Iron is hammered into making"
- Holds iron bar, says `krun`
- Strikes with hammer, says `dakka pora` repeatedly (hammer-makes)
- Hands finished horseshoe to traveler NPC, says `pora-me krun` (past-prefix demo)
- **Exposes**: `krun`, `dakka`, `pora`
- **Grammar hint**: `pora-me` (made) shows past-prefix; first exposure to `me-`

### 4.3 Fisher — "Fish come from water"
- Standing by water with net, says `sela`
- Pulls net, fish flopping, says `mira`
- Says `mira nai sela` (fish come [from] water)
- **Exposes**: `sela`, `mira`, `nai`
- **Grammar hint**: subject-verb-object word order confirmed

### 4.4 Weaver — "Cloth is woven long"
- Hands working loom, says `kove`
- Pulls a long piece of finished cloth, holds it stretched, says `talo lim` (cloth long)
- Demonstrates binding action with cloth strip on a child's wrist, says `kove` again
- **Exposes**: `talo`, `kove`, `lim`

### 4.5 Child — "Small friend runs and plays"
- Two child NPCs visible. One child looks at the other and says `vu` (friend), then says `ela` and runs
- The two chase, laugh; child returns and says `du`, points at self
- Calls out `ne!` to player (you!) and waves — first clear exposure of `ne`
- **Exposes**: `du`, `ela`, `vu` + grammar `ne`

### 4.6 Traveler — "Far road, stranger walks"
- Sits at village edge with walking stick, says `gel` (gestures at self, "stranger")
- Points down the road into distance, says `solar naima` (path-far)
- Stands, looks at player, says `solar-an naima` (will-walk-far) — exposes `-an` future suffix
- **Exposes**: `solar`, `naima`, `gel` + grammar `-an`

### 4.7 Storyteller — "I remember this place from before"
- Sits with children gathered, gestures broadly at village, says `sun` (this place)
- Says `me-nai me-` (past-came, past-marker emphasized) — recounting arrival of someone
- Taps head, says `taro` (I remember)
- Closes story with `taro sun` (remember this place)
- **Exposes**: `taro`, `sun`, `me-` (past prefix as grammar)

---

## 5. Worked Decipherment Path — The Elder Question

Given a player who has completed all 7 vignettes, the elder's question becomes:

> `Ne sun-wo nai-an ka?`

### Step-by-step recognition

| Token | Player recognizes | Source vignette | Internal recall |
|---|---|---|---|
| `Ne` | "you" — addressing me | Child (calling out) + Stall offers | "Every NPC said `ne` when looking at me." |
| `sun` | "this place" / village | Storyteller | "The storyteller used `sun` while gesturing at the village." |
| `-wo` | topic marker (filler) | Cross-vignette frequency | "I've seen `-wo` after many subjects. Probably a marker. I can skip mentally." |
| `nai` | "come" | Fisher (fish come from water) | "Fish came. Now... me? Coming?" |
| `-an` | future marker | Traveler (will-walk-far) | "Same suffix as `solar-an`. Future." |
| `ka` | "?" question particle | Stall offers ("buy ___ ka?") | "End-of-line `ka` means it's a question." |

**Compiled meaning**: "You — this place — will-come — ?" → "Will you come back to this place?"

The player's "aha" is the moment of stitching: each individual word was learned in isolation, but the syntax has been silently absorbed through repeated exposure to NPC sentences. When the elder asks, every fragment is familiar; the SHAPE of the sentence (you-topic-verb-question) matches dozens of NPC sentences they've already parsed.

### Comprehension requirement

To "read" the question with confidence, the player needs:
- ≥4 of the 6 tokens decoded with certainty (`ne`, `sun`, `nai`, `ka` are minimum)
- Pattern-recognition on `-wo` and `-an` (can be unsure and still arrive at meaning)
- Result: a player who finished ~5 of 7 vignettes will likely comprehend; a player who finished all 7 definitely will

### Answer mechanic (binary multiple-choice; recommended)

Below the question, two answer cards appear:

| Card A | Card B |
|---|---|
| `Tola-an` | `Naima` |
| (will give / yes I will return) | (far / no I go far) |

- Each card uses words the player has confirmed (`tola` from Baker, `naima` from Traveler).
- No "wrong" answer triggers a failure state. Picking `tola-an` → warm goodbye scene; picking `naima` → wistful goodbye scene. Both are endings; neither is "the" ending.
- This honors Pillar 3 (no failure) while making the choice meaningful: the player has agency over what kind of departure this is.
- **Replay variant**: in subsequent runs (re-seeded), the question's surface changes but the choice remains binary.

---

## 6. What This Question UNLOCKS

This artifact resolves the following items from the 2026-05-28 design-review:

| Blocker (from review) | Resolution from this artifact |
|---|---|
| [game-designer #1] Multiple-choice climax allows brute-force | Binary (2-option) choice with both options emotionally valid; no decoy elimination; comprehension is in the question, not the answer |
| [game-designer #6] 20 words can't carry meaningful question | Concrete proof: 6 tokens + grammar = meaningful question, with 21 content slots reserve |
| [narrative-director #4] No sample elder question | This document |
| [narrative-director #7] No narrative thesis | Thesis: "the small kindness of being asked to return" |
| [systems-designer #3 partial] Phoneme inventory cap | 16 phonemes proposed, within 17–20 cap |
| [systems-designer #6] Vocabulary-to-vignette math loose | 7 vignettes × 3 content words + 4 grammar particles = exactly 25 slots, no shared-word ambiguity |
| [narrative-director #2 partial] Baker on revisit | Baker vignette spec gives 3 content words + grammar hint; revisit behavior still open (silent vs comprehensible idle line) |
| [narrative-director #6] Cultural neutrality risk | Question's social act ("come back?") is universal; neutralizes some sterility risk |

---

## 7. What This LEAVES Open

Honest accounting — this artifact alone does NOT resolve:

| Still-open blocker | Status |
|---|---|
| [game-designer #2] Per-vignette progress counter UX (display, timing, wording, swap-loop exploit) | Untouched. Still needs UX spec. |
| [game-designer #3] Replay marketing/reality gap in Unique Hook | Untouched. Still needs hook reframe. |
| [game-designer #4] Pillar 1 vs 3 conflict at climax | Partially addressed (binary y/n softens conflict); still needs explicit pillar-priority statement |
| [game-designer #5 / narrative-director #2 full] Baker revisit behavior | Recommended path: short comprehensible idle line using already-decoded words (e.g. baker says `tola mura ka?` on revisit — "give bread?" — invitational, not new info). Still needs design lock. |
| [systems-designer #7] 4-weekend Full Vision scope infeasible | Untouched. CD's 6–8 weekend re-baseline still standing. |
| [systems-designer #2] Shimmer behavior on screen-space UI (notebook, history) | Untouched. Still needs spec. |
| [ux-designer all 8 findings] | Untouched. Notebook UX is a separate workstream. |
| [godot-specialist #3] WebGL2 NEAREST filter on font import | Engineering detail, deferred to SPIKE 3 |

**Recommendation for next session**: choose ONE of:
- (a) Resolve the per-vignette progress counter UX (blocker most likely to undermine the climax we just designed)
- (b) Lock the multiple-choice vs free-composition decision in the main GDD (downstream of this question, now answerable)
- (c) Run SPIKE 1 (shimmer architecture on Web) since it's still upstream of art bible and downstream design

---

## 8. Re-seed Reference (Procedural Language Implication)

When the procedural language generator runs (Full Vision feature, deferred), it produces a new phonetic surface for each of the 25 semantic slots. The vignette tableaux DO NOT CHANGE — the baker still holds bread, the storyteller still gestures at the village. Only the words for "bread," "village," etc., are re-rolled.

The elder's question structure is also stable across seeds:
```
PRO_YOU + NOUN_PLACE + PART_TOP + VERB_COME + SUFFIX_FUT + PART_Q + ?
```
Only the surface form changes:

| Seed A | Seed B (hypothetical) | Seed C (hypothetical) |
|---|---|---|
| `Ne sun-wo nai-an ka?` | `Vi raga-lu pen-ar to?` | `Ka loni-vu kai-im sa?` |

This is a critical commitment: **the game's narrative thesis ("will you come back to this place?") is seed-invariant**. The PROCEDURAL element is the phonetic-decode puzzle. The AUTHORED element is the emotional payload.

---

## 9. Status / Next Steps

**This file's status**: Draft v0.1 — keystone artifact only. Does NOT replace `game-concept-lexicon-village.md`. Should be referenced (linked) from the GDD once 6 remaining blockers are also addressed.

**Recommended downstream actions**:
1. Update `game-concept-lexicon-village.md` Open Questions table to mark "elder's final question content" as RESOLVED, pointing here.
2. Update `design/gdd/reviews/game-concept-lexicon-village-review-log.md` to reflect: defer rejected by user; keystone artifact authored 2026-05-29; 5 of 8 review blockers now addressable; remaining work re-prioritized.
3. Decide ONE next-blocker to attack (recommendation in §7).
4. Eventually: this file's mini-lexicon + vignette tableaux feed into `/map-systems` for the Lexicon Village project (when prereqs for `/map-systems` are met).
