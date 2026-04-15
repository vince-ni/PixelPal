# Security

## Threat model in one paragraph

PixelPal runs locally on your Mac, reads shell + Claude Code hook events from a Unix domain socket, and optionally pushes notifications to your phone via ntfy and backs up character-discovery state to Cloudflare D1. Work data (command content, file contents, agent prompts, diffs) physically cannot leave the device because it never enters the system boundary — only exit codes, durations, timestamps, and git branch names cross the socket, and only the speech line + notification kind cross the ntfy boundary. The D1 backup holds a list of unlockable character IDs and cumulative day counts, keyed by an anonymous device UUID.

Security-sensitive surfaces, in order of concern:

1. **Unix domain socket** — adversarial input handling
2. **ntfy remote push** — topic-as-capability token
3. **AutoConfigurator** — writes to `~/.zshrc` and Claude Code config
4. **CloudSync** — outbound HTTPS to Cloudflare Workers

## Reporting a vulnerability

**Please do not file security issues on the public GitHub tracker.**

Email the details to the address listed on my [GitHub profile](https://github.com/vince-ni). Expect an acknowledgment within 72 hours. If the issue is valid and reproducible, we'll coordinate a fix timeline and public disclosure together.

**What to include:**
- macOS version (`sw_vers`)
- PixelPal build (commit hash from `git rev-parse HEAD` if built from source)
- A minimal reproduction
- Whether the issue is exploitable in the default configuration or only under a specific setup
- Suggested severity (low / medium / high / critical) — yours, not authoritative

## Coverage already in place

**Red-team tests.** The socket server has 8 adversarial test cases running on every build: malformed JSON, oversized payloads, partial frames, concurrent writes, injection attempts, UTF-8 edge cases, null fields, boundary timestamps. See `Tests/PixelPalTests/*SocketTests*` (and equivalent coverage scattered across Provider / State / Speech suites for their respective input surfaces).

**ntfy request construction tests.** Separate suite asserts URL construction, HTTP method, required headers (Title / Priority / Tags), and body encoding against the ntfy publish format. Empty topic yields no request — defensive against a misconfigured sink posting to `ntfy.sh/` root.

**Capability topic generation.** 20 characters from a 32-character alphabet with ambiguous characters (`0/o/1/l`) removed. Entropy ≈ 10³⁰ possible topics per user. The generator is covered by tests asserting prefix, length, alphabet safety, and uniqueness across generations.

**No secrets in the repo.** `Backend/wrangler.toml` database ID is a `TODO_AFTER_CREATION` placeholder. No API keys, no tokens, no account identifiers ever appear in tracked files. Persisted secrets (when added) use the macOS Keychain via `kSecClassGenericPassword`.

## Known risk acceptances

Stated explicitly rather than hidden. If any of these become exploitable in a way I haven't anticipated, they're in scope for reports.

- **Git history contains early sprite blobs** — commits `3b000c1` and `8e58d6f` (before the `.gitignore` rule for `Assets/*.gif` / `*.png` was added) include `Assets/idle.png`, `Assets/spike_large.png`, and four Spike animation GIFs. `abd7960` removed them from the working tree but the git blobs remain reachable via history. Spike is the day-one welcome character; this is an accepted trade-off rather than a leak.
- **`pixelpal.app` domain is not owned.** The `SUFeedURL` Sparkle auto-update key was removed in `c7e6279` specifically because the domain was unregistered; leaving the URL in place would have let a squatter push arbitrary updates to installed copies. Until the domain is registered, no Sparkle-based auto-update path exists.
- **Shell hook runs in the user's shell context.** The 50-line zsh hook (`Shell/pixelpal.zsh`) executes whatever the user's zsh executes. It does not escalate, does not fork privileged processes, and does not read files outside what the shell already exposes. An adversary who could modify the hook already has the user's shell access.
- **ntfy.sh public server is default.** Users who distrust the public instance can self-host ntfy and point PixelPal at their own server via the `pixelpal_ntfy_server` UserDefaults key. The app itself treats the server as opaque.

## What's out of scope

- Vulnerabilities in underlying macOS frameworks (AppKit, SwiftUI, Foundation) — report to Apple
- Vulnerabilities in ntfy itself — report to [ntfy/ntfy](https://github.com/binwiederhier/ntfy)
- Vulnerabilities in Cloudflare Workers — report to Cloudflare
- Social-engineering attacks that require the user to manually run malicious scripts
- Physical access scenarios
