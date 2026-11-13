import AppKit
import ApplicationServices

/// Tracks the Accessibility grant and starts the watcher once it's there.
final class Permission: ObservableObject {
    static let shared = Permission(trusted: AXIsProcessTrusted())
    @Published private(set) var trusted: Bool
    private var timer: Timer?

    init(trusted: Bool) { self.trusted = trusted }

    func startPolling() {
        update()
        // The grant can be added or removed in System Settings at any time.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.update() }
    }

    private func update() {
        let now = AXIsProcessTrusted()
        if now != trusted {
            trusted = now
            if !now { Windows.setup.show() }  // Revoked while running.
        }
        if now { Watcher.shared.start() }
        Settings.shared.refreshLoginItem()
    }

    /// Adds Exeunt to the Accessibility list, then opens that pane of System Settings.
    func request() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
