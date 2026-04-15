<div align="center">

<!-- Replace with docs/hero.png when available. Recommended: 1200×630 panel + floating character composite. -->
<img src="docs/hero.png" alt="PixelPal" width="720" onerror="this.style.display='none'">

# PixelPal

**The only AI agent companion that cares about you, not just your code.**

A macOS menu-bar app that manages your Claude Code / Codex / Aider sessions while a pixel character quietly keeps you company. It notices long sessions, celebrates what ships, and grows with you over months.

[**Quick start**](#quick-start) · [**Architecture**](./docs/architecture.md) · [**Design principles**](./docs/design-principles.md) · [**UI redesign journey**](./docs/ui-redesign-journey.md) · [**Roadmap**](#roadmap)

![Platform](https://img.shields.io/badge/platform-macOS_14+-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
[![CI](https://github.com/vince-ni/PixelPal/actions/workflows/ci.yml/badge.svg)](https://github.com/vince-ni/PixelPal/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-green)
![Universal](https://img.shields.io/badge/build-Universal_Binary-purple)

</div>

---

## Why this exists

Every week another tool lands that makes AI coding more capable. Conductor manages diffs. Vibe Island owns the notch. Jean orchestrates multi-tool workflows. They all answer the same question: _how do we make the agent do more?_

PixelPal asks a different one: **the developer running three Claude Code sessions at 1 AM — are they okay?**

Productivity tools treat humans like machines that happen to get tired. PixelPal treats the tired human as the actual product surface.

## Quick start

```bash
git clone https://github.com/vince-ni/PixelPal.git
cd PixelPal && bash Scripts/build.sh
open .build/PixelPal.app
```

**Requirements:** macOS 14+, Xcode Command Line Tools. Universal Binary (Apple Silicon + Intel). First launch auto-configures shell + Claude Code hooks — no manual setup.

A signed `.dmg` will ship with the first public release.

## What's inside

|  |  |
|---|---|
| **Menu-bar presence** | Pixel character in the status bar, draggable floating companion in a screen corner, Minimal Mode to keep only the menu bar |
| **Session management** | Spawn / monitor / auto-restart / stop Claude Code, Codex, Aider sessions from one panel |
| **Context-aware speech** | Characters speak only when a `WorkContext` observation crosses a threshold worth speaking about — never on a timer |
| **Passive evolution** | Six stages driven by cumulative days. Animal Crossing philosophy: absence never punishes, money cannot accelerate |
| **Discovery system** | Nine characters unlock through your real work journey — no gacha, no store |
| **Three-layer breaks** | 20-min eye rest / 52-min micro break / 90-min deep rest, gradual unlock during the first week |
| **Remote push via ntfy** | Phone push when a task completes and you've walked away. Capability-based (topic is the token). Self-hostable |
| **Zero config** | Auto-detects Claude Code, injects shell hook on first launch, uninstalls cleanly on app removal |

What's deliberately **not** built: a store, a gacha, a streak counter, a shame notification, or anything that punishes absence. [Design principles →](./docs/design-principles.md)

## Architecture

```
 Any terminal ──(zsh hook)──▶ Unix socket ──▶ PixelPalCore ──▶ PixelPal (AppKit)
 Claude/Codex/Aider ──(hooks)──▶ ProviderAdapter ──▶ SpeechEngine ──▶ bubble
                                 ↓                         ↓
                          StateMachine ←→ WorkContext ──▶ NotificationRouter ──▶ ntfy ──▶ phone
```

Work data never leaves the device. Only anonymized character-discovery state optionally syncs via iCloud KV and a thin Cloudflare Workers / D1 backup.

**Deep dive:** [docs/architecture.md](./docs/architecture.md) — six core abstractions, event flow end-to-end, security model, test philosophy, and an explicit non-goals section.

## Engineering discipline

- **Library before app.** `PixelPalCore` compiles against Foundation alone — no AppKit dependency. The core could ship as a CLI, iOS companion, or team daemon unchanged.
- **Adapters, not forks.** `ProviderAdapter` is a 30-line protocol. Adding a fourth AI tool is one file; the session manager doesn't know what it's running.
- **Observation over scripting.** Every utterance is a pure function of `WorkContext`. The character never speaks on a timer.
- **Capability over identity.** The ntfy topic is the token. No account, no server-side state, no analytics.
- **Red team at every external boundary.** Socket server has 8 adversarial tests covering malformed JSON, oversized payloads, concurrent writes, injection attempts. 95 tests, 14 suites, on every build.
- **Delete rather than abstract.** Two production protocols, not six. Speculative generality is treated as debt.

[Full write-up →](./docs/architecture.md) · [Seven principles →](./docs/design-principles.md)

## Roadmap

**Shipped (v0.2):** library/executable split · three-provider adapter · context-aware speech · passive evolution · remote push via ntfy · character-voiced state + stage labels · per-character accent.

**Next (v0.3):** make the intelligence visible — surface *why* the character spoke right now ("noticed: 90 min straight, 3 errors in the last 10"). The `WorkContext`-driven judgment behind each speech event is currently invisible to the user. Closing that gap turns the product from "a talking pixel pet" into "a companion with demonstrable reason."

**Planned (v0.4+):** signed `.dmg` distribution · optional web dashboard via Tailscale Funnel · companion-log silhouettes for undiscovered characters · evolution sprite variants (evo1-5 per character).

**Deferred:** Pro subscription tier · Team Plan anonymized dashboards · Windows / Linux support.

## Tech stack

Swift 5.9 · SwiftUI + AppKit (deliberate hybrid — AppKit for menu bar, panel, keyboard shortcuts; SwiftUI for everything else) · Swift Package Manager library + executable targets · `swift-testing` · Unix domain socket IPC · Nearest-neighbor `NSImage` rendering · Cloudflare Workers + D1 backend (~130 LOC TypeScript, anonymous device UUID only).

~5,200 production lines of Swift. 95 tests across 14 suites.

## Privacy

- All work data stays on your Mac (`~/Library/Application Support/PixelPal/`).
- No telemetry, no analytics, no tracking of any kind.
- Character progress optionally syncs via iCloud KV; disable any time.
- No command content is stored — only timing metadata and aggregate patterns.
- Remote push via ntfy carries only the character's speech line and notification kind. Never command content, never work data.
- Uninstall removes all injected hooks.

## Contributing

This is a single-author project still finding its voice. I'm not accepting feature PRs yet, but I welcome:

- **Bug reports** — open an [issue](https://github.com/vince-ni/PixelPal/issues) with macOS version + reproduction steps
- **Design feedback** — especially around the diagnostic frame in [ui-redesign-journey.md](./docs/ui-redesign-journey.md)
- **Security reports** — see [SECURITY.md](./SECURITY.md)

If you're reading the code because you're thinking about building something similar: the [architecture writeup](./docs/architecture.md) and [design principles](./docs/design-principles.md) are the artifacts I wish I'd had when starting. Fork freely under MIT; the sprite art is the only part that's closed.

## Credits

Character art generated with [Pixel Engine](https://pixelengine.ai). Everything else — product design, personality system, speech pools, interaction philosophy, and this codebase — by [Vince Ni](https://github.com/vince-ni).

## License

MIT — see [LICENSE](LICENSE). Applies to all code in this repository. Pixel sprite art under `Assets/` is not distributed under MIT and is not included in this repo; running from source gives you SF Symbol fallbacks.
