import SwiftUI

struct ProgramListView: View {
    let programs: [RobotProgram]
    @Binding var selectedProgram: RobotProgram?
    let onAddProgram: () -> Void
    let onDeleteProgram: (RobotProgram) -> Void

    var body: some View {
        List(selection: $selectedProgram) {
            ForEach(programs) { program in
                ProgramRowView(program: program)
                    .tag(program)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteProgram(program)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddProgram) {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .overlay {
            if programs.isEmpty {
                ContentUnavailableView(
                    "No Programs",
                    systemImage: "doc.badge.plus",
                    description: Text("Tap + to create your first program.")
                )
            }
        }
    }
}

struct ProgramRowView: View {
    let program: RobotProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name)
                .font(.headline)
            Text("\(program.commands.count) commands")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
