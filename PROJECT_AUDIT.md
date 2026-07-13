# One Clock Project Audit

**Audit date:** 2026-07-13
**Repository baseline:** `ab2feb2` on `main`
**Scope:** product flow, SwiftUI and AppKit architecture, runtime behavior, tests, roadmap alignment, and GitHub readiness

## Executive Summary

One Clock has a sound timer engine and a focused product concept. The state machine, persistence, menu commands, panel reuse, log, and presentation helpers have automated tests. The current branch passed the complete test suite before and after the single-instance fix.

The main reliability bug was process-level duplication. The app reused one `NSPanel` inside each process but allowed macOS to start more than one process. Two forced launches produced two One Clock processes and two menu bar items. The fix now declares the app as single-instance and applies a deterministic launch guard. A repeated runtime check leaves one process.

The remaining work centers on product decisions, accessibility, recovery edge cases, and distribution. The repository had no public release or topics at the time of this audit, so a visitor could build the app but could not install a signed binary.

## Evidence

- Reviewed all app source, tests, build scripts, `Info.plist`, entitlements, CI, Git history, README assets, and deleted PRD and technical-spec revisions.
- Ran the full Xcode test suite in a normal macOS environment. All tests passed.
- Counted 69 `@Test` definitions after adding three single-instance policy tests. One definition runs six parameterized phase cases.
- Reproduced two concurrent One Clock processes before the fix.
- Repeated the same launch sequence after the fix and observed one process.
- Inspected the four repository screenshots for setup, running, compact, and tutorial states.
- Attempted a live accessibility capture. The macOS accessibility service timed out, so VoiceOver, focus order, and target behavior still require manual checks.

## Product Flow Health

| Step | Health | Finding |
|---|---|---|
| 1. Discover and install | Blocked for general users | No signed download, GitHub Release, or install path exists. Source build works. |
| 2. First launch | Good with review needed | The tutorial explains the flow, but seven steps may delay the first sprint. Measure completion before changing it. |
| 3. Set up a sprint | Good | Task, timer, presets, and Start follow a clear hierarchy. Positional digit entry needs keyboard and VoiceOver validation. |
| 4. Run and control | Good | The large timer and fixed control row make pause, add time, and finish easy to find. |
| 5. Reach time limit | Partial | Sound, notification, overtime, and one-time triggering exist. The PRD's visual transition cue is missing. |
| 6. Finish and review | Good | Result summary and editable log work. The log uses local storage intended for personal volumes. |
| 7. Hide, quit, and return | Needs a decision | Hide works as expected. Relaunch currently counts time while the app was closed, while the original technical spec required a paused restore that excludes downtime. |

## Findings by Priority

### P0: Duplicate menu bar instances

**Status:** Fixed and verified.

`FloatingPanelController` already reused one panel, but `AppDelegate` did not enforce one app process. The fix adds:

- `LSMultipleInstancesProhibited` in `Info.plist` for Launch Services.
- `SingleInstancePolicy` to choose the earliest running process, with process ID as a deterministic tie-breaker.
- An early `AppDelegate` guard that activates the primary process and terminates a later process.
- Three policy tests plus a repeated two-launch runtime check.

### P1: Recovery behavior conflicts with the original product decision

The current engine derives elapsed time from absolute timestamps. A running sprint keeps accumulating after quit and relaunch. The deleted technical spec required relaunch into Paused or Overtime Paused and excluded app downtime from focused time.

This is a product decision, not a test failure. The repository should choose one policy and encode it in tests, UI copy, and the README.

**Recommendation:** restore as paused and exclude downtime. A focus log should record time when One Clock was active, not time after the user chose Quit. Hiding the panel remains the way to keep a sprint running in the background.

### P1: Original MVP items remain incomplete

The PRD defined these items, but the current app does not implement them:

- `-5m` in setup, running, and paused states.
- A visible time-up transition cue.
- User-adjustable panel opacity.

`-5m` and the time-up cue fit the product. Opacity needs validation because lower opacity can reduce contrast and adds a setting to a deliberately small app.

### P1: Accessibility needs an explicit pass

`FloatingPanelView.swift` uses fixed 52 pt and 22 pt timer sizes, several `caption2` labels, small plain icon buttons, and color changes for some compact-state cues. The full panel includes text state labels, but compact mode does not expose the paused or overtime label visually.

Recommended checks:

- Increase small status and result text where the layout allows it.
- Give close, compact, expand, pause, and finish controls reliable hit areas.
- Add a non-color paused and overtime cue in compact mode.
- Verify keyboard focus, VoiceOver names and values, Increase Contrast, Reduce Transparency, and Reduce Motion.

The screenshots support a risk assessment only. They do not prove accessibility compliance.

### P1: Public distribution is not ready

The project uses the development bundle identifier `dev.andrehung.OneClock.dev`. It has no signed or notarized artifact, release, or update path. The current `.icns` works for development, while App Store distribution requires an asset catalog and release metadata.

### P2: Persistence lacks schema and corruption handling

`UserDefaultsSprintStore` and `UserDefaultsSprintLogStore` decode with `try?`. Invalid data returns an empty state without recording the error or removing the corrupt payload. The models also have no explicit schema version.

Add a versioned envelope, clear or quarantine corrupt data, and test migration and fallback behavior before public distribution.

### P2: Clock changes and sleep or wake remain untested

The engine uses wall-clock `Date` values so it can recover after relaunch. Manual clock changes can move time backward, and sleep policy depends on the unresolved recovery decision. Add explicit tests and lifecycle handling for:

- Clock moving backward or forward.
- Mac sleep and wake during Running and Paused.
- App termination during Running and Overtime.

### P2: The main SwiftUI file is too large

`FloatingPanelView.swift` contains 863 lines and many view types, layout rules, onboarding, editor logic, log presentation, and compact-mode behavior. This raises regression risk when changing one part of the panel.

Split it by feature after the P1 behavior decisions. Keep the current visual structure and extract setup, active, result, compact, log, onboarding, and shared panel components into focused files.

### P2: CI checks behavior but not release readiness

CI runs Debug tests on macOS. It does not run a Release build, static analysis, an automated accessibility check, or a coverage threshold. Add Release build and analysis first. Keep multi-monitor, Spaces, full-screen, notification permission, and VoiceOver in a documented manual matrix.

## Roadmap Alignment

| Capability | Current status | Source decision |
|---|---|---|
| One active sprint | Complete within one process | Original MVP |
| One app process | Complete after this audit | User-reported requirement |
| Pause, resume, finish | Complete | Original MVP |
| `+5m` | Complete | Original MVP |
| `-5m` | Missing | Original MVP |
| Overtime | Complete | Original MVP |
| Sound and notification | Complete | Original MVP |
| Time-up visual cue | Missing | Original MVP |
| Compact and hidden modes | Complete | Original MVP |
| Window position restore | Implemented, manual edge cases remain | Original MVP |
| Adjustable opacity | Missing, validate before building | PRD v0.2 |
| Relaunch recovery | Implemented with different semantics | Technical spec conflict |
| Sprint log and export | Complete | Added beyond original MVP |
| First-run tutorial | Complete | Added beyond original MVP |
| Signed distribution | Missing | Distribution backlog |

## Test Coverage and Gaps

### Covered well

- Sprint transitions and elapsed-time calculations.
- Pause and resume across multiple segments.
- Overtime and `+5m` behavior.
- Finish outcomes and result formatting.
- Active sprint persistence and restore.
- Log append, rename, clear, and export formatting.
- Notification and sound coordination through test doubles.
- Menu command availability.
- Panel reuse and hide or show behavior.
- Layout threshold and compact resize geometry.
- Single-instance selection policy.

### Add next

- Corrupt and old persistence payloads.
- Termination, sleep, wake, and clock changes.
- Real notification authorization states.
- Export save-panel success and write failure.
- Keyboard-only setup and positional time entry.
- VoiceOver labels, focus order, and compact-state announcements.
- Panel visibility after monitor removal and across Spaces.
- A process-level smoke test for repeated launch where CI supports UI sessions.

## Recommended Sequence

1. Keep the single-instance fix and corrected public documentation.
2. Decide recovery semantics and `-5m` behavior.
3. Implement the selected behavior with transition and lifecycle tests.
4. Complete accessibility and manual environment QA.
5. Harden persistence and CI.
6. Prepare a signed GitHub Release.

See [ROADMAP.md](ROADMAP.md) for scoped milestones and acceptance criteria.
