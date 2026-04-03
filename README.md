# Cat Eye

The octocat's eye never blinks. A lightweight native macOS menu bar app that watches your GitHub Actions and Pull Requests so you don't have to. No Electron, no web views — just a 224KB Swift binary that sits quietly in your menu bar, glowing green or red.

## Features

### Actions Tab
- **Live status icon** — GitHub mark tinted green (passing), red (failing), or orange (running)
- **Pulsing animation** — icon gently pulses when any action is actively running
- **Rich popover** — scrollable list of recent runs across all your repos, styled like the GitHub Actions UI
- **Per-run details** — workflow name, run number, branch badge, timestamps, and duration
- **Calculated ETA** — estimates remaining time for running actions based on historical durations
- **macOS notifications** — alerts when actions start or finish (success/failure), click to open the popover

### Pull Requests Tab
- **Review queue** — shows PRs where your review is requested, across all tracked repos
- **Expandable detail** — click any PR to expand inline with full description and labels
- **PR actions** — approve, request changes, comment, merge (merge/rebase/squash), or close — all from the menu bar
- **Inline comments** — type and submit comments without leaving the popover

### General
- **Tabbed interface** — switch between Actions and Pull Requests
- **Repo filter** — "All Repos" or pick a specific repo; persists across tabs
- **Built-in setup** — login to GitHub and pick repos to track from the settings panel
- **Copy URL** — one-click copy of any run or PR URL to clipboard
- **Direct links** — click to open runs or PRs in GitHub
- **Multi-repo** — monitor as many repos as you want from a single widget
- **Adaptive polling** — 30s when idle, 10s when actions are running (configurable)
- **Hot-reload config** — change tracked repos from settings without restarting
- **Auto-detects `gh` CLI** — finds your GitHub CLI install automatically
- **Tiny footprint** — 224KB binary, ~0.3% memory, zero dependencies beyond macOS

## Requirements

- macOS 13+ (Ventura or later)
- [GitHub CLI](https://cli.github.com/) (`gh`) installed (`brew install gh`)
- Apple Silicon or Intel Mac

## Installation

### Quick start

```bash
# Install GitHub CLI if you haven't
brew install gh

# Clone and build
git clone https://github.com/clintoncodewell/cat-eye.git
cd cat-eye
./build.sh

# Run
open CatEye.app
```

On first launch, the **Settings panel** opens automatically. From there you can:
1. **Login** — click "Login..." to authenticate with GitHub (opens Terminal with `gh auth login`)
2. **Pick repos** — your repos and org repos are fetched automatically; check the ones you want to track
3. **Save** — click "Save & Apply" and you're monitoring

Reopen Settings any time via the gear icon in the footer.

### Make it findable via Spotlight / Raycast

```bash
# Symlink into ~/Applications (indexed by Spotlight)
ln -sf "$(pwd)/CatEye.app" ~/Applications/CatEye.app
```

Then search for **"Cat Eye"** in Spotlight or Raycast.

### Auto-start on login

```bash
cat > ~/Library/LaunchAgents/com.cateye.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cateye</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>/path/to/cat-eye/CatEye.app</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Enable it
launchctl load ~/Library/LaunchAgents/com.cateye.plist
```

Replace `/path/to/cat-eye/` with your actual install path.

## Configuration

Config lives in `~/.config/cat-eye/config.json` (managed via the Settings panel, or edit directly):

```json
{
    "repos": [
        "myorg/backend",
        "myorg/frontend",
        "myuser/side-project"
    ],
    "pollInterval": 30,
    "pollActiveInterval": 10,
    "runsPerRepo": 10
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `repos` | `[]` | GitHub repos to monitor (`owner/repo` format) |
| `pollInterval` | `30` | Seconds between checks when idle |
| `pollActiveInterval` | `10` | Seconds between checks when a run is in progress |
| `runsPerRepo` | `10` | Number of recent runs to fetch per repo |

## Building from source

```bash
# Requires Xcode Command Line Tools
xcode-select --install

# Build (produces CatEye.app)
./build.sh
```

## How it works

- Uses the `gh` CLI under the hood — no API tokens to manage, no OAuth flows. If `gh auth status` works, Cat Eye works.
- Fetches run data via `gh run list --json` for each configured repo, all concurrently.
- Runs as a macOS accessory app (no Dock icon, no Cmd+Tab entry).
- Notifications use the native `UserNotifications` framework — respects Do Not Disturb and Focus modes.

## Menu bar icon states

| Icon | Meaning |
|------|---------|
| Green | All recent key runs passing |
| Red | Most recent deploy/test run failed |
| Orange (pulsing) | A run is currently in progress |
| Gray | No data or no repos configured |

Prioritizes **deploy** and **smoke test** workflows for overall status, so Dependabot noise won't turn your icon red.

## Process info

| | |
|---|---|
| **Process name** | `cat-eye` |
| **Spotlight name** | Cat Eye |
| **Binary size** | ~224KB |
| **Memory** | ~0.3% on 16GB Mac |
| **Bundle ID** | `com.clintoncodewell.cat-eye` |

## License

MIT
