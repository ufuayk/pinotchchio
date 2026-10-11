import AppKit
import SwiftUI
import Combine

final class NotchPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

final class NotchController: NSObject {
    let store = TodoStore()
    let settings = AppSettings()
    let state = AppState()

    private let panel: NotchPanel
    private let host: NSHostingView<AnyView>
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var statusItem: NSStatusItem?
    private var cachedNotch = NSRect.zero
    private(set) var isExpanded = false

    override init() {
        host = NSHostingView(rootView: AnyView(EmptyView()))
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel = NotchPanel(contentRect: .zero,
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered,
                           defer: false)
        super.init()

        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.onCancel = { [weak self] in
            guard let self = self else { return }
            if self.state.page != .tasks { self.state.page = .tasks } else { self.collapse() }
        }

        cachedNotch = computeNotchRect()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.cachedNotch = self.computeNotchRect()
        }

        installMonitors()
        refreshStatusItem()

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)
    }

    private var targetScreen: NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func computeNotchRect() -> NSRect {
        let s = targetScreen
        var w: CGFloat = 200
        var h: CGFloat = max(24, s.frame.maxY - s.visibleFrame.maxY)
        if s.safeAreaInsets.top > 0 {
            h = s.safeAreaInsets.top
            if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
                w = s.frame.width - l.width - r.width
            }
        }
        return NSRect(x: s.frame.midX - w / 2, y: s.frame.maxY - h, width: w, height: h)
    }

    private var notchSize: CGSize { CGSize(width: cachedNotch.width, height: cachedNotch.height) }

    private func windowRect() -> NSRect {
        let s = targetScreen
        let h = Layout.maxHeight(notch: cachedNotch.height)
        return NSRect(x: s.frame.midX - Layout.width / 2, y: s.frame.maxY - h, width: Layout.width, height: h)
    }

    private func visibleRect() -> NSRect {
        let s = targetScreen
        let h = Layout.height(page: state.page, tasks: store.items.count, listHeight: state.listHeight, archived: store.archive.count,
                              adding: state.isAdding, notch: cachedNotch.height)
        return NSRect(x: s.frame.midX - Layout.width / 2, y: s.frame.maxY - h, width: Layout.width, height: h)
    }

    private func isOnNotch(_ p: NSPoint) -> Bool {
        cachedNotch.insetBy(dx: -4, dy: -4).contains(p)
    }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true

        state.isOpen = false
        host.rootView = AnyView(
            TodoView(notch: notchSize)
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(state)
        )
        panel.setFrame(windowRect(), display: false)
        panel.orderFrontRegardless()
        panel.makeKey()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self = self, self.isExpanded else { return }
            self.state.isOpen = true
        }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        NotificationCenter.default.post(name: .notchDidCollapse, object: nil) 
        store.flush()                                                          
        state.isOpen = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, !self.isExpanded else { return }
            self.panel.orderOut(nil)
            self.host.rootView = AnyView(EmptyView()) 
            self.state.page = .tasks
            self.state.isAdding = false
        }
    }

    private func refreshStatusItem() {
        guard settings.showMenuBarIcon else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "pinotchchio")
            statusItem = item
        }
        let menu = NSMenu()
        let open = NSMenuItem(title: settings.t(.openApp), action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self
        let quit = NSMenuItem(title: settings.t(.quit), action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func openFromMenu() { expand() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func installMonitors() {
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            guard let self = self else { return }
            let p = NSEvent.mouseLocation
            if self.isExpanded {
                if !self.visibleRect().contains(p) { self.collapse() }
            } else if self.isOnNotch(p) {
                self.expand()
            }
        }) { monitors.append(g) }

        if let l = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            guard let self = self, self.isExpanded else { return event }
            let p = NSEvent.mouseLocation
            if self.isOnNotch(p) {
                self.collapse()
                return nil
            }
            if !self.visibleRect().contains(p) {
                self.collapse()
            }
            return event
        }) { monitors.append(l) }
    }

    deinit {
        monitors.forEach { NSEvent.removeMonitor($0) }
    }
}
