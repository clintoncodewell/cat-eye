# GH Actions Bar

A lightweight native macOS menu bar app that shows live GitHub Actions status at a glance. No Electron, no web views — just a 175KB Swift binary that sits quietly in your menu bar.

## Features

- **Built-in setup** — login to GitHub and pick repos to track, all from the app's settings panel
- **Live status icon** — GitHub mark in your menu bar, tinted green (passing), red (failing), or orange (running)
- **Pulsing animation** — icon gently pulses when any action is actively running
- **Rich popover** — click to see a scrollable list of recent runs across all your repos, styled like the GitHub Actions UI
- **Per-run details** — workflow name, run number, branch badge, timestamps, and duration
- **Calculated ETA** — for running actions, estimates remaining time based on historical run durations
- **macOS notifications** — get alerted when an action starts or finishes (success/failure), click the notification to open the popover
- **Copy URL** — one-click copy of any run's URL to your clipboard
- **Direct links** — click any run to open it in GitHub, or jump straight to a repo's Actions page
- **Multi-repo** — monitor as many repos as you want from a single widget
- **Adaptive polling** — checks every 30s normally, every 10s when actions are running (all configurable)
- **Hot-reload config** — change tracked repos from the settings panel without restarting
- **Auto-detects `gh` CLI** — finds your GitHub CLI install automatically
- **Tiny footprint** — 175KB binary, ~0.3% memory, zero dependencies beyond macOS itself

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
git clone https://github.com/clintoncodewell/gh-actions-bar.git
cd gh-actions-bar
./build.sh

# Run
open GHActionsBar.app
```

On first launch, the **Settings panel** opens automatically. From there you can:
1. **Login** — click "Login..." to authenticate with GitHub (opens Terminal with `gh auth login`)
2. **Pick repos** — your repos and org repos are fetched automatically; check the ones you want to track
3. **Save** — click "Save & Apply" and you're monitoring

You can reopen Settings any time via the gear icon in the footer.

### Make it findable via Spotlight / Raycast

```bash
# Symlink into ~/Applications (indexed by Spotlight)
ln -sf "$(pwd)/GHActionsBar.app" ~/Applications/GHActionsBar.app
```

Then search for **"GH Actions"** in Spotlight or Raycast.

### Auto-start on login

Create a Launch Agent:

```bash
cat > ~/Library/LaunchAgents/com.ghactionsbar.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ghactionsbar</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>/path/to/gh-actions-bar/GHActionsBar.app</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Enable it
launchctl load ~/Library/LaunchAgents/com.ghactionsbar.plist
```

Replace `/path/to/gh-actions-bar/` with your actual install path.

## Configuration

All config lives in `~/.config/gh-actions-bar/config.json`:

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

After editing the config, click **Refresh** in the popover or restart the app.

## Building from source

```bash
# Requires Xcode Command Line Tools
xcode-select --install

# Build (produces GHActionsBar.app)
./build.sh
```

The build script compiles with `-Osize` for minimal binary size and strips debug symbols.

## How it works

- Uses the `gh` CLI under the hood — no API tokens to manage, no OAuth flows. If `gh auth status` works, the app works.
- Fetches run data via `gh run list --json` for each configured repo.
- All repos are fetched concurrently to minimize latency.
- Runs as a macOS accessory app (no Dock icon, no Cmd+Tab entry).
- Notifications use the native `UserNotifications` framework — respects Do Not Disturb and Focus modes.

## Menu bar icon states

| Icon | Meaning |
|------|---------|
| Green GitHub mark | All recent key runs passing |
| Red GitHub mark | Most recent deploy/test run failed |
| Orange GitHub mark (pulsing) | A run is currently in progress |
| Gray GitHub mark | No data or no repos configured |

The app prioritizes **deploy** and **smoke test** workflows when determining overall status, so Dependabot noise won't turn your icon red.

## Process info

| | |
|---|---|
| **Process name** | `gh-actions-bar` |
| **Spotlight name** | GH Actions Bar |
| **Binary size** | ~175KB |
| **Memory** | ~0.3% on 16GB Mac |
| **Bundle ID** | `com.clintoncodewell.gh-actions-bar` |

## License

MIT
