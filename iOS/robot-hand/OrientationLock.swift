import UIKit

enum OrientationLock {
    static func lockLandscape() {
        let orientation: UIInterfaceOrientation
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            orientation = .landscapeLeft
        case .landscapeRight:
            orientation = .landscapeRight
        default:
            orientation = .landscapeRight
        }
        lock(.landscape, rotateTo: orientation)
    }

    static func lock(_ mask: UIInterfaceOrientationMask, rotateTo orientation: UIInterfaceOrientation? = nil) {
        let apply = {
            AppDelegate.orientationLock = mask
            if #available(iOS 16.0, *),
               let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                    print("Orientation lock request failed: \(error)")
                }
            }
            if let orientation = orientation {
                UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            }
            UIViewController.attemptRotationToDeviceOrientation()
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    static func unlock() {
        lock(.all, rotateTo: nil)
    }
}
