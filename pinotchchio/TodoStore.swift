import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
}

struct ArchivedItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var deleted: Bool  
}

private struct Snapshot: Codable {
    var items: [TodoItem]
    var archive: [ArchivedItem]
}

final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = [] { didSet { scheduleSave() } }
    @Published var archive: [ArchivedItem] = [] { didSet { scheduleSave() } }

    private var saveWork: DispatchWorkItem?

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("NotchTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    init() {
        var migrated = false
        if let data = try? Data(contentsOf: fileURL),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            items = snap.items
            archive = snap.archive
        } else if let old = UserDefaults.standard.data(forKey: "notchtodo.items"),
                  let list = try? JSONDecoder().decode([TodoItem].self, from: old) {
            items = list          // v1'den taşı
            migrated = true
        }
        let finished = items.filter { $0.isDone }
        if !finished.isEmpty {
            items.removeAll { $0.isDone }
            archive.insert(contentsOf: finished.map { ArchivedItem(id: $0.id, title: $0.title, deleted: false) }, at: 0)
        }
        if migrated { flush() }
    }

    func add(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) { items.append(TodoItem(title: t)) }
    }

    func rename(_ id: UUID, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].title = t
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { items[i].isDone.toggle() }
        guard items[i].isDone else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        let id = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self,
                  let i = self.items.firstIndex(where: { $0.id == id && $0.isDone }) else { return }
            self.moveToArchive(at: i, deleted: false)
        }
    }

    func delete(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        moveToArchive(at: i, deleted: true)
    }

    func resetArchive() {
        withAnimation(.easeInOut(duration: 0.2)) { archive.removeAll() }
    }

    private func moveToArchive(at i: Int, deleted: Bool) {
        let it = items[i]
        withAnimation(.easeInOut(duration: 0.25)) {
            items.remove(at: i)
            archive.insert(ArchivedItem(id: it.id, title: it.title, deleted: deleted), at: 0)
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flush() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
    }

    func flush() {
        saveWork?.cancel()
        if let data = try? JSONEncoder().encode(Snapshot(items: items, archive: archive)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
