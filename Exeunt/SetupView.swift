import SwiftUI

enum Setup {
    /// A required step is undone: no Accessibility access, or launch at login off without the user choosing that.
    static var missingStep: Bool {
        !Permission.shared.trusted || (!Settings.shared.launchAtLogin && !Settings.shared.loginOptOut)
    }
}

/// The entry point: a checklist that ticks itself off as each step gets done.
struct SetupView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var permission = Permission.shared

    var body: some View {
        VStack(spacing: 0) {
            Curtain(subtitle: "Three steps and the curtain's up.")
            VStack(alignment: .leading, spacing: 0) {
                Step(number: 1, done: permission.trusted, title: "Allow Accessibility access",
                     detail: "Exeunt counts each app's windows and asks the app to quit, which macOS only allows once you switch Exeunt on in Privacy & Security > Accessibility. If it isn't listed, press + and choose Exeunt from Applications.",
                     action: ("Open Accessibility Settings", permission.request))
                Divider()
                Step(number: 2, done: settings.launchAtLogin, title: "Open Exeunt at login",
                     detail: "So it's already watching when you start your Mac.",
                     action: ("Turn On", { settings.launchAtLogin = true }))
                Divider()
                Step(number: 3, done: settings.hasQuitAnApp, title: "Try it",
                     detail: "Open TextEdit, close its window with the red button or Cmd+W, and watch it quit.",
                     action: ("Open TextEdit", openTextEdit))
                    .disabled(!permission.trusted)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            HStack {
                Button("Settings…") { Windows.settings.show() }
                Spacer()
                Button("Done") { Windows.setup.close() }.keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 24)
            .padding(.top, 8)
        }
        .frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func openTextEdit() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct Step: View {
    let number: Int
    let done: Bool
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let action: (LocalizedStringKey, () -> Void)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green : Stage.gilt.opacity(0.18))
                if done {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(Stage.serif(15, .semibold)).foregroundStyle(Stage.velvet)
                }
            }
            .frame(width: 28, height: 28)
            .animation(.easeOut(duration: 0.25), value: done)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(done ? .secondary : .primary)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !done {
                    Button(action.0, action: action.1).buttonStyle(.borderedProminent).tint(Stage.velvet)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(number)")
        .accessibilityValue(done ? "Done" : "To do")
    }
}
