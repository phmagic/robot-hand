import SwiftUI

struct DataCollectionView: View {
    @Environment(\.dismiss) var dismiss
   
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var imageClassifier: ImageClassifier
    // Note: cameraManager is already an @EnvironmentObject, no need to pass currentCameraFrame

    // Internal state for data collection UI
    @State private var selectedGestureForCapture: Gesture = .rock
    @State private var capturedImageInfo: String = ""
    @State private var rockImageCount: Int = 0
    @State private var paperImageCount: Int = 0
    @State private var scissorsImageCount: Int = 0
    @State private var noneImageCount: Int = 0

    @State private var zipFileURLToExport: URL? // For triggering document picker
    @State private var showClearDataAlert: Bool = false // For clear data confirmation
    @State private var confirmedClearAction: Bool = false // New state to trigger confirmed clear in DataCollectionView
    
    var body: some View {
        VStack {
            PredictionCameraView()
            .environmentObject(cameraManager)
            .environmentObject(imageClassifier)

            Picker("Gesture to Capture", selection: $selectedGestureForCapture) {
                ForEach(Gesture.allCases) { gesture in
                    Text(gesture.rawValue).tag(gesture)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button {
                captureImage()
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Capture \(selectedGestureForCapture.rawValue)")
                }
            }
            .padding(.vertical, 5)
            .buttonStyle(.bordered)

            Button {
                exportData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Export Training Data (ZIP)")
                }
            }
            .padding(.vertical, 5)
            .buttonStyle(.bordered)

            Button {
                showClearDataAlert = true // Trigger alert in ContentView
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Clear All Training Data")
                }
            }
            .padding(.vertical, 5)
            .buttonStyle(.bordered)
            .tint(.red) // Make the button red to indicate destructive action

            Text(capturedImageInfo)
                .font(.caption)
                .frame(minHeight: 20)

            HStack {
                Text("Rock: \(rockImageCount)")
                Spacer()
                Text("Paper: \(paperImageCount)")
                Spacer()
                Text("Scissors: \(scissorsImageCount)")
                        Text("None: \(noneImageCount)")
            }
            .font(.footnote)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            updateCounts()
        }
        .onChange(of: confirmedClearAction) { newValue in
            if newValue {
                performClearDataConfirmed()
                confirmedClearAction = false // Reset the trigger
            }
        }
        .sheet(item: $zipFileURLToExport) { urlToExport in // Present DocumentPicker when zipFileURLToExport is set
            DocumentPicker(url: urlToExport)
        }
        .alert("Clear All Training Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { confirmedClearAction = false } // Ensure it's reset if cancelled
            Button("Clear", role: .destructive) { confirmedClearAction = true } // Set flag for DataCollectionView to act
        } message: {
            Text("This action cannot be undone. All captured images will be permanently deleted.")
        }
        .toolbar {
            ToolbarItem {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
    }

    // MARK: - Data Collection Methods
    func updateCounts() {
        rockImageCount = ImageStorageManager.shared.countImages(forGesture: .rock)
        paperImageCount = ImageStorageManager.shared.countImages(forGesture: .paper)
        scissorsImageCount = ImageStorageManager.shared.countImages(forGesture: .scissors)
        noneImageCount = ImageStorageManager.shared.countImages(forGesture: .none)
    }

    func captureImage() {
        guard let frame = cameraManager.currentFrame else {
            capturedImageInfo = "No camera frame available."
            return
        }

        let result = ImageStorageManager.shared.saveImage(frame, forGesture: selectedGestureForCapture)
        switch result {
        case .success(let message):
            capturedImageInfo = message.absoluteString
            updateCounts() // Refresh counts after saving
        case .failure(let error):
            capturedImageInfo = "Error saving image: \(error.localizedDescription)"
        }
    }

    func exportData() {
        let result = ImageStorageManager.shared.exportTrainingDataToZip()
        switch result {
        case .success(let url):
            self.capturedImageInfo = "Export successful. ZIP file ready."
            self.zipFileURLToExport = url // This will trigger the .sheet in ContentView
        case .failure(let error):
            self.capturedImageInfo = "Export failed: \(error.localizedDescription)"
            self.zipFileURLToExport = nil
        }
    }

    func performClearDataConfirmed() {
        let result = ImageStorageManager.shared.clearAllTrainingData()
        switch result {
        case .success:
            self.capturedImageInfo = "All training data cleared."
            updateCounts()
        case .failure(let error):
            self.capturedImageInfo = "Failed to clear data: \(error.localizedDescription)"
        }
    }
}


