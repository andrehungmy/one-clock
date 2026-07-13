# Contributing to One Clock

One Clock is a small macOS utility. Keep changes focused, testable, and consistent with the one-task product scope.

## Development Setup

Requirements:

- macOS 14 or later
- Xcode 16 or later with Swift 6 support

Build and open a development app:

```sh
./script/build_and_run.sh
```

Run the complete test suite:

```sh
./script/test.sh
```

Set `ONECLOCK_DERIVED_DATA` if you want a different build directory. Avoid `DerivedData` inside an iCloud-synced Desktop or Documents folder because Finder metadata can break code signing.

## Change Rules

- Keep timer calculations in `Domain/`, outside SwiftUI views.
- Keep one source of truth in `SprintSessionController` and `AppState`.
- Keep window lifecycle code in `Window/`.
- Do not add third-party frameworks without a clear need and prior agreement.
- Do not add accounts, sync, analytics, or network dependencies to solve a local feature.
- Preserve existing data when changing Codable models or `UserDefaults` keys.

## Before Opening a Pull Request

1. Reproduce the issue or state the product outcome.
2. Add or update a test that fails without the change.
3. Run `./script/test.sh`.
4. Run the relevant items in the manual environment matrix in [ROADMAP.md](ROADMAP.md).
5. Update README or roadmap behavior when the user-facing contract changes.

Include this information in the pull request:

- Problem and user impact.
- Root cause or product decision.
- What changed.
- Automated and manual verification.
- Screenshots for visible UI changes.
- Known limits or follow-up work.

## Reporting a Bug

Open a GitHub issue with:

- macOS and One Clock version.
- Install method or source commit.
- Expected and observed behavior.
- Exact reproduction steps.
- Whether the issue happens every time.
- Relevant screenshots or screen recording.
- Whether an active sprint or log data was affected.

Do not post private task names or exported logs unless you have removed sensitive content.

## Product Decisions

Some behavior remains open, including relaunch recovery and `-5m` near zero. Check [ROADMAP.md](ROADMAP.md) before implementing an unresolved item. Record the chosen behavior and acceptance criteria in the same change.
