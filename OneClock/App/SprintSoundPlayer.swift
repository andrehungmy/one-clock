import AppKit

@MainActor
final class SystemSprintCuePlayer: SprintCuePlaying {
    func playOvertimeCue() {
        NSSound(named: "Ping")?.play()
    }

    func playFinishCue() {
        NSSound(named: "Glass")?.play()
    }
}
