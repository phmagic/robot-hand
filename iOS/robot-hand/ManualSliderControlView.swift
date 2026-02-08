import SwiftUI

struct ManualSliderControlView: View {
    @EnvironmentObject var ble: BLERobotArmViewModel // Renamed for consistency
    @State private var selectedPosition = 0
    @State private var syncServos = false
    
    @State private var thumb: Double = 0
    @State private var index: Double = 0
    @State private var middle: Double = 0
    @State private var ring: Double = 0
    @State private var pinky: Double = 0
    @State private var wrist: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manual Control")
                .font(.title)
                .padding(.top)

            // Servo sliders
            ServoSlider(label: "Thumb", value: $thumb, min: 0, max: 150, onChanged: { thumb = Double(Int($0)); ble.sendCommand(prefix: "T", value: Int($0)) })
            ServoSlider(label: "Index", value: $index, min: 0, max: 180, onChanged: { index = Double(Int($0)); ble.sendCommand(prefix: "I", value: Int($0)) })
            ServoSlider(label: "Middle", value: $middle, min: 0, max: 180, onChanged: { middle = Double(Int($0)); ble.sendCommand(prefix: "M", value: Int($0)) })
            ServoSlider(label: "Ring", value: $ring, min: 0, max: 180, onChanged: { ring = Double(Int($0)); ble.sendCommand(prefix: "R", value: Int($0)) })
            ServoSlider(label: "Pinky", value: $pinky, min: 0, max: 150, onChanged: { pinky = Double(Int($0)); ble.sendCommand(prefix: "P", value: Int($0)) })
            ServoSlider(label: "Wrist", value: $wrist, min: 0, max: 180, onChanged: { wrist = Double(Int($0)); ble.sendCommand(prefix: "W", value: Int($0)) })
            Spacer()
            
            Button {
                ble.disconnect()
            } label: {
                Label("Disconnect", systemImage: "")
            }
            
            Toggle("Sync Servos", isOn: $syncServos)
        }
        .onChange(of: thumb) { newValue in
            if syncServos {
                index = newValue
                middle = newValue
                ring = newValue
                pinky = newValue
                syncServos(value: newValue)
            }
        }
        .onChange(of: index) { newValue in
            if syncServos {
                thumb = newValue
                middle = newValue
                ring = newValue
                pinky = newValue
                syncServos(value: newValue)
            }
        }
        .onChange(of: middle) { newValue in
            if syncServos {
                thumb = newValue
                index = newValue
                ring = newValue
                pinky = newValue
                syncServos(value: newValue)
            }
        }
        .onChange(of: ring) { newValue in
            if syncServos {
                thumb = newValue
                index = newValue
                middle = newValue
                pinky = newValue
                syncServos(value: newValue)
            }
        }
        .onChange(of: pinky) { newValue in
            if syncServos {
                thumb = newValue
                index = newValue
                middle = newValue
                ring = newValue
                syncServos(value: newValue)
            }
        }
        .navigationTitle("Manual Control") // Optional: sets a title for the navigation bar
    }

    func syncServos(value: Double) {
        ble.sendCommand(prefix: "T", value: Int(value))
        ble.sendCommand(prefix: "I", value: Int(value))
        ble.sendCommand(prefix: "M", value: Int(value))
        ble.sendCommand(prefix: "R", value: Int(value))
        ble.sendCommand(prefix: "P", value: Int(value))
        ble.sendCommand(prefix: "W", value: Int(value))
    }
}
struct ServoSlider: View {
    let label: String
    @Binding var value: Double
    let min: Int
    let max: Int
    var onChanged: (Double) -> Void
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(label): \(Int(value))")
                Spacer()
            }
            Slider(value: Binding(
                get: { value },
                set: { newValue in value = newValue; onChanged(newValue) }
            ), in: Double(min)...Double(max))
        }.padding(.vertical, 8)
    }
}
