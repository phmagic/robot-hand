import AVFoundation
import SwiftUI // For CGImage
import Combine // For Published
import UIKit

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: CGImage?
    @Published var currentPixelBuffer: CVPixelBuffer?
    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.rpsrobot.sessionQueue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var permissionGranted = false
    private let context = CIContext() // Initialize CIContext once

    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOrientationChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            self?.permissionGranted = granted
            if granted {
                self?.setupCaptureSession()
            }
        }
    }

    func setupCaptureSession() {
        guard permissionGranted else {
            print("Camera permission not granted.")
            return
        }

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo // Use a preset suitable for live view and analysis

        guard let session = captureSession else {
            print("Failed to create capture session.")
            return
        }

        // Select the front camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get the front camera.")
            return
        }

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("Could not add video device input to the session.")
                return
            }
        } catch {
            print("Could not create video device input: \(error)")
            return
        }

        // Setup video output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.rpsrobot.videoDataOutputQueue"))
        videoOutput?.alwaysDiscardsLateVideoFrames = true // Recommended for real-time processing
        // Specify pixel format. kCVPixelFormatType_32BGRA is common.
        videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]


        if session.canAddOutput(videoOutput!) {
            session.addOutput(videoOutput!)
            // Ensure correct orientation
            if let connection = videoOutput?.connection(with: .video) {
                updateVideoOrientation()
                // The SwiftUI Image in ContentView uses .upMirrored, which handles the
                // typical front-camera mirroring. So, we don't need to set isVideoMirrored here
                // unless the .upMirrored in SwiftUI isn't achieving the desired effect.
            } else {
                print("Could not get video connection.")
            }
        } else {
            print("Could not add video data output to the session.")
            return
        }
        
        session.startRunning()
        print("Capture session started.")
    }

    @objc private func handleOrientationChange() {
        sessionQueue.async { [weak self] in
            self?.updateVideoOrientation()
        }
    }

    func refreshVideoOrientation() {
        sessionQueue.async { [weak self] in
            self?.updateVideoOrientation()
        }
    }

    private func updateVideoOrientation() {
        guard let connection = videoOutput?.connection(with: .video) else { return }

        var interfaceOrientation: UIInterfaceOrientation?
        let readOrientation = {
            interfaceOrientation = (UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first)?
                .interfaceOrientation
        }

        if Thread.isMainThread {
            readOrientation()
        } else {
            DispatchQueue.main.sync(execute: readOrientation)
        }

        let angle: CGFloat
        switch interfaceOrientation {
//        case .landscapeLeft:
//            angle = 90
//        case .landscapeRight:
//            angle = 270
//        case .portrait:
//            angle = 0
//        case .portraitUpsideDown:
//            angle = 180
        default:
            angle = 0
        }

        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
            print("Video connection rotation angle set to \(angle) degrees.")
        } else {
            print("Video connection does not support rotation angle \(angle).")
        }
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Publish the pixel buffer for ML processing
        DispatchQueue.main.async {
            self.currentPixelBuffer = cvPixelBuffer
        }

        // Existing CGImage conversion for UI display
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        // Use the pre-initialized context
        guard let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        DispatchQueue.main.async {
            self.currentFrame = cgImage
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            print("Capture session stopped.")
        }
    }
}
