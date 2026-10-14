import SwiftUI

@main
struct QuedaAlertApp: App {
    @StateObject private var notif = NotificationManager.shared
    @StateObject private var ble = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .environmentObject(notif)
                .onAppear { notif.requestPermission() }
        }
    }
}
