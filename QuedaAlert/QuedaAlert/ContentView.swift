import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
    @EnvironmentObject var notif: NotificationManager

    var body: some View {
        NavigationStack {
            List {
                Section("Estado") {
                    LabeledContent("Conexão", value: ble.state)
                    LabeledContent("Notificações", value: notif.statusText)
                    if notif.denied {
                        Button("Abrir Ajustes do iPhone") {
                            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                        }
                    }
                }

                Section("Última mensagem") {
                    Text(ble.lastMessage).font(.title2.monospaced())
                }

                Section("micro:bit") {
                    if ble.isConnected {
                        Button("Desconectar", role: .destructive) { ble.disconnect() }
                    } else {
                        Button(ble.isScanning ? "Parar busca" : "Buscar dispositivos") { ble.toggleScan() }
                        ForEach(ble.found) { d in
                            Button { ble.connect(d.peripheral) } label: {
                                HStack { Text(d.name); Spacer()
                                    Text("\(d.rssi) dBm").foregroundStyle(.secondary) }
                            }
                        }
                    }
                }

                if ble.isConnected {
                    Section {
                        ForEach(ble.characteristics) { c in
                            Button { ble.select(c.id) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.charUUID).font(.footnote.monospaced())
                                        Text("Serviço \(c.serviceUUID) · \(c.props)")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if ble.selectedCharID == c.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    } header: { Text("Característica das mensagens") }
                    footer: { Text("Toque na que envia o texto QUEDA. Se nenhuma funcionar, o micro:bit pode precisar estar pareado (aceite o pedido do iOS).") }
                }

                Section("Teste") {
                    Button("Enviar notificação de teste") { notif.sendFall(source: "teste") }
                }

                Section("Histórico") {
                    if ble.history.isEmpty { Text("Nenhum evento ainda").foregroundStyle(.secondary) }
                    ForEach(ble.history) { e in
                        VStack(alignment: .leading) {
                            Text(e.text)
                            Text(e.date.formatted(date: .abbreviated, time: .standard))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !ble.history.isEmpty { Button("Limpar histórico") { ble.clearHistory() } }
                }
            }
            .navigationTitle("Queda Alert")
        }
    }
}
