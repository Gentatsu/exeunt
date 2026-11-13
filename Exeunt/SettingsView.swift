import SwiftUI
import UniformTypeIdentifiers

/// Stage colours: velvet curtain, gilt and programme paper.
enum Stage {
    static let velvet = Color(red: 0.47, green: 0.06, blue: 0.11)
    static let velvetDeep = Color(red: 0.22, green: 0.02, blue: 0.05)
    static let gilt = Color(red: 0.86, green: 0.67, blue: 0.32)
    static let paper = Color(red: 0.99, green: 0.96, blue: 0.90)
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var permission = Permission.shared

    var body: some View {
        VStack(spacing: 0) {
            Curtain()
            VStack(alignment: .leading, spacing: 18) {
                PermissionCard(trusted: permission.trusted, request: permission.request)
                Toggle("Quit apps when their last window closes", isOn: $settings.enabled)
                    .font(.headline)
                AppListSection(settings: settings).disabled(!settings.enabled)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Open Exeunt at login", isOn: $settings.launchAtLogin)
                    Toggle("Show in menu bar", isOn: $settings.showIcon)
                    Text("With the icon hidden, open Exeunt again from Launchpad or Spotlight to see these settings.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// The header: folds of velvet with the name in gilt.
struct Curtain: View {
    var subtitle = "When the last window closes, the app leaves the stage."

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<14, id: \.self) { _ in
                    LinearGradient(colors: [Stage.velvetDeep, Stage.velvet, Stage.velvet.opacity(0.85), Stage.velvetDeep],
                                   startPoint: .leading, endPoint: .trailing)
                }
            }
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 6) {
                Text("Exeunt").font(Stage.serif(44, .semibold)).foregroundStyle(Stage.gilt)
                Text(subtitle)
                    .font(Stage.serif(14).italic()).foregroundStyle(Stage.paper.opacity(0.9))
            }
            .padding(.top, 18)
            .accessibilityElement(children: .combine)
        }
        .frame(height: 150)
        .overlay(alignment: .bottom) { Rectangle().fill(Stage.gilt).frame(height: 3) }
    }
}

struct PermissionCard: View {
    let trusted: Bool
    let request: () -> Void

    var body: some View {
        if trusted {
            Label("Accessibility access is on. Exeunt is watching for closed windows.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Exeunt needs Accessibility access", systemImage: "hand.raised.fill")
                    .font(Stage.serif(17, .semibold))
                Text("To tell when an app's last window has closed, Exeunt counts each app's windows, then asks the app to quit, just as Cmd+Q would. macOS only allows that for apps you grant Accessibility access. Exeunt never reads what's in your windows, and nothing leaves your Mac.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Open the settings, then switch on Exeunt. If it isn't listed, press + and choose Exeunt from Applications.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings", action: request).buttonStyle(.borderedProminent).tint(Stage.velvet)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Stage.gilt.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Stage.gilt.opacity(0.6)))
        }
    }
}

struct AppListSection: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Which apps", selection: $settings.mode) {
                Text("Quit every app, except the ones listed").tag(QuitPolicy.Mode.allExcept)
                Text("Only quit the apps listed").tag(QuitPolicy.Mode.onlyListed)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            VStack(spacing: 0) {
                if settings.list.isEmpty {
                    Text(settings.mode == .allExcept ? "No exceptions yet: every app takes its bow."
                                                     : "No apps listed yet, so nothing will be quit.")
                        .font(Stage.serif(13).italic()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                ForEach(settings.list, id: \.self) { id in
                    AppRow(bundleID: id) { settings.list.removeAll { $0 == id } }
                    if id != settings.list.last { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))

            HStack {
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") { settings.add(app.bundleIdentifier!) }
                    }
                }
                .fixedSize()
                Button("Choose from Applications…", action: choose)
                Spacer()
                Text("Finder is never quit.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let id = app.bundleIdentifier else { return false }
                return !QuitPolicy.neverQuit.contains(id) && !settings.list.contains(id)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { if let id = Bundle(url: url)?.bundleIdentifier { settings.add(id) } }
    }
}

struct AppRow: View {
    let bundleID: String
    let remove: () -> Void

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let name = url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        HStack(spacing: 10) {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed").font(.title2).frame(width: 24, height: 24)
            }
            Text(name ?? bundleID)
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(name ?? bundleID)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
