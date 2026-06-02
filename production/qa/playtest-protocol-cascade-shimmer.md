# Cascade Shimmer Playtest Protocol — AC-15 (L-013)

> **Sprint**: sprint-01 L-013
> **Target**: Lexicon Village #10 Cascade Shimmer — AC-15 spread-language test
> **Status**: USER-BLOCKED — requires 3 first-time testers
> **Test scope**: CENTRAL FEEL validation; failure here triggers knob retune (RIPPLE_DURATION / DWELL_DURATION)
> **Build**: v0.56+ Web (`dist/index.html`)

## What AC-15 actually says

> GIVEN baker vignette completes in MVP playtest with ≥3 first-time testers,
> WHEN each tester independently describes what they saw,
> THEN ≥3 of 3 testers use language in {sweep, wave, spreading, rippling, rolling, radiating};
> NONE use {flash, pop, blink, burst, explosion} as primary description.

This is the **make-or-break test** for the entire cascade shimmer system. If
the language reads as "burst", the wavefront has collapsed perceptually to
"pop" and the per-glyph spread math has failed its job. Knob retune is the
fix; ship-blocker if retune doesn't recover.

## Tester recruitment (user)

You need **3 people who have never played Lexicon Village before**. Ideally:
- 1 visual learner (e.g., designer, photographer)
- 1 verbal learner (e.g., writer, reader)
- 1 systems learner (e.g., programmer, gamer)

Each tester does the session **alone** (no peeking at other testers' words —
the test is independent description, not group consensus).

## Pre-test brief (what to tell the tester)

**Read this verbatim**:

> "I'm going to ask you to play a short puzzle game and then describe one
> specific moment to me afterward. The game has a moment where, after you
> solve the puzzle, the foreign words on screen change into your language.
> Pay attention to that moment. When it's over, I'm going to ask you to
> describe what you saw in your own words — there's no right answer, I'm
> just curious what it looked like to you."

**Do NOT**:
- Say "shimmer", "wave", "ripple", "spread", "cascade", or any of the target
  language. This contaminates the test.
- Say "flash", "pop", "burst", or any of the anti-language either. Just say
  "the moment when the words change."
- Hover near them — leave them alone to play. Be in the next room if
  practical.

## Test session (~10-15 minutes per tester)

1. **Setup**: open `dist/index.html` in Chrome (or Firefox). Confirm audio works
   (cascade shimmer chime is part of the moment). Volume to comfortable level.
2. **Pre-cascade play**: Title → Start → click baker → watch vignette → press N
   to open notebook → place 3 icons. Tester does this themselves.
3. **The moment**: when the third icon clicks into place, the cascade shimmer
   fires. **This is the moment to watch.**
4. **Post-cascade**: let them keep playing (click elder → ending). No need
   to interrupt.

## Interview (5 minutes)

**Open with**:

> "Tell me about the moment when the foreign words turned into Chinese.
> Just describe what it looked like."

**Listen for** (record verbatim):
- ✅ TARGET language: sweep, wave, spreading, rippling, rolling, radiating,
  flowing, washed over, traveled across, moved across, came outward,
  expanded, opened up
- ❌ ANTI language: flash, pop, blink, burst, explosion, splash, sparkle,
  bang, snap, click, twinkle

**Probe (only if their answer is ambiguous, e.g., "it changed")**:
> "How did it change? Was it all at once, or did it have a direction?"

Probe is okay because it asks about temporal/spatial structure without leading.

**Do NOT probe**:
- "Did it spread?" (leading)
- "Was it like a wave?" (leading)
- "Was it a flash?" (leading toward anti-language; would invalidate result)

## Results template

Create one entry per tester. Add to:
`production/qa/playtest-results/cascade-shimmer-YYYY-MM-DD-T<N>.md`

```markdown
# Cascade Shimmer Playtest — Tester N

> **Date**: YYYY-MM-DD
> **Tester profile**: visual learner / verbal learner / systems learner
> **Game version**: v0.56 Web build
> **Browser**: Chrome XXX / Firefox YYY

## Verbatim description (first 30 seconds, unprompted)

> "[paste exactly what they said]"

## Probe response (if asked)

> "[paste if applicable]"

## Classification

- Primary language category: TARGET ✅ / ANTI ❌ / AMBIGUOUS ⚠
- Words used from TARGET set: [list]
- Words used from ANTI set: [list]

## Notes

[Any other observations — were they surprised? Did the chime register?
Did the brevity (1.5s) feel too fast/right/slow?]
```

## Pass/fail decision

After all 3 testers:

- **PASS**: 3/3 used TARGET-set words and 0/3 used ANTI-set words as primary
  description. Ship as-is.
- **MIXED PASS**: 2/3 TARGET, 1/3 AMBIGUOUS. Document but consider shippable —
  AC-15 wording is strict (≥3/3); but a single ambiguous tester is usually
  vocabulary, not perception. Decide based on the ambiguous tester's probe response.
- **FAIL**: any tester uses ANTI-set words as primary description.

## Knob retune fallback (if FAIL)

The two load-bearing knobs are in `lv_cascade_shimmer.gd`:

```
const RIPPLE_DURATION: float = 1.2   # current
const DWELL_DURATION: float = 0.4    # current
```

If testers say "flash" or "pop":
1. **Lengthen RIPPLE_DURATION to 1.5s** — slows the wavefront, making
   spatial spread more readable.
2. **Shorten DWELL_DURATION to 0.3s** — reduces the "held bright" feeling
   that can collapse to "flash"; pushes wave toward "moving" feel.
3. **Both**: try 1.5s + 0.3s together.

After retune, **repeat the test with 3 new testers** (used testers are
contaminated). Do NOT retune more than twice — if the third try still fails,
escalate to fundamental redesign (Option C in cascade-shimmer.md OQ-1:
RichTextEffect Web path or shader path).

## Why knob retune (not implementation rewrite)

Per cascade-shimmer.md game-designer review: the **percept** of "wave vs flash"
is governed by the **dwell-to-attack ratio** and the **wavefront duration**.
The math (Formula 2 ease-out, per-glyph stagger) is correct as designed; if
the percept fails, the timing constants are tuned wrong, not the algorithm.

Per anti-pattern doc:
- ❌ DON'T collapse the 3 phases into one tween (that explicitly causes "pop")
- ❌ DON'T add particle systems / sparkles (that explicitly causes "celebration")
- ✅ DO tune RIPPLE_DURATION + DWELL_DURATION first

## Schedule

- **L-013 owner**: self (user)
- **Estimate**: 3 testers × 15-20 min each + 30 min analysis = ~2 hours
- **Block**: required before v1.0 release tag
- **Recovery budget**: if FAIL, +2h retune + +2h second-round 3-tester test
