import Foundation
import Testing
@testable import OneClock

@Suite("SprintPresentation")
struct SprintPresentationTests {
    @Test("Positional digits resolve empty slots as zero")
    func positionalDigitsResolveEmptySlotsAsZero() {
        var digits = SprintDurationDigits()
        #expect(digits.resolvedDuration == 0)

        // "5" in the first minute slot reads as 50:00.
        digits.setDigit(5, at: 0)
        #expect(digits.resolvedDuration == 3_000)

        // "5" in the second minute slot alone reads as 05:00.
        var second = SprintDurationDigits()
        second.setDigit(5, at: 1)
        #expect(second.resolvedDuration == 300)

        // Seconds slots behave the same way: _ _ : 4 5 → 00:45.
        var seconds = SprintDurationDigits()
        seconds.setDigit(4, at: 2)
        seconds.setDigit(5, at: 3)
        #expect(seconds.resolvedDuration == 45)
    }

    @Test("Seconds tens slot rejects digits above five")
    func secondsTensSlotRejectsInvalidDigits() {
        var digits = SprintDurationDigits()
        let rejected = digits.setDigit(6, at: 2)
        #expect(!rejected)
        #expect(digits.digit(at: 2) == nil)

        let acceptedTens = digits.setDigit(5, at: 2)
        let acceptedOnes = digits.setDigit(9, at: 3)
        #expect(acceptedTens)
        #expect(acceptedOnes)
        #expect(digits.resolvedDuration == 59)
    }

    @Test("Digits initialize from a duration and round-trip")
    func digitsInitializeFromDuration() {
        let pomodoro = SprintDurationDigits(duration: 1_500)
        #expect(pomodoro.digit(at: 0) == 2)
        #expect(pomodoro.digit(at: 1) == 5)
        #expect(pomodoro.digit(at: 2) == 0)
        #expect(pomodoro.digit(at: 3) == 0)
        #expect(pomodoro.resolvedDuration == 1_500)

        let maximum = SprintDurationDigits(duration: Sprint.maximumDisplayedDuration)
        #expect(maximum.resolvedDuration == Sprint.maximumDisplayedDuration)

        let clamped = SprintDurationDigits(duration: 10_000)
        #expect(clamped.resolvedDuration == Sprint.maximumDisplayedDuration)
    }

    @Test("Clearing a digit returns the slot to placeholder")
    func clearingDigitReturnsPlaceholder() {
        var digits = SprintDurationDigits(duration: 1_500)
        digits.clearDigit(at: 0)
        #expect(digits.digit(at: 0) == nil)
        #expect(digits.resolvedDuration == 300)
    }

    @Test("MMSS formatting uses stable two digit seconds")
    func mmssFormatting() {
        #expect(SprintTimeFormatter.minutesAndSeconds(0) == "00:00")
        #expect(SprintTimeFormatter.minutesAndSeconds(65) == "01:05")
        #expect(SprintTimeFormatter.minutesAndSeconds(5_999) == "99:59")
    }

    @Test("Overtime formatting uses leading plus")
    func overtimeFormatting() {
        #expect(SprintTimeFormatter.overtime(0) == "+00:00")
        #expect(SprintTimeFormatter.overtime(222) == "+03:42")
    }

    @Test("Menu bar title mirrors the active sprint state")
    func menuBarTitleMirrorsSprintState() {
        #expect(SprintMenuBarPresentation.title(for: .setup, remainingTime: 1_500, overtimeDuration: 0) == nil)
        #expect(SprintMenuBarPresentation.title(for: .completed, remainingTime: 0, overtimeDuration: 0) == nil)
        #expect(SprintMenuBarPresentation.title(for: .running, remainingTime: 754, overtimeDuration: 0) == "12:34")
        #expect(SprintMenuBarPresentation.title(for: .paused, remainingTime: 754, overtimeDuration: 0) == "12:34")
        #expect(SprintMenuBarPresentation.title(for: .overtimeRunning, remainingTime: 0, overtimeDuration: 90) == "+01:30")
        #expect(SprintMenuBarPresentation.title(for: .overtimePaused, remainingTime: 0, overtimeDuration: 90) == "+01:30")
    }

    @Test("Menu bar symbol reflects paused state")
    func menuBarSymbolReflectsPausedState() {
        #expect(SprintMenuBarPresentation.symbolName(for: .setup) == "timer")
        #expect(SprintMenuBarPresentation.symbolName(for: .running) == "timer")
        #expect(SprintMenuBarPresentation.symbolName(for: .paused) == "pause.circle")
        #expect(SprintMenuBarPresentation.symbolName(for: .overtimePaused) == "pause.circle")
    }

    @Test("Status presentation maps every phase to a stable label and style", arguments: [
        (SprintPhase.setup, "One Clock", SprintStatusStyle.idle),
        (SprintPhase.running, "Focus", SprintStatusStyle.focus),
        (SprintPhase.paused, "Paused", SprintStatusStyle.paused),
        (SprintPhase.overtimeRunning, "Overtime", SprintStatusStyle.overtime),
        (SprintPhase.overtimePaused, "Overtime · Paused", SprintStatusStyle.overtime),
        (SprintPhase.completed, "Complete", SprintStatusStyle.complete),
    ])
    func statusPresentationMapsPhases(phase: SprintPhase, label: String, style: SprintStatusStyle) {
        let presentation = SprintStatusPresentation(phase: phase)
        #expect(presentation.label == label)
        #expect(presentation.style == style)
    }

    @Test("Progress fraction follows focused time and pins at one in overtime")
    func progressFractionFollowsFocusedTime() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let sprint = try SprintEngine.start(Sprint(taskTitle: "Focus", plannedDuration: 600), at: start)

        #expect(SprintProgress.fraction(for: nil, at: start) == 0)
        #expect(SprintProgress.fraction(for: sprint, at: start) == 0)
        #expect(SprintProgress.fraction(for: sprint, at: start.addingTimeInterval(150)) == 0.25)
        #expect(SprintProgress.fraction(for: sprint, at: start.addingTimeInterval(600)) == 1)

        let overtime = try SprintEngine.advanced(sprint, to: start.addingTimeInterval(700))
        #expect(overtime.phase == .overtimeRunning)
        #expect(SprintProgress.fraction(for: overtime, at: start.addingTimeInterval(700)) == 1)

        let finished = try SprintEngine.finish(sprint, at: start.addingTimeInterval(300))
        #expect(SprintProgress.fraction(for: finished, at: start.addingTimeInterval(300)) == 1)
    }

    @Test("Result summary reports over, early, and on-plan finishes")
    func resultSummaryCaption() {
        #expect(SprintResultSummary.caption(planned: 1_500, invested: 1_650) == "Planned 25:00 · 02:30 over")
        #expect(SprintResultSummary.caption(planned: 1_500, invested: 1_370) == "Planned 25:00 · 02:10 early")
        #expect(SprintResultSummary.caption(planned: 1_500, invested: 1_500) == "Planned 25:00 · on plan")
    }

    @Test("Onboarding flow covers the full user journey")
    func onboardingFlowCoversJourney() {
        let steps = OnboardingFlow.steps

        #expect(steps.count == 7)
        #expect(steps.allSatisfy { !$0.title.isEmpty && !$0.message.isEmpty && !$0.symbolName.isEmpty })
        #expect(Set(steps.map(\.title)).count == steps.count)
        #expect(steps.first?.title == "Welcome to One Clock")
        #expect(steps.last?.title == "Ready to focus?")
    }
}
