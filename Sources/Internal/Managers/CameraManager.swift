//
//  CameraManager.swift of MijickCameraView
//
//  Created by Tomasz Kurylik
//    - Twitter: https://twitter.com/tkurylik
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//
//  Copyright ©2024 Mijick. Licensed under MIT License.


import SwiftUI
import AVKit

@MainActor public class CameraManager: NSObject, ObservableObject {
    @Published var attributes: CameraManagerAttributes = .init()

    // MARK: Input
    private(set) var captureSession: any CaptureSession
    private(set) var frontCameraInput: (any CaptureDeviceInput)?
    private(set) var backCameraInput: (any CaptureDeviceInput)?
    private(set) var audioInput: (any CaptureDeviceInput)?

    // MARK: Output
    private(set) var photoOutput: CameraManagerPhoto = .init()
    private(set) var videoOutput: CameraManagerVideo = .init()

    // MARK: UI Elements
    private(set) var cameraLayer: AVCaptureVideoPreviewLayer = .init()
    private(set) var cameraMetalView: CameraMetalView = .init()
    private(set) var cameraGridView: GridView = .init()

    // MARK: Others
    private(set) var permissionsManager: CameraManagerPermissionsManager = .init()
    private(set) var motionManager: CameraManagerMotionManager = .init()
    private(set) var notificationCenterManager: CameraManagerNotificationCenter = .init()

    // MARK: Initializer
    init<CS: CaptureSession, CDI: CaptureDeviceInput>(captureSession: CS, fontCameraInput: CDI?, backCameraInput: CDI?, audioInput: CDI?) {
        self.captureSession = captureSession
        self.frontCameraInput = fontCameraInput
        self.backCameraInput = backCameraInput
        self.audioInput = audioInput
    }
}

// MARK: Setup
extension CameraManager {
    func setup(in cameraView: UIView) async throws {
        await permissionsManager.requestAccess(parent: self)

        setupCameraLayer(cameraView)
        try setupDeviceInputs()
        try setupDevice()
        try setupDeviceOutput()
        try setupFrameRecorder()
        notificationCenterManager.setup(parent: self)
        motionManager.setup(parent: self)
        try cameraMetalView.setup(parent: self)
        cameraGridView.setup(parent: self)

        startSession()
    }
}
private extension CameraManager {
    func setupCameraLayer(_ cameraView: UIView) {
        captureSession.sessionPreset = attributes.resolution

        cameraLayer.session = captureSession as? AVCaptureSession
        cameraLayer.videoGravity = .resizeAspectFill
        cameraLayer.isHidden = true
        cameraView.layer.addSublayer(cameraLayer)
    }
    func setupDeviceInputs() throws {
        try captureSession.add(input: currentCameraInput)
        if attributes.isAudioSourceAvailable { try captureSession.add(input: audioInput) }
    }
    func setupDevice() throws {
        guard let device = currentCameraInput?.device else { return }

        try device.lockForConfiguration()
        device.setExposureMode(attributes.cameraExposure.mode, duration: attributes.cameraExposure.duration, iso: attributes.cameraExposure.iso)
        device.setExposureTargetBias(attributes.cameraExposure.targetBias)
        device.setFrameRate(attributes.frameRate)
        device.hdrMode = attributes.hdrMode
        device.unlockForConfiguration()
    }
    func setupDeviceOutput() throws {
        try photoOutput.setup(parent: self)
        try videoOutput.setup(parent: self)
    }
    func setupFrameRecorder() throws {
        let captureVideoOutput = AVCaptureVideoDataOutput()
        captureVideoOutput.setSampleBufferDelegate(cameraMetalView, queue: DispatchQueue.main)

        try captureSession.add(output: captureVideoOutput)
    }
    func startSession() { Task.detached { [self] in
        await captureSession.startRunning()
        await cameraMetalView.performCameraEntranceAnimation()
    }}
}

// MARK: Cancel
extension CameraManager {
    func cancel() {
        captureSession = captureSession.stopRunningAndReturnNewInstance()
        motionManager.reset()
        videoOutput.reset()
        notificationCenterManager.reset()
    }
}


// MARK: - LIVE UPDATES



// MARK: Output Type
extension CameraManager {
    func setOutputType(_ outputType: CameraOutputType) throws {
        guard outputType != attributes.outputType, !isChanging else { return }

        attributes.outputType = outputType
        attributes.torchMode = .off
    }
}





// MARK: - Changing Camera Position
extension CameraManager {
    func changeCamera(_ newPosition: CameraPosition) throws { Task { if newPosition != attributes.cameraPosition && !isChanging {
        await cameraMetalView.beginCameraFlipAnimation()
        
        removeCameraInput(attributes.cameraPosition)
        try setupCameraInput(newPosition)
        updateCameraPosition(newPosition)
        updateTorchMode(.off)
        cameraMetalView.finishCameraFlipAnimation()
    }}}
}
private extension CameraManager {
    func removeCameraInput(_ position: CameraPosition) { if let input = getInput(position) {
        captureSession.remove(input: input)
    }}
    func updateCameraPosition(_ position: CameraPosition) {
        attributes.cameraPosition = position
    }
}
private extension CameraManager {
    func getInput(_ position: CameraPosition) -> (any CaptureDeviceInput)? { switch position {
        case .front: frontCameraInput
        case .back: backCameraInput
    }}
}

// MARK: - Changing Camera Filters
extension CameraManager {
    func changeCameraFilters(_ newCameraFilters: [CIFilter]) throws { if newCameraFilters != attributes.cameraFilters {
        attributes.cameraFilters = newCameraFilters
    }}
}

// MARK: - Camera Focusing
extension CameraManager {
    func setCameraFocus(_ touchPoint: CGPoint) throws { if let device = currentCameraInput?.device {
        try setCameraFocus(touchPoint, device)
        cameraMetalView.performCameraFocusAnimation(touchPoint: touchPoint)
    }}
}
private extension CameraManager {
    func setCameraFocus(_ touchPoint: CGPoint, _ device: any CaptureDevice) throws {
        let focusPoint = convertTouchPointToFocusPoint(touchPoint)
        try configureCameraFocus(focusPoint, device)
    }
}
private extension CameraManager {
    func convertTouchPointToFocusPoint(_ touchPoint: CGPoint) -> CGPoint { .init(
        x: touchPoint.y / cameraView.frame.height,
        y: 1 - touchPoint.x / cameraView.frame.width
    )}
    func configureCameraFocus(_ focusPoint: CGPoint, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        setFocusPointOfInterest(focusPoint, device)
        setExposurePointOfInterest(focusPoint, device)
        device.unlockForConfiguration()
    }
}
private extension CameraManager {
    func setFocusPointOfInterest(_ focusPoint: CGPoint, _ device: any CaptureDevice) { if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = focusPoint
        device.focusMode = .autoFocus
    }}
    func setExposurePointOfInterest(_ focusPoint: CGPoint, _ device: any CaptureDevice) { if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = focusPoint
        device.exposureMode = .autoExpose
    }}
}

// MARK: - Changing Zoom Factor
extension CameraManager {
    func changeZoomFactor(_ factor: CGFloat) throws { if let device = currentCameraInput?.device, !isChanging {
        try setVideoZoomFactor(factor, device)
        updateZoomFactor(factor)
    }}
}
private extension CameraManager {
    func setVideoZoomFactor(_ zoomFactor: CGFloat, _ device: any CaptureDevice) throws  {
        try device.lockForConfiguration()
        device.setZoomFactor(zoomFactor)
        device.unlockForConfiguration()
    }
    func updateZoomFactor(_ value: CGFloat) {
        attributes.zoomFactor = value
    }
}

// MARK: - Changing Flash Mode
extension CameraManager {
    func changeFlashMode(_ mode: CameraFlashMode) throws { if let device = currentCameraInput?.device, device.hasFlash, !isChanging {
        updateFlashMode(mode)
    }}
}
private extension CameraManager {
    func updateFlashMode(_ value: CameraFlashMode) {
        attributes.flashMode = value
    }
}

// MARK: - Changing Torch Mode
extension CameraManager {
    func changeTorchMode(_ mode: CameraTorchMode) throws { if let device = currentCameraInput?.device, device.hasTorch, !isChanging {
        try changeTorchMode(device, mode)
        updateTorchMode(mode)
    }}
}
private extension CameraManager {
    func changeTorchMode(_ device: any CaptureDevice, _ mode: CameraTorchMode) throws {
        try device.lockForConfiguration()
        device.torchMode = mode.get()
        device.unlockForConfiguration()
    }
    func updateTorchMode(_ value: CameraTorchMode) {
        attributes.torchMode = value
    }
}

// MARK: - Changing Exposure Mode
extension CameraManager {
    func changeExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode) throws { if let device = currentCameraInput?.device, newExposureMode != attributes.cameraExposure.mode {
        try changeExposureMode(newExposureMode, device)
        updateExposureMode(newExposureMode)
    }}
}
private extension CameraManager {
    func changeExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.setExposureMode(newExposureMode, duration: attributes.cameraExposure.duration, iso: attributes.cameraExposure.iso)
        device.unlockForConfiguration()
    }
    func updateExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode) {
        attributes.cameraExposure.mode = newExposureMode
    }
}

// MARK: - Changing Exposure Duration
extension CameraManager {
    func changeExposureDuration(_ newExposureDuration: CMTime) throws { if let device = currentCameraInput?.device, newExposureDuration != attributes.cameraExposure.duration {
        try changeExposureDuration(newExposureDuration, device)
        updateExposureDuration(newExposureDuration)
    }}
}
private extension CameraManager {
    func changeExposureDuration(_ newExposureDuration: CMTime, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.setExposureMode(.custom, duration: newExposureDuration, iso: attributes.cameraExposure.iso)
        device.unlockForConfiguration()
    }
    func updateExposureDuration(_ newExposureDuration: CMTime) {
        attributes.cameraExposure.duration = newExposureDuration
    }
}

// MARK: - Changing ISO
extension CameraManager {
    func changeISO(_ newISO: Float) throws { if let device = currentCameraInput?.device, newISO != attributes.cameraExposure.iso {
        try changeISO(newISO, device)
        updateISO(newISO)
    }}
}
private extension CameraManager {
    func changeISO(_ newISO: Float, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.setExposureMode(.custom, duration: attributes.cameraExposure.duration, iso: newISO)
        device.unlockForConfiguration()
    }
    func updateISO(_ newISO: Float) {
        attributes.cameraExposure.iso = newISO
    }
}

// MARK: - Changing Exposure Target Bias
extension CameraManager {
    func changeExposureTargetBias(_ newExposureTargetBias: Float) throws { if let device = currentCameraInput?.device, newExposureTargetBias != attributes.cameraExposure.targetBias {
        try changeExposureTargetBias(newExposureTargetBias, device)
        updateExposureTargetBias(newExposureTargetBias)
    }}
}
private extension CameraManager {
    func changeExposureTargetBias(_ newExposureTargetBias: Float, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.setExposureTargetBias(newExposureTargetBias)
        device.unlockForConfiguration()
    }
    func updateExposureTargetBias(_ newExposureTargetBias: Float) {
        attributes.cameraExposure.targetBias = newExposureTargetBias
    }
}

// MARK: - Changing Camera HDR Mode
extension CameraManager {
    func changeHDRMode(_ newHDRMode: CameraHDRMode) throws { if let device = currentCameraInput?.device, newHDRMode != attributes.hdrMode {
        try changeHDRMode(newHDRMode, device)
        updateHDRMode(newHDRMode)
    }}
}
private extension CameraManager {
    func changeHDRMode(_ newHDRMode: CameraHDRMode, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.hdrMode = newHDRMode
        device.unlockForConfiguration()
    }
    func updateHDRMode(_ newHDRMode: CameraHDRMode) {
        attributes.hdrMode = newHDRMode
    }
}

// MARK: - Changing Camera Resolution
extension CameraManager {
    func changeResolution(_ newResolution: AVCaptureSession.Preset) throws { if newResolution != attributes.resolution {
        captureSession.sessionPreset = newResolution
        attributes.resolution = newResolution
    }}
}

// MARK: - Changing Frame Rate
extension CameraManager {
    func changeFrameRate(_ newFrameRate: Int32) throws { if let device = currentCameraInput?.device, newFrameRate != attributes.frameRate {
        try updateFrameRate(newFrameRate, device)
        updateFrameRate(newFrameRate)
    }}
}
private extension CameraManager {
    func updateFrameRate(_ newFrameRate: Int32, _ device: any CaptureDevice) throws {
        try device.lockForConfiguration()
        device.setFrameRate(newFrameRate)
        device.unlockForConfiguration()
    }
    func updateFrameRate(_ newFrameRate: Int32) {
        attributes.frameRate = newFrameRate
    }
}

// MARK: - Changing Mirror Mode
extension CameraManager {
    func changeMirrorMode(_ shouldMirror: Bool) { if !isChanging {
        attributes.mirrorOutput = shouldMirror
    }}
}

// MARK: - Changing Grid Mode
extension CameraManager {
    func changeGridVisibility(_ shouldShowGrid: Bool) { if !isChanging {
        cameraGridView.changeVisibility(shouldShowGrid)
    }}
}

// MARK: - Capturing Output
extension CameraManager {
    func captureOutput() { if !isChanging { switch attributes.outputType {
        case .photo: photoOutput.capture()
        case .video: videoOutput.toggleRecording()
    }}}
}

// MARK: - Modifiers
extension CameraManager {
    var hasFlash: Bool { currentCameraInput?.device.hasFlash ?? false }
    var hasTorch: Bool { currentCameraInput?.device.hasTorch ?? false }
}

// MARK: - Helpers
extension CameraManager {
    var currentCameraInput: (any CaptureDeviceInput)? { switch attributes.cameraPosition {
        case .front: frontCameraInput
        case .back: backCameraInput
    }}
    var cameraView: UIView { cameraLayer.superview ?? .init() }
    var isChanging: Bool { cameraMetalView.isAnimating }
}


// MARK: - Errors
public enum MijickCameraError: Error {
    case microphonePermissionsNotGranted, cameraPermissionsNotGranted
    case cannotSetupInput, cannotSetupOutput
    case cannotCreateMetalDevice
    case incorrectFrameRate
}




// MARK: - Initialising Camera
private extension CameraManager {
    func setupCameraInput(_ cameraPosition: CameraPosition) throws { switch cameraPosition {
        case .front: try setupInput(frontCameraInput)
        case .back: try setupInput(backCameraInput)
    }}
}
private extension CameraManager {
    func setupInput(_ input: (any CaptureDeviceInput)?) throws {
        try captureSession.add(input: input)
    }
}




// Dodać możliwe błędy przy set exposure, itd.
