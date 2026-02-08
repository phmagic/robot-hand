import SwiftUI
import SwiftData

enum PlaybackMode {
    case once
    case loop
    case bounce

    var iconName: String {
        switch self {
        case .once: return "play.fill"
        case .loop: return "repeat"
        case .bounce: return "arrow.left.arrow.right"
        }
    }

    var label: String {
        switch self {
        case .once: return "Play"
        case .loop: return "Loop"
        case .bounce: return "Bounce"
        }
    }
}

struct ProgramEditorView: View {
    @Bindable var program: RobotProgram
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bleManager: BLERobotArmViewModel

    @State private var selectedCommandIndex: Int?
    @State private var isPlaying = false
    @State private var currentPlaybackIndex: Int = 0

    // Playback mode
    @State private var playbackMode: PlaybackMode = .once
    @State private var isPlayingForward: Bool = true  // For bounce mode

    // Virtual hand state
    @State private var displayedPositions: StoredFingerPositions = .openHand

    // Cache sorted commands to avoid repeated sorting
    @State private var cachedCommands: [ProgramCommand] = []
    @State private var programName: String = ""

    // Playback timer management
    @State private var pendingPlaybackWork: DispatchWorkItem?

    // Inline editing state
    @State private var editThumb: Double = 0
    @State private var editIndex: Double = 0
    @State private var editMiddle: Double = 0
    @State private var editRing: Double = 0
    @State private var editPinky: Double = 0
    @State private var editWrist: Double = 90
    @State private var editWaitDuration: Double = 1.0

    private var selectedCommand: ProgramCommand? {
        guard let index = selectedCommandIndex, index < cachedCommands.count else { return nil }
        return cachedCommands[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with program name and playback controls
            HStack {
                TextField("Program Name", text: $programName)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onSubmit {
                        program.name = programName
                    }

                Spacer()

                playbackControls
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Main content area: Virtual Hand + Inline Sliders
            GeometryReader { geometry in
                let showSliders = selectedCommand != nil && !isPlaying
                let handWidth = showSliders ? geometry.size.width * 0.55 : geometry.size.width

                HStack(spacing: 0) {
                    // Virtual Hand View (left side)
                    VirtualHandView(positions: displayedPositions)
                        .frame(width: handWidth)
                        .background(Color(.secondarySystemBackground))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sendPreviewToRobot()
                        }

                    if showSliders {
                        Divider()

                        // Inline slider panel (right side)
                        inlineSliderPanel
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                    }
                }
            }

            Divider()

            // Command Tray (bottom)
            CommandTrayView(
                commands: cachedCommands,
                selectedIndex: $selectedCommandIndex,
                currentPlaybackIndex: isPlaying ? currentPlaybackIndex : nil,
                onAddCommand: addCommand,
                onSelectCommand: selectCommand,
                onDeleteCommand: deleteCommand
            )
            .frame(height: 160)
        }
        .onAppear {
            programName = program.name
            refreshCachedCommands()
        }
        .onDisappear {
            if program.name != programName {
                program.name = programName
            }
            program.markUpdated()
        }
        .onChange(of: selectedCommandIndex) { _, newIndex in
            if let index = newIndex, index < cachedCommands.count {
                let command = cachedCommands[index]
                if command.type == .move {
                    displayedPositions = command.fingerPositions
                    loadSliderValues(from: command)
                } else {
                    editWaitDuration = command.waitDuration
                }
            }
        }
    }

    @ViewBuilder
    private var inlineSliderPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let command = selectedCommand {
                    // Command type header
                    HStack {
                        Image(systemName: command.type.iconName)
                            .foregroundStyle(command.type == .move ? .blue : .orange)
                        Text(command.type.rawValue)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    if command.type == .move {
                        moveSliders
                    } else {
                        waitSlider
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var moveSliders: some View {
        VStack(spacing: 12) {
            Text("Finger Positions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            InlineServoSlider(label: "Thumb", value: $editThumb, range: 0...150, color: .red) {
                updateFromSliders()
            }
            InlineServoSlider(label: "Index", value: $editIndex, range: 0...180, color: .orange) {
                updateFromSliders()
            }
            InlineServoSlider(label: "Middle", value: $editMiddle, range: 0...180, color: .yellow) {
                updateFromSliders()
            }
            InlineServoSlider(label: "Ring", value: $editRing, range: 0...180, color: .green) {
                updateFromSliders()
            }
            InlineServoSlider(label: "Pinky", value: $editPinky, range: 0...150, color: .blue) {
                updateFromSliders()
            }

            Divider()
                .padding(.vertical, 4)

            Text("Wrist Position")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            InlineServoSlider(label: "Wrist", value: $editWrist, range: 0...180, color: .purple) {
                updateFromSliders()
            }

            Divider()
                .padding(.vertical, 4)

            // Preview and presets
            Button {
                sendPreviewToRobot()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Preview on Robot")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!bleManager.isConnected)

            HStack(spacing: 12) {
                Button("Open") {
                    applyPreset(.openHand)
                }
                .buttonStyle(.bordered)

                Button("Fist") {
                    applyPreset(.closedFist)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var waitSlider: some View {
        VStack(spacing: 12) {
            Text("Wait Duration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(String(format: "%.1f sec", editWaitDuration))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.orange)
            }

            Slider(value: $editWaitDuration, in: 0.1...10.0, step: 0.1) { _ in
                saveWaitDuration()
            }
        }
    }

    private func loadSliderValues(from command: ProgramCommand) {
        let pos = command.fingerPositions
        editThumb = Double(pos.thumb)
        editIndex = Double(pos.index)
        editMiddle = Double(pos.middle)
        editRing = Double(pos.ring)
        editPinky = Double(pos.pinky)
        editWrist = Double(pos.wrist)
    }

    private func updateFromSliders() {
        let positions = StoredFingerPositions(
            thumb: Int(editThumb),
            index: Int(editIndex),
            middle: Int(editMiddle),
            ring: Int(editRing),
            pinky: Int(editPinky),
            wrist: Int(editWrist)
        )
        displayedPositions = positions

        // Save to command
        if let command = selectedCommand, command.type == .move {
            command.fingerPositions = positions
        }
    }

    private func saveWaitDuration() {
        if let command = selectedCommand, command.type == .wait {
            command.waitDuration = editWaitDuration
        }
    }

    private func sendPreviewToRobot() {
        bleManager.setFingerPositions(displayedPositions.toFingerServoPositions())
        bleManager.sendCommand(prefix: "W", value: displayedPositions.wrist)
    }

    private func applyPreset(_ preset: StoredFingerPositions) {
        editThumb = Double(preset.thumb)
        editIndex = Double(preset.index)
        editMiddle = Double(preset.middle)
        editRing = Double(preset.ring)
        editPinky = Double(preset.pinky)
        editWrist = Double(preset.wrist)
        updateFromSliders()
    }

    private func refreshCachedCommands() {
        cachedCommands = program.commands.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            // Stop button (only when playing)
            if isPlaying {
                Button {
                    stopPlayback()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }

            // Play once button
            Button {
                if isPlaying && playbackMode == .once {
                    stopPlayback()
                } else {
                    startPlayback(mode: .once)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(playbackButtonColor(for: .once))
            }
            .disabled(cachedCommands.isEmpty)

            // Loop button
            Button {
                if isPlaying && playbackMode == .loop {
                    stopPlayback()
                } else {
                    startPlayback(mode: .loop)
                }
            } label: {
                Image(systemName: "repeat")
                    .font(.title2)
                    .foregroundStyle(playbackButtonColor(for: .loop))
            }
            .disabled(cachedCommands.isEmpty)

            // Bounce button
            Button {
                if isPlaying && playbackMode == .bounce {
                    stopPlayback()
                } else {
                    startPlayback(mode: .bounce)
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(playbackButtonColor(for: .bounce))
            }
            .disabled(cachedCommands.isEmpty)
        }
    }

    private func playbackButtonColor(for mode: PlaybackMode) -> Color {
        if cachedCommands.isEmpty {
            return .gray
        }
        if isPlaying && playbackMode == mode {
            return .green
        }
        return .primary
    }

    private func addCommand(type: CommandType) {
        let command = ProgramCommand(type: type)
        if type == .move {
            command.fingerPositions = displayedPositions
        }
        program.addCommand(command)
        refreshCachedCommands()
        selectedCommandIndex = cachedCommands.count - 1

        // Load slider values for new command
        if type == .move {
            loadSliderValues(from: command)
        } else {
            editWaitDuration = command.waitDuration
        }
    }

    private func selectCommand(at index: Int) {
        // Selection is handled via binding, slider values load via onChange
    }

    private func deleteCommand(_ command: ProgramCommand) {
        program.removeCommand(command)
        refreshCachedCommands()
        if selectedCommandIndex != nil {
            if cachedCommands.isEmpty {
                selectedCommandIndex = nil
            } else if let index = selectedCommandIndex, index >= cachedCommands.count {
                selectedCommandIndex = cachedCommands.count - 1
            }
        }
    }

    private func startPlayback(mode: PlaybackMode) {
        guard !cachedCommands.isEmpty else { return }

        // Cancel any existing playback before starting new one
        cancelPendingPlayback()

        playbackMode = mode
        isPlaying = true
        isPlayingForward = true
        currentPlaybackIndex = 0
        selectedCommandIndex = 0
        executeCommand(at: 0)
    }

    private func stopPlayback() {
        cancelPendingPlayback()
        isPlaying = false
    }

    private func cancelPendingPlayback() {
        pendingPlaybackWork?.cancel()
        pendingPlaybackWork = nil
    }

    private func executeCommand(at index: Int) {
        guard isPlaying else { return }

        // Check bounds and handle end of sequence
        if index < 0 || index >= cachedCommands.count {
            handleEndOfSequence(lastIndex: index)
            return
        }

        currentPlaybackIndex = index
        selectedCommandIndex = index
        let command = cachedCommands[index]

        switch command.type {
        case .move:
            displayedPositions = command.fingerPositions
            sendToRobot(command.fingerPositions)
            // Delay before next command to allow servo movement
            scheduleNextCommand(after: 0.5, fromIndex: index)

        case .wait:
            scheduleNextCommand(after: command.waitDuration, fromIndex: index)
        }
    }

    private func scheduleNextCommand(after delay: Double, fromIndex index: Int) {
        let workItem = DispatchWorkItem { [self] in
            advanceToNextCommand(from: index)
        }
        pendingPlaybackWork = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func advanceToNextCommand(from index: Int) {
        guard isPlaying else { return }

        let nextIndex: Int
        if isPlayingForward {
            nextIndex = index + 1
        } else {
            nextIndex = index - 1
        }

        executeCommand(at: nextIndex)
    }

    private func handleEndOfSequence(lastIndex: Int) {
        switch playbackMode {
        case .once:
            stopPlayback()

        case .loop:
            // Restart from beginning
            currentPlaybackIndex = 0
            selectedCommandIndex = 0
            executeCommand(at: 0)

        case .bounce:
            // Reverse direction
            isPlayingForward.toggle()
            if isPlayingForward {
                // Was going backward, now going forward - start from 0
                executeCommand(at: 0)
            } else {
                // Was going forward, now going backward - start from last
                executeCommand(at: cachedCommands.count - 1)
            }
        }
    }

    private func sendToRobot(_ positions: StoredFingerPositions) {
        bleManager.setFingerPositions(positions.toFingerServoPositions())
        bleManager.sendCommand(prefix: "W", value: positions.wrist)
    }
}

struct InlineServoSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: 1) { _ in
                onChange()
            }
            .tint(color)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RobotProgram.self, ProgramCommand.self, configurations: config)

    let program = RobotProgram(name: "Test Program")
    program.addCommand(ProgramCommand(type: .move, fingerPositions: .openHand))
    program.addCommand(ProgramCommand(type: .wait, waitDuration: 1.0))
    program.addCommand(ProgramCommand(type: .move, fingerPositions: .closedFist))
    container.mainContext.insert(program)

    return ProgramEditorView(program: program)
        .modelContainer(container)
        .environmentObject(BLERobotArmViewModel())
}
