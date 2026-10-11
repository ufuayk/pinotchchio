import SwiftUI

@main
struct PinotchchioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) 
        let c = NotchController()
        controller = c

        let key = "pinatnotch.hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { c.expand() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.store.flush()
    }
}
