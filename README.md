# One Clock

One Clock is a macOS menu bar focus timer that keeps the current task and remaining time visible in a lightweight floating window.

## Problem

Focus timers often become either too intrusive or too easy to ignore. One Clock explores a calmer middle ground: a persistent focus anchor that reminds the user what they intended to work on without becoming a full task manager.

## Product Hypothesis

If a timer keeps the active task visible alongside time remaining, users can recover focus faster after interruptions and make cleaner decisions about when to continue, pause, or finish a focus sprint.

## Current Status

This repository is an early personal alpha / portfolio project. Milestone 0 is a working macOS app shell with a menu bar lifecycle and a reusable floating `NSPanel` technical spike.

## MVP Direction

The MVP is a local-first macOS app for a single active focus sprint. It will support setup, running, pause/resume, time adjustment, overtime, finish/result, window visibility controls, and recovery of unfinished sprint state.

## Screenshots

![Setup mockup](docs/images/setup.png)

![Running mockup](docs/images/running.png)

![Finish mockup](docs/images/finish.png)

## Technology Stack

- macOS native app
- Swift
- SwiftUI for views and menu bar UI
- AppKit for floating window lifecycle
- Xcode project with a local build-and-run script

## Build and Run

```sh
./script/build_and_run.sh
```

## Repository Structure

```text
OneClock/              macOS app source
OneClock.xcodeproj/    Xcode project
script/                local development scripts
docs/
  product/             PRD, technical spec, wireframe
  decisions/           technical decision records and spikes
  images/              product mockups
```

## Documentation

- [Product Requirements](docs/product/prd.md)
- [Technical Specification v0.1](docs/product/technical-spec-v0.1.md)
- [Wireframe Specification](docs/product/wireframe.md)
- [Floating Window Spike](docs/decisions/floating-window-spike.md)

## Known Limitations

- Current app UI is a technical spike placeholder, not the final MVP experience.
- Timer domain logic, persistence, notifications, sound, overtime, and result flow are not implemented yet.
- Floating window behavior still needs manual validation across Spaces, full-screen apps, multiple monitors, focus changes, and sleep/wake.
- No App Store packaging, signing, auto-update, analytics, sync, or account system is included.

## Planned Next Milestone

Milestone 1 should replace the placeholder panel with the core focus sprint flow: setup, running, pause/resume, finish/result, and a small testable timer state model.
