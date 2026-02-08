import Vision
import CoreVideo
import Combine

struct SmoothedFingerCurls: Equatable {
    var thumb: Double = 0.0
    var index: Double = 0.0
    var middle: Double = 0.0
    var ring: Double = 0.0
    var pinky: Double = 0.0

    mutating func update(with raw: SmoothedFingerCurls, factor: Double) {
        thumb = factor * raw.thumb + (1 - factor) * thumb
        index = factor * raw.index + (1 - factor) * index
        middle = factor * raw.middle + (1 - factor) * middle
        ring = factor * raw.ring + (1 - factor) * ring
        pinky = factor * raw.pinky + (1 - factor) * pinky
    }

    mutating func reset() {
        thumb = 0.0
        index = 0.0
        middle = 0.0
        ring = 0.0
        pinky = 0.0
    }
}

final class HandPoseDetector: ObservableObject {
    @Published var recognizedPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    @Published var hasHand: Bool = false
    @Published var smoothedCurls: SmoothedFingerCurls = SmoothedFingerCurls()

    /// Smoothing factor: 0.0 = no change, 1.0 = no smoothing. Lower values = smoother but more lag.
    var smoothingFactor: Double = 0.35

    private let request = VNDetectHumanHandPoseRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let processingQueue = DispatchQueue(label: "com.rpsrobot.handPoseQueue")
    private var isProcessing = false
    private var hasInitializedSmoothing = false

    init() {
        request.maximumHandCount = 1
    }

    func updateSmoothedCurls(raw: SmoothedFingerCurls) {
        if !hasInitializedSmoothing {
            smoothedCurls = raw
            hasInitializedSmoothing = true
        } else {
            smoothedCurls.update(with: raw, factor: smoothingFactor)
        }
    }

    func resetSmoothing() {
        smoothedCurls.reset()
        hasInitializedSmoothing = false
    }

    func process(pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }
            do {
                try self.sequenceHandler.perform([self.request], on: pixelBuffer)
                guard let observation = self.request.results?.first else {
                    DispatchQueue.main.async {
                        self.recognizedPoints = [:]
                        self.hasHand = false
                    }
                    return
                }
                let points = try observation.recognizedPoints(.all)
                var mapped: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
                for (joint, point) in points where point.confidence > 0.3 {
                    mapped[joint] = CGPoint(x: point.location.x, y: point.location.y)
                }
                DispatchQueue.main.async {
                    self.recognizedPoints = mapped
                    self.hasHand = !mapped.isEmpty
                }
            } catch {
                DispatchQueue.main.async {
                    self.recognizedPoints = [:]
                    self.hasHand = false
                }
            }
        }
    }
}
