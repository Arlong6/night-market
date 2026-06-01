# Game Concept: Lexicon Village（字典村莊）

*Created: 2026-05-27*
*Revised: 2026-05-28 (post first-pass design review — 5 blocking items resolved)*
*Status: Draft (revised)*
*Replaces: none — parallel concept to `game-concept-rpg.md` (Night Market, currently shipping at v0.53)*

---

## Elevator Pitch

> It's a **language-decipherment discovery game** where you arrive in a village
> whose inhabitants speak a constructed language you cannot read. By talking
> to NPCs, watching their actions, and noting recurring symbols, you piece
> together their language one word at a time — until you can understand the
> elder's final question. No combat, no failure state, no timer. A single
> 45–60 minute sit-down experience.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Language-decipherment puzzle / Discovery adventure |
| **Platform** | Web (HTML5 via Godot 4.6) |
| **Target Audience** | Players of *Chants of Sennaar*, *Heaven's Vault*, *Return of the Obra Dinn* — adults who like single-sitting brain-tickling puzzle-narratives |
| **Player Count** | Single-player |
| **Session Length** | 45–60 minutes (designed as one-sitting completion) |
| **Monetization** | None (itch.io / web free release) |
| **Estimated Scope** | Medium (6–8 weekends part-time solo; **re-baselined 2026-05-29** from prior 2–4 weekend estimate after review found scope arithmetic failed — language design alone consumes 2–4 weekends per the doc's own Risks section) |
| **Comparable Titles** | *Chants of Sennaar* (closest), *Tunic* (symbol decoding), *Heaven's Vault* (translation pacing) |

---

## Core Fantasy

You step off the road into a village where every conversation is a wall of
unfamiliar glyphs. The first NPC speaks and you understand nothing. Then you
notice the baker holds bread when she says `krunta`. The blacksmith hands a
customer iron when she says `krunta`. By the time the third NPC says it, you
have already guessed — and the moment you confirm in your notebook, **the
word `krunta` shimmers and resolves into your language across every sign,
shop banner, and previous conversation you have ever seen**. The world
slightly tilts toward legibility. Then you find the next word.

The fantasy is **the small private fireworks of comprehension** — that
moment of "oh, *that's* what they meant" — repeated 20 times in a single
sitting until the village stops being foreign.

---

## Unique Hook

It's like *Chants of Sennaar*, **AND ALSO**:
- **Single-sitting scale** (45–60 min, not 8 hours), designed for one
  complete playthrough — an evening, not a content marathon. **This is the
  primary hook.** A finishable game you can recommend to a friend.
- **A single climactic comprehension** — the elder's final question is
  composed entirely of words you have learned. Reading it (and naming the
  kind of departure you want via a binary choice) is the win condition.
  There is no other puzzle gate.
- **Procedurally seeded language for puzzle-replay** — each new run
  generates a fresh phonetic surface from a deterministic seed. Vignette
  content and semantic slots are stable across runs; only the cipher shape
  changes. **Honest framing** (revised 2026-05-29): primary replay
  audience is language-puzzle veterans and speed-runners who want to crack
  a fresh cipher faster than last time. Casual players will play once, and
  that one playthrough IS the complete intended experience. Replay is
  explicitly "Sudoku with new numbers," not "first-contact discovery."

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Discovery** | **1** (primary) | Every word resolved is a private "aha"; the whole game IS discovery |
| **Challenge** | 2 | Decipherment requires hypothesis + verification; brain-load is the difficulty |
| **Sensation** | 3 | Shimmer animation on word-resolution; the visual "fireworks" of comprehension |
| **Submission** | 4 | Calm, low-stress, ambient; can pause indefinitely between decipherments |
| **Narrative** | 5 | The village has internal life implied by NPC actions, but no plot arc |
| Fantasy | N/A | Player is themselves; no role-play |
| Fellowship | N/A | Single-player only |
| Expression | N/A | No creative output from player |

### Key Dynamics (Emergent player behaviors)

- Players will **revisit NPCs after learning new words** to re-read previous dialogue with fresh eyes.
- Players will **physically write notes** (paper, or a real text editor) alongside the in-game notebook — and that's a feature, not a bug.
- Players will **form hypotheses in batches**, holding 3–4 guesses in their head before committing them to the notebook.
- Players will **share screenshots of their cracked dictionary** with friends ("look how much I figured out!").

### Core Mechanics (Systems we build)

1. **Symbol-to-meaning binding**: Players assign a "meaning icon" to a glyph in their notebook. Free assignment, no penalty for being wrong. Meaning icons are culture-neutral pictograms (not English words); abstract words (conjunctions, particles) are deduced via context triangulation rather than direct iconography.
2. **Vignette confirmation with progress indicator**: Each NPC has a self-contained scene that exposes 3–5 new words. In the notebook's per-vignette page:
   - **Slot visuals**: Each word-slot displays either the meaning-icon the player has placed (a "guess"), or a "?" placeholder if no guess is placed. The two states are visually distinct.
   - **Counter**: A per-vignette counter (e.g., "3/5 待解") shows the total still-unsolved count — slots that are unguessed PLUS slots with placed guesses that are not yet correct. The counter does NOT reveal which specific guesses are wrong.
   - **Visibility**: Counter is shown only on the per-vignette page within the notebook — not on the HUD, not in the main game view. NPC interactions remain free of "find N things" framing.
   - **Update timing**: Counter updates live on each swap. A counter drop on a swap reveals that the swap improved a slot's correctness; players who notice this can binary-search their hypotheses. **Sudoku-style elimination is accepted as a valid play style** — the design recognizes it as a legitimate path to comprehension. (Trade-off: Pillar 1 "Discovery above Mastery" is partially softened at the swap-and-check loop; Pillar 3 "No Failure" takes precedence in this micro-context.)
   - **Cascade trigger**: When ALL words in a vignette are correctly bound, the game cascade-shimmers them across the world (see Shimmer Specification).
   
   This combination resolves the original "4-of-5 silence" failure mode (placed-slots are visible at a glance) while preserving the no-per-word-feedback discipline (counter reveals distance, not which guess is wrong). UX spec locked 2026-05-29; supersedes the prior one-line description.
3. **Phonetic-only procedural language**: A deterministic seed produces a phonetically consistent surface form (syllable rules, root-affix patterns, word-order grammar). **Semantic slots are hand-authored per vignette** — `NOUN_BREAD` always denotes bread; only the glyph-sequence carrying that meaning changes per seed. Re-seed swaps the cipher shape, not the world content. This commits to phonetic-surface procedural and rejects semantic procedural (which would break authored vignettes).
4. **Final-question with binary departure choice**: The elder asks one composed question (see `design/gdd/lexicon-village-elder-question.md` for the keystone artifact). The player sees the question in foreign script, with **2 candidate answers** below — each composed of meaning-icons drawn from the player's confirmed vocabulary. Both answers are emotionally valid: one expresses return/continuity (e.g. `tola-an` "I will give [my return]"), the other expresses departure/distance (e.g. `naima` "[I will go] far"). The player picks one. **Neither answer is "wrong"** — each triggers a different closing scene (warm vs wistful). Comprehension lives in reading the question, not in choosing among decoys. The "no failure" pillar holds; the player owns the meaning of their leaving. (Revised 2026-05-29 from prior 3–4-candidate multiple-choice spec, which game-designer review flagged as brute-forceable.)
5. **Notebook UI with click-or-drag input**: **Click-to-select / click-to-place is the PRIMARY input mode** (always-on, MVP scope, locked). Drag-to-bind is an **enhancement** layered on top after **SPIKE 2** verifies Godot 4.6 `_get_drag_data` / `_drop_data` works reliably on Chrome AND Firefox in Web HTML5 export — if Firefox is unreliable, drag is cut and click is sole path. Touch always uses click-mode (no touch-drag). Keyboard alone can complete the game (full a11y; per `design/gdd/input-system.md` Section C and AC-5). No keyboard typing required, no Fitts's-law-failing tiny drag targets. (Revised 2026-05-29 from prior "drag-primary, click-fallback" spec after Input System GDD authoring revealed Web HTML5 cross-browser unreliability — see `design/gdd/input-system.md` OQ-4 + reconciliation note in Section C.)

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Player visits NPCs in any order, hypothesizes in any order, no railroad | **Core** |
| **Competence** | Dictionary growth from 0 → 25+ words IS the competence signal. Shimmer is the visible reward | **Core** |
| **Relatedness** | Low — this is a quiet, internal game. Optional: share final-dictionary screenshot socially | **Minimal** |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** (PRIMARY) — Discovery of language structure is the entire game
- [x] **Achievers** (SECONDARY) — Completing the dictionary is a clear goal
- [ ] Socializers — Single-player only
- [ ] Killers/Competitors — No competition; speed-runs are an emergent meta only

### Flow State Design

- **Onboarding curve**: First 5 minutes — player meets one NPC who points at a clear object while speaking (e.g., points at bread while saying `krunta`). Player guesses, opens notebook, confirms. First shimmer happens within 5 minutes.
- **Difficulty scaling**: Early NPCs use simple, concrete vocabulary (nouns + actions). Later NPCs use abstract or conjunction words that require triangulation.
- **Feedback clarity**: Three-state signal — (1) per-vignette progress counter in the notebook ("3/5 待解") tells the player roughly *where* they stand without revealing *which* guess is wrong, (2) cascade-shimmer is the binary win signal when a vignette is fully bound, (3) no per-word right/wrong feedback ever fires. Players know if they are close; they do not know which specific guess is the blocker. Discovery preserved, silence eliminated.
- **Recovery from failure**: There is no failure. The game has no fail state, no penalty, no timer. Wrong guesses can be revised freely in the notebook.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Approach an NPC → trigger their dialogue → see a line in foreign script →
hover/select a glyph → in the notebook, drag a meaning icon onto the glyph
(or remove an existing guess). Close notebook, advance dialogue.

### Short-Term (5 minutes) — "Vignette"
Complete one NPC's full interaction: their introduction line(s), their
action (visible animation or context cue), their closing line. Form
hypotheses for the 3–5 new words exposed. When all of the vignette's words
are correctly bound in the notebook, the game **cascade-shimmers** those
words across every sign, banner, and remembered dialogue in the world.

**Post-vignette revisit behavior (locked 2026-05-29)**: After the cascade
for a given NPC, that NPC's interaction switches to a single comprehensible
**idle line** composed entirely of words from their just-decoded vignette
(plus any earlier-decoded words). Example: post-cascade, the baker says
`Tola mura ka?` ("Give bread?") on revisit — invitational, not new
information, never a quest hook. The line is the same every revisit; the
NPC is still herself, still doing her one thing, but her one thing is now
legible to the player. This pattern applies to **all 7 NPCs**; each
authored idle line is ≤4 tokens using only vocabulary already in scope.

This behavior is **NOT a violation** of anti-pillar #2 — the NPC has not
noticed the player or changed in response to player progress. The line
existed before the cascade; the player simply could not read it. The
shimmer changed the player's eyes, not the village's behavior. (See
narrative-director re-review 2026-05-28 finding #2 resolution.)

### Session-Level (45–60 minutes — the entire game)
Visit all 5–7 NPCs scattered around the village. Accumulate ~20–25 words.
Return to the village elder. The elder asks a single question composed
entirely of words from the player's learned vocabulary (see
`design/gdd/lexicon-village-elder-question.md`). Below the question, **2
candidate answers** appear, each composed of meaning-icons from the
player's confirmed dictionary. The player reads the question, picks the
answer that names the kind of departure they want. **Both answers trigger
a closing scene** — one warm (return / yes), one wistful (depart / no);
neither is "correct." End scene shows full dictionary and time taken.

### Long-Term Progression
**Within one playthrough**: vocabulary grows from 0 to ~25 words. That's
the entire arc.

**Across playthroughs**: each new run uses a different language seed → all
glyph-sequences and word-forms are re-randomized at the phonetic surface
*only*. Semantics, vignette content, and NPC actions are unchanged. The
baker still holds bread; only her word for it differs. Replay is
explicitly cipher-cracking with a fresh shape, not new content. Trade-off
acknowledged: second runs are recognition-with-re-decode (Sudoku with new
numbers), not first-contact discovery. Primary audience: speed-runners
and language-puzzle veterans. Casual players will play once.

### Retention Hooks
- **Curiosity**: The elder's final question is teased early — players see
  the elder waiting in the village center from minute 1. They cannot read
  the question, but they can see it exists.
- **Investment**: Mid-game, the player has 8–10 words. They are not
  abandoning the playthrough — they want their dictionary to grow.
- **Mastery (across runs)**: Speed-runners and language-puzzle veterans
  will replay to crack a new seed faster.
- **NOT social, NOT progression-based** — this is a sit-down experience,
  not a daily-engagement game.

---

## Game Pillars

### Pillar 1: Discovery Above Mastery

The core pleasure is "oh, *that's* what it means" — not "I have mastered
this skill." Every design decision should optimize for the first-time
surprise of comprehension, not for the long-term skill curve.

*Design test*: When choosing between "add another puzzle gate" vs. "add a
language Easter egg that rewards careful re-reading" → choose the Easter
egg. We are not building a skill ladder; we are building an aha factory.

### Pillar 2: Language IS the World

90% of design effort goes into linguistic consistency (phoneme rules,
root-affix systems, grammar). 10% goes into art and audio. The constructed
language is the content; everything else is a frame.

*Design test*: When choosing between "draw a new NPC sprite variant" vs.
"design three morphological variants of a root word" → choose the
morphology. The visual world can stay minimal; the language cannot.

### Pillar 3: No Failure, Only Re-reading

The game has no fail state. Wrong guesses do not penalize, regress, or
gate. Errors are an invitation to re-read context, not a punishment. The
emotional tone is calm and forgiving, never frustrating.

*Design test*: When choosing between "wrong guess locks the word for 30
seconds" vs. "wrong guess does nothing and the player can re-edit freely"
→ choose nothing-happens. The game must reward patience, not punish haste.

### Pillar Priority — When They Conflict (added 2026-05-29)

Pillar 1 (Discovery above Mastery) and Pillar 3 (No Failure, Only Re-reading) can pull against each other at specific moments. Locked priority for those moments:

- **Counter swap-and-check loop** (notebook page) → **Pillar 3 wins.** Players who notice the counter "leak" the correctness of their swap can binary-search through hypotheses (place all 5 guesses, swap one, observe counter, deduce). This is accepted as a valid play style — Sudoku-style elimination over pure discovery. See Core Mechanic #2.
- **Elder's final question** (climax) → **Both held** via binary choice with no "correct" answer. Pillar 1 lives in reading the question itself; Pillar 3 lives in both answers being valid endings. No brute-force is possible because nothing is being brute-forced. See Core Mechanic #4 and `design/gdd/lexicon-village-elder-question.md`.
- **Everywhere else** → **Pillar 1 wins.** No design choice between the two should silently default to Pillar 3 outside the two contexts above without surfacing in this GDD.

### Anti-Pillars (What This Game Is NOT)

- **NOT a typing or word game**: The player never types a word in the
  constructed language. All decipherment is point-and-click meaning
  assignment. Touch-friendly future is preserved.
- **NOT plot- or branching-driven**: NPCs have no dialogue trees, no
  romance options, no quest chains, no state changes responding to player
  progress. Character is *implied through vignette tableau* (the baker
  holding bread implies warmth) but never stated or extended. The emotional
  contract is "a quiet world that does not change," not "characters who
  acknowledge you." Players will project personality onto NPCs anyway —
  the design accepts this as a feature, but does not honor it with arcs.
- **NOT a time-pressured game**: No day/night cycle, no expiring
  conversations, no game-over timer, no resource scarcity. Pure calm.

---

## Visual Identity Anchor

> *Note: Solo review mode — visual direction set inline, not via art-director
> gate. May be revised when `/art-bible` is run.*

**Selected direction**: **Sun-Bleached Pages**

**One-line visual rule**: *Everything in the world looks old, dry, and
slightly faded — except the words you have just understood, which glow with
fresh ink.*

**Supporting principles**:
1. **Muted parchment palette baseline** — earthy ochres, faded ink black,
   sun-yellow highlights. No saturated primaries except in the shimmer.
   - *Design test*: Avoid neon, avoid Saturday-morning-cartoon contrast.
2. **Glyphs as typography, not pictographs** — the constructed language
   uses abstract symbols that read as "alien script," not cute icons. A
   custom monospaced symbol font is the primary art asset.
   - *Design test*: Glyphs must be recognizable at 8×8 pixels.
3. **Shimmer is the only motion** — the world is otherwise static. NPCs
   stand in place. Wind doesn't blow. The single dynamic visual is the
   cascade-shimmer when a word is unlocked: a wave of legibility sweeping
   across all instances of that word.
   - *Design test*: Every motion the engine renders must justify itself
     against this rule. If it's not shimmer, ask why it exists.

**Color philosophy**: The world is faded and quiet. Comprehension is
luminous. The visual reward of decipherment is the contrast between the
two.

---

## Shimmer Specification

The cascade-shimmer is the central feel moment of the game and the single
biggest delivery vector for the core fantasy. Specified here as a
first-class system, not deferred to implementation.

### Visual Behavior — Ripple Propagation

When a vignette is fully bound and confirmed, the shimmer **ripples outward
from the triggering NPC's spatial position across the village** over
approximately **1.5 seconds**. Words in that vignette that are visible on
screen (on signs, banners, recent dialogue) light from gibberish into the
player's language as the wave reaches their screen position — closer
instances resolve first, farther instances later. This "I can see it
spreading" visualization is the chosen tone (selected over quiet glow and
dramatic burst alternatives).

| Property | Value | Notes |
| ---- | ---- | ---- |
| Total duration | 1.5 s | Long enough to feel like a sweep, short enough to keep momentum |
| Easing | Ease-out from origin | Wavefront slows as it expands |
| Color transition | Faded parchment → fresh ink with brief overshoot to warm sun-yellow | Overshoot is the "fireworks" moment |
| Per-glyph dwell | ~0.4 s | Glyph spends this time mid-transition before settling |
| Max concurrent ripples | 1 | Additional confirmations queue behind a brief delay to preserve spatial clarity |

### Audio Behavior

A single soft chime tone follows the ripple's wavefront. Spatially panned
left-to-right or per the ripple's screen origin. Total ~1.2 s. No layered
hits, no percussion. Repeated shimmers use the same sample (no escalation
or fatigue masking by audio variety). The audio is supportive, not
load-bearing — the game must remain meaningful if audio is muted.

### Single-Word Resolve vs. Cascade

- **Cascade shimmer** (vignette confirmation): all words in the just-confirmed vignette ripple simultaneously, each from its own source instance. This is the celebratory moment.
- **Retroactive resolve** (a confirmed word appears in a NEW scene after the cascade): the word fades in already-legible with a *quiet glow-in fade* (~0.3 s), no ripple, no audio. It's a gentle reminder that comprehension persists, not a re-celebration.

### Performance Bounds

- Live shimmer animation runs only on **visible** text instances. Off-screen instances are marked dirty and resolve to their final state without animation.
- Freed dialogue history nodes (e.g., dialogue panels closed before the shimmer) are NOT re-instantiated to animate. When the player re-opens the history, they see the resolved form already-applied.
- Maximum simultaneous animated glyphs: budgeted at 80 (the doc's prior risk note of "30–50 simultaneous" is acknowledged; 80 is the hard cap before queuing).

### Why This Spec Exists

Without specifying ripple direction, duration, propagation rule, and
concurrency cap, the shimmer becomes either visually overwhelming (30+
simultaneous flashes on a busy screen) or invisible (one glyph dissolve
that nobody notices). Both kill the core fantasy. The ripple tone choice
is the design commitment that makes the shimmer scalable from 1 word to
many without losing legibility.

### Acceptance Test

When the baker vignette is confirmed in MVP playtest, three testers must
each independently describe the shimmer using words like "sweep," "wave,"
"spreading," or "rippling" — NOT "flash," "pop," or "blink." If the
language testers use suggests dramatic burst, the implementation has drifted
from intent and must be retuned before further vignettes are built.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| *Chants of Sennaar* | Symbol → meaning binding, soft-confirmation shimmer | Single-sitting scope; procedural language seed for re-play | Proves the core mechanic is fun and shippable |
| *Heaven's Vault* | Translation as continuous play, ambient pacing | No story branches; pure mechanic focus | Validates calm pacing for puzzle-narrative |
| *Return of the Obra Dinn* | Notebook-as-interface, hypothesis tracking | No murder mystery; only language | Validates the "private investigator" UI feel |
| *Tunic* | Hidden meaning under a foreign script | Decoding is the goal, not an optional layer | Validates that players will engage with deciphering as primary play |

**Non-game inspirations**:
- *Arrival* (2016 film) — the emotional weight of first contact, the
  experience of meaning emerging from noise
- The Voynich Manuscript — the aesthetic of a real-world undeciphered text
- Linguist field diaries (e.g., from documentation of endangered languages)
  — the patient, evidence-based hypothesis style

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 25–45 |
| **Gaming experience** | Mid-core; comfortable with puzzles, not necessarily action games |
| **Time availability** | One uninterrupted 45–60 minute evening session |
| **Platform preference** | Desktop browser (laptop in bed, coffee shop) |
| **Current games they play** | *Chants of Sennaar*, *Outer Wilds*, *Tunic*, *Her Story* |
| **What they're looking for** | A short, complete, satisfying puzzle-narrative they can finish in one sitting and recommend to a friend |
| **What would turn them away** | Long onboarding tutorials; in-game purchases; needing to install something; required text input in a foreign script |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 (matches existing project; GDScript continues) |
| **Key Technical Challenges** | (1) Cascade-shimmer architecture on Web HTML5 — RichTextEffect BBCode is the leading candidate; spike required before art bible. (2) Custom 8×8 px bitmap glyph font with `antialiasing = NONE` on font AND theme. (3) Phonetic procedural language generator with a "phonetic distinctiveness" quality filter for output words. (4) Drag-and-drop on Web HTML5 has cross-browser timing differences (Chrome vs Firefox) — needs click-fallback. (5) Audio-gesture guard for shimmer SFX (same pattern as existing project's CJK-font workaround). |
| **Art Style** | 16-bit pixel art, muted parchment palette, ColorRect placeholder first |
| **Art Pipeline Complexity** | Low — the world is static. The only meaningful art assets are NPC sprites (~7), background tiles, and the glyph font |
| **Audio Needs** | Minimal — 1 ambient music track, 1 shimmer SFX, 1 dialogue blip. No voice acting |
| **Networking** | None |
| **Content Volume** | 1 village, 5–7 NPCs, ~25 unique vocabulary words per playthrough (procedurally re-rolled), 1 final question |
| **Procedural Systems** | Constructed language generator (seed-driven). Same input seed → same language. This is the core procedural asset |

---

## Risks and Open Questions

### Design Risks
- **Difficulty calibration is unproven**: The line between "satisfyingly hard"
  and "dead-stuck and frustrated" is narrow. Playtest will be critical.
- **Players may not engage with the notebook**: If the notebook UI feels like
  homework, the whole game collapses. The notebook is the game.
- **Procedural language quality may vary**: A bad seed could produce a
  language that's too easy (transparent cognates) or too hard (no
  morphological hints). Need a quality filter on seeds.

### Technical Risks
- **Glyph font design is a real art task**, not a coding task — needs an
  hour with a font editor (e.g., Aseprite + custom export) before the
  language even has visual form.
- **Cascade-shimmer across all rendered instances** requires every UI text
  node to support partial-word replacement and animated transitions.
  Architecturally non-trivial in Godot's default Label.

### Market Risks
- **Genre is owned by *Chants of Sennaar*** — comparisons are inevitable.
  Our differentiator (single-sitting + procedural) must be loud enough to
  matter.
- **Niche audience** — language puzzle fans are passionate but small.
  Treat this as a portfolio piece / itch.io free release, not a commercial
  project.

### Scope Risks
- **Language design is invisible work — 3–5 days, not 1–2 days.** Pillar 2
  says 90% of effort goes into linguistic consistency; the original estimate
  contradicted that. Phoneme inventory, root-affix morphology, basic grammar
  for the elder's final question, and ~25 seeded words all need to be
  designed before they can be implemented. This is hard to estimate and
  hard to demo mid-flight. Locked at 3–5 focused days for the MVP language
  layer; could expand to 1–2 weeks for Full Vision quality bar.
- **One bad NPC vignette breaks the whole game** — if any one NPC's scene
  is unclear, players hit a wall. QA must include "fresh-eyes" playtest of
  every vignette.
- **Shimmer architecture decision is upstream of everything else** — the
  RichTextEffect BBCode path, per-glyph Control nodes, and shader-uniform
  approach each have different layout and accessibility implications.
  Must be resolved with a Godot 4.6 Web HTML5 spike before art bible work
  begins (see Next Steps).

### Open Questions

| Question | How we plan to answer |
| ---- | ---- |
| ~~Does the per-vignette progress counter ("3/5 待解") feel revealing-enough without spoiling?~~ **RESOLVED 2026-05-29** — counter UX locked in Mechanic #2 (live update, notebook-only, distinct slot visuals, sudoku-elimination accepted). Playtest will validate the swap-and-check loop's feel, not the counter design itself. | — |
| Does the elder's final question deliver narrative weight at 25-word vocabulary? | **RESOLVED 2026-05-29** — see `design/gdd/lexicon-village-elder-question.md` keystone artifact. Question selected: "Will you come back to this place?" (`Ne sun-wo nai-an ka?`). Playtest will validate emotional payload. |
| What's the right number of words to learn per vignette? | Prototype the baker vignette with 3 words, then 5; pick what feels best |
| How transparent should the language be? Real-language cognates yes/no? | Design two seed types (opaque vs. cognate-friendly) and playtest both |
| ~~Does the elder's multiple-choice answer screen feel revelatory or quiz-y?~~ **RESOLVED 2026-05-29** — answer mechanic locked as binary 2-option (both emotionally valid, no "correct"). Playtest will validate whether the binary choice feels like ownership of meaning vs simplistic — but the quiz-vs-revelation framing is dissolved by removing decoy candidates entirely. | — |
| Does the ripple shimmer scale at 5+ simultaneous instances on a busy screen? | Build a stress test scene with 30 word-instances; trigger the cascade; verify performance and visual clarity on a Web export, not just in-editor |

---

## MVP Definition

**Core hypothesis**: Players will experience genuine "aha" moments from
deciphering a constructed language using only NPC dialogue and visual
context — and one such moment is satisfying enough that they want the
next one.

**Required for MVP**:
1. **One full vignette** (the baker, or equivalent first NPC) that exposes
   3 words via spoken line + visible action context.
2. **Notebook UI** — symbols on the left, meaning icons on the right,
   drag-to-bind interaction WITH click-to-select / click-to-place fallback.
3. **Per-vignette progress counter** displayed in the notebook (e.g., "3/3
   待解" → "0/3 待解" as words confirm). This is the feedback layer that
   resolves the "4-of-5 silence" risk; it must ship in MVP.
4. **Cascade-shimmer effect** — when all 3 vignette words are correctly
   bound, ripple sweeps outward from baker across the visible scene over
   ~1.5 s. (Single-instance shimmer in MVP is acceptable; full cross-village
   propagation deferred to Vertical Slice once art exists.)
5. **One hand-authored mini-language** for MVP (procedural generator
   deferred to Vertical Slice).
6. **Web HTML5 build** that loads in a browser without errors.

**Explicitly NOT in MVP**:
- Procedural language generator (hard-code one language first)
- Multiple NPCs (one is enough to test the loop)
- Final elder question (no need for a climax in MVP; build it in Vertical Slice once mid-game words exist)
- Custom glyph font (use placeholder Latin-letter substitution cipher first)
- Music or SFX (silence is acceptable for MVP; audio-gesture guard added at Vertical Slice)

### Scope Tiers (re-baselined 2026-05-29)

> Prior tier estimate (4 weekends total Full Vision) failed scope arithmetic — the doc's own Scope Risks subsection names 2–4 weekends for language design alone. Honest re-baseline accepts Full Vision at **6–8 weekends part-time solo**, with a potential **+3 weekend contingency** if all three web spikes require fallback architecture.

| Tier | Content | Features | Timeline (cumulative) |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 NPC (baker), 3 words, hand-authored language, Latin-substitution glyphs | Core notebook + cascade-shimmer loop only | **1 weekend** |
| **Vertical Slice** | 3 NPCs, ~10 words, custom 8×8 glyph font, hand-authored language | Core loop + basic UI polish + shimmer animation refined + binary-choice answer scaffold | **+2 weekends (cumulative: 3)** |
| **Full Vision** | 5–7 NPCs, ~25 words, **procedural language generator**, elder's final question end-to-end, music + ambient | Full game + replay value via language re-seed | **+3–4 weekends (cumulative: 6–7)** |
| **Spike contingency** | Add architectural fallback work if any of SPIKE 1 (shimmer), SPIKE 2 (drag), SPIKE 3 (font) fails on Web HTML5 | Per-spike fallback architecture | **+1 weekend per failed spike (worst case: +3)** |

**User-acknowledged trade-off (2026-05-29)**: chose to keep procedural language generator in Full Vision rather than cut it for time. Accepts that Full Vision is now a 6–8 weekend commitment, comparable in size to a small standalone project — not the "weekend project" framing of the prior estimate.

---

## Next Steps

**Step ordering matters — technical spikes precede design decomposition. The
shimmer architecture is upstream of the art bible, and the art bible is
upstream of system decomposition.**

- [x] Concept doc written and revised (this document)
- [x] First-pass design review complete (Verdict: NEEDS REVISION → resolved 2026-05-28)
- [ ] **SPIKE 1 — shimmer-on-Web** (`prototypes/shimmer-spike/`): 40-line `RichTextEffect` BBCode test in a Godot 4.6 Web HTML5 export. Verify per-character animated color/alpha works on Chrome AND Firefox. Decide between RichTextEffect, per-glyph Control nodes, or shader-uniform path. **This locks the shimmer architecture before anything else.**
- [ ] **SPIKE 2 — drag-and-drop on Web** (`prototypes/drag-spike/`): 20-line Control with `_get_drag_data` and `_drop_data`, exported to Web, tested on Chrome and Firefox. If drag breaks cross-browser, click-fallback is the primary input in MVP.
- [ ] **SPIKE 3 — 8×8 bitmap font on Web** (`prototypes/font-spike/`): import one bitmap font with `antialiasing = NONE` on font AND theme, render at 8 px on Web. Verify legibility without subpixel blur.
- [ ] Record shimmer architecture decision as an ADR via `/architecture-decision shimmer-rendering`
- [ ] Run `/art-bible` — language glyph design lives here. Cannot start before SPIKE 3 confirms glyph rendering pipeline.
- [ ] Run `/map-systems` to decompose into individual systems (notebook UI, dialogue system, language generator, vignette state machine, shimmer animation). Cannot start before art bible + shimmer ADR.
- [ ] Author per-system GDDs with `/design-system` in dependency order
- [ ] Run `/create-architecture` for the remaining cross-system decisions (after spikes have resolved the high-risk ones)
- [ ] `/prototype baker-vignette` — full vignette using locked architecture. Validates "is the aha moment fun?"
- [ ] If prototype validates, `/sprint-plan new`
