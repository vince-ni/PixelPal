# PixelPal — Design Principles

Seven invariants. Every commit is measured against them before merge. A change that violates any of them doesn't ship, however well it is written.

These are not "preferences we try to follow when we can." They are the product. Drop any one of them and PixelPal becomes the thing it refuses to be.

---

## 1. Ambient by default. Speech earns its moment.

**95% of the time, the character is silent.** Breathing in the corner. Sometimes looking around. Sometimes moving through an idle animation. Not speaking. Not notifying. Not trying to be noticed. A companion that trusts you to work is worth more than one that keeps asking if you're okay.

The 5% where the character does speak has to earn its way there. Every utterance passes through `SpeechEngine.canSpeak()`, which enforces:
- 30-second minimum between any two lines
- 2 dismissals in 5 minutes → silent for 1 hour
- In flow state, only deep-rest reminders break through
- At night, at most one late-night observation per hour

**The opposite this rules out.** Desktop companions that "check in" every 15 minutes. Productivity apps that celebrate every commit with a confetti burst. Anything that treats the user's attention as a free resource. If a feature makes the character say *more* things, it needs to show its work.

The 5-second auto-fade bubble with no X button is the visible shape of this principle. Bubbles pass through your attention the way a cat walking across a desk does — you notice, you carry on, you're not asked for a verdict.

---

## 2. Never punish absence.

**Take a week off. A month. A quarter. The character is exactly as you left it.** No "I missed you." No stage regression. No dimming. No guilt animation. No "come back and resume your streak."

Evolution in PixelPal is a pure function of *cumulative* days together, never elapsed time. If you spent 30 days with Spike over 6 months of sporadic use, Spike is `Bonded`. The gap doesn't cost you anything — neither does it grant anything; there is no "catch-up" either. Time is counted, not measured.

The opposite this rules out. Every productivity app that shows a broken-streak notification. Every Tamagotchi that dies. Every product that turns the user's continued use into an obligation and calls it engagement. These patterns are attention-extractive; they pretend to be features.

**This principle is the single most important one.** It's the reason the product can credibly tell users it cares about them. A product that punishes absence does not care about the user; it cares about retention. Choosing one means refusing the other.

---

## 3. Product voice is character voice.

**The character's name belongs where the product's name would go.** The header shows "Spike," not "PixelPal." The state subtitle reads "Watching you work," not "Working." The evolution stage reads "Best friend," not "Bonded."

This has a technical consequence that is easy to underestimate: every user-facing string must be written in the active character's voice. Nine characters × five states × six stages = 99 labels hand-authored, each phrased in-character. Spike says "YES!! Another one!!" on task complete. Blunt says "Result: success." Dragon says "…good." Each of them means the same thing. The character layer carries the semantic content; the state layer is a mechanism, invisible to the user.

**The opposite this rules out.** Engineering vocabulary leaking into UI. `.rawValue` in `Text(...)`. Internal taxonomy strings ("Simple," "Expressive," "Complex," "Enigmatic") shown to users who have no reason to care. Default "system blue" accents because configuring per-character color felt like extra work. Any time the product's voice shifts out of character, the pitch quietly dies.

Audit command for this principle: `rg '\.rawValue' Sources/PixelPal/` and `rg 'Text\(.*\.label\)' Sources/`. Both should return zero matches. If either returns a match, the principle has been violated somewhere.

---

## 4. Sprite, not emoji.

**If the product's visual identity is pixel characters, use pixel characters.** Everywhere. Companion Log, speech bubble, panel header, menu bar icon, notifications, silhouettes for undiscovered characters — all rendered from `SpriteSheet.avatar(...)` or `SpriteSheet.silhouette(...)` with nearest-neighbor scaling.

Apple emoji are excellent. They are also the thing every other macOS app uses. A user who spent two weeks unlocking Ramble and opens the log to see 🦉 — the same emoji that appears in Messages, Notes, Slack, and every other surface on the device — has been handed a generic version of what was supposed to be their character. Emoji in a PixelPal UI is a failure of craft.

**The opposite this rules out.** Emoji as fallback icon. Emoji as notification indicator. Emoji as "temporary placeholder until we get the art" (which always stays permanent). The few places where no sprite is available — running from source without `Assets/`, unsupported state — fall back to SF Symbols, never to emoji. SF Symbols at least feel like platform vocabulary; emoji feel like defeat.

This extends to silhouettes. The `▓▓` block-character placeholder was a technical shortcut that survived longer than it should have. The replacement — alpha-channel silhouettes generated from the real sprite — preserves each undiscovered character's shape while hiding their identity. Even in absence, the visual language is consistent.

---

## 5. Silence when idle. Never ask for a report.

**The user does not have to tell the companion anything.** Not "I took a break." Not "I'm focusing." Not "please snooze for an hour." The companion infers. If inference is hard, the product fails silently and tries again later. It does not pass the problem to the user.

There is no `I took a break` button. There is no "mark focused" toggle. There is no daily check-in. The old version of the UI had a button asking users to clock out of work sessions with their companion — it was removed in `ba51da4` and a public apology was written in the commit message. The moment the user has to report to the companion is the moment the relationship becomes a transaction.

**The opposite this rules out.** Check-in dialogs. Morning mood prompts. "How focused were you today?" modals. "You haven't been seen in a while — everything okay?" notifications. All of these are the product extracting signal from the user in order to pretend to care. The product either cares enough to observe, or it doesn't. Asking is the tell.

The engineering cost of this principle is high. `ReminderEngine` has to infer breaks from idle detection. `SpeechEngine` has to infer flow state from command velocity and error rate. `WorkContext.minutesSinceBreak` is a computed value, not a user-input field. Every one of these inferences is imperfect — but imperfect observation is better than perfect interrogation.

---

## 6. Topic is the capability.

**A token-based security model, by choice, not by default.** PixelPal's remote notification channel — ntfy — uses unguessable topic strings (20-character base32-minus-ambiguous) as the sole credential. No account, no server-side state, no user database. Anyone who holds the topic can publish and subscribe; anyone who doesn't, can't.

This is capability-based security in the classical sense. The token *is* the authority. There is no "who are you" question the server asks. The topic encodes the right to send and receive, nothing else. Leaking it leaks the exact capability it grants and nothing beyond.

The product deliberately ships ntfy-compatible rather than inventing a proprietary push protocol. Users who distrust the public `ntfy.sh` instance can self-host in 15 minutes and point PixelPal at their own server. The codebase assumes this will be a common path, not an edge case.

**The opposite this rules out.** Proprietary cloud that requires sign-up to use core features. Analytics endpoints keyed to device identifiers. Anonymous-but-linkable telemetry. Anything that centralizes trust in a vendor the user did not ask to trust.

The ntfy implementation is one file, 30 lines. Replacing it with Pushover, Discord, Slack, Telegram, or a self-hosted alternative is another file, another 30 lines. The `NotificationSink` protocol makes channel independence structural, not aspirational.

---

## 7. Delete code rather than abstract it.

**Complexity is debt. Abstraction is deferred complexity.** Every abstraction has an adoption tax (readers have to learn it), a maintenance tax (changes touch more files), and an over-fit tax (once built, it resists the shapes of future needs). If the concrete code is readable and short, the concrete code wins.

PixelPal's codebase has three protocols — `ProviderAdapter`, `NotificationSink`, and `@MainActor` views — not because protocols were fashionable, but because each one isolates a real seam that the product will cross more than twice. A fourth protocol would require evidence that another real seam exists.

When a refactor removes code, the commit message should lead with the lines deleted, not the lines added. When a refactor adds code, the commit message should justify the addition with a concrete need, not a hypothetical extensibility.

**The opposite this rules out.** Speculative generalization. Base classes waiting for a third subclass that never arrives. Extension points that nobody uses. "Just in case" parameters. Option bags for optional configuration nobody has asked for. Dead code kept around "because we might need it" — if the git log has it, we have it.

Audit examples from recent history:
- `emojiForState` and `emojiFor` helpers were removed from `main.swift` and `SessionPanelView.swift` the moment sprite-based rendering replaced them. No "deprecated" comment, no re-export shim.
- `stateColor` was removed from `SessionPanelView.swift` the moment the character-voiced state label replaced the colored status dot. No backwards-compat hack for "if someone was relying on it."
- The `NotificationSink` protocol was added because we had two sinks (local bubble, remote ntfy) with a third imminent (the router). Before the second sink shipped, there was no protocol — just a struct calling an NSUserNotification directly.

The discipline is unglamorous. It is also the reason the codebase stays readable at 4,100 lines of production code. Every line that doesn't exist is a line that doesn't need to be read, tested, or maintained.

---

## How these principles are enforced

Not through a linter. Not through a CI check. Through the same mechanism every strong product uses: a person reading the diff and holding up each change against the principle it potentially violates.

The review question is always the same:

> *Does this change reinforce the principles, or does it quietly dilute them?*

If the answer is "neither, it's orthogonal," the change is fine. If the answer is "reinforce," ship it. If the answer is "dilute," the change needs to be rethought, not rewritten. A dilution rewritten is still a dilution.

Every one of the seven is worth saying out loud before any substantial piece of work begins. Pair with another engineer, read them aloud, argue about which one the current work is serving or compromising. The principles are there to make decisions fast, not to decorate a repo.

---

## Related reading

- [architecture.md](./architecture.md) — how these principles shape the code layout
- [ui-redesign-journey.md](./ui-redesign-journey.md) — 13 places the UI violated these principles and how each was repaired

*Written by [Vince Ni](https://github.com/vince-ni). Repo: [github.com/vince-ni/PixelPal](https://github.com/vince-ni/PixelPal).*
