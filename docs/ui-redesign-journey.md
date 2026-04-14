# PixelPal — A UI Redesign That Started With "What Are We Quietly Lying About?"

> A field report on rebuilding the PixelPal panel UI in one focused session. Written for the next person reading this repo — recruiter, collaborator, future me.

## TL;DR

PixelPal's pitch is **"the only AI agent companion that cares about you, not just your code."** When I sat down to add a new feature (push notifications), I opened the panel and noticed the UI was quietly contradicting that pitch in seven places. This document is the journey from that observation to a 10-commit refactor that brought the visual product back into alignment with what we say it is.

The interesting part is not which buttons moved. The interesting part is the diagnostic frame: **every UI element is either reinforcing or diluting the product thesis. Audit them as a system, not as components.**

---

## Where this started

I was about to push a feature commit (`Phase 2.5: remote push via ntfy`). Before pushing publicly I did a real-machine pass through the app — clicked the menu bar, opened the panel, fired a test bubble, walked through the Companion Log.

What I expected: a quick sanity check, then ship.

What I actually saw: a panel that read like a control surface for an AI dev tool, not a companion that cares about a person. I kept noticing small things — emoji where pixel art should be, an "Uninstall" button as visually loud as "Quit," a button asking me to "report" my breaks. None of these were bugs. The code was correct. The product worked. But the UI was telling the user a different story than the pitch was.

I paused the push and ran an audit.

---

## The diagnostic frame

The question I asked of every single UI element was:

> **Is this reinforcing "cares about you" or quietly contradicting it?**

This is a deceptively simple test. It cuts through the usual "what's the best button color / where should this go" debates because it forces every choice back to the product thesis. A button isn't *just* a button — its prominence is a signal about what the product values.

Run that test against PixelPal's panel and a pattern emerges fast: the UI was full of patterns that subtly said the **opposite** of what the pitch claimed.

---

## The seven contradictions

### 1. "Uninstall" was a first-class footer button

Sat next to "Quit" with equal visual weight. Quit is an everyday action. Uninstall is rare and destructive. Equal weight violated Nielsen heuristic #5 (error prevention) and — more importantly — sent a quiet signal: **"the way out is one click away."** A product that claims to care about you doesn't put "leave me" at eye level.

### 2. "I took a break" — a button asking the user to clock out with their companion

PRD explicitly states PixelPal must "never become the thing it promised not to be." Forest, Finch, and every successful parasocial-attachment app *infer* user state. They never ask the user to report. This button quietly turned the companion relationship into a check-in dynamic.

### 3. State labels were engineering rawValues

The header showed `"idle"`, `"working"`, `"nudge"`, `"comfort"` — straight enum cases. A user spending weeks with Spike doesn't think "Spike is in nudge state." They think "Spike is looking out for me." The app was leaking its own internal language into the place where the relationship should live.

### 4. Header said "PixelPal," not "Spike"

The most prominent text in the panel was the brand name. But the user's emotional anchor — what they spend weeks bonding with — is the character. Compare: Apple Music shows the song, not "Music." Wallet shows the card, not "Wallet." PixelPal showed the brand and demoted the character.

### 5. Companion Log used Apple emoji instead of pixel sprites

A user unlocks Ramble after two weeks of work. They open the Companion Log. They see... 🦉 — the same Apple owl emoji every other macOS app uses. The product's whole identity is custom pixel characters; using emoji as the placeholder was a gift-unwrapping downgrade.

### 6. `▓▓` as the undiscovered-character placeholder

Two block characters. Not mysterious, not beautiful, not a hint. The PRD specifies silhouettes — actual character-shaped shadows — and the implementation had drifted to ASCII filler.

### 7. Speech bubble had an `x` button

Every time a bubble appeared, the user had to *decide* whether to dismiss it. Bubbles already auto-fade in 5 seconds. The `x` made an ambient passing-by feel into a transactional dismissal. iOS notifications removed their `x` for the same reason: notifications should "pass through" your attention, not demand a verdict.

Plus six smaller information-architecture issues — Work Dashboard locked into one tab, New Session button buried below session list, footer 4 rows tall, redundant state indicators, etc.

---

## Approach: layer the work, not the polish

The temptation with 13 findings is to sit down and refactor everything at once. That makes a single huge unreviewable diff and loses the ability to recover the rationale later. I split into three layers, ordered by **how far each was from the product thesis**:

- **P0 — eliminate the loudest contradictions** (Uninstall prominence, "I took a break," brand-first header, dismiss button)
- **P1 — restructure information so it stops fighting the architecture** (state labels, dashboard placement, sprites, glow rings)
- **P2 — visual polish that earns its place** (per-character accent, typography, ambient footer)

Each layer became 1-3 atomic commits, each with a `Why:` explanation in the commit message, each leaving the test suite green. This means anyone reviewing the history can see exactly which thinking drove which change — and revert any single decision without unwinding the rest.

The total: **10 UI commits across 6 phases** (P0 / P1a / P1b / P1c / P2a / P2b / + a 4-commit follow-up round C7-C10 for catches discovered during real-machine validation).

---

## What changed (mapped to commits)

| Phase | Commit | The contradiction it removed |
|-------|--------|------------------------------|
| P0 | `ba51da4` | Brand-first header, Uninstall prominence, reporting button, bubble dismiss button — collapsed into a character-first header + a gear menu for low-frequency settings |
| P1a | `acbe34b` | Engineering state labels — replaced with 9 × 5 = 45 character-voiced labels ("Spike: You've got this!!" instead of "working") |
| P1b | `eaccf4d` | Work Dashboard locked into Sessions tab — promoted to global; New Session button moved from bottom to top (Fitts's law for the highest-frequency action) |
| P1c | `b8f9b47` | Emoji and `▓▓` placeholder — replaced with real pixel sprites for discovered characters and proper silhouettes (alpha-mask preserved) for undiscovered ones; glow ring replaces "Use" link / checkmark dual-state |
| P2a | `0f18050` | All accent colors were system-blue — each of the 9 characters got a tuned hex (Spike warm orange, Dash cool teal, Blunt deep blue, etc.); whole panel `.tint()`s to whoever is active |
| P2b | `375ca88` | Panel had no character voice in the static UI — added an italic-serif ambient footer ("— Spike") that lingers with the last spoken line |

After the first six commits I rebuilt and walked through the product as a real user. That found four more contradictions — emoji *still* in the bubble, animated character in the corner but a static one in the panel header, "Bonded" still leaking engineering-speak into the relationship label, one orphan font size:

| Round | Commit | What was caught only by real-machine testing |
|-------|--------|---------------------------------------------|
| C7 | `c7d5d01` | Bubble was still rendering an emoji as the identity icon (immediate inconsistency with P1c). Companion row had a redundant `· Simple` style tag. |
| C8 | `f028992` | Header avatar was a static frame while the same character on the floating window was animated — split-personality. New `AnimatedAvatarView` drives the same frame-rate table as the floater. |
| C9 | `866a892` | Stage labels (`newborn`/`familiar`/`bonded`) were engineering names. 9 × 6 = 54 character-voiced versions ("Spike: Best friend," "Blunt: Interest: high," "Dragon: …trusted"). |
| C10 | `5c76abc` | One orphan 13pt font (bubble text) — rest of the product is on 10/11/12/14. Work Dashboard given a soft card treatment so it reads as a status region, not a row between dividers. |

---

## Tradeoffs I made consciously

Three places I chose **not** to do the obvious-looking fix, with reasoning:

**Companion Log sprites stay static.** The header avatar animates. I considered making all 9 companion rows animate too. Decided against it: opening the log would fill the panel with nine simultaneously twitching sprites — the catalogue would feel like a crowd. The header is the one always-visible avatar; that's where breath belongs. Documented this trade as a known asymmetry.

**Bubble avatar stays static.** Same logic, different reason: bubble life is 5 seconds. Animating it costs frames for almost no user-noticed value. *I would revisit this if the bubble pattern changes — it's a small change to wire up.*

**Did not unify all font sizes to a strict 3-tier scale.** Wrote it into the P2b plan, then on inspection found the existing distribution (10 / 11 / 12 / 14) was already coherent once one orphan 13pt was removed. Over-polishing a working hierarchy is churn. **Knowing when not to refactor is half the discipline.**

---

## What this redesign does NOT do (honesty section)

The most important thing this report can do is be straight about its own limits.

This refactor is a **brand consistency upgrade**, not a **product capability upgrade**. PixelPal's `ReminderEngine` still uses the same three-layer reminder logic. `SpeechEngine` still triggers on the same context conditions. `DiscoveryManager` unlocks characters on the same journey signals. The companion isn't smarter than it was before this session.

What changed: every UI surface now stops contradicting the pitch. The product **looks like** what it claims to be. That's worth something — pitch dilution at the UI layer is real and measurable in user trust — but it's not the same as making PixelPal more capable.

The next layer of work, deliberately not done in this session, is **making the existing intelligence visible**. SpeechEngine's `WorkContext`-driven judgment is invisible to the user; they just see "Spike said something." A user who could see *why* Spike spoke right now ("noticed: 90 minutes straight, no break, 3 errors in last 10 minutes") would feel the moat — would feel the difference between PixelPal and a generic talking pixel pet. That work is queued but not in this PR.

---

## Lessons I'm taking forward

Five things I'd tell myself before the next UI redesign:

1. **The diagnostic question matters more than the fixes.** "Is this reinforcing or diluting the pitch?" is reusable across any product I work on. Most UI bugs are pitch-dilution bugs in disguise.

2. **Real-machine testing finds 30%+ of issues that code review misses.** Of the 13 contradictions, 4 of them I only saw after I built the app and clicked through it as a user. The C7-C10 round wouldn't exist if I'd shipped after the first six commits.

3. **Engineering-speak in user-facing strings is the most common pitch leak.** rawValues, enum case names, internal taxonomies (`Simple` / `Expressive` / `Complex` / `Enigmatic`) — every one of these had quietly leaked into UI strings over time. They needed an active hunt to find. Future audit checklist item: grep for `.rawValue` and any internal taxonomy string in any `Text(...)` view.

4. **Decompose by *signal proximity to thesis*, not by component.** Doing P0 (loudest contradictions) before P1 (information architecture) before P2 (polish) means even if I'd shipped after one phase, the product would already be more aligned. Each layer increased thesis fidelity. If I'd refactored by component (header / footer / sprites) the in-between commits wouldn't have been shippable.

5. **Document the no-fixes too.** Listing what I considered but chose not to do is more valuable for future-me (and for hiring readers) than listing what I did. The shipped diff shows the work; the rejected fixes show the judgment.

---

## What this means for PixelPal's positioning

PixelPal is being built as a job-hunt portfolio piece in addition to being a real product. The refactor sharpens both stories:

- **Product story**: a companion app that takes its own pitch seriously enough to remove a button that contradicted it, and to write 99 character-voiced strings instead of leaving 5 raw enums. The competitive landscape (Conductor, Vibe Island, Jean) optimizes what the agent does. PixelPal optimizes what happens to the human. The UI now shows that.

- **PM portfolio story**: this is a worked example of **product taste applied as engineering rigor**. 14 commits, each with rationale. A diagnostic frame that is reusable. Conscious tradeoffs documented. Honesty about what the work doesn't do. The intent is for a hiring reviewer to read this doc, look at the commit history, and conclude: *this person can ship, and they can think about what they're shipping.*

---

## Appendix: full commit ledger for this session

```
5c76abc UI C10: typography pass + dashboard card treatment
866a892 UI C9: character-voiced evolution stage labels
f028992 UI C8: animated header avatar — character breathes in panel too
c7d5d01 UI C7: bubble shows character sprite; companion row drops style tag
375ca88 UI P2b: ambient character voice footer
0f18050 UI P2a: per-character accent color — panel tints to active companion
b8f9b47 UI P1c: companion sprites with silhouettes, glow ring replaces Use/✓
eaccf4d UI P1b: global work dashboard + New Session promoted
acbe34b UI P1a: character-voiced state labels in header
ba51da4 UI P0: character-first header + settings menu + remove reporting UI
988ce2e Phase 2.5: remote push via ntfy — always-with-you companion
c7e6279 Security: remove Sparkle feed URL + align README closed-source claims
4073920 Rewrite README for Phase 2 + portfolio narrative
d762024 Phase 2: intelligence layer — library split, providers, evolution, speech engine
```

**Test coverage**: 95 tests across 14 suites. Every commit ran the suite green before landing.

**Build target**: macOS 14+, Universal Binary (Apple Silicon + Intel), Swift 5.9.

---

*Written 2026-04-14. Repo: [vince-ni/PixelPal](https://github.com/vince-ni/PixelPal). Author: [Vince Ni](https://github.com/vince-ni).*
