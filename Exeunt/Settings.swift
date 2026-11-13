import AppKit
import ServiceManagement

/// User preferences, kept in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults: UserDefaults
    /// Demo copies (screenshots) and test runs never touch the real login item.
    private let live: Bool

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var mode: QuitPolicy.Mode { didSet { defaults.set(mode.rawValue, forKey: "mode") } }
    @Published var list: [String] { didSet { defaults.set(list, forKey: "list") } }
    @Published var showIcon: Bool { didSet { defaults.set(showIcon, forKey: "showIcon") } }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(!launchAtLogin, forKey: "loginOptOut")
            guard live, launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                try launchAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            } catch {
                NSLog("Exeunt: login item change failed: \(error)")
            }
        }
    }

    /// Set the first time Exeunt quits something, which ticks off setup's "try it" step.
    @Published var hasQuitAnApp: Bool { didSet { defaults.set(hasQuitAnApp, forKey: "hasQuitAnApp") } }
    /// Off by the user's own choice, so setup doesn't nag about it.
    var loginOptOut: Bool { defaults.bool(forKey: "loginOptOut") }

    var policy: QuitPolicy { QuitPolicy(enabled: enabled, mode: mode, list: Set(list)) }

    init(defaults: UserDefaults = .standard, live: Bool = !isTesting) {
        self.defaults = defaults
        self.live = live
        defaults.register(defaults: ["enabled": true, "mode": QuitPolicy.Mode.allExcept.rawValue, "showIcon": true])
        enabled = defaults.bool(forKey: "enabled")
        mode = QuitPolicy.Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .allExcept
        list = defaults.stringArray(forKey: "list") ?? []
        showIcon = defaults.bool(forKey: "showIcon")
        hasQuitAnApp = defaults.bool(forKey: "hasQuitAnApp")
        // Launch at login is on by default: register once, on first run.
        if live, !defaults.bool(forKey: "registeredLogin") {
            defaults.set(true, forKey: "registeredLogin")
            try? SMAppService.mainApp.register()
        }
        launchAtLogin = live ? SMAppService.mainApp.status == .enabled : true
    }

    /// Picks up changes made in System Settings > General > Login Items.
    func refreshLoginItem() {
        guard live else { return }
        let on = SMAppService.mainApp.status == .enabled
        if on != launchAtLogin { launchAtLogin = on }
    }

    func add(_ bundleID: String) {
        if !list.contains(bundleID), !QuitPolicy.neverQuit.contains(bundleID) { list.append(bundleID) }
    }
}

let isTesting = NSClassFromString("XCTestCase") != nil
