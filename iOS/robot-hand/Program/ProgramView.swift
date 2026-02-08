import SwiftUI
import SwiftData

struct ProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bleManager: BLERobotArmViewModel
    @Query(sort: \RobotProgram.updatedAt, order: .reverse) private var programs: [RobotProgram]

    @State private var selectedProgram: RobotProgram?
    @State private var showNewProgramAlert = false
    @State private var newProgramName = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProgramListView(
                programs: programs,
                selectedProgram: $selectedProgram,
                onAddProgram: { showNewProgramAlert = true },
                onDeleteProgram: deleteProgram
            )
            .navigationTitle("Programs")
        } detail: {
            if let program = selectedProgram {
                ProgramEditorView(program: program)
            } else {
                ContentUnavailableView(
                    "No Program Selected",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Select a program from the sidebar or create a new one.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .alert("New Program", isPresented: $showNewProgramAlert) {
            TextField("Program Name", text: $newProgramName)
            Button("Cancel", role: .cancel) { newProgramName = "" }
            Button("Create") { createProgram() }
        }
    }

    private func createProgram() {
        let program = RobotProgram(name: newProgramName.isEmpty ? "Untitled" : newProgramName)
        modelContext.insert(program)
        selectedProgram = program
        newProgramName = ""
    }

    private func deleteProgram(_ program: RobotProgram) {
        if selectedProgram?.id == program.id {
            selectedProgram = nil
        }
        modelContext.delete(program)
    }
}
