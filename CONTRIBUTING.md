# Contributing to PixelPal

Thanks for the interest. A few notes on where this project is in its life, and what that means for what's welcome right now.

## Current stance

PixelPal is a single-author project still finding its voice. The codebase, the design principles, and the aesthetic are deliberately opinionated — see [docs/design-principles.md](./docs/design-principles.md). Feature PRs are **not** currently accepted, because the product shape is still being discovered, and merging external opinions too early locks that shape prematurely.

This will change when the product reaches a stable surface. When it does, this document will be rewritten and the top banner removed.

## What's welcome now

**Bug reports.** Open an [issue](https://github.com/vince-ni/PixelPal/issues) with:
- macOS version (`sw_vers`)
- Which AI tool you're running (Claude Code / Codex / Aider) and version
- A minimal reproduction
- Whether the bug reproduces from a fresh install

**Design feedback.** The repo ships three long-form documents ([architecture](./docs/architecture.md), [design principles](./docs/design-principles.md), [UI redesign journey](./docs/ui-redesign-journey.md)). If you read one and think "this reasoning has a hole in it," open a discussion or drop a line via the email in my GitHub profile. Counter-arguments are far more useful to me right now than code.

**Security reports.** See [SECURITY.md](./SECURITY.md). Please do not file security issues on the public tracker.

**Porting experiments.** If you want to try running `PixelPalCore` on iOS or as a CLI, that's the exact path the library was designed for. I'd love to see what you make. Drop a link in an issue.

## What's not welcome right now

- Feature additions (new characters, new providers, new notification sinks) — these would pin down architectural choices that aren't ready
- Refactors that change the seven [design principles](./docs/design-principles.md)
- Style / lint / formatting PRs — the style exists on purpose; see `.editorconfig` and the existing code
- Dependency additions — the codebase deliberately stays close to stdlib + Foundation + Apple frameworks. Adding a third-party dependency needs to clear a high bar

## If you fork

Fork freely under MIT. The sprite art under `Assets/` is the only part that isn't distributed — running from source gives you SF Symbol fallbacks. If you ship a derivative product, credit is appreciated but not required.

## Contact

- **Bugs / feedback** — [GitHub issues](https://github.com/vince-ni/PixelPal/issues)
- **Security** — see [SECURITY.md](./SECURITY.md)
- **Everything else** — email on my [GitHub profile](https://github.com/vince-ni)
