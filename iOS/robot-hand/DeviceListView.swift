import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ble: BLERobotArmViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Button("Scan for Robot") {
                ble.scanAndConnect()
            }
            if let error = ble.errorMessage, ble.isBluetoothOn {
                Text(error).foregroundColor(.red).font(.caption)
            }
            
            if !ble.isBluetoothOn {
                Text("Bluetooth is not available or not powered on.")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            if !ble.discoveredDevices.isEmpty {
                List(ble.discoveredDevices, id: \.identifier) { device in
                    Button(action: {
                        ble.connect(to: device)
                    }) {
                        HStack {
                            Text(device.name ?? "Unknown")
                            Spacer()
                            Text(device.identifier.uuidString.prefix(8))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            if ble.robotPeripheral?.identifier == device.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        }
        .task {
            ble.scanAndConnect()
        }
        .padding()
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                 Text("Done")
                }
            }
        }
    }
}
