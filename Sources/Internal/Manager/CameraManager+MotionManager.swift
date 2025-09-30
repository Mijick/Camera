//
//  CameraManager+MotionManager.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import CoreMotion
import AVKit

@MainActor class CameraManagerMotionManager {
    private(set) weak var parent: CameraManager?
    private(set) var manager: CMMotionManager = .init()
}

// MARK: Setup
extension CameraManagerMotionManager {
    func setup(parent: CameraManager) {
        self.parent = parent
        manager.accelerometerUpdateInterval = 0.05
        manager.startAccelerometerUpdates(to: .current ?? .init(), withHandler: handleAccelerometerUpdates)
    }
}
private extension CameraManagerMotionManager {
    func handleAccelerometerUpdates(_ data: CMAccelerometerData?, _ error: Error?) {
        guard let data, error == nil, parent != nil else { return }

        let newDeviceOrientation = getDeviceOrientation(data.acceleration)
        updateDeviceOrientation(newDeviceOrientation)
        updateUserBlockedScreenRotation()
        updateFrameOrientation()
        redrawGrid()
    }
}
private extension CameraManagerMotionManager {
    func getDeviceOrientation(_ acceleration: CMAcceleration) -> AVCaptureVideoOrientation {
        switch acceleration {
        case let acceleration where acceleration.x >= 0.75: .landscapeLeft
        case let acceleration where acceleration.x <= -0.75: .landscapeRight
        case let acceleration where acceleration.y <= -0.75: .portrait
        case let acceleration where acceleration.y >= 0.75: .portraitUpsideDown
        default: parent?.attributes.deviceOrientation ?? AVCaptureVideoOrientation.portrait
        }
    }
    func updateDeviceOrientation(_ newDeviceOrientation: AVCaptureVideoOrientation) {
        if newDeviceOrientation != parent?.attributes.deviceOrientation {
            parent?.attributes.deviceOrientation = newDeviceOrientation
        }
    }
    func updateUserBlockedScreenRotation() {
        let newUserBlockedScreenRotation = getNewUserBlockedScreenRotation()
        if newUserBlockedScreenRotation != parent?.attributes.userBlockedScreenRotation {
            parent?.attributes.userBlockedScreenRotation = newUserBlockedScreenRotation
        }
    }
    func updateFrameOrientation() {
        guard let parent else { return }

        if UIDevice.current.orientation != .portraitUpsideDown {
            let newFrameOrientation = getNewFrameOrientation(parent.attributes.orientationLocked ? .portrait : UIDevice.current.orientation)
            updateFrameOrientation(newFrameOrientation)
        }
    }
    func redrawGrid() {
        guard let parent else { return }

        if !parent.attributes.orientationLocked {
            parent.cameraGridView.draw(.zero)
        }
    }
}
private extension CameraManagerMotionManager {
    func getNewUserBlockedScreenRotation() -> Bool {
        guard let parent else { return false }

        return switch parent.attributes.deviceOrientation.rawValue == UIDevice.current.orientation.rawValue {
        case true: false
        case false: !parent.attributes.orientationLocked
        }
    }
    func getNewFrameOrientation(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .up }

        return switch parent.attributes.cameraPosition {
        case .back: getNewFrameOrientationForBackCamera(orientation)
        case .front: getNewFrameOrientationForFrontCamera(orientation)
        }
    }
    func updateFrameOrientation(_ newFrameOrientation: CGImagePropertyOrientation) {
        guard let parent else { return }

        if newFrameOrientation != parent.attributes.frameOrientation {
            let shouldAnimate = shouldAnimateFrameOrientationChange(newFrameOrientation)
            updateFrameOrientation(withAnimation: shouldAnimate, newFrameOrientation: newFrameOrientation)
        }
    }
}
private extension CameraManagerMotionManager {
    func getNewFrameOrientationForBackCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .up }
        
        return switch orientation {
        case .portrait: parent.attributes.mirrorOutput ? .leftMirrored : .right
        case .landscapeLeft: parent.attributes.mirrorOutput ? .upMirrored : .up
        case .landscapeRight: parent.attributes.mirrorOutput ? .downMirrored : .down
        default: parent.attributes.mirrorOutput ? .leftMirrored : .right
        }
    }
    func getNewFrameOrientationForFrontCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .up }

        return switch orientation {
        case .portrait: parent.attributes.mirrorOutput ? .right : .leftMirrored
        case .landscapeLeft: parent.attributes.mirrorOutput ? .down : .downMirrored
        case .landscapeRight: parent.attributes.mirrorOutput ? .up : .upMirrored
        default: parent.attributes.mirrorOutput ? .right : .leftMirrored
        }
    }
    func shouldAnimateFrameOrientationChange(_ newFrameOrientation: CGImagePropertyOrientation) -> Bool {
        guard let parent else { return false }

        let backCameraOrientations: [CGImagePropertyOrientation] = [.left, .right, .up, .down],
            frontCameraOrientations: [CGImagePropertyOrientation] = [.leftMirrored, .rightMirrored, .upMirrored, .downMirrored]

        return (backCameraOrientations.contains(newFrameOrientation) && backCameraOrientations.contains(parent.attributes.frameOrientation)) ||
        (frontCameraOrientations.contains(parent.attributes.frameOrientation) && frontCameraOrientations.contains(newFrameOrientation))
    }
    func updateFrameOrientation(withAnimation shouldAnimate: Bool, newFrameOrientation: CGImagePropertyOrientation) {
        Task {
            guard let parent else { return }
            await parent.cameraMetalView.beginCameraOrientationAnimation(if: shouldAnimate)
            parent.attributes.frameOrientation = newFrameOrientation
            parent.cameraMetalView.finishCameraOrientationAnimation(if: shouldAnimate)
        }
    }
}

// MARK: Reset
extension CameraManagerMotionManager {
    func reset() {
        manager.stopAccelerometerUpdates()
    }
}
