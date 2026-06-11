# Contributing to Cat Eye

Thanks for your interest! Cat Eye is intentionally small: a single Swift file, zero dependencies beyond macOS and the `gh` CLI. Contributions that keep it that way are very welcome.

## Getting started

```bash
git clone https://github.com/clintoncodewell/cat-eye.git
cd cat-eye
./build.sh
open CatEye.app
```

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

## Guidelines

- **Keep it lean.** No external packages, no frameworks beyond AppKit/UserNotifications. The whole app lives in `main.swift` — please keep it that way unless there's a compelling reason.
- **Security matters.** The app shells out to `gh` only via hardcoded trusted paths with an allowlisted environment, and validates all repo input. Don't weaken these.
- **Accessibility matters.** Status is never conveyed by colour alone (we use the Okabe-Ito palette plus shape/text signals). New UI should follow the same rule and stay keyboard-navigable.
- **No telemetry, no tokens.** Cat Eye never handles credentials itself — auth is delegated entirely to the `gh` CLI.

## Submitting changes

1. Fork the repo and create a branch.
2. Make your change and verify it builds (`./build.sh`) and runs.
3. Update the README if behaviour or configuration changed.
4. Open a pull request with a clear description of what and why.

## Reporting bugs

Open a GitHub issue with your macOS version, `gh --version` output, and steps to reproduce. Screenshots help — but please use demo data, not your real repo names.
