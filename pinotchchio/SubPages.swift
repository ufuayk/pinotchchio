import SwiftUI

struct ArchivePage: View {
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if store.archive.isEmpty {
            Text(settings.t(.emptyArchive))
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.row)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.archive) { a in
                        HStack(spacing: 10) {
                            Spacer(minLength: 0)
                            Image(systemName: a.deleted ? "trash" : "checkmark.circle.fill")
                                .font(.system(size: a.deleted ? 12 : 17))
                                .foregroundColor(Color.gray)
                                .frame(width: 17)
                            Text(a.title)
                                .font(.system(size: 14))
                                .foregroundColor(Color.gray)
                                .strikethrough(a.deleted)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(height: Layout.row)
                    }
                }
            }
        }
    }
}

struct SettingsPage: View {
    @EnvironmentObject var settings: AppSettings
    @State private var devHover = false

    private let devURL = URL(string: "https://github.com/ufuayk")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(settings.t(.launchAtLogin)) {
                switchView(Binding(get: { settings.launchAtLogin },
                                   set: { settings.setLaunchAtLogin($0) }))
            }
            row(settings.t(.menuBarIcon)) {
                switchView($settings.showMenuBarIcon)
            }
            row(settings.t(.liquidGlass)) {
                switchView($settings.liquidGlass)
            }
            Button {
                settings.cycleLanguage()
            } label: {
                row(settings.t(.language)) {
                    HStack(spacing: 4) {
                        Text(settings.languageName).font(.system(size: 13))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                    }
                    .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                row(settings.t(.quit)) {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Text("pinotchchio")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                Spacer(minLength: 0)
                Button {
                    NSWorkspace.shared.open(devURL)
                } label: {
                    Text("ufuayk")
                        .font(.system(size: 12))
                        .underline(devHover)
                        .foregroundColor(devHover ? Color.white : Color.white.opacity(0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { devHover = $0 }
                .animation(.easeOut(duration: 0.15), value: devHover)
            }
            .frame(height: Layout.row)
        }
    }

    private func row<T: View>(_ title: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(.white)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: Layout.row)
        .contentShape(Rectangle())
    }

    private func switchView(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
    }
}
