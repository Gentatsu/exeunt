import SwiftUI

@main
struct ExeuntApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permission = Permission.shared

    var body: some Scene {
        // MenuBarExtra writes isInserted back on every update; passing equal values through re-publishes and loops.
        let showIcon = Binding(get: { settings.showIcon }, set: { if $0 != settings.showIcon { settings.showIcon = $0 } })
        MenuBarExtra("Exeunt", systemImage: "theatermasks", isInserted: showIcon) {
            Toggle("Quit Apps When Their Last Window Closes", isOn: $settings.enabled)
            if !permission.trusted {
                Button("Needs Accessibility Access…") { Windows.setup.show() }
            }
            Divider()
            Button("Setup…") { Windows.setup.show() }
            Button("Settings…") { Windows.settings.show() }.keyboardShortcut(",")
            Button("Quit Exeunt") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTesting else { return }
        #if DEBUG
        if let dir = UserDefaults.standard.string(forKey: "shots") { Screenshots.render(to: dir); exit(0) }
        #endif
        // A windowless agent would otherwise be eligible for automatic termination.
        ProcessInfo.processInfo.disableAutomaticTermination("Watching for closed windows")
        Permission.shared.startPolling()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "seenSetup") || Setup.missingStep {
            defaults.set(true, forKey: "seenSetup")
            Windows.setup.show()
        }
    }

    /// Opening Exeunt again from Launchpad, Spotlight or Finder shows setup, the way back in with the icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Windows.setup.show()
        return true
    }
}

/// The app's two windows, made on first use and reused after.
final class Windows {
    static let setup = Windows(title: String(localized: "Exeunt Setup")) { AnyView(SetupView()) }
    static let settings = Windows(title: "Exeunt") { AnyView(SettingsView()) }

    private let title: String
    private let content: () -> AnyView
    private var window: NSWindow?

    private init(title: String, content: @escaping () -> AnyView) {
        self.title = title
        self.content = content
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: content()))
            w.title = title
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}
