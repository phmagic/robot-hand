import SwiftUI

struct PredictionCameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var imageClassifier: ImageClassifier

    private let frameHeight: CGFloat?
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let bottomPadding: CGFloat
    private let showsOverlay: Bool
    private let autoClassify: Bool
    private let contentMode: ContentMode
    private let isClipped: Bool
    private let overlayAlignment: Alignment

    init(frameHeight: CGFloat? = 300,
         cornerRadius: CGFloat = 10,
         horizontalPadding: CGFloat = 16,
         bottomPadding: CGFloat = 5,
         showsOverlay: Bool = true,
         autoClassify: Bool = true,
         contentMode: ContentMode = .fit,
         isClipped: Bool = false,
         overlayAlignment: Alignment = .bottom) {
        self.frameHeight = frameHeight
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.showsOverlay = showsOverlay
        self.autoClassify = autoClassify
        self.contentMode = contentMode
        self.isClipped = isClipped
        self.overlayAlignment = overlayAlignment
    }
    
    var body: some View {
        ZStack(alignment: overlayAlignment) {
            CameraView(cgImage: cameraManager.currentFrame,
                       cornerRadius: cornerRadius,
                       contentMode: contentMode,
                       isClipped: isClipped)
            if showsOverlay, let pred = imageClassifier.currentPrediction {
                PredictionOverlayView(prediction: pred.label,
                                      confidence: pred.confidence)
            }
            
        }
        .frame(height: frameHeight)
        .frame(maxWidth: .infinity, maxHeight: frameHeight == nil ? .infinity : nil)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
        .onChange(of: cameraManager.currentPixelBuffer) { newPixelBuffer in
            guard autoClassify else { return }
            if let pixelBuffer = newPixelBuffer {
                imageClassifier.classifyImage(pixelBuffer: pixelBuffer)
            }
        }
        
    }
}

// Helper sub-views for better organization
struct CameraView: View {
    let cgImage: CGImage?
    var cornerRadius: CGFloat = 10
    var contentMode: ContentMode = .fit
    var isClipped: Bool = false
    var body: some View {
        if let image = cgImage {
            let cameraImage = Image(image, scale: 1.0, orientation: .upMirrored, label: Text("Camera Feed"))
                .resizable()
            Group {
                if contentMode == .fill {
                    cameraImage
                        .scaledToFill()
                } else {
                    cameraImage
                        .scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .if(isClipped) { view in
                view.clipped()
            }
            .cornerRadius(cornerRadius)
            .shadow(radius: 3)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(cornerRadius)
                .overlay(Text("Camera feed unavailable").foregroundColor(.white))
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct PredictionOverlayView: View {
    let prediction: String
    let confidence: Float
    var body: some View {
        VStack {
            Text("Prediction: \(prediction)")
                .font(.callout).bold()
            Text("Confidence: \(String(format: "%.1f", confidence * 100))%")
                .font(.caption)
        }
        .padding(6)
        .background(Color.black.opacity(0.55))
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding(6)
    }
}
