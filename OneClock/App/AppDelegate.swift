import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sprintSession: SprintSessionController?

    private var isPrimaryInstance = true

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
            return
        }

        isPrimaryInstance = false
        NSRunningApplication(processIdentifier: primaryProcessIdentifier)?.activate(options: [])
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard isPrimaryInstance else {
            return
        }

        Self.sprintSession?.prepareForTermination()
    }
}
