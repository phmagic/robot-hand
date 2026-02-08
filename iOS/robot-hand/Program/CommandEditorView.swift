import SwiftUI

struct CommandEditorView: View {
    @Bindable var command: ProgramCommand
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bleManager: BLERobotArmViewModel

    let onPreview: (StoredFingerPositions) -> Void

    // Local editing state
    @State private var thumb: Double = 0
    @State private var index: Double = 0
    @State private var middle: Double = 0
    @State private var ring: Double = 0
    @State private var pinky: Double = 0
    @State private var wrist: Double = 90
    @State private var waitDuration: Double = 1.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: command.type.iconName)
                            .foregroundStyle(command.type == .move ? .blue : .orange)
                        Text(command.type.rawValue)
                            .font(.headline)
                    }
                } header: {
                    Text("Command Type")
                }

                if command.type == .move {
                    moveCommandEditor
                } else {
                    waitCommandEditor
                }
            }
            .navigationTitle("Edit Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCommand()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCommandValues()
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var moveCommandEditor: some View {
        Section {
            VerticalServoSlider(label: "Thumb", value: $thumb, range: 0...150, color: .red) {
                updatePreview()
            }
            VerticalServoSlider(label: "Index", value: $index, range: 0...180, color: .orange) {
                updatePreview()
            }
            VerticalServoSlider(label: "Middle", value: $middle, range: 0...180, color: .yellow) {
                updatePreview()
            }
            VerticalServoSlider(label: "Ring", value: $ring, range: 0...180, color: .green) {
                updatePreview()
            }
            VerticalServoSlider(label: "Pinky", value: $pinky, range: 0...150, color: .blue) {
                updatePreview()
            }
        } header: {
            Text("Finger Positions")
        }

        Section {
            HStack {
                Text("Wrist")
                Spacer()
                Text("\(Int(wrist))")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $wrist, in: 0...180, step: 1) { _ in
                updatePreview()
            }
        } header: {
            Text("Wrist Position")
        }

        Section {
            Button {
                sendPreviewToRobot()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Preview on Robot")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!bleManager.isConnected)
        }

        Section {
            HStack(spacing: 12) {
                Button("Open Hand") {
                    applyPreset(.openHand)
                }
                .buttonStyle(.bordered)

                Button("Closed Fist") {
                    applyPreset(.closedFist)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Presets")
        }
    }

    @ViewBuilder
    private var waitCommandEditor: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(String(format: "%.1f seconds", waitDuration))
                        .foregroundColor(.secondary)
                }
                Slider(value: $waitDuration, in: 0.1...10.0, step: 0.1)
            }
        } header: {
            Text("Wait Duration")
        }
    }

    private func loadCommandValues() {
        if command.type == .move {
            let pos = command.fingerPositions
            thumb = Double(pos.thumb)
            index = Double(pos.index)
            middle = Double(pos.middle)
            ring = Double(pos.ring)
            pinky = Double(pos.pinky)
            wrist = Double(pos.wrist)
        } else {
            waitDuration = command.waitDuration
        }
    }

    private func saveCommand() {
        if command.type == .move {
            command.fingerPositions = currentPositions
        } else {
            command.waitDuration = waitDuration
        }
    }

    private var currentPositions: StoredFingerPositions {
        StoredFingerPositions(
            thumb: Int(thumb),
            index: Int(index),
            middle: Int(middle),
            ring: Int(ring),
            pinky: Int(pinky),
            wrist: Int(wrist)
        )
    }

    private func updatePreview() {
        onPreview(currentPositions)
    }

    private func sendPreviewToRobot() {
        let positions = currentPositions
        bleManager.setFingerPositions(positions.toFingerServoPositions())
        bleManager.sendCommand(prefix: "W", value: positions.wrist)
    }

    private func applyPreset(_ preset: StoredFingerPositions) {
        thumb = Double(preset.thumb)
        index = Double(preset.index)
        middle = Double(preset.middle)
        ring = Double(preset.ring)
        pinky = Double(preset.pinky)
        wrist = Double(preset.wrist)
        updatePreview()
    }
}

struct VerticalServoSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let onChange: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
            Spacer()
            Text("\(Int(value))")
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
            Slider(value: $value, in: range, step: 1) { _ in
                onChange()
            }
            .frame(width: 150)
        }
    }
}
