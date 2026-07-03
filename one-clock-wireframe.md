# One Clock — Floating Window Wireframe Specification v0.1

**Document type:** Low-fidelity wireframe and interaction specification  
**Product:** One Clock  
**Platform:** macOS  
**Status:** Draft based on confirmed design decisions  
**Last updated:** 2026-07-03

---

## 1. Document Purpose

This document records the confirmed UI/UX decisions for the first low-fidelity wireframe of One Clock.

The current scope focuses on:

- Setup
- Running
- Pause
- Collapsed Pill
- Time’s Up
- Overtime
- Result
- Menu Bar re-entry
- Window behavior and interaction rules

This document does not define final visual styling, colors, typography tokens, production-ready dimensions, or implementation architecture.

---

## 2. Product UI Principle

One Clock is not designed primarily as another Pomodoro timer.

Its floating window should function as a lightweight **Focus Anchor** that continuously answers:

1. What am I currently working on?
2. How much time remains?
3. What is the current timer state?
4. What is the next valid action?

### Confirmed information hierarchy

1. **Task name**
2. **Time**
3. **Progress**
4. **Controls**

The task is always the primary visual element. Time remains important, but secondary.

---

## 3. Overall Visual Direction

### Confirmed direction

- Floating macOS utility window
- Always-on-top behavior
- Semi-transparent material
- Background blur
- Rounded rectangular form
- Subtle border or shadow
- Player-like control layout
- Compact and calm when idle
- Expanded only when the user interacts

### Important clarification

The background should not be fully transparent.

A completely transparent window would create contrast and readability problems when placed above bright, dark, or visually complex content.

The intended direction is:

> Semi-transparent macOS material with blur, stable contrast, and visible window boundaries.

The visual design must remain legible when macOS accessibility settings such as Reduce Transparency or Increase Contrast are enabled.

---

## 4. Window Modes

One Clock uses three primary spatial modes.

### 4.1 Resting Card

The normal always-on-top state.

```text
┌──────────────────────────────┐
│ Complete One Clock Hover     │
│ and Collapsed Wireframes     │
│                              │
│ 24:18                        │
│ ━━━━━━━━━━━───────────────  │
└──────────────────────────────┘
```

Purpose:

- Preserve task context
- Show remaining time
- Show progress
- Avoid unnecessary controls and visual noise

---

### 4.2 Hover / Focus Card

The Resting Card expands when:

- The pointer enters the window
- The window receives keyboard focus
- VoiceOver or another accessibility interaction focuses the controls

```text
┌──────────────────────────────┐
│ Complete One Clock Hover   ⌄ │
│ and Collapsed Wireframes     │
│                              │
│ 24:18                        │
│ ━━━━━━━━━━━───────────────  │
│                              │
│       −5    ⏸    +5          │
└──────────────────────────────┘
```

Purpose:

- Provide direct timer controls
- Allow task editing
- Provide collapse control

---

### 4.3 Collapsed Pill

The manually collapsed state.

```text
┌──────────────────────────────┐
│ Complete One Clock…   24:18 │
└──────────────────────────────┘
```

Purpose:

- Reduce screen obstruction
- Preserve both task context and time awareness

The Pill does not automatically expand on hover.

The user must click the Pill to restore the Resting Card.

---

## 5. Window Expansion and Collapse Rules

### Hover expansion

- Controls are hidden in the Resting Card.
- Hover expands the card and reveals the controls.
- Expansion normally occurs downward.
- If the card is near the bottom edge of the screen, it expands upward.
- The animation should be subtle and fast.
- Recommended initial transition duration: approximately 150–200 ms.
- No spring or bounce animation.
- After the pointer leaves, the card should wait briefly before collapsing.
- Recommended initial dismissal delay: approximately 300–500 ms.

### Manual collapse

A collapse chevron appears in the upper-right corner of the Hover / Focus Card.

```text
⌄
```

Rules:

- Only visible during hover, keyboard focus, or accessibility focus
- Must not be confused with the `−5` control
- Recommended hit target: at least 28 × 28 pt
- Collapsing should preserve the anchored screen edge
- Near the right edge, the right boundary should remain fixed
- Near the left edge, the left boundary should remain fixed

### Restore from Pill

- Hover only applies a subtle visual highlight
- Hover does not expand the Pill
- A single click restores the Resting Card
- Dragging must not accidentally trigger restoration
- The implementation should distinguish click from drag using a movement threshold

---

## 6. Task Name Behavior

### Display

The task name is the primary visual element.

#### Normal card

- Maximum two lines
- Text beyond two lines is truncated
- The task region may reserve two-line height for layout stability

```text
Complete One Clock Hover
and Collapsed Wireframes
```

#### Collapsed Pill

- One line only
- Truncated with an ellipsis
- The remaining time stays fixed on the right

```text
Complete One Clock…   24:18
```

### Inline editing

The task name can be edited directly in Setup and Running states.

Interaction:

- Single-click the task text to enter inline edit
- Place the cursor at the clicked text position
- `Enter` saves
- `Esc` cancels
- Clicking outside saves a valid value
- Editing does not pause the timer
- The control region remains expanded while editing
- The task text region is not the primary drag region
- Empty card background or designated empty areas are draggable

### Result state

The task name remains visible, up to two lines, but cannot be edited from the Result Card.

---

## 7. Time and Progress Behavior

### Time display

Running state uses:

```text
MM:SS
```

Example:

```text
24:18
```

Requirements:

- Seconds remain visible
- Use monospaced digits
- Prevent layout movement as numbers change

### Progress line

The card shows:

- Remaining time as numbers
- Completed proportion as a progress line

The progress line fills from left to right.

```text
Start:
━────────────────────────────

Halfway:
━━━━━━━━━━━━━━───────────────

Near completion:
━━━━━━━━━━━━━━━━━━━━━━━━━━──
```

This represents completed Focus Block progress, not remaining time.

Initial design guidance:

- Approximate height: 2–3 pt
- Low visual contrast
- Smooth progress updates
- Pause stops the progress
- Time adjustments animate to the recalculated position
- Avoid distracting continuous motion

### Adding time

If the user adds five minutes, the total planned duration increases and the completed proportion is recalculated.

Example:

```text
Before: 15 / 25 minutes = 60%
After +5: 15 / 30 minutes = 50%
```

The progress line should smoothly move to the new percentage.

---

## 8. Setup State

The Setup Card appears when:

- One Clock is launched for a new session
- The user opens it from the Menu Bar
- The user invokes the relevant shortcut
- The user selects New Sprint from the Result Card

```text
┌──────────────────────────────┐
│ [ What do I want to finish? ]│
│                              │
│            25:00             │
│                              │
│       −5             +5      │
│                              │
│           [ Start ]          │
└──────────────────────────────┘
```

### Setup behavior

- Opens at the last floating window position
- Retains the previous sprint’s task name
- Retains the previous sprint’s configured time
- Does not automatically begin counting down
- User may edit task or time before pressing Start
- Reset clears retained values

### Time adjustment controls

- `−5` subtracts five minutes
- `+5` adds five minutes
- Minimum time is `00:00`
- Maximum time is `99:59`
- Start is disabled at `00:00`

### Direct time entry

The complete `MM:SS` value is selected and edited as four digits.

Examples:

```text
0500 → 05:00
2530 → 25:30
9959 → 99:59
```

Rules:

- Four digits are interpreted as `MMSS`
- Maximum value is `99:59`
- Seconds must be between `00` and `59`
- `0000` cannot start a sprint
- `Enter` confirms
- `Esc` restores the previous value
- Invalid input is not saved

---

## 9. Running State

### Resting

```text
┌──────────────────────────────┐
│ Complete One Clock Hover     │
│ and Collapsed Wireframes     │
│                              │
│ 24:18                        │
│ ━━━━━━━━━━━───────────────  │
└──────────────────────────────┘
```

### Hover / Focus

```text
┌──────────────────────────────┐
│ Complete One Clock Hover   ⌄ │
│ and Collapsed Wireframes     │
│                              │
│ 24:18                        │
│ ━━━━━━━━━━━───────────────  │
│                              │
│       −5    ⏸    +5          │
└──────────────────────────────┘
```

### Controls

- `−5`: subtract five minutes from remaining time
- Pause: pause the sprint
- `+5`: add five minutes
- Collapse chevron: switch to Pill
- Task name: inline edit

Reset and other destructive or low-frequency actions should not appear in the primary player control row.

---

## 10. Pause State

Pause retains the remaining time.

### Resting

```text
┌──────────────────────────────┐
│ Complete One Clock Wireframe │
│                              │
│ ⏸ 24:18                     │
│ ━━━━━━━━━━━───────────────  │
└──────────────────────────────┘
```

### Hover / Focus

```text
┌──────────────────────────────┐
│ Complete One Clock Wireframe │
│                              │
│ ⏸ 24:18                     │
│ ━━━━━━━━━━━───────────────  │
│                              │
│       −5    ▶    +5          │
└──────────────────────────────┘
```

Rules:

- Countdown stops
- Progress stops
- Remaining time remains visible
- Pause icon must appear
- Resume replaces Pause as the central control
- `−5` and `+5` remain available
- State must not be communicated by color alone

### Paused Pill

```text
Complete One Clock…   ⏸ 24:18
```

---

## 11. Time’s Up State

When countdown reaches `00:00`, One Clock triggers:

- Sound
- macOS Notification
- Floating window animation

The user then chooses one of three actions.

```text
┌──────────────────────────────┐
│ Complete One Clock Wireframe │
│                              │
│          Time’s up           │
│            00:00             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                              │
│    +5     Overtime     Done  │
└──────────────────────────────┘
```

### Control priority

- `Overtime` is the central primary action
- `+5` is the bounded extension action
- `Done` ends the sprint and opens Result

### Important restriction

`New Sprint` must not appear in the Time’s Up state.

### Action behavior

#### `+5`

```text
00:00 → 05:00
```

- Return to Running
- Keep the same task
- Increase total planned duration
- Recalculate the progress percentage

#### `Overtime`

- Enter Overtime mode
- Begin counting upward from zero
- Do not create a new countdown target

#### `Done`

- End the current sprint
- Open the Result Card

---

## 12. Overtime State

### Resting

```text
┌──────────────────────────────┐
│ Complete One Clock Wireframe │
│                              │
│ OVERTIME · +03:42            │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━  │
└──────────────────────────────┘
```

### Hover / Focus

```text
┌──────────────────────────────┐
│ Complete One Clock Wireframe │
│                              │
│ OVERTIME · +03:42            │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                              │
│          ⏸       Done        │
└──────────────────────────────┘
```

Rules:

- Display full `OVERTIME` state label
- Show upward elapsed time with a leading `+`
- Use monospaced digits
- Progress line remains fully filled
- Do not show `−5` or `+5`
- Pause / Resume remains available
- Done opens Result

### Paused Overtime

```text
⏸ OVERTIME · +03:42
━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Overtime Pill

```text
Complete One Clock…   +03:42
```

The `+` acts as the compact Overtime indicator.

---

## 13. Result Card

Pressing Done from Running, Time’s Up, or Overtime expands the existing floating card into the Result Card.

It does not open a separate centered window.

```text
┌────────────────────────────────┐
│ Sprint complete              × │
│                                │
│ Complete One Clock Hover       │
│ and Collapsed Wireframes       │
│                                │
│            28:42               │
│          Focused time          │
│                                │
│          [ New Sprint ]        │
└────────────────────────────────┘
```

### Confirmed information

The Result Card shows only:

- Completion state
- Task name, maximum two lines
- Total focused time
- New Sprint
- Close

The Result Card does not show:

- Planned time
- Overtime breakdown
- Planned-versus-actual comparison
- Adjust button
- Charts
- Productivity score
- Additional statistics

### Focused time calculation

Focused time includes:

```text
Active countdown time
+ Overtime time
= Focused time
```

Paused time is excluded.

Example:

```text
Original duration: 25:00
Overtime: 03:42
Focused time: 28:42
```

If Done is pressed before countdown completion:

```text
Original duration: 25:00
Remaining: 07:15
Focused time: 17:45
```

### Actions

#### New Sprint

- Return to Setup
- Preserve the previous task
- Preserve the previous configured duration
- Do not automatically start the countdown

#### Close `×`

- Close the floating window
- Keep One Clock running in the Menu Bar
- Do not quit the application

---

## 14. Menu Bar Behavior

One Clock remains available from the macOS Menu Bar after the floating window closes.

### Reopen behavior

When reopened from the Menu Bar or shortcut:

- Setup Card appears at the last floating window position
- Previous task and configured duration remain available
- The user can edit or immediately press Start

### Quit behavior

Application exit must be a separate Menu Bar action:

```text
Quit One Clock
```

Closing the floating card must never be interpreted as quitting the application.

---

## 15. Window Position and Dragging

### Confirmed behavior

- Floating window can be dragged
- The last position is remembered
- Setup, Running, Overtime, and Result use the same position reference
- The window should reopen on the previous display when possible
- If that display is disconnected, the window must be moved into a visible area
- Resolution or workspace changes must not leave the window off-screen

### Draggable regions

- Empty card background is draggable
- Task text is used for editing and should not be the primary drag region
- Buttons and controls must remain interactive
- Pill supports dragging
- Click and drag behavior must be disambiguated

---

## 16. State Flow

```text
Setup
  ↓ Start
Running
  ├─ Pause ↔ Resume
  ├─ Collapse ↔ Expand
  ├─ Done → Result
  └─ 00:00 → Time’s Up
                 ├─ +5 → Running
                 ├─ Overtime → Overtime
                 └─ Done → Result

Overtime
  ├─ Pause ↔ Resume
  └─ Done → Result

Result
  ├─ New Sprint → Setup with retained values
  └─ × → Close floating window; app remains in Menu Bar

Menu Bar / Shortcut
  └─ Open Setup at last window position
```

---

## 17. Confirmed Design Decisions

| Area | Decision |
|---|---|
| Primary visual hierarchy | Task first, time second |
| Background | Semi-transparent material, not fully transparent |
| Normal controls | Hidden until hover or focus |
| Hover behavior | Card expands to reveal controls |
| Expansion direction | Downward by default, upward near bottom edge |
| Collapsed mode | One-line Pill with task and time |
| Restore from Pill | Single click, not hover |
| Collapse control | Chevron shown during hover / focus |
| Task editing | Inline edit |
| Task display | Two lines in card, one line in Pill |
| Time display | Includes seconds |
| Progress | Completed proportion fills left to right |
| Pause | Retain time and show pause icon |
| Time’s Up primary action | Overtime |
| Overtime display | `OVERTIME · +MM:SS` |
| Overtime progress | Fully filled line |
| Result presentation | Existing card expands in place |
| Result information | Task and focused time only |
| Result close | Close window, retain Menu Bar app |
| New Sprint | Returns to Setup with retained values |
| Setup time entry | Whole four-digit `MMSS` input |
| Setup location | Reopens at last window position |

---

## 18. Items Not Yet Finalized

The following still require future design decisions or prototype validation:

- Exact card width and height
- Minimum and maximum Pill width
- Final spacing system
- Font styles and sizes
- Final material and opacity values
- Border and shadow strength
- Light and dark mode appearance
- Accent colors
- Time’s Up animation behavior
- Sound selection and volume behavior
- Full keyboard shortcut mapping
- Menu Bar menu structure
- Reset placement and confirmation behavior
- How Done is exposed during active Running state
- Whether a dedicated interruption state is included in the personal MVP
- Multi-monitor and macOS Spaces behavior
- Full-screen and screen-sharing behavior
- Accessibility labels and VoiceOver reading order

---

## 19. Recommended Next Deliverable

The next design artifact should be a **low-fidelity state sheet** containing one frame for each of the following:

1. Setup
2. Running Resting
3. Running Hover
4. Running Inline Edit
5. Paused Resting
6. Paused Hover
7. Collapsed Running Pill
8. Collapsed Paused Pill
9. Time’s Up
10. Overtime Resting
11. Overtime Hover
12. Collapsed Overtime Pill
13. Result
14. Menu Bar closed-window state

The purpose of this state sheet is to validate:

- Spatial consistency
- Control placement
- Card expansion direction
- State recognition
- Text truncation
- Transition continuity
- Screen obstruction risk

Only after validating the state sheet should the project move into high-fidelity visual styling or implementation.
