import Vision
import CoreML
import UIKit // For UIImage and CVPixelBuffer
import Combine // For @Published

// Struct to hold prediction data and conform to Equatable
struct PredictionData: Equatable {
    let label: String
    let confidence: Float

    static func == (lhs: PredictionData, rhs: PredictionData) -> Bool {
        return lhs.label == rhs.label && lhs.confidence == rhs.confidence
    }
}

class ImageClassifier: ObservableObject {
    @Published var currentPrediction: PredictionData?

    private var model: VNCoreMLModel?

    init(modelName: String = "RPSClassifier") { // Default to RPSClassifier.mlmodel
        loadModel(modelName: modelName)
    }

    private func loadModel(modelName: String) {
        guard let compiledModelUrl = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("Error: Failed to find compiled model \(modelName).mlmodelc in bundle.")
            // You might want to try loading the uncompiled .mlmodel file as a fallback
            // or provide more robust error handling.
            if let uncompiledModelUrl = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
                 print("Found uncompiled model \(modelName).mlmodel. Attempting to compile.")
                 do {
                     let tempModel = try MLModel(contentsOf: uncompiledModelUrl)
                     self.model = try VNCoreMLModel(for: tempModel)
                     print("Successfully loaded and compiled \(modelName).mlmodel on the fly.")
                 } catch {
                     print("Error: Failed to load or compile \(modelName).mlmodel: \(error)")
                 }
            } else {
                print("Error: Also failed to find uncompiled model \(modelName).mlmodel.")
            }
            return
        }

        do {
            let coreMLModel = try MLModel(contentsOf: compiledModelUrl)
            self.model = try VNCoreMLModel(for: coreMLModel)
            print("Successfully loaded model: \(modelName).mlmodelc")
        } catch {
            print("Error: Failed to load model \(modelName).mlmodelc: \(error)")
        }
    }

    func classifyImage(pixelBuffer: CVPixelBuffer) {
        guard let model = self.model else {
            print("Model not loaded, cannot classify image.")
            return
        }

        let request = VNCoreMLRequest(model: model) { [weak self] (request, error) in
            if let error = error {
                print("Vision request error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.currentPrediction = PredictionData(label: "Error", confidence: 0)
                }
                return
            }

            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                print("No classification results or failed to cast.")
                DispatchQueue.main.async {
                    self?.currentPrediction = PredictionData(label: "Unknown", confidence: 0)
                }
                return
            }
            
            // Update the published property on the main thread
            DispatchQueue.main.async {
                self?.currentPrediction = PredictionData(label: topResult.identifier, confidence: topResult.confidence)
                 // print("Prediction: \(topResult.identifier) - Confidence: \(topResult.confidence)")
            }
        }
        
        // Vision framework expects images in a specific orientation.
        // If your model was trained on images with a particular orientation, ensure consistency.
        // For CVPixelBuffer directly from camera, orientation might need to be handled.
        // However, often models are trained to be somewhat robust or the camera output is already suitable.
        // If issues arise, you might need to create a CIImage and specify orientation.
        // For now, we proceed directly.

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform classification: \(error.localizedDescription)")
        }
    }
}
