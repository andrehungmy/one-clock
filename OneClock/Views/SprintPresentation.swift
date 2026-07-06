import Foundation

/// Positional MM:SS editor model: four independently editable digit slots
/// (M M : S S). Empty slots resolve as zero, so a lone "5" in the first slot
/// reads — and starts — as 50:00, matching how the digits are displayed.
/// Per-slot bounds (seconds tens ≤ 5) make invalid durations unrepresentable.
struct SprintDurationDigits: Equatable {
    static let slotCount = 4

    private var slots: [Int?]

    init() {
        slots = Array(repeating: nil, count: Self.slotCount)
    }

    init(duration: TimeInterval) {
        let clamped = max(0, min(duration, Sprint.maximumDisplayedDuration))
        let total = Int(clamped.rounded())
        let minutes = total / 60
        let seconds = total % 60
        slots = [minutes / 10, minutes % 10, seconds / 10, seconds % 10]
    }

    static func maximumDigit(at index: Int) -> Int {
        index == 2 ? 5 : 9
    }

    var resolvedDuration: TimeInterval {
        let digit = { (index: Int) in self.slots[index] ?? 0 }
        let minutes = digit(0) * 10 + digit(1)
        let seconds = digit(2) * 10 + digit(3)
        return TimeInterval(minutes * 60 + seconds)
    }

    func digit(at index: Int) -> Int? {
        guard slots.indices.contains(index) else {
            return nil
        }
        return slots[index]
    }

    @discardableResult
    mutating func setDigit(_ value: Int, at index: Int) -> Bool {
        guard slots.indices.contains(index),
              value >= 0,
              value <= Self.maximumDigit(at: index) else {
            return false
        }

        slots[index] = value
        return true
    }

    mutating func clearDigit(at index: Int) {
        guard slots.indices.contains(index) else {
            return
        }
        slots[index] = nil
    }
}

/// Semantic state category driving panel accent colors. Kept separate from
/// `SprintPhase` so the view maps five phases onto a smaller visual language.
enum SprintStatusStyle: Equatable {
    case idle
    case focus
    case paused
    case overtime
    case complete
}

/// Status-row content for a phase. The row exists in every state with a fixed
/// height, so state changes only ever swap its text and tint — never layout.
struct SprintStatusPresentation: Equatable {
    let label: String
    let style: SprintStatusStyle

    init(phase: SprintPhase) {
        switch phase {
        case .setup:
            label = "One Clock"
            style = .idle
        case .running:
            label = "Focus"
            style = .focus
        case .paused:
            label = "Paused"
            style = .paused
        case .overtimeRunning:
            label = "Overtime"
            style = .overtime
        case .overtimePaused:
            label = "Overtime · Paused"
            style = .overtime
        case .completed:
            label = "Complete"
            style = .complete
        }
    }
}

enum SprintProgress {
    /// Fraction of the planned duration that has been focused, clamped to 0…1.
    /// Overtime and completed sprints pin to 1 so the bar never moves backwards.
    static func fraction(for sprint: Sprint?, at date: Date) -> Double {
        guard let sprint else {
            return 0
        }

        switch sprint.phase {
        case .setup:
            return 0
        case .overtimeRunning, .overtimePaused, .completed:
            return 1
        case .running, .paused:
            let total = SprintEngine.totalPlannedDuration(for: sprint)
            guard total > 0 else {
                return 0
            }
            return min(1, max(0, SprintEngine.focusedElapsedTime(for: sprint, at: date) / total))
        }
    }
}

enum SprintResultSummary {
    /// One-line completion summary, e.g. "Planned 25:00 · 02:30 over".
    static func caption(planned: TimeInterval, invested: TimeInterval) -> String {
        let base = "Planned \(SprintTimeFormatter.minutesAndSeconds(planned))"
        let delta = invested - planned

        if delta >= 1 {
            return "\(base) · \(SprintTimeFormatter.minutesAndSeconds(delta)) over"
        }
        if delta <= -1 {
            return "\(base) · \(SprintTimeFormatter.minutesAndSeconds(-delta)) early"
        }
        return "\(base) · on plan"
    }
}

struct OnboardingStep: Equatable {
    let symbolName: String
    let title: String
    let message: String
}

/// First-run tutorial content, mirroring the actual user flow: name → set
/// duration → start → in-flight controls → log. Rendered by the panel's
/// onboarding overlay; also reachable from the menu bar ("Show Tutorial").
enum OnboardingFlow {
    static let steps: [OnboardingStep] = [
        OnboardingStep(
            symbolName: "timer",
            title: "Welcome to One Clock",
            message: "One task, one countdown — a floating anchor that stays in sight while you work."
        ),
        OnboardingStep(
            symbolName: "character.cursor.ibeam",
            title: "Name your sprint",
            message: "Click the name field and type. Leave it empty and sprints name themselves — Sprint 1, Sprint 2, … Rename anytime, even mid-sprint."
        ),
        OnboardingStep(
            symbolName: "keyboard",
            title: "Set the duration",
            message: "Click any digit and type — a 5 in the first slot reads 50:00. Or tap 15m · 25m · 45m."
        ),
        OnboardingStep(
            symbolName: "play.fill",
            title: "Start",
            message: "Press Return, or hit Start in the bottom-right corner. It stays there in every screen."
        ),
        OnboardingStep(
            symbolName: "pause.fill",
            title: "While it runs",
            message: "Pause, add +5m, or finish from the bottom row. Shrink to a pill or hide the panel from the top-right — the menu bar keeps counting."
        ),
        OnboardingStep(
            symbolName: "list.bullet.rectangle",
            title: "Your sprint log",
            message: "Every finished sprint is recorded. Widen the panel to browse and rename entries; export or clear from the menu bar icon."
        ),
        OnboardingStep(
            symbolName: "flag.checkered",
            title: "Ready to focus?",
            message: "Set a task, give it a time, and press Return — your first sprint is one keystroke away."
        ),
    ]
}

enum SprintMenuBarPresentation {
    /// Menu bar text shown next to the status item icon. Returns nil when no
    /// sprint is active so the menu bar stays icon-only and quiet.
    static func title(for phase: SprintPhase, remainingTime: TimeInterval, overtimeDuration: TimeInterval) -> String? {
        switch phase {
        case .setup, .completed:
            nil
        case .running, .paused:
            SprintTimeFormatter.minutesAndSeconds(remainingTime)
        case .overtimeRunning, .overtimePaused:
            SprintTimeFormatter.overtime(overtimeDuration)
        }
    }

    /// SF Symbol for the status item, reflecting the sprint state at a glance.
    static func symbolName(for phase: SprintPhase) -> String {
        switch phase {
        case .setup, .completed:
            "timer"
        case .running, .overtimeRunning:
            "timer"
        case .paused, .overtimePaused:
            "pause.circle"
        }
    }
}

enum SprintTimeFormatter {
    static func minutesAndSeconds(_ duration: TimeInterval) -> String {
        let clamped = max(0, Int(duration.rounded(.down)))
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func overtime(_ duration: TimeInterval) -> String {
        "+\(minutesAndSeconds(duration))"
    }
}
