import AppKit
import Carbon.HIToolbox

@MainActor
final class PanelAccessCoordinator {
    static let shared = PanelAccessCoordinator()

    weak var appState: AppState?

    func requestShowPanel() {
        appState?.showPanel()
    }
}

private enum PanelAccessRequest {
    private static let namePrefix = "dev.andrehung.OneClock.show-panel"

    static func notificationName(bundleIdentifier: String) -> CFNotificationName {
        CFNotificationName("\(namePrefix).\(bundleIdentifier)" as CFString)
    }

    static func post(bundleIdentifier: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName(bundleIdentifier: bundleIdentifier),
            nil,
            nil,
            true
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sprintSession: SprintSessionController?

    private var isPrimaryInstance = true
    private var observedPanelRequestName: CFNotificationName?
    private var globalPanelShortcut: GlobalPanelShortcut?

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let runningApplications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).filter { !$0.isTerminated }
        let instances = runningApplications.map {
            AppInstanceIdentity(
                processIdentifier: $0.processIdentifier,
                launchDate: $0.launchDate
            )
        }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        guard let primaryProcessIdentifier = SingleInstancePolicy.primaryProcessIdentifier(in: instances),
              primaryProcessIdentifier != currentProcessIdentifier else {
            observePanelAccessRequests(bundleIdentifier: bundleIdentifier)
            return
        }

        isPrimaryInstance = false
        PanelAccessRequest.post(bundleIdentifier: bundleIdentifier)
        NSRunningApplication(processIdentifier: primaryProcessIdentifier)?.activate(options: [])
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        globalPanelShortcut = GlobalPanelShortcut {
            PanelAccessCoordinator.shared.requestShowPanel()
        }
        globalPanelShortcut?.register()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        PanelAccessCoordinator.shared.requestShowPanel()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopObservingPanelAccessRequests()

        guard isPrimaryInstance else {
            return
        }

        Self.sprintSession?.prepareForTermination()
    }

    private func observePanelAccessRequests(bundleIdentifier: String) {
        let name = PanelAccessRequest.notificationName(bundleIdentifier: bundleIdentifier)
        observedPanelRequestName = name
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else {
                    return
                }

                let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    delegate.handlePanelAccessRequest()
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func stopObservingPanelAccessRequests() {
        guard let observedPanelRequestName else {
            return
        }

        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            observedPanelRequestName,
            nil
        )
        self.observedPanelRequestName = nil
    }

    fileprivate func handlePanelAccessRequest() {
        NSApp.activate(ignoringOtherApps: true)
        PanelAccessCoordinator.shared.requestShowPanel()
    }
}

private final class GlobalPanelShortcut: @unchecked Sendable {
    private static let signature: OSType = 0x4F4E434C // "ONCL"
    private static let identifier: UInt32 = 1

    private let action: @MainActor () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr,
                      hotKeyID.signature == GlobalPanelShortcut.signature,
                      hotKeyID.id == GlobalPanelShortcut.identifier else {
                    return OSStatus(eventNotHandledErr)
                }

                let shortcut = Unmanaged<GlobalPanelShortcut>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    shortcut.action()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }
}
