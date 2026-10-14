import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var statusText = "Verificando…"
    @Published var denied = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            self.refresh()
        }
    }

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                switch s.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.statusText = "Permitidas"; self.denied = false
                case .denied:
                    self.statusText = "Negadas (ative em Ajustes)"; self.denied = true
                default:
                    self.statusText = "Não solicitadas"; self.denied = false
                }
            }
        }
    }

    func send(title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func sendFall(source: String) {
        let f = DateFormatter(); f.timeStyle = .medium
        send(title: "⚠️ QUEDA detectada",
             body: "Aviso recebido (\(source)) às \(f.string(from: Date())).")
    }

    // Mostra o banner mesmo com o app aberto
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
