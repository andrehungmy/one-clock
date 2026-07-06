# One Clock

[![CI](https://github.com/andrehungmy/one-clock/actions/workflows/ci.yml/badge.svg)](https://github.com/andrehungmy/one-clock/actions/workflows/ci.yml)

One Clock is a macOS menu bar focus timer that keeps the current task and remaining time visible in a lightweight floating window.

## Problem

Focus timers often become either too intrusive or too easy to ignore. One Clock explores a calmer middle ground: a persistent focus anchor that reminds the user what they intended to work on without becoming a full task manager.

## Product Hypothesis

If a timer keeps the active task visible alongside time remaining, users can recover focus faster after interruptions and make cleaner decisions about when to continue, pause, or finish a focus sprint.

## Features

- **Single focus sprint** — one task title, one countdown, no task manager. Leave the title empty and the sprint auto-names itself ("Sprint 1", "Sprint 2", …) based on your log.
- **Rename anywhere** — the sprint name is editable before, during, after a sprint, and directly in the log sidebar; renames propagate to the recorded history.
- **First-run tutorial** — a seven-step walkthrough opens on first launch (or anytime via "Show Tutorial" in the menu) and ends by handing you the keyboard for your first sprint.
- **A primary action that never moves** — one controls row spans the bottom of the panel, so Start, Finish, and New Sprint always live in the bottom-right corner, with or without the log sidebar.
- **Positional MM:SS entry** — the colon is always visible and each digit is its own slot: click any position and type (a "5" in the first slot reads 50:00, in the second slot 05:00); empty slots show as dimmed zeros so what you see is exactly what starts. Arrow keys and Backspace edit in place; Return starts.
- **Quick presets** — 15m / 25m / 45m chips, and +5m during any active state (in overtime it returns the sprint to a running countdown).
- **Floating always-on-top panel** — translucent, follows you across Spaces and full-screen apps; drag anywhere, resize from 260×212 up to 800×560, hide with `Esc` or the close button (the timer keeps running and stays visible in the menu bar).
- **Compact mode** — collapse the panel to a slim pill (state dot, live time, task name) that barely occupies the workspace; expand, or hide it entirely, from the pill itself. The choice persists.
- **Sprint log sidebar** — widen the panel and your logged sprints appear as a fixed-width list beside the timer, newest day first, with names editable in place; narrow it (or go compact) and the panel returns to a single column.
- **Layout-stable states** — every state renders the same fixed slot skeleton with fixed type sizes; pausing, overtime, and window resizing never shift the title, numbers, or controls.
- **Near-zero energy use** — no per-second animations (digits flip like a plain clock), per-second updates invalidate only the time and progress leaves, and the backdrop is a window-server-composited `NSVisualEffectView`: ~0.4 % CPU while counting down.
- **Menu bar countdown** — remaining time (or `+MM:SS` overtime) is always visible in the status bar; a pause icon shows when the sprint is paused.
- **Time-up notification** — when the countdown reaches zero you get a system notification and a subtle sound cue, then the sprint keeps counting up as overtime instead of interrupting you.
- **Sprint log** — every finished sprint records its name, originally planned time, and actual invested time, grouped by day; export as Markdown or JSON from the menu bar, or clear the log (with confirmation).
- **Post-sprint summary** — the result screen compares planned vs invested time ("Planned 25:00 · 02:30 over") with one action: New Sprint.
- **Session recovery** — an in-progress sprint survives quitting or relaunching the app; elapsed time is derived from absolute timestamps, so it stays accurate across the gap.
- **Menu bar controls** — start, pause/resume, finish, new, reset, and the sprint log are available from the status item menu even when the panel is hidden; the countdown keeps updating while you drag the panel or browse menus.

## Screenshots

Setting up a sprint, with the log sidebar revealed by widening the panel:

<img src="assets/setup.png" width="640" alt="Setup: positional MM:SS entry, quick presets, and the sprint log sidebar">

A sprint in progress — the primary action stays bottom-right in every state:

<img src="assets/running.png" width="640" alt="Running: live countdown, pause and +5m controls, editable sprint name">

Compact pill mode keeps the countdown visible while barely occupying the workspace:

<img src="assets/compact.png" width="264" alt="Compact pill: state dot, live time, and task name">

A seven-step tutorial introduces the flow on first launch:

<img src="assets/tutorial.png" width="340" alt="First-run tutorial overlay">

## Requirements

- macOS 14.0 or later
- Xcode 16 or later (Swift 6) to build from source

## Build and Run

```sh
./script/build_and_run.sh
```

Run the test suite:

```sh
./script/test.sh
```

> **Note for iCloud-synced folders:** if the repository lives under `~/Desktop` or `~/Documents` with iCloud sync enabled, keep `DerivedData` outside the synced folder (the scripts already do this). The iCloud file provider adds Finder metadata to build products, which makes `codesign` fail with "resource fork, Finder information, or similar detritus not allowed".

## Architecture

```text
OneClock/
  App/       App entry point, menu bar scene, sound cues
  Domain/    Pure sprint state machine (no UI, no timers)
  State/     Observable session controller, persistence
  Views/     SwiftUI panel views and presentation helpers
  Window/    AppKit floating NSPanel lifecycle
```

- **Domain layer** (`SprintEngine`, `Sprint`) is a pure, synchronous state machine driven by explicit `Date` values — fully deterministic and unit-testable without timers.
- **`SprintSessionController`** owns the active sprint, coordinates a 1-second ticker, persists every state transition, and plays sound cues on overtime/finish. Clock, ticker, store, and sound player are all injected protocols, so tests use manual fakes.
- **`FloatingPanelController`** wraps a borderless, resizable `NSPanel` that can join all Spaces; SwiftUI content is hosted via `NSHostingController`.

## Repository Structure

```text
OneClock/              macOS app source
OneClockTests/         unit tests (Swift Testing)
OneClock.xcodeproj/    Xcode project
script/                local development scripts
assets/                README screenshots
.github/workflows/     CI (build + test on macOS)
```

## Distribution Readiness

Aligned with Apple's platform requirements today:

- **App Sandbox** is enabled with a minimal entitlement set (user-selected read/write, needed only for log export via the save panel).
- **Hardened Runtime** is enabled in build settings; it takes effect when the app is signed with a real identity (local dev builds are ad-hoc signed, where macOS omits the runtime flag).
- Info.plist declares `LSApplicationCategoryType` (Productivity), copyright, and `LSUIElement` for the menu-bar-only lifecycle. No private APIs, no network access.

Remaining gaps before App Store / notarized distribution:

- Developer ID or App Store signing and notarization (requires an Apple Developer account).
- An asset-catalog `AppIcon` — the App Store requires one; the app currently ships a generated `.icns` (see `script/generate_app_icon.swift`).
- App Store Connect metadata, screenshots, and a privacy label (trivial: no data collection).

## Known Limitations

- No `−5 min` control yet (PRD defines it; the engine only supports adding time).
- The sprint log lives in `UserDefaults` — fine for personal volumes, not designed as a database.
- Enabling the sandbox moved app data into the app container; data written by pre-sandbox dev builds is not migrated.

## License

[MIT](LICENSE)
