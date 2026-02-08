import SwiftUI
import Vision

struct MimicView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var bleManager: BLERobotArmViewModel

    @StateObject private var handPoseDetector = HandPoseDetector()
    @AppStorage("mimicHandCalibration") private var calibrationJSON: String = ""
    @State private var calibration: HandCalibrationData? = nil
    @State private var statusText = "Tap anywhere to capture your hand."
    @State private var lastPoseSummary: String = ""
    @State private var showDebug: Bool = true
    @State private var showCalibration: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                CameraView(cgImage: cameraManager.currentFrame,
                           cornerRadius: 0,
                           contentMode: .fill,
                           isClipped: true)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(Color.black)
                    .contentShape(Rectangle())

                HandPoseOverlayView(points: handPoseDetector.recognizedPoints,
                                    imageSize: cameraManager.currentFrame.map { CGSize(width: $0.width, height: $0.height) })
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)

                VStack(spacing: 6) {
                    Text(statusText)
                        .font(.callout)
                        .foregroundColor(.white)
                    if !lastPoseSummary.isEmpty {
                        Text(lastPoseSummary)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.55))
                .cornerRadius(10)
                .padding()
                .allowsHitTesting(false)

                if showDebug {
                    debugPanel
                        .padding()
                        .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height, alignment: .topLeading)
                        .allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showCalibration = true
            } label: {
                Text("Calibrate")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            captureAndMimic()
        }
        .ignoresSafeArea()
        .onChange(of: cameraManager.currentPixelBuffer) { newPixelBuffer in
            if let pixelBuffer = newPixelBuffer {
                handPoseDetector.process(pixelBuffer: pixelBuffer)
            }
        }
        .onChange(of: handPoseDetector.recognizedPoints) { _ in
            updateSmoothedCurls()
        }
        .onAppear {
            OrientationLock.lockLandscape()
            cameraManager.refreshVideoOrientation()
            if calibration == nil, let stored = decodeCalibration(from: calibrationJSON) {
                calibration = stored
            }
        }
        .onDisappear {
            OrientationLock.unlock()
            cameraManager.refreshVideoOrientation()
        }
        .onChange(of: calibration) { newValue in
            calibrationJSON = encodeCalibration(newValue)
        }
        .sheet(isPresented: $showCalibration) {
            MimicCalibrationView(handPoseDetector: handPoseDetector,
                                 calibration: $calibration)
                .environmentObject(cameraManager)
        }
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug")
                .font(.caption).bold()
            if !handPoseDetector.hasHand {
                Text("Hand: not detected")
                    .font(.caption2)
            } else {
                Text("Hand: detected")
                    .font(.caption2)
                ForEach(debugFingerRows, id: \.label) { row in
                    Text("\(row.label): \(row.raw) → \(row.smoothed) → \(row.servo)")
                        .font(.caption2)
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
        .foregroundColor(.white)
        .cornerRadius(10)
    }

    private var debugFingerRows: [(label: String, raw: String, smoothed: String, servo: String)] {
        guard handPoseDetector.hasHand else { return [] }

        let smoothed = handPoseDetector.smoothedCurls
        let thumbNorm = normalizedCurl(raw: smoothed.thumb, calibration: calibration?.thumb)
        let indexNorm = normalizedCurl(raw: smoothed.index, calibration: calibration?.index)
        let middleNorm = normalizedCurl(raw: smoothed.middle, calibration: calibration?.middle)
        let ringNorm = normalizedCurl(raw: smoothed.ring, calibration: calibration?.ring)
        let pinkyNorm = normalizedCurl(raw: smoothed.pinky, calibration: calibration?.pinky)

        return [
            ("Thumb", format(smoothed.thumb), format(thumbNorm), "\(servoValue(curl: thumbNorm, min: 0, max: 150))"),
            ("Index", format(smoothed.index), format(indexNorm), "\(servoValue(curl: indexNorm, min: 0, max: 180))"),
            ("Middle", format(smoothed.middle), format(middleNorm), "\(servoValue(curl: middleNorm, min: 0, max: 180))"),
            ("Ring", format(smoothed.ring), format(ringNorm), "\(servoValue(curl: ringNorm, min: 0, max: 180))"),
            ("Pinky", format(smoothed.pinky), format(pinkyNorm), "\(servoValue(curl: pinkyNorm, min: 0, max: 150))")
        ]
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func captureAndMimic() {
        guard handPoseDetector.hasHand else {
            statusText = "No hand detected. Tap to try again."
            return
        }
        let positions = servoPositionsFromSmoothedCurls()
        bleManager.setFingerPositions(positions)
        lastPoseSummary = summaryText(for: positions)
        statusText = "Mimicking hand pose. Tap to capture again."
    }

    private func servoPositionsFromSmoothedCurls() -> FingerServoPositions {
        let smoothed = handPoseDetector.smoothedCurls
        let thumbCurl = normalizedCurl(raw: smoothed.thumb, calibration: calibration?.thumb)
        let indexCurl = normalizedCurl(raw: smoothed.index, calibration: calibration?.index)
        let middleCurl = normalizedCurl(raw: smoothed.middle, calibration: calibration?.middle)
        let ringCurl = normalizedCurl(raw: smoothed.ring, calibration: calibration?.ring)
        let pinkyCurl = normalizedCurl(raw: smoothed.pinky, calibration: calibration?.pinky)

        return FingerServoPositions(
            thumb: servoValue(curl: thumbCurl, min: 0, max: 150),
            index: servoValue(curl: indexCurl, min: 0, max: 180),
            middle: servoValue(curl: middleCurl, min: 0, max: 180),
            ring: servoValue(curl: ringCurl, min: 0, max: 180),
            pinky: servoValue(curl: pinkyCurl, min: 0, max: 150)
        )
    }

    private func summaryText(for positions: FingerServoPositions) -> String {
        "T\(positions.thumb) I\(positions.index) M\(positions.middle) R\(positions.ring) P\(positions.pinky)"
    }

    private func updateSmoothedCurls() {
        guard handPoseDetector.hasHand else {
            handPoseDetector.resetSmoothing()
            return
        }
        let curls = fingerCurls(from: handPoseDetector.recognizedPoints)
        let raw = SmoothedFingerCurls(
            thumb: curls.thumb,
            index: curls.index,
            middle: curls.middle,
            ring: curls.ring,
            pinky: curls.pinky
        )
        handPoseDetector.updateSmoothedCurls(raw: raw)
    }
}

struct HandPoseOverlayView: View {
    let points: [VNHumanHandPoseObservation.JointName: CGPoint]
    let imageSize: CGSize?

    private let jointPairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
        (.wrist, .thumbCMC),
        (.thumbCMC, .thumbMP),
        (.thumbMP, .thumbIP),
        (.thumbIP, .thumbTip),

        (.wrist, .indexMCP),
        (.indexMCP, .indexPIP),
        (.indexPIP, .indexDIP),
        (.indexDIP, .indexTip),

        (.wrist, .middleMCP),
        (.middleMCP, .middlePIP),
        (.middlePIP, .middleDIP),
        (.middleDIP, .middleTip),

        (.wrist, .ringMCP),
        (.ringMCP, .ringPIP),
        (.ringPIP, .ringDIP),
        (.ringDIP, .ringTip),

        (.wrist, .littleMCP),
        (.littleMCP, .littlePIP),
        (.littlePIP, .littleDIP),
        (.littleDIP, .littleTip)
    ]

    var body: some View {
        Canvas { context, size in
            for (startJoint, endJoint) in jointPairs {
                guard let start = points[startJoint], let end = points[endJoint] else { continue }
                let startPoint = viewPoint(from: start, size: size)
                let endPoint = viewPoint(from: end, size: size)
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.green), lineWidth: 3)
            }

            for point in points.values {
                let center = viewPoint(from: point, size: size)
                let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
    }

    private func viewPoint(from normalizedPoint: CGPoint, size: CGSize) -> CGPoint {
        guard let imageSize = imageSize, imageSize.width > 0, imageSize.height > 0 else {
            let x = (1 - normalizedPoint.x) * size.width
            let y = (1 - normalizedPoint.y) * size.height
            return CGPoint(x: x, y: y)
        }

        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let xOffset = (scaledWidth - size.width) / 2
        let yOffset = (scaledHeight - size.height) / 2

        let x = (1 - normalizedPoint.x) * imageSize.width * scale - xOffset
        let y = (1 - normalizedPoint.y) * imageSize.height * scale - yOffset
        return CGPoint(x: x, y: y)
    }
}

struct MimicCalibrationView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @ObservedObject var handPoseDetector: HandPoseDetector
    @Binding var calibration: HandCalibrationData?
    @Environment(\.dismiss) private var dismiss

    @State private var stepIndex: Int = 0
    @State private var workingCalibration: HandCalibrationData = HandCalibrationData()
    @State private var statusText: String = "Position your hand and tap Capture."

    private let steps: [CalibrationStep] = [
        .openHand,
        .closeFist,
        .openThumb,
        .openIndex,
        .openMiddle,
        .openRing,
        .openPinky
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                CameraView(cgImage: cameraManager.currentFrame,
                           cornerRadius: 0,
                           contentMode: .fill,
                           isClipped: true)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(Color.black)

                HandPoseOverlayView(points: handPoseDetector.recognizedPoints,
                                    imageSize: cameraManager.currentFrame.map { CGSize(width: $0.width, height: $0.height) })
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)

                VStack(spacing: 10) {
                    Text("Calibration")
                        .font(.headline)
                    Text(currentStep.title)
                        .font(.title3.bold())
                    Text(currentStep.detail)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("Reset") {
                            resetCalibration()
                        }
                        .buttonStyle(.bordered)

                        Button("Capture") {
                            captureStep()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if let current = calibration {
                workingCalibration = current
            }
        }
        .onChange(of: cameraManager.currentPixelBuffer) { newPixelBuffer in
            if let pixelBuffer = newPixelBuffer {
                handPoseDetector.process(pixelBuffer: pixelBuffer)
            }
        }
    }

    private var currentStep: CalibrationStep {
        steps[min(stepIndex, steps.count - 1)]
    }

    private func captureStep() {
        guard handPoseDetector.hasHand else {
            statusText = "No hand detected. Adjust your hand and try again."
            return
        }
        let curls = fingerCurls(from: handPoseDetector.recognizedPoints)
        switch currentStep {
        case .openHand:
            workingCalibration.setOpenAll(curls)
        case .closeFist:
            workingCalibration.setClosedAll(curls)
        case .openThumb:
            workingCalibration.thumb.open = curls.thumb
        case .openIndex:
            workingCalibration.index.open = curls.index
        case .openMiddle:
            workingCalibration.middle.open = curls.middle
        case .openRing:
            workingCalibration.ring.open = curls.ring
        case .openPinky:
            workingCalibration.pinky.open = curls.pinky
        }

        if stepIndex < steps.count - 1 {
            stepIndex += 1
            statusText = "Captured. Move to the next step."
        } else {
            calibration = workingCalibration
            dismiss()
        }
    }

    private func resetCalibration() {
        workingCalibration = HandCalibrationData()
        calibration = nil
        stepIndex = 0
        statusText = "Calibration reset. Start from open hand."
    }
}

enum CalibrationStep {
    case openHand
    case closeFist
    case openThumb
    case openIndex
    case openMiddle
    case openRing
    case openPinky

    var title: String {
        switch self {
        case .openHand:
            return "Open Hand"
        case .closeFist:
            return "Close Fist"
        case .openThumb:
            return "Open Thumb"
        case .openIndex:
            return "Open Index Finger"
        case .openMiddle:
            return "Open Middle Finger"
        case .openRing:
            return "Open Ring Finger"
        case .openPinky:
            return "Open Pinky Finger"
        }
    }

    var detail: String {
        switch self {
        case .openHand:
            return "Spread your fingers naturally."
        case .closeFist:
            return "Make a tight fist."
        case .openThumb:
            return "Open only your thumb; keep other fingers closed."
        case .openIndex:
            return "Open only your index finger; keep others closed."
        case .openMiddle:
            return "Open only your middle finger; keep others closed."
        case .openRing:
            return "Open only your ring finger; keep others closed."
        case .openPinky:
            return "Open only your pinky finger; keep others closed."
        }
    }
}

struct FingerCalibration: Codable, Equatable {
    var open: Double
    var closed: Double

    init(open: Double = 0.0, closed: Double = 1.0) {
        self.open = open
        self.closed = closed
    }
}

struct HandCalibrationData: Codable, Equatable {
    var thumb: FingerCalibration
    var index: FingerCalibration
    var middle: FingerCalibration
    var ring: FingerCalibration
    var pinky: FingerCalibration

    init() {
        thumb = FingerCalibration()
        index = FingerCalibration()
        middle = FingerCalibration()
        ring = FingerCalibration()
        pinky = FingerCalibration()
    }

    mutating func setOpenAll(_ curls: FingerCurlValues) {
        thumb.open = curls.thumb
        index.open = curls.index
        middle.open = curls.middle
        ring.open = curls.ring
        pinky.open = curls.pinky
    }

    mutating func setClosedAll(_ curls: FingerCurlValues) {
        thumb.closed = curls.thumb
        index.closed = curls.index
        middle.closed = curls.middle
        ring.closed = curls.ring
        pinky.closed = curls.pinky
    }
}

struct FingerCurlValues {
    let thumb: Double
    let index: Double
    let middle: Double
    let ring: Double
    let pinky: Double
}

private func fingerCurls(from points: [VNHumanHandPoseObservation.JointName: CGPoint]) -> FingerCurlValues {
    FingerCurlValues(
        thumb: fingerCurl(points: points, mcp: .thumbCMC, pip: .thumbMP, dip: .thumbIP, tip: .thumbTip),
        index: fingerCurl(points: points, mcp: .indexMCP, pip: .indexPIP, dip: .indexDIP, tip: .indexTip),
        middle: fingerCurl(points: points, mcp: .middleMCP, pip: .middlePIP, dip: .middleDIP, tip: .middleTip),
        ring: fingerCurl(points: points, mcp: .ringMCP, pip: .ringPIP, dip: .ringDIP, tip: .ringTip),
        pinky: fingerCurl(points: points, mcp: .littleMCP, pip: .littlePIP, dip: .littleDIP, tip: .littleTip)
    )
}

/// Calculates finger curl using joint angles (more rotation-invariant than distances)
private func fingerCurl(points: [VNHumanHandPoseObservation.JointName: CGPoint],
                        mcp: VNHumanHandPoseObservation.JointName,
                        pip: VNHumanHandPoseObservation.JointName,
                        dip: VNHumanHandPoseObservation.JointName,
                        tip: VNHumanHandPoseObservation.JointName) -> Double {
    guard let mcpPoint = points[mcp],
          let pipPoint = points[pip],
          let dipPoint = points[dip],
          let tipPoint = points[tip] else {
        return 0.0
    }

    // Calculate angles at PIP and DIP joints
    let pipAngle = angleBetweenVectors(from: mcpPoint, through: pipPoint, to: dipPoint)
    let dipAngle = angleBetweenVectors(from: pipPoint, through: dipPoint, to: tipPoint)

    // Average the joint angles, normalize to 0-1
    // 180° (π) = straight finger = 0 curl
    // ~60° (~π/3) = fully bent = 1 curl
    let avgAngle = (pipAngle + dipAngle) / 2.0
    let minAngle = Double.pi / 3.0  // ~60° for fully curled
    let maxAngle = Double.pi        // 180° for straight

    let normalized = (maxAngle - avgAngle) / (maxAngle - minAngle)
    return clamp(normalized, min: 0.0, max: 1.0)
}

/// Calculates the angle at point b, formed by vectors b→a and b→c
private func angleBetweenVectors(from a: CGPoint, through b: CGPoint, to c: CGPoint) -> Double {
    let v1 = CGPoint(x: a.x - b.x, y: a.y - b.y)
    let v2 = CGPoint(x: c.x - b.x, y: c.y - b.y)

    let dot = Double(v1.x * v2.x + v1.y * v2.y)
    let mag1 = sqrt(Double(v1.x * v1.x + v1.y * v1.y))
    let mag2 = sqrt(Double(v2.x * v2.x + v2.y * v2.y))

    guard mag1 > 0.0001, mag2 > 0.0001 else { return Double.pi }
    return acos(clamp(dot / (mag1 * mag2), min: -1.0, max: 1.0))
}

private func normalizedCurl(raw: Double, calibration: FingerCalibration?) -> Double {
    guard let calibration = calibration, calibration.closed != calibration.open else {
        return clamp(raw, min: 0.0, max: 1.0)
    }
    let value = (raw - calibration.open) / (calibration.closed - calibration.open)
    return clamp(value, min: 0.0, max: 1.0)
}

private func servoValue(curl: Double, min: Int, max: Int) -> Int {
    let clamped = clamp(curl, min: 0.0, max: 1.0)
    let value = Double(min) + clamped * Double(max - min)
    return Int(value.rounded())
}

private func clamp(_ value: Double, min: Double, max: Double) -> Double {
    Swift.max(min, Swift.min(value, max))
}

private func encodeCalibration(_ calibration: HandCalibrationData?) -> String {
    guard let calibration = calibration,
          let data = try? JSONEncoder().encode(calibration) else {
        return ""
    }
    return String(data: data, encoding: .utf8) ?? ""
}

private func decodeCalibration(from json: String) -> HandCalibrationData? {
    guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(HandCalibrationData.self, from: data)
}
