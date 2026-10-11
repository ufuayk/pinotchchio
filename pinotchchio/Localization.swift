import Foundation

enum Str: String {
    case add, history, liquidGlass, newTask, archive, settings, emptyArchive, resetArchive, resetConfirm
    case launchAtLogin, menuBarIcon, language, openApp, quit
}

struct LanguagePack {
    let code: String   // "fr.json" -> "fr"
    let name: String 
    let strings: [String: String]
}

final class Localizer {
    static let shared = Localizer()
    let packs: [LanguagePack]
    private let byCode: [String: LanguagePack]

    private struct Raw: Decodable {
        let name: String
        let strings: [String: String]
    }

    private init() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Languages") ?? []
        var list: [LanguagePack] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let raw = try? JSONDecoder().decode(Raw.self, from: data) else { continue }
            list.append(LanguagePack(code: url.deletingPathExtension().lastPathComponent,
                                     name: raw.name,
                                     strings: raw.strings))
        }
        list.sort { a, b in
            if a.code == "en" { return true }
            if b.code == "en" { return false }
            return a.name < b.name
        }
        packs = list
        byCode = Dictionary(uniqueKeysWithValues: list.map { ($0.code, $0) })
    }

    func string(_ key: Str, code: String) -> String {
        byCode[code]?.strings[key.rawValue]
            ?? byCode["en"]?.strings[key.rawValue]
            ?? key.rawValue
    }
}
