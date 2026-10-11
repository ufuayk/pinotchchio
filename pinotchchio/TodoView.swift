import SwiftUI

extension Notification.Name {
    static let notchDidCollapse = Notification.Name("notchDidCollapse")
}

enum Layout {
    static let width: CGFloat = 360
    static let row: CGFloat = 32
    static let topGap: CGFloat = 6
    static let bottomPad: CGFloat = 12
    static let sidePad: CGFloat = 18
    static let maxRows = 8

    static func height(page: Page, tasks: Int, listHeight: CGFloat, archived: Int, adding: Bool, notch: CGFloat) -> CGFloat {
        let content: CGFloat
        switch page {
        case .tasks:
            let list = tasks == 0 ? 0 : max(listHeight, CGFloat(tasks) * row)
            content = min(list, CGFloat(maxRows) * row) + (adding ? row : 0) + row
        case .archive:  content = CGFloat(max(1, min(archived, maxRows))) * row
        case .settings: content = 6 * row                                   // 5 ayar + alt bilgi
        }
        return notch + topGap + content + bottomPad
    }

    static func maxHeight(notch: CGFloat) -> CGFloat {
        notch + topGap + CGFloat(maxRows + 2) * row + bottomPad
    }
}

enum Anim {
    static let open  = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.5)
    static let fit   = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.35)
    static let close = Animation.timingCurve(0.45, 0.0, 0.2, 1.0, duration: 0.3)
    static let page  = Animation.easeInOut(duration: 0.2)
}

struct NotchShape: Shape {
    var radius: CGFloat = 22

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = max(0, min(radius, rect.height, rect.width / 2))
        let k: CGFloat = 0.4477
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY - r * k),
                   control2: CGPoint(x: rect.maxX - r * k, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                   control1: CGPoint(x: rect.minX + r * k, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.maxY - r * k))
        p.closeSubpath()
        return p
    }
}

struct TodoView: View {
    let notch: CGSize
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var settings: AppSettings

    @State private var confirmingReset = false

    private var targetHeight: CGFloat {
        Layout.height(page: state.page, tasks: store.items.count, listHeight: state.listHeight,
                      archived: store.archive.count, adding: state.isAdding, notch: notch.height)
    }

    var body: some View {
        let open = state.isOpen
        let radius: CGFloat = open ? 22 : 9

        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                pageView
                    .id(state.page)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .animation(Anim.page, value: state.page)
            .padding(.top, notch.height + Layout.topGap)
            .padding(.horizontal, Layout.sidePad)
            .padding(.bottom, Layout.bottomPad)

            topBar
        }
        .frame(width: Layout.width)
        .opacity(open ? 1 : 0)
        .animation(.easeOut(duration: 0.18).delay(open ? 0.12 : 0), value: open)
        .frame(width: open ? Layout.width : notch.width,
               height: open ? targetHeight : notch.height,
               alignment: .top)
        .background(backdrop(radius))
        .clipShape(NotchShape(radius: radius))
        .animation(open ? Anim.open : Anim.close, value: open)
        .animation(Anim.fit, value: targetHeight)
        .contextMenu {
            Button(settings.t(.quit)) { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func backdrop(_ radius: CGFloat) -> some View {
        if settings.liquidGlass {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: NotchShape(radius: radius))
            } else {
                VisualEffectBackground()
            }
            #else
            VisualEffectBackground()
            #endif
        } else {
            NotchShape(radius: radius).fill(Color.black)
        }
    }

    @ViewBuilder
    private var pageView: some View {
        switch state.page {
        case .tasks:    TaskListPage()
        case .archive:  ArchivePage()
        case .settings: SettingsPage()
        }
    }

    private var topBar: some View {
        let sideW = max(40, (Layout.width - notch.width) / 2 - 14)
        return ZStack {
            if state.page != .tasks {
                HStack(spacing: 0) {
                    HoverIcon(symbol: "chevron.left") {
                        confirmingReset = false
                        state.page = .tasks
                    }
                    .frame(width: sideW, alignment: .leading)

                    Spacer(minLength: 0)

                    trailing
                        .frame(width: sideW, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .transition(.opacity)
            }
        }
        .frame(width: Layout.width, height: notch.height)
        .animation(Anim.page, value: state.page)
    }

    @ViewBuilder
    private var trailing: some View {
        if state.page == .archive {
            if !store.archive.isEmpty {
                Button {
                    if confirmingReset {
                        store.resetArchive()
                        confirmingReset = false
                    } else {
                        confirmingReset = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmingReset = false }
                    }
                } label: {
                    Text(confirmingReset ? settings.t(.resetConfirm) : settings.t(.resetArchive))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(confirmingReset ? Color.red : Color.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if state.page == .settings {
            Text(settings.t(.settings))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

private struct ListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct HoverIcon: View {
    let symbol: String
    var label: String? = nil
    var rotation: Double = 0
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: label == nil ? 28 : 22, height: 28)
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundColor(hovering ? Color.white : Color.white.opacity(0.45))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeInOut(duration: 0.22), value: rotation)
    }
}

struct TaskListPage: View {
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var state: AppState

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.items) { item in
                        TaskRow(item: item).transition(.opacity)
                    }
                }
                .background(GeometryReader { g in
                    Color.clear.preference(key: ListHeightKey.self, value: g.size.height)
                })
                .onPreferenceChange(ListHeightKey.self) { h in
                    DispatchQueue.main.async {
                        if abs(state.listHeight - h) > 0.5 { state.listHeight = h }
                    }
                }
            }

            if state.isAdding {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 17)
                    TextField(settings.t(.newTask), text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .focused($fieldFocused)
                        .onSubmit { commitDraft(); focusField() }
                        .onExitCommand { commitDraft(); state.isAdding = false }
                }
                .frame(height: Layout.row)
                .transition(.opacity)
            }

            HStack(spacing: 22) {
                HoverIcon(symbol: "plus", label: settings.t(.add), rotation: state.isAdding ? 45 : 0) {
                    if state.isAdding {
                        commitDraft()
                        state.isAdding = false
                    } else {
                        state.isAdding = true
                        focusField()
                    }
                }
                HoverIcon(symbol: "archivebox", label: settings.t(.history)) { go(.archive) }
                HoverIcon(symbol: "gearshape", label: settings.t(.settings)) { go(.settings) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.row)
        }
        .onReceive(NotificationCenter.default.publisher(for: .notchDidCollapse)) { _ in
            commitDraft()
        }
    }

    private func go(_ page: Page) {
        commitDraft()
        state.isAdding = false
        state.page = page
    }

    private func commitDraft() {
        store.add(draft)
        draft = ""
    }

    private func focusField() {
        DispatchQueue.main.async { fieldFocused = true }
    }
}

struct TaskRow: View {
    let item: TodoItem
    @EnvironmentObject var store: TodoStore

    @State private var editing = false
    @State private var text = ""
    @State private var taps = 0
    @State private var tapWork: DispatchWorkItem?
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                HStack(spacing: 10) {
                    tick
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .focused($focused)
                        .onSubmit { commit() }
                        .onExitCommand { editing = false }
                        .onChange(of: focused) { isFocused in
                            if !isFocused { commit() }
                        }
                    Color.clear.frame(width: 17, height: 1) 
                }
            } else {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    tick
                    Text(item.title)
                        .font(.system(size: 14))
                        .foregroundColor(item.isDone ? Color.gray : Color.white)
                        .strikethrough(item.isDone)
                        .multilineTextAlignment(.leading) 
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { tapped() }
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: Layout.row)
        .onReceive(NotificationCenter.default.publisher(for: .notchDidCollapse)) { _ in
            commit()
        }
    }

    private var tick: some View {
        Button {
            store.toggle(item)
        } label: {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundColor(item.isDone ? Color.gray : Color.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    private func tapped() {
        taps += 1
        tapWork?.cancel()
        if taps >= 4 {
            taps = 0
            store.delete(item)
            return
        }
        let work = DispatchWorkItem {
            if taps >= 2 {
                text = item.title
                editing = true
                DispatchQueue.main.async { focused = true }
            }
            taps = 0
        }
        tapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func commit() {
        guard editing else { return }
        editing = false
        store.rename(item.id, to: text)
    }
}