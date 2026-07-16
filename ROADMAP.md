# One Clock Roadmap

This roadmap orders work by user risk and dependency. Checked items are complete in the current working tree. Unchecked items need implementation or a recorded product decision.

## Milestone 0.1.1: Reliability Baseline

Target outcome: one reliable local app process with documented behavior and repeatable verification.

- [x] Prevent multiple One Clock processes and menu bar items.
- [x] Add deterministic single-instance policy tests.
- [x] Correct README claims about macOS Spaces behavior.
- [x] Document the source-only install status.
- [x] Decide relaunch recovery semantics.
- [x] Restore Running and Overtime as paused without counting app downtime.
- [x] Add five-second recovery heartbeats and an exact normal-Quit checkpoint.
- [ ] Add corrupt persistence fallback and schema-version tests.
- [ ] Run and record the manual environment matrix.
- [ ] Add a Release build and static analysis to CI.

### Recovery decision

**Selected on 2026-07-14: restore paused and exclude downtime.** Quitting One Clock ends active focus measurement until the user resumes. Hiding the panel keeps the sprint running.

Implementation behavior:

- Normal Quit writes an exact Paused or Overtime Paused checkpoint.
- Running refreshes its recovery checkpoint every five seconds.
- Crash or force quit can lose up to about five seconds of focus time, but offline time is never counted.
- Legacy Running data restores at the last trustworthy segment boundary.

Acceptance criteria:

- [x] README and tests describe the same policy.
- [x] Running and Overtime use the same restore rule.
- [x] Crash, normal Quit, and relaunch have recorded expected behavior.
- [x] No restore path replays the time-up notification or sound.
- [ ] Define and verify the separate Mac sleep and wake policy.

## Milestone 0.2: Complete the Focus Controls

Target outcome: finish the useful parts of the original MVP without expanding One Clock into a task manager.

- [x] Keep `Finish` available in compact mode, including Overtime.
- [ ] Add `-5m` to setup, running, and paused states.
- [ ] Add a visible time-up cue that respects Reduce Motion.
- [ ] Keep the primary action in a stable position across states.
- [ ] Add transition tests for subtraction near `00:00` and `99:59`.
- [ ] Update menu bar commands and tutorial copy.

### `-5m` decision

**Recommended behavior:**

- Setup: subtract five minutes and clamp at `00:00`. Start stays disabled at zero.
- Running or Paused: subtract from remaining time. Crossing zero enters the matching Overtime state.
- Overtime: do not show `-5m`. Use `+5m` to return to a bounded countdown.

Acceptance criteria:

- No displayed remaining time becomes negative.
- Repeated subtraction cannot create duplicate overtime cues.
- Pause or resume state remains stable after adjustment.
- Result planned time remains understandable after adjustments.

## Milestone 0.3: Accessibility and UI Maintainability

Target outcome: preserve the current visual hierarchy while making every core action usable without a pointer or color cue.

- [ ] Verify the complete flow with keyboard navigation and VoiceOver.
- [ ] Increase undersized status and result text where needed.
- [ ] Give icon controls consistent hit areas and focus states.
- [ ] Add text or symbol state cues for compact Paused and Overtime.
- [ ] Verify Increase Contrast, Reduce Transparency, and Reduce Motion.
- [ ] Split `FloatingPanelView.swift` into focused feature files.
- [ ] Add UI or accessibility tests for the highest-risk controls.

### Opacity control decision

The old PRD includes adjustable panel opacity. Do not implement it until a manual contrast test confirms a useful range. The default material already balances visibility and obstruction.

## Milestone 0.4: Data Durability

Target outcome: protect sprint history and active sessions across upgrades and invalid local data.

- [ ] Wrap persisted data in an explicit schema version.
- [ ] Add migration tests for older sprint payloads.
- [ ] Quarantine or clear corrupt payloads and surface a recoverable error.
- [ ] Escape task titles in Markdown export.
- [ ] Define log size limits and expected performance.
- [ ] Add an import path only if users need it after export testing.

## Milestone 1.0: Public Distribution

Target outcome: a user can download, verify, install, run, and update One Clock without Xcode.

- [ ] Replace the development bundle identifier.
- [ ] Add a production asset-catalog app icon.
- [ ] Sign and notarize the app.
- [ ] Publish a versioned GitHub Release with checksums and install steps.
- [ ] Test first install, upgrade, and uninstall behavior.
- [ ] Publish privacy and support information.
- [ ] Decide whether to add an updater after the first release.

## Manual Environment Matrix

Run this matrix before each public release:

- One and repeated app launches.
- Panel show, hide, compact, expand, close, and reopen.
- Running, Paused, Overtime, and Complete on one Space and full-screen apps.
- Drag between displays, disconnect a display, then reopen.
- Sleep and wake during Running and Paused.
- Notification authorized, denied, and not determined.
- Sound muted and unmuted.
- Keyboard-only setup and controls.
- VoiceOver, Increase Contrast, Reduce Transparency, and Reduce Motion.
- Quit and relaunch in every active state.

## Deferred by Product Scope

These items do not support the current one-task focus anchor and are not planned for the near-term roadmap:

- Accounts or cloud sync.
- Multiple simultaneous timers.
- Projects, tags, subtasks, or a full task manager.
- Calendar and to-do integrations.
- App or website blocking.
- Productivity scores, streaks, or analytics dashboards.
- Team collaboration.
