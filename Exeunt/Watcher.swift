import AppKit
import ApplicationServices

/// Watches clicks and Cmd+W, and quits an app once its last window has gone.
///
/// AX "window destroyed" notifications don't fire on macOS 26, so instead: count the app's standard windows just
/// before a possible close (mouse-down, Cmd pressed) and again just after (mouse-up, Cmd+W). Windows before and none
/// after means the last one closed.
final class Watcher {
    static let shared = Watcher()
    private var monitor: Any?
    private var before: (pid: pid_t, count: Int)?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .flagsChanged, .keyDown]) {
            [weak self] event in self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch event.type {
        case .leftMouseDown: snapshot(pidUnderMouse() ?? frontmostPID())
        case .leftMouseUp: checkSoon()
        case .flagsChanged where cmd: snapshot(frontmostPID())
        case .keyDown where cmd && event.charactersIgnoringModifiers?.lowercased() == "w": checkSoon()
        default: break
        }
    }

    private func snapshot(_ pid: pid_t?) {
        guard let pid, let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
              Settings.shared.enabled, let count = Self.standardWindowCount(pid) else { before = nil; return }
        before = (pid, count)
    }

    private func checkSoon() {
        guard let before, before.count > 0 else { return }
        // Give the window time to close, or the app time to open a replacement.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let app = NSRunningApplication(processIdentifier: before.pid), !app.isTerminated else { return }
            let after = Self.standardWindowCount(before.pid)
            // Keep the count current, so a second Cmd+W with Cmd still held compares against the right number.
            if let after, self?.before?.pid == before.pid { self?.before = (before.pid, after) }
            if Settings.shared.policy.shouldQuit(bundleID: app.bundleIdentifier, windowsBefore: before.count,
                                                 windowsAfter: after) {
                Self.quit(app)
                if !Settings.shared.hasQuitAnApp { Settings.shared.hasQuitAnApp = true }
            }
        }
    }

    private func frontmostPID() -> pid_t? { NSWorkspace.shared.frontmostApplication?.processIdentifier }

    /// The app that owns whatever is under the pointer, so a close button on a background window counts.
    private func pidUnderMouse() -> pid_t? {
        guard let screen = NSScreen.screens.first else { return nil }
        let point = NSEvent.mouseLocation
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x),
                                               Float(screen.frame.maxY - point.y), &element) == .success,
              let element else { return nil }
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    static func standardWindowCount(_ pid: pid_t) -> Int? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
        if err == .noValue { return 0 }
        guard err == .success, let windows = value as? [AXUIElement] else { return nil }
        return windows.filter { window in
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
            return subrole as? String == kAXStandardWindowSubrole
        }.count
    }

    /// Presses the app's own Quit menu item. `terminate()` sends an Apple Event, which under the hardened runtime
    /// means an Automation prompt for every app, so it's only the fallback.
    static func quit(_ app: NSRunningApplication) {
        if let item = quitMenuItem(app.processIdentifier),
           AXUIElementPerformAction(item, kAXPressAction as CFString) == .success { return }
        app.terminate()
    }

    private static func quitMenuItem(_ pid: pid_t) -> AXUIElement? {
        guard let bar = attribute(AXUIElementCreateApplication(pid), kAXMenuBarAttribute),
              CFGetTypeID(bar) == AXUIElementGetTypeID() else { return nil }
        // Skip the Apple menu; the app menu comes next and is where Quit lives.
        for menu in children(bar as! AXUIElement).dropFirst() {
            for list in children(menu) {
                for item in children(list) {
                    let key = (attribute(item, kAXMenuItemCmdCharAttribute) as? String)?.uppercased()
                    if key == "Q", attribute(item, kAXMenuItemCmdModifiersAttribute) as? Int == 0 { return item }
                }
            }
        }
        return nil
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
