import SwiftUI

/// Fixed vertical skeleton shared by every panel state. Each state renders the
/// same slots (status, title, time, meta) at the same heights, and a single
/// controls row spans the window bottom, so the primary action (Start /
/// Finish / New Sprint) always sits in the bottom-right corner — in every
/// state and whether or not the log sidebar is visible.
/// Type sizes are fixed (no geometry-driven scaling) so live window resizing
/// never reflows the numbers; `minimumScaleFactor` is a safety net only.
private enum PanelMetrics {
    static let statusHeight: CGFloat = 14
    static let titleHeight: CGFloat = 22
    static let timeMinHeight: CGFloat = 62
    static let metaHeight: CGFloat = 14
    static let controlsHeight: CGFloat = 28
    static let rowSpacing: CGFloat = 10
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let timeFontSize: CGFloat = 52

    static let compactSize = CGSize(width: 264, height: 60)
    static let compactTimeFontSize: CGFloat = 22

    static var timeFont: Font {
        .system(size: timeFontSize, weight: .bold, design: .rounded)
    }
}

/// Pure, unit-testable layout decisions for the expanded panel, split out of
/// the SwiftUI view and the AppKit window controller so they can be checked
/// without rendering. Two invariants regress silently otherwise: the log
/// sidebar appears only past a width threshold — and when it does it is a
/// fixed-width *right* column, so the status row (and its close button) stays
/// at the top-right of the main column, not above the sidebar — and switching
/// to/from the compact pill stays anchored to the panel's top edge.
enum PanelLayout {
    /// At or above this content width the log sidebar is shown as a fixed
    /// right-hand column; below it (and in compact mode) the panel is a single
    /// column and the close button sits at the panel's own top-right corner.
    static let logSidebarMinWidth: CGFloat = 500

    /// Fixed width of the log sidebar column, so the main column — and the
    /// controls row under both — keeps its geometry as the panel widens.
    static let logSidebarWidth: CGFloat = 185

    static func showsLogSidebar(forContentWidth width: CGFloat) -> Bool {
        width >= logSidebarMinWidth
    }

    /// Resizes `current` to `size` while holding its top edge (`maxY`) fixed, so
    /// switching between the full panel and the compact pill grows or shrinks
    /// from the bottom and the panel stays anchored to its top-left corner.
    static func topAnchoredFrame(from current: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: current.origin.x,
            y: current.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private extension SprintStatusStyle {
    var tint: Color {
        switch self {
        case .idle: .secondary
        case .focus: .accentColor
        case .paused: .yellow
        case .overtime: .orange
        case .complete: .green
        }
    }
}

/// Real AppKit visual effect view. SwiftUI's `Material` renders through
/// RenderBox with an in-process software blur that reruns on every content
/// change — with a once-per-second clock that pinned ~30% CPU. An
/// `NSVisualEffectView` backdrop is composited by the window server instead,
/// so per-second digit updates cost almost nothing.
private struct PanelBackdrop: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = cornerRadius
    }
}

struct FloatingPanelView: View {
    static let compactModeDefaultsKey = "panelCompactMode"
    static let hasSeenTutorialDefaultsKey = "hasSeenTutorial"
    static let tutorialRequestedDefaultsKey = "tutorialRequested"

    @Bindable var session: SprintSessionController
    var onClose: @MainActor () -> Void = {}
    var onCompactChange: @MainActor (Bool) -> Void = { _ in }

    @State private var isCompact = false
    @AppStorage(FloatingPanelView.hasSeenTutorialDefaultsKey) private var hasSeenTutorial = false
    @AppStorage(FloatingPanelView.tutorialRequestedDefaultsKey) private var tutorialRequested = false

    var body: some View {
        Group {
            if isCompact {
                CompactPanelView(
                    session: session,
                    onExpand: { setCompact(false) },
                    onClose: onClose
                )
                .padding(.horizontal, PanelMetrics.padding)
                .frame(width: PanelMetrics.compactSize.width, height: PanelMetrics.compactSize.height)
            } else {
                expandedBody
            }
        }
        .background(PanelBackdrop(cornerRadius: currentCornerRadius))
        .overlay {
            panelShape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .overlay {
            if tutorialRequested, !isCompact {
                OnboardingOverlay {
                    hasSeenTutorial = true
                    tutorialRequested = false
                }
                .clipShape(panelShape)
            }
        }
        .onAppear {
            restoreCompactPreference()
            if !hasSeenTutorial {
                tutorialRequested = true
            }
        }
        .onChange(of: session.lifecycleState) { _, newPhase in
            if newPhase == .setup, isCompact {
                setCompact(false)
            }
        }
        .onChange(of: tutorialRequested) { _, requested in
            if requested, isCompact {
                setCompact(false)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var currentCornerRadius: CGFloat {
        isCompact ? PanelMetrics.compactSize.height / 2 : PanelMetrics.cornerRadius
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
    }

    private var expandedBody: some View {
        GeometryReader { proxy in
            let showLogSidebar = PanelLayout.showsLogSidebar(forContentWidth: proxy.size.width)
            VStack(alignment: .leading, spacing: PanelMetrics.rowSpacing) {
                HStack(alignment: .top, spacing: PanelMetrics.rowSpacing) {
                    upperColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    if showLogSidebar {
                        Divider()

                        SprintLogSidebar(session: session)
                            .frame(width: PanelLayout.logSidebarWidth)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }

                PanelControlsRow(session: session)
            }
            .padding(PanelMetrics.padding)
        }
        .frame(minWidth: 260, idealWidth: 320, maxWidth: .infinity,
               minHeight: 212, idealHeight: 236, maxHeight: .infinity,
               alignment: .top)
    }

    private var upperColumn: some View {
        let compactAction: (() -> Void)? = session.lifecycleState == .setup
            ? nil
            : { setCompact(true) }

        return VStack(alignment: .leading, spacing: PanelMetrics.rowSpacing) {
            PanelStatusRow(
                status: SprintStatusPresentation(phase: session.lifecycleState),
                onCompact: compactAction,
                onClose: onClose
            )

            switch session.lifecycleState {
            case .setup:
                SetupSprintView(session: session)
            case .running, .paused, .overtimeRunning, .overtimePaused:
                ActiveSprintView(session: session)
            case .completed:
                ResultSprintView(session: session)
            }
        }
    }

    private func restoreCompactPreference() {
        guard session.lifecycleState != .setup else {
            onCompactChange(false)
            return
        }

        let stored = UserDefaults.standard.bool(forKey: Self.compactModeDefaultsKey)
        isCompact = stored
        onCompactChange(stored)
    }

    private func setCompact(_ compact: Bool) {
        isCompact = compact
        UserDefaults.standard.set(compact, forKey: Self.compactModeDefaultsKey)
        onCompactChange(compact)
    }
}

private struct PanelStatusRow: View {
    let status: SprintStatusPresentation
    var onCompact: (() -> Void)?
    let onClose: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.style.tint)
                .frame(width: 6, height: 6)

            Text(status.label)
                .font(.caption2.weight(.semibold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let onCompact {
                Button("Compact View", systemImage: "arrow.down.right.and.arrow.up.left") {
                    onCompact()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .help("Shrink to a compact timer")
            }

            Button("Hide One Clock", systemImage: "xmark") {
                onClose()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .help("Hide One Clock (Esc)")
        }
        .frame(height: PanelMetrics.statusHeight)
    }
}

/// The sprint name, editable in every phase — setup, running, paused, and
/// completed. Renames propagate to the active sprint and, once completed, to
/// its log entry.
private struct PanelTitleField: View {
    @Bindable var session: SprintSessionController
    var prompt = "Sprint name"

    var body: some View {
        TextField(prompt, text: Binding(
            get: { session.taskTitle },
            set: { session.updateTaskTitle($0) }
        ))
        .textFieldStyle(.plain)
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: PanelMetrics.titleHeight)
        .help("Click to rename this sprint")
    }
}

// Time and progress render without per-second animations (digits flip like a
// plain clock) and read the ticking properties only in leaf views, so a tick
// invalidates two small rects instead of the whole panel.
private struct PanelTimeText: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(PanelMetrics.timeFont)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(minHeight: PanelMetrics.timeMinHeight)
    }
}

private struct PanelProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, fraction))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))

                if clamped > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, proxy.size.width * clamped))
                }
            }
        }
        .drawingGroup()
        .frame(height: 4)
        .frame(height: PanelMetrics.metaHeight)
    }
}

/// One controls row for the whole panel, pinned under both columns so the
/// primary action never moves: presets + Start in setup, pause/+5m/Finish
/// while active, New Sprint after completion — always bottom-right.
private struct PanelControlsRow: View {
    private static let presetMinutes = [15, 25, 45]

    @Bindable var session: SprintSessionController

    var body: some View {
        HStack(spacing: 6) {
            switch session.lifecycleState {
            case .setup:
                ForEach(Self.presetMinutes, id: \.self) { minutes in
                    Button("\(minutes)m") {
                        session.updatePlannedDuration(TimeInterval(minutes * 60))
                    }
                    .monospacedDigit()
                    .help("Set \(minutes):00")
                }

                Spacer(minLength: 8)

                Button("Start", systemImage: "play.fill") {
                    session.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.canStart)
                .help("Start the sprint (Return)")

            case .running, .paused, .overtimeRunning, .overtimePaused:
                let isPaused = session.lifecycleState == .paused
                    || session.lifecycleState == .overtimePaused

                Button(isPaused ? "Resume" : "Pause",
                       systemImage: isPaused ? "play.fill" : "pause.fill") {
                    if isPaused {
                        session.resume()
                    } else {
                        session.pause()
                    }
                }
                .labelStyle(.iconOnly)
                .disabled(!(session.canPause || session.canResume))
                .help(isPaused ? "Resume" : "Pause")

                Button("+5m") {
                    session.addFiveMinutes()
                }
                .monospacedDigit()
                .disabled(!session.canAddFiveMinutes)
                .help("Add 5 minutes")

                Spacer(minLength: 8)

                Button("Finish", systemImage: "stop.fill") {
                    session.finish()
                }
                .labelStyle(.iconOnly)
                .disabled(!session.canFinish)
                .help("Finish sprint")

            case .completed:
                Spacer(minLength: 8)

                Button("New Sprint", systemImage: "plus.circle.fill") {
                    session.newSprint()
                }
                .buttonStyle(.borderedProminent)
                .help("Set up the next sprint")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(height: PanelMetrics.controlsHeight)
    }
}

private struct SetupSprintView: View {
    private enum Slot: Hashable {
        case task
        case digit(Int)
    }

    @Bindable var session: SprintSessionController
    @State private var digits = SprintDurationDigits()
    @FocusState private var focusedSlot: Slot?

    private var canStartFromInput: Bool {
        digits.resolvedDuration > 0
    }

    var body: some View {
        TextField("What do I want to finish?", text: Binding(
            get: { session.taskTitle },
            set: { session.updateTaskTitle($0) }
        ))
        .textFieldStyle(.plain)
        .font(.body.weight(.semibold))
        .focused($focusedSlot, equals: .task)
        .onSubmit { focusedSlot = .digit(0) }
        .frame(height: PanelMetrics.titleHeight)

        durationEditor
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(minHeight: PanelMetrics.timeMinHeight)

        Text(canStartFromInput ? "Press Return to start" : "Set a duration to start")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: PanelMetrics.metaHeight)
            .onAppear {
                digits = SprintDurationDigits(duration: session.plannedDuration)
                focusedSlot = .task
            }
            .onChange(of: session.plannedDuration) { _, newValue in
                if newValue != digits.resolvedDuration {
                    digits = SprintDurationDigits(duration: newValue)
                }
            }
    }

    /// MM:SS with a persistent colon; each digit is its own focusable slot,
    /// clickable and editable independently. Empty slots render as dimmed
    /// zeros so the value Start will use is always exactly what is shown.
    private var durationEditor: some View {
        HStack(spacing: 2) {
            digitCell(0)
            digitCell(1)

            Text(":")
                .font(PanelMetrics.timeFont)
                .foregroundStyle(.secondary)

            digitCell(2)
            digitCell(3)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if focusedSlot == nil || focusedSlot == .task {
                focusedSlot = .digit(0)
            }
        }
    }

    private func digitCell(_ index: Int) -> some View {
        let value = digits.digit(at: index)
        let isFocused = focusedSlot == .digit(index)

        return Text(value.map(String.init) ?? "0")
            .font(PanelMetrics.timeFont)
            .monospacedDigit()
            .foregroundStyle(value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFocused ? Color.accentColor.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
            .focusable()
            .focusEffectDisabled()
            .focused($focusedSlot, equals: .digit(index))
            .onTapGesture { focusedSlot = .digit(index) }
            .onKeyPress(phases: .down) { press in
                handleKey(press, at: index)
            }
            .accessibilityLabel(index < 2 ? "Minutes digit \(index + 1)" : "Seconds digit \(index - 1)")
            .accessibilityValue(value.map(String.init) ?? "empty")
    }

    private func handleKey(_ press: KeyPress, at index: Int) -> KeyPress.Result {
        if let digit = press.characters.first?.wholeNumberValue {
            if digits.setDigit(digit, at: index) {
                pushDuration()
                if index < SprintDurationDigits.slotCount - 1 {
                    focusedSlot = .digit(index + 1)
                }
            }
            return .handled
        }

        if press.key == .delete {
            if digits.digit(at: index) != nil {
                digits.clearDigit(at: index)
            } else if index > 0 {
                digits.clearDigit(at: index - 1)
                focusedSlot = .digit(index - 1)
            }
            pushDuration()
            return .handled
        }
        if press.key == .leftArrow {
            focusedSlot = .digit(max(0, index - 1))
            return .handled
        }
        if press.key == .rightArrow {
            focusedSlot = .digit(min(SprintDurationDigits.slotCount - 1, index + 1))
            return .handled
        }
        if press.key == .return {
            pushDuration()
            if canStartFromInput {
                session.start()
            }
            return .handled
        }

        return .ignored
    }

    private func pushDuration() {
        session.updatePlannedDuration(digits.resolvedDuration)
    }
}

/// Reads the per-second ticking properties in its own tiny `body` so that
/// each tick invalidates only this leaf (a small dirty rect), never the whole
/// panel. Reading `currentDate`-derived values higher up forced full-window
/// redraws every second, which is where the ~30% CPU went.
private struct ActiveTimeReadout: View {
    let session: SprintSessionController

    var body: some View {
        let phase = session.lifecycleState
        let isPaused = phase == .paused || phase == .overtimePaused
        let isOvertime = phase == .overtimeRunning || phase == .overtimePaused
        let text = isOvertime
            ? SprintTimeFormatter.overtime(session.overtimeDuration)
            : SprintTimeFormatter.minutesAndSeconds(session.remainingTime)
        let color: Color = isPaused ? .secondary : (isOvertime ? .orange : .primary)

        PanelTimeText(text: text, color: color)
    }
}

private struct ActiveProgressReadout: View {
    let session: SprintSessionController

    var body: some View {
        PanelProgressBar(
            fraction: SprintProgress.fraction(for: session.sprint, at: session.currentDate),
            tint: SprintStatusPresentation(phase: session.lifecycleState).style.tint
        )
    }
}

private struct ActiveSprintView: View {
    @Bindable var session: SprintSessionController

    var body: some View {
        PanelTitleField(session: session)

        ActiveTimeReadout(session: session)

        ActiveProgressReadout(session: session)
    }
}

private struct ResultSprintView: View {
    @Bindable var session: SprintSessionController

    var body: some View {
        PanelTitleField(session: session)

        PanelTimeText(
            text: SprintTimeFormatter.minutesAndSeconds(session.elapsedTime),
            color: .primary
        )

        Text(SprintResultSummary.caption(planned: session.plannedDuration, invested: session.elapsedTime))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: PanelMetrics.metaHeight)
    }
}

/// Log list shown beside the main column when the panel is wide enough.
/// Newest day first; within a day, sprints run morning → night, matching the
/// export format. Entry names are editable in place.
private struct SprintLogSidebar: View {
    @Bindable var session: SprintSessionController

    private var dayGroups: [(date: String, entries: [SprintLogEntry])] {
        SprintLogExport.dayGroups(entries: session.logEntries).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PanelMetrics.rowSpacing) {
            Text("Sprint Log")
                .font(.caption2.weight(.semibold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .frame(height: PanelMetrics.statusHeight)

            if session.logEntries.isEmpty {
                Text("Completed sprints show up here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(dayGroups, id: \.date) { group in
                            Text(group.date)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 2)

                            ForEach(group.entries) { entry in
                                SprintLogRow(session: session, entry: entry)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}

private struct SprintLogRow: View {
    @Bindable var session: SprintSessionController
    let entry: SprintLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            TextField("Untitled", text: Binding(
                get: { entry.title },
                set: { session.renameLogEntry(id: entry.id, to: $0) }
            ))
            .textFieldStyle(.plain)
            .font(.caption.weight(.medium))
            .help("Click to rename this entry")

            Text("Planned \(SprintTimeFormatter.minutesAndSeconds(entry.plannedDuration)) · Complete \(SprintTimeFormatter.minutesAndSeconds(entry.investedDuration))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pill-shaped compact mode: state dot, live time, task title, finish, expand,
/// and hide controls. The sprint keeps running until the user finishes it;
/// this is the minimal-footprint anchor for deep work.
private struct CompactPanelView: View {
    @Bindable var session: SprintSessionController
    let onExpand: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    private var status: SprintStatusPresentation {
        SprintStatusPresentation(phase: session.lifecycleState)
    }

    private var isPaused: Bool {
        session.lifecycleState == .paused || session.lifecycleState == .overtimePaused
    }

    private var isOvertime: Bool {
        session.lifecycleState == .overtimeRunning || session.lifecycleState == .overtimePaused
    }

    private var timeText: String {
        switch session.lifecycleState {
        case .completed:
            SprintTimeFormatter.minutesAndSeconds(session.elapsedTime)
        case .overtimeRunning, .overtimePaused:
            SprintTimeFormatter.overtime(session.overtimeDuration)
        default:
            SprintTimeFormatter.minutesAndSeconds(session.remainingTime)
        }
    }

    private var timeColor: Color {
        if isPaused {
            return .secondary
        }
        return isOvertime ? .orange : .primary
    }

    private var displayTitle: String {
        let title = session.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled Sprint" : title
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.style.tint)
                .frame(width: 6, height: 6)

            Text(timeText)
                .font(.system(size: PanelMetrics.compactTimeFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(timeColor)

            Text(displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(displayTitle)

            Spacer(minLength: 4)

            if session.canFinish {
                Button("Finish", systemImage: "stop.fill") {
                    session.finish()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .help("Finish sprint")
                .accessibilityHint("Stops timing and records this sprint")
            }

            Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
                onExpand()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .help("Expand One Clock")

            Button("Hide One Clock", systemImage: "xmark") {
                onClose()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .help("Hide One Clock (Esc)")
        }
        .accessibilityElement(children: .contain)
    }
}

/// First-run coach overlay: dims the panel and walks through the flow in
/// seven quick steps, ending with a "try it yourself" call to action.
private struct OnboardingOverlay: View {
    let onFinish: () -> Void

    @State private var stepIndex = 0

    private var step: OnboardingStep {
        OnboardingFlow.steps[stepIndex]
    }

    private var isLastStep: Bool {
        stepIndex == OnboardingFlow.steps.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 10) {
                Image(systemName: step.symbolName)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 26)

                Text(step.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(step.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    ForEach(OnboardingFlow.steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index <= stepIndex ? Color.accentColor : Color.primary.opacity(0.15))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.top, 2)

                HStack {
                    if !isLastStep {
                        Button("Skip") {
                            onFinish()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(isLastStep ? "Try it now" : "Next") {
                        if isLastStep {
                            onFinish()
                        } else {
                            stepIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(width: 236)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    FloatingPanelView(session: SprintSessionController())
        .padding()
}
