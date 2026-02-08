import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var bleManager: BLERobotArmViewModel

    var body: some View {
        List {
            Section("Robot Connection") {
                HStack {
                    Text(bleManager.isConnected ? "Connected" : "Disconnected")
                    Spacer()
                    Text(bleManager.robotPeripheral?.name ?? "Robot")
                        .foregroundColor(.secondary)
                }
                if bleManager.isConnected {
                    Button("Disconnect") {
                        bleManager.disconnect()
                    }
                } else {
                    NavigationLink {
                        DeviceListView()
                    } label: {
                        Text("Scan for Robots")
                    }
                }
            }

            Section("Quick Positions") {
                Button("All Fingers Curled") {
                    bleManager.setFingerPositions(
                        FingerServoPositions(thumb: 150, index: 180, middle: 180, ring: 180, pinky: 150)
                    )
                }
                Button("All Fingers Straight") {
                    bleManager.setFingerPositions(
                        FingerServoPositions(thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0)
                    )
                }
                Button("Scissors") {
                    bleManager.setFingerPositions(
                        FingerServoPositions(thumb: 150, index: 0, middle: 0, ring: 180, pinky: 150)
                    )
                }
            }

            Section("Manual Control") {
                NavigationLink {
                    ManualSliderControlView()
                } label: {
                    Text("Manual Slider Control")
                }
            }

            Section("Training Data") {
                NavigationLink {
                    DataCollectionView()
                } label: {
                    Label("Collect Training Data", systemImage: "camera")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
