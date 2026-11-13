#if DEBUG
import SwiftUI

/// Renders the README screenshots from the real settings view, at 2x: `Exeunt -shots <dir>`.
enum Screenshots {
    static func render(to dir: String) {
        let settings = Settings(defaults: UserDefaults(suiteName: "shots-\(UUID())")!, live: false)
        settings.list = ["com.apple.Music", "com.apple.Terminal", "com.apple.MobileSMS"]
        write(SettingsView(settings: settings, permission: Permission(trusted: true)), to: dir + "/settings.png")
        settings.launchAtLogin = true
        write(SetupView(settings: settings, permission: Permission(trusted: true)), to: dir + "/setup.png")
    }

    private static func write(_ view: some View, to path: String) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        host.layoutSubtreeIfNeeded()
        let size = host.bounds.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#endif
