# PixelPal

The only AI agent companion that cares about you, not just your code.

PixelPal is a macOS app that manages your AI coding sessions (Claude Code, Codex, Aider) while a pixel character keeps you company. It reminds you to take breaks, celebrates when tasks complete, and grows with you over time.

## Features

- **Pixel companion** — A character lives in your screen corner, reacting to your work. 95% quiet ambient presence, 5% personality.
- **Session management** — Spawn, monitor, and stop AI agent sessions from one panel. Auto-restart on crash.
- **Break reminders** — Three-layer scientific breaks (20-20-20 rule, micro breaks, deep rest). Gradual unlock over your first week.
- **Discovery system** — 9 characters unlock through your work journey. No gacha, no store. They come to you.
- **Zero config** — Auto-detects Claude Code and shell, injects hooks on first launch. No manual setup.
- **Works with any terminal** — Ghostty, iTerm2, Terminal.app, cmux, Warp, VS Code terminal.

## Install

```bash
# Build from source
git clone https://github.com/vince-ni/PixelPal.git
cd PixelPal
bash Scripts/build.sh
open .build/PixelPal.app
```

Or download the latest `.dmg` from [Releases](https://github.com/vince-ni/PixelPal/releases).

## How It Works

PixelPal listens to your terminal via a lightweight shell hook (zsh, ~45 lines) and Claude Code hooks. Events flow through a Unix socket to the app, which updates the character state and tracks your work patterns.

```
Terminal (any) → shell hook → Unix socket → PixelPal
Claude Code    → hooks      → Unix socket → PixelPal
                                              ↓
                                     Character state machine
                                     Break reminder engine
                                     Session manager
                                     Work pattern tracker
```

No data leaves your machine. Work patterns are stored locally. Character progress syncs via iCloud (optional).

## Characters

Characters are discovered through your work journey, not purchased:

| Character | Hint | Style |
|-----------|------|-------|
| 🦔 Spike | Always here from the start | Simple |
| 🐆 Dash | Takes time to trust you | Simple |
| 🐕 Badge | Studying your work patterns | Expressive |
| 🦉 Ramble | Waits until you've settled in | Expressive |
| 🐢 Rush | Attracted to a certain rhythm | Expressive |
| 🦊 Blunt | Watching your output | Complex |
| 🔥 Meltdown | Only appears at milestones | Complex |
| 🐉 ... | Only comes out at night | Enigmatic |
| 🫧 . | ...... | Enigmatic |

Characters evolve passively through days of companionship. No XP, no grinding, no pressure.

## Privacy

- All work data stays local (JSON files, never uploaded)
- No telemetry, no analytics, no tracking
- Character data syncs via iCloud (optional, can be disabled)
- No command content stored — only timing metadata

## Tech Stack

- Swift + SwiftUI (macOS 14+)
- Universal Binary (Apple Silicon + Intel)
- Unix domain socket IPC
- Nearest-neighbor pixel rendering
- Cloudflare Workers + D1 (optional backup)

## Project Structure

```
Sources/PixelPal/
├── main.swift              — App entry + MenuBarController
├── Core/
│   ├── StateMachine.swift  — Character state (idle/working/celebrate/nudge/comfort)
│   ├── SocketServer.swift  — Unix socket event receiver
│   ├── SessionManager.swift — AI agent process lifecycle
│   ├── DiscoveryManager.swift — Character discovery conditions
│   ├── ReminderEngine.swift — Three-layer scientific breaks
│   ├── WorkPatternStore.swift — Local work data persistence
│   └── CloudSync.swift     — iCloud + D1 sync
├── Config/
│   └── AutoConfigurator.swift — Zero-config hook injection
└── UI/
    ├── SpriteSheet.swift   — Pixel art asset loading
    ├── FloatingCharacterWindow.swift — Draggable corner companion
    ├── BubbleWindow.swift  — Speech bubble notifications
    ├── SessionPanelView.swift — Session + companion panels
    └── WeeklyReportView.swift — Shareable weekly report card
```

## Contributing

Character art generated with [Pixel Engine](https://pixelengine.ai). Character design, personality system, and interaction philosophy by [Vince](https://github.com/vince-ni).

## License

MIT — see [LICENSE](LICENSE).
