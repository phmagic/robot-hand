import SwiftUI

struct HomeView: View {
    @StateObject private var bleManager = BLERobotArmViewModel()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var imageClassifier = ImageClassifier(modelName: "RockPaperScissors_3")

    var body: some View {
        TabView {
            NavigationStack {
                GameView()
                    .navigationTitle("Play")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            RobotConnectionStatusView()
                        }
                    }
            }
            .tabItem {
                Label("Play", systemImage: "gamecontroller.fill")
            }

            NavigationStack {
                MimicView()
                    .navigationTitle("Mimic")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            RobotConnectionStatusView()
                        }
                    }
            }
            .tabItem {
                Label("Mimic", systemImage: "hand.raised.fill")
            }

            ProgramView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        RobotConnectionStatusView()
                    }
                }
                .tabItem {
                    Label("Program", systemImage: "list.bullet.rectangle.portrait")
                }

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            RobotConnectionStatusView()
                        }
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
        }
        .environmentObject(bleManager)
        .environmentObject(cameraManager)
        .environmentObject(imageClassifier)
    }
}

struct RobotConnectionStatusView: View {
    @EnvironmentObject private var bleManager: BLERobotArmViewModel
    @State private var showDevicePopover = false

    var body: some View {
        Button {
            showDevicePopover = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDevicePopover, arrowEdge: .top) {
            NavigationStack {
                DeviceListView()
                    .environmentObject(bleManager)
            }
            .frame(minWidth: 320, minHeight: 360)
        }
    }

    private var statusText: String {
        if bleManager.isConnected {
            return bleManager.robotPeripheral?.name ?? "Robot Connected"
        }
        if !bleManager.isBluetoothOn {
            return "Bluetooth Off"
        }
        return "Robot Disconnected"
    }
}
