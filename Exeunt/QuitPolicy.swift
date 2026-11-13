import Foundation

/// Decides whether an app should be quit after a possible window close.
struct QuitPolicy: Equatable {
    enum Mode: String, CaseIterable {
        case allExcept, onlyListed
    }

    static let neverQuit: Set<String> = ["com.apple.finder", "uk.co.onibaku.exeunt"]

    var enabled = true
    var mode = Mode.allExcept
    var list: Set<String> = []

    /// `after` is nil when the window count couldn't be read, which never quits.
    func shouldQuit(bundleID: String?, windowsBefore: Int, windowsAfter: Int?) -> Bool {
        guard enabled, let id = bundleID, !Self.neverQuit.contains(id),
              windowsBefore > 0, windowsAfter == 0 else { return false }
        return mode == .allExcept ? !list.contains(id) : list.contains(id)
    }
}
