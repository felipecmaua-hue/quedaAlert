import Foundation
import CoreBluetooth

struct FoundDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
}

struct CharInfo: Identifiable, Hashable {
    let id: String          // "serviceUUID|characteristicUUID"
    let serviceUUID: String
    let charUUID: String
    let props: String
}

struct EventItem: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var state = "Iniciando Bluetooth…"
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var found: [FoundDevice] = []
    @Published var characteristics: [CharInfo] = []
    @Published var selectedCharID: String?
    @Published var lastMessage = "—"
    @Published var history: [EventItem] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var charMap: [String: CBCharacteristic] = [:]
    private var subscribed: CBCharacteristic?
    private var userDisconnected = false
    private let defaults = UserDefaults.standard
    private enum Keys { static let device = "savedDevice"; static let char = "savedChar" }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionRestoreIdentifierKey: "queda.alert.central",
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }

    // MARK: - Ações da interface
    func toggleScan() {
        if isScanning { stopScan(); return }
        guard central.state == .poweredOn else { return }
        found.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScan() {
        central.stopScan(); isScanning = false
    }

    func connect(_ p: CBPeripheral) {
        stopScan()
        userDisconnected = false
        peripheral = p
        p.delegate = self
        state = "Conectando a \(p.name ?? "dispositivo")…"
        central.connect(p, options: nil)   // sem timeout: o iOS espera o aparelho aparecer
    }

    func disconnect() {
        userDisconnected = true
        defaults.removeObject(forKey: Keys.device)
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        resetConnectionUI(text: "Desconectado")
    }

    func select(_ id: String) {
        guard let p = peripheral, let c = charMap[id] else { return }
        if let old = subscribed, old !== c { p.setNotifyValue(false, for: old) }
        p.setNotifyValue(true, for: c)
        subscribed = c
        selectedCharID = id
        defaults.set(id, forKey: Keys.char)
        log("Inscrito na característica \(c.uuid.uuidString)")
    }

    func clearHistory() { history.removeAll() }

    // MARK: - Reconexão
    private func resume() {
        if let p = peripheral {
            p.delegate = self
            if p.state == .connected { didBecomeConnected(p) } else { connect(p) }
            return
        }
        if let s = defaults.string(forKey: Keys.device), let uuid = UUID(uuidString: s),
           let p = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            connect(p)
        }
    }

    private func didBecomeConnected(_ p: CBPeripheral) {
        isConnected = true
        state = "Conectado a \(p.name ?? "micro:bit")"
        defaults.set(p.identifier.uuidString, forKey: Keys.device)
        characteristics.removeAll(); charMap.removeAll()
        p.discoverServices(nil)
        log("Conectado a \(p.name ?? "dispositivo")")
    }

    private func resetConnectionUI(text: String) {
        isConnected = false
        state = text
        characteristics.removeAll(); charMap.removeAll()
        selectedCharID = nil; subscribed = nil
    }

    private func log(_ t: String) { history.insert(EventItem(text: t), at: 0) }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: state = "Bluetooth ligado"; resume()
        case .poweredOff: resetConnectionUI(text: "Bluetooth desligado")
        case .unauthorized: state = "Sem permissão de Bluetooth (veja Ajustes)"
        case .unsupported: state = "Bluetooth não suportado"
        default: state = "Bluetooth indisponível"
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let ps = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let p = ps.first {
            peripheral = p
            p.delegate = self
            log("Estado restaurado pelo iOS")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        guard let name = name, !name.isEmpty else { return }
        if let i = found.firstIndex(where: { $0.id == p.identifier }) {
            found[i].rssi = RSSI.intValue
        } else {
            found.append(FoundDevice(id: p.identifier, peripheral: p, name: name, rssi: RSSI.intValue))
            found.sort { a, b in
                let am = a.name.lowercased().contains("micro:bit"), bm = b.name.lowercased().contains("micro:bit")
                return am != bm ? am : a.rssi > b.rssi
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        didBecomeConnected(p)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        log("Falha ao conectar: \(error?.localizedDescription ?? "?")")
        if !userDisconnected { central.connect(p, options: nil) }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        resetConnectionUI(text: "Desconectado — tentando reconectar…")
        log("Conexão perdida")
        guard !userDisconnected else { state = "Desconectado"; return }
        NotificationManager.shared.send(title: "Conexão com o micro:bit perdida",
                                        body: "O Queda Alert está tentando reconectar. Mantenha o micro:bit por perto.")
        central.connect(p, options: nil)   // pedido pendente: reconecta sozinho quando o micro:bit voltar
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        p.services?.forEach { p.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let saved = defaults.string(forKey: Keys.char)
        for c in service.characteristics ?? [] {
            var props: [String] = []
            if c.properties.contains(.notify) { props.append("notify") }
            if c.properties.contains(.indicate) { props.append("indicate") }
            guard !props.isEmpty else { continue }
            let id = "\(service.uuid.uuidString)|\(c.uuid.uuidString)"
            charMap[id] = c
            characteristics.append(CharInfo(id: id, serviceUUID: service.uuid.uuidString,
                                            charUUID: c.uuid.uuidString, props: props.joined(separator: "+")))
            if id == saved { select(id) }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        if let e = error { log("Erro ao assinar \(c.uuid.uuidString): \(e.localizedDescription)") }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard error == nil, let data = c.value else { return }
        let raw = String(data: data, encoding: .utf8) ?? data.map { String(format: "%02X", $0) }.joined(separator: " ")
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        lastMessage = text.isEmpty ? "(vazio)" : text
        log("Recebido: \(lastMessage)")
        if text.uppercased().contains("QUEDA") {
            NotificationManager.shared.sendFall(source: "micro:bit")
        }
    }
}
