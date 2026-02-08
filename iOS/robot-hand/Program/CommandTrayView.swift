import SwiftUI

struct CommandTrayView: View {
    let commands: [ProgramCommand]
    @Binding var selectedIndex: Int?
    let currentPlaybackIndex: Int?
    let onAddCommand: (CommandType) -> Void
    let onSelectCommand: (Int) -> Void
    let onDeleteCommand: (ProgramCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Commands")
                    .font(.headline)
                Spacer()
                Menu {
                    Button {
                        onAddCommand(.move)
                    } label: {
                        Label("Move", systemImage: "hand.raised.fill")
                    }
                    Button {
                        onAddCommand(.wait)
                    } label: {
                        Label("Wait", systemImage: "clock.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Horizontal scrolling command list
            if commands.isEmpty {
                VStack {
                    Spacer()
                    Text("No commands yet")
                        .foregroundStyle(.secondary)
                    Text("Tap + to add a command")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                            CommandTileView(
                                command: command,
                                index: index,
                                isSelected: selectedIndex == index,
                                isPlaying: currentPlaybackIndex == index
                            )
                            .onTapGesture {
                                selectedIndex = index
                                onSelectCommand(index)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDeleteCommand(command)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

struct CommandTileView: View {
    let command: ProgramCommand
    let index: Int
    let isSelected: Bool
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .frame(width: 70, height: 70)

                VStack(spacing: 4) {
                    Image(systemName: command.type.iconName)
                        .font(.title2)

                    if command.type == .wait {
                        Text(String(format: "%.1fs", command.waitDuration))
                            .font(.caption2)
                    } else {
                        Text("Move")
                            .font(.caption2)
                    }
                }
                .foregroundColor(isSelected || isPlaying ? .white : .primary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isPlaying {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 4, y: -4)
                }
            }

            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var backgroundColor: Color {
        if isPlaying {
            return .green
        } else if isSelected {
            return .blue
        } else {
            return Color(.tertiarySystemFill)
        }
    }
}

#Preview {
    CommandTrayView(
        commands: [
            ProgramCommand(type: .move, orderIndex: 0),
            ProgramCommand(type: .wait, orderIndex: 1, waitDuration: 2.0),
            ProgramCommand(type: .move, orderIndex: 2)
        ],
        selectedIndex: .constant(1),
        currentPlaybackIndex: nil,
        onAddCommand: { _ in },
        onSelectCommand: { _ in },
        onDeleteCommand: { _ in }
    )
    .frame(height: 180)
}
