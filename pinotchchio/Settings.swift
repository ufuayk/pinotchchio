import SwiftUI
import ServiceManagement

enum Page { case tasks, archive, settings }

final class AppState: ObservableObject {
    @Published var page: Page = .tasks
    @Published var isAdding = false     
    @Published var listHeight: CGFloat = 0   
    @Published var isOpen = false        
}

final class AppSettings: ObservableObject {
    @Published var languageCode: String {
        didSet { UserDefaults.standard.set(languageCode, forKey: "pinatnotch.language") }
    }
    @Published var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "pinatnotch.showMenuBarIcon") }
    }
    @Published var liquidGlass: Bool {
        didSet { UserDefaults.standard.set(liquidGlass, forKey: "pinatnotch.liquidGlass") }
    }
    @Published var launchAtLogin: Bool

    init() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: "pinatnotch.language") ?? "en"
        languageCode = Localizer.shared.packs.contains { $0.code == saved } ? saved : "en"
        showMenuBarIcon = d.object(forKey: "pinatnotch.showMenuBarIcon") as? Bool ?? true
        liquidGlass = d.bool(forKey: "pinatnotch.liquidGlass")   
        launchAtLogin = SMAppService.mainApp.status == .enabled  
    }

    func t(_ key: Str) -> String {
        Localizer.shared.string(key, code: languageCode)
    }

    var languageName: String {
        Localizer.shared.packs.first { $0.code == languageCode }?.name ?? languageCode
    }

    func cycleLanguage() {
        let packs = Localizer.shared.packs
        guard !packs.isEmpty else { return }
        let i = packs.firstIndex { $0.code == languageCode } ?? 0
        languageCode = packs[(i + 1) % packs.count].code
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
