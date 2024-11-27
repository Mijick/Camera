//
//  CameraManager.swift of MijickCameraView
//
//  Created by Tomasz Kurylik
//    - Twitter: https://twitter.com/tkurylik
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//
//  Copyright ©2024 Mijick. Licensed under MIT License.


@preconcurrency import AVKit
import SwiftUI
import CoreMotion
import MijickTimer

@MainActor public class CameraManager: NSObject, ObservableObject {
    @Published var attributes: CameraManagerAttributes = .init()

    // MARK: Input
    private var captureSession: AVCaptureSession!
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    // MARK: Output
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?

    var d: CameraManagerPhoto = .init()

    // MARK: Metal
    private var firstRecordedFrame: UIImage?

    // MARK: UI Elements
    private(set) var cameraLayer: AVCaptureVideoPreviewLayer!
    private(set) var cameraMetalView: CameraMetalView!
    private(set) var cameraGridView: GridView!
    private(set) var cameraFocusView: UIImageView = .create(image: .iconCrosshair, tintColor: .yellow, size: 92)

    // MARK: Other Objects
    private var motionManager: CMMotionManager = .init()
    private var timer: MTimer = .createNewInstance()

    // MARK: Other Attributes
    private(set) var isRunning: Bool = false
    private(set) var frameOrientation: CGImagePropertyOrientation = .right
    private(set) var orientationLocked: Bool = false
}

extension CameraManager {
    func setAttributes(outputType: CameraOutputType? = nil, cameraPosition: CameraPosition? = nil, cameraFilters: [CIFilter]? = nil, resolution: AVCaptureSession.Preset? = nil, frameRate: Int32? = nil, flashMode: CameraFlashMode? = nil, gridVisible: Bool? = nil, cameraFocusImage: UIImage? = nil, cameraFocusImageColor: UIColor? = nil, cameraFocusImageSize: CGFloat? = nil) {
        if let outputType { self.attributes.outputType = outputType }
        if let cameraPosition { self.attributes.cameraPosition = cameraPosition }
        if let cameraFilters { self.attributes.cameraFilters = cameraFilters }
        if let resolution { self.attributes.resolution = resolution }
        if let frameRate { self.attributes.frameRate = frameRate }
        if let flashMode { self.attributes.flashMode = flashMode }
        if let gridVisible { self.attributes.isGridVisible = gridVisible }
        if let cameraFocusImage { self.cameraFocusView.image = cameraFocusImage }
        if let cameraFocusImageColor { self.cameraFocusView.tintColor = cameraFocusImageColor }
        if let cameraFocusImageSize { self.cameraFocusView.frame.size = .init(width: cameraFocusImageSize, height: cameraFocusImageSize) }
    }
}

// MARK: - Cancellation
extension CameraManager {
    func cancel() {
        cancelProcesses()
        removeObservers()
    }
}
private extension CameraManager {
    func cancelProcesses() {
        captureSession.stopRunning()
        motionManager.stopAccelerometerUpdates()
        timer.reset()
    }
    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: captureSession)
    }
}

// MARK: - Changing Attributes
extension CameraManager {
    func resetCapturedMedia() {
        attributes.capturedMedia = nil
    }
    func resetZoomAndTorch() {
        attributes.zoomFactor = 1.0
        attributes.torchMode = .off
    }
}

// MARK: - Initialising Camera
extension CameraManager {
    func setup(in cameraView: UIView) {
        do {
            makeCameraViewInvisible(cameraView)
            checkPermissions()
            initialiseCaptureSession()
            initialiseCameraLayer(cameraView)
            initialiseCameraMetalView()
            initialiseCameraGridView()
            initialiseInputs()
            initialiseOutputs()
            initializeMotionManager()
            initialiseObservers()

            try setupDeviceInputs()
            try setupDeviceOutput()
            try setupFrameRecorder()
            try setupCameraAttributes()
            try setupFrameRate()

            Task { await startCaptureSession() }
        } catch { print("CANNOT SETUP CAMERA: \(error)") }
    }
}
private extension CameraManager {
    func makeCameraViewInvisible(_ view: UIView) {
        view.alpha = 0
    }
    func checkPermissions() { Task { @MainActor in
        do {
            try await checkPermissions(.video)
            try await checkPermissions(.audio)
            animateCameraViewEntrance()
        } catch { attributes.error = error as? CameraManagerError }
    }}
    func initialiseCaptureSession() {
        captureSession = .init()
        captureSession.sessionPreset = attributes.resolution
    }
    func initialiseCameraLayer(_ cameraView: UIView) {
        cameraLayer = .init(session: captureSession)
        cameraLayer.videoGravity = .resizeAspectFill
        cameraLayer.isHidden = true

        cameraView.layer.addSublayer(cameraLayer)
    }
    func initialiseCameraMetalView() {
        cameraMetalView = .init()
        cameraMetalView.setup(self)
    }
    func initialiseCameraGridView() {
        cameraGridView?.removeFromSuperview()
        cameraGridView = .init()
        cameraGridView.alpha = attributes.isGridVisible ? 1 : 0
        cameraGridView.addToParent(cameraView)
    }
    func initialiseInputs() {
        frontCameraInput = .get(for: .video, position: .front, .builtInWideAngleCamera)
        backCameraInput = .get(for: .video)
        audioInput = .get(for: .audio)
    }
    func initialiseOutputs() {
        photoOutput = .init()
        videoOutput = .init()
    }
    func initializeMotionManager() {
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.startAccelerometerUpdates(to: OperationQueue.current ?? .init(), withHandler: handleAccelerometerUpdates)
    }
    func initialiseObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleSessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: captureSession)
    }
    func setupDeviceInputs() throws {
        try setupCameraInput(attributes.cameraPosition)
        try setupInput(audioInput)
    }
    func setupDeviceOutput() throws {
        try setupOutput(photoOutput)
        try setupOutput(videoOutput)
    }
    func setupFrameRecorder() throws {
        let captureVideoOutput = AVCaptureVideoDataOutput()
        captureVideoOutput.setSampleBufferDelegate(cameraMetalView, queue: DispatchQueue.main)

        if captureSession.canAddOutput(captureVideoOutput) { captureSession?.addOutput(captureVideoOutput) }
    }
    func setupCameraAttributes() throws { if let device = getDevice(attributes.cameraPosition) { DispatchQueue.main.async { [self] in
        attributes.cameraExposure.duration = device.exposureDuration
        attributes.cameraExposure.iso = device.iso
        attributes.cameraExposure.targetBias = device.exposureTargetBias
        attributes.cameraExposure.mode = device.exposureMode
        attributes.hdrMode = device.hdrMode
    }}}
    func setupFrameRate() throws { if let device = getDevice(attributes.cameraPosition) {
        try checkNewFrameRate(attributes.frameRate, device)
        try updateFrameRate(attributes.frameRate, device)
    }}
    nonisolated func startCaptureSession() async {
        await captureSession.startRunning()
    }
}
private extension CameraManager {
    func checkPermissions(_ mediaType: AVMediaType) async throws { switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .denied, .restricted: throw getPermissionsError(mediaType)
        case .notDetermined: let granted = await AVCaptureDevice.requestAccess(for: mediaType); if !granted { throw getPermissionsError(mediaType) }
        default: return
    }}
    func animateCameraViewEntrance() {
        UIView.animate(withDuration: 0.3, delay: 1.2) { [self] in cameraView.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [self] in isRunning = true }
    }
    func setupCameraInput(_ cameraPosition: CameraPosition) throws { switch cameraPosition {
        case .front: try setupInput(frontCameraInput)
        case .back: try setupInput(backCameraInput)
    }}
}
private extension CameraManager {
    func getPermissionsError(_ mediaType: AVMediaType) -> CameraManagerError { switch mediaType {
        case .audio: .microphonePermissionsNotGranted
        case .video: .cameraPermissionsNotGranted
        default: .cameraPermissionsNotGranted
    }}
    func setupInput(_ input: AVCaptureDeviceInput?) throws {
        guard let input,
              captureSession.canAddInput(input)
        else { throw CameraManagerError.cannotSetupInput }

        captureSession.addInput(input)
    }
    func setupOutput(_ output: AVCaptureOutput?) throws {
        guard let output,
              captureSession.canAddOutput(output)
        else { throw CameraManagerError.cannotSetupOutput }

        captureSession.addOutput(output)
    }
}

// MARK: - Locking Camera Orientation
extension CameraManager {
    func lockOrientation() {
        orientationLocked = true
    }
}

// MARK: - Changing Output Type
extension CameraManager {
    func changeOutputType(_ newOutputType: CameraOutputType) throws { if newOutputType != attributes.outputType && !isChanging {
        updateCameraOutputType(newOutputType)
        updateTorchMode(.off)
    }}
}
private extension CameraManager {
    func updateCameraOutputType(_ cameraOutputType: CameraOutputType) {
        attributes.outputType = cameraOutputType
    }
}

// MARK: - Changing Camera Position
extension CameraManager {
    func changeCamera(_ newPosition: CameraPosition) throws { if newPosition != attributes.cameraPosition && !isChanging {
        cameraMetalView.captureCurrentFrameAndDelay(.blurAndFlip) { [self] in
            removeCameraInput(attributes.cameraPosition)
            try setupCameraInput(newPosition)
            updateCameraPosition(newPosition)
            
            updateTorchMode(.off)
        }
    }}
}
private extension CameraManager {
    func removeCameraInput(_ position: CameraPosition) { if let input = getInput(position) {
        captureSession.removeInput(input)
    }}
    func updateCameraPosition(_ position: CameraPosition) {
        attributes.cameraPosition = position
    }
}
private extension CameraManager {
    func getInput(_ position: CameraPosition) -> AVCaptureInput? { switch position {
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
    func setCameraFocus(_ touchPoint: CGPoint) throws { if let device = getDevice(attributes.cameraPosition) {
        removeCameraFocusAnimations()
        insertCameraFocus(touchPoint)

        try setCameraFocus(touchPoint, device)
    }}
}
private extension CameraManager {
    func removeCameraFocusAnimations() {
        cameraFocusView.layer.removeAllAnimations()
    }
    func insertCameraFocus(_ touchPoint: CGPoint) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [self] in
        insertNewCameraFocusView(touchPoint)
        animateCameraFocusView()
    }}
    func setCameraFocus(_ touchPoint: CGPoint, _ device: AVCaptureDevice) throws {
        let focusPoint = convertTouchPointToFocusPoint(touchPoint)
        try configureCameraFocus(focusPoint, device)
    }
}
private extension CameraManager {
    func insertNewCameraFocusView(_ touchPoint: CGPoint) {
        cameraFocusView.frame.origin.x = touchPoint.x - cameraFocusView.frame.size.width / 2
        cameraFocusView.frame.origin.y = touchPoint.y - cameraFocusView.frame.size.height / 2
        cameraFocusView.transform = .init(scaleX: 0, y: 0)
        cameraFocusView.alpha = 1

        cameraView.addSubview(cameraFocusView)
    }
    func animateCameraFocusView() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) { [self] in cameraFocusView.transform = .init(scaleX: 1, y: 1) }
        UIView.animate(withDuration: 0.5, delay: 1.5) { [self] in cameraFocusView.alpha = 0.2 } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 3.5) { [self] in cameraFocusView.alpha = 0 }
        }
    }
    func convertTouchPointToFocusPoint(_ touchPoint: CGPoint) -> CGPoint { .init(
        x: touchPoint.y / cameraView.frame.height,
        y: 1 - touchPoint.x / cameraView.frame.width
    )}
    func configureCameraFocus(_ focusPoint: CGPoint, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        setFocusPointOfInterest(focusPoint, device)
        setExposurePointOfInterest(focusPoint, device)
    }}
}
private extension CameraManager {
    func setFocusPointOfInterest(_ focusPoint: CGPoint, _ device: AVCaptureDevice) { if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = focusPoint
        device.focusMode = .autoFocus
    }}
    func setExposurePointOfInterest(_ focusPoint: CGPoint, _ device: AVCaptureDevice) { if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = focusPoint
        device.exposureMode = .autoExpose
    }}
}

// MARK: - Changing Zoom Factor
extension CameraManager {
    func changeZoomFactor(_ value: CGFloat) throws { if let device = getDevice(attributes.cameraPosition), !isChanging {
        let zoomFactor = calculateZoomFactor(value, device)

        try setVideoZoomFactor(zoomFactor, device)
        updateZoomFactor(zoomFactor)
    }}
}
private extension CameraManager {
    func getDevice(_ position: CameraPosition) -> AVCaptureDevice? { switch position {
        case .front: frontCameraInput?.device
        case .back: backCameraInput?.device
    }}
    func calculateZoomFactor(_ value: CGFloat, _ device: AVCaptureDevice) -> CGFloat {
        min(max(value, getMinZoomLevel(device)), getMaxZoomLevel(device))
    }
    func setVideoZoomFactor(_ zoomFactor: CGFloat, _ device: AVCaptureDevice) throws  { try withLockingDeviceForConfiguration(device) { device in
        device.videoZoomFactor = zoomFactor
    }}
    func updateZoomFactor(_ value: CGFloat) {
        attributes.zoomFactor = value
    }
}
private extension CameraManager {
    func getMinZoomLevel(_ device: AVCaptureDevice) -> CGFloat {
        device.minAvailableVideoZoomFactor
    }
    func getMaxZoomLevel(_ device: AVCaptureDevice) -> CGFloat {
        min(device.maxAvailableVideoZoomFactor, 3)
    }
}

// MARK: - Changing Flash Mode
extension CameraManager {
    func changeFlashMode(_ mode: CameraFlashMode) throws { if let device = getDevice(attributes.cameraPosition), device.hasFlash, !isChanging {
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
    func changeTorchMode(_ mode: CameraTorchMode) throws { if let device = getDevice(attributes.cameraPosition), device.hasTorch, !isChanging {
        try changeTorchMode(device, mode)
        updateTorchMode(mode)
    }}
}
private extension CameraManager {
    func changeTorchMode(_ device: AVCaptureDevice, _ mode: CameraTorchMode) throws { try withLockingDeviceForConfiguration(device) { device in
        device.torchMode = mode.get()
    }}
    func updateTorchMode(_ value: CameraTorchMode) {
        attributes.torchMode = value
    }
}

// MARK: - Changing Exposure Mode
extension CameraManager {
    func changeExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode) throws { if let device = getDevice(attributes.cameraPosition), device.isExposureModeSupported(newExposureMode), newExposureMode != attributes.cameraExposure.mode {
        try changeExposureMode(newExposureMode, device)
        updateExposureMode(newExposureMode)
    }}
}
private extension CameraManager {
    func changeExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.exposureMode = newExposureMode
    }}
    func updateExposureMode(_ newExposureMode: AVCaptureDevice.ExposureMode) {
        attributes.cameraExposure.mode = newExposureMode
    }
}

// MARK: - Changing Exposure Duration
extension CameraManager {
    func changeExposureDuration(_ newExposureDuration: CMTime) throws { if let device = getDevice(attributes.cameraPosition), device.isExposureModeSupported(.custom), newExposureDuration != attributes.cameraExposure.duration {
        let newExposureDuration = min(max(newExposureDuration, device.activeFormat.minExposureDuration), device.activeFormat.maxExposureDuration)

        try changeExposureDuration(newExposureDuration, device)
        updateExposureDuration(newExposureDuration)
    }}
}
private extension CameraManager {
    func changeExposureDuration(_ newExposureDuration: CMTime, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.setExposureModeCustom(duration: newExposureDuration, iso: attributes.cameraExposure.iso)
    }}
    func updateExposureDuration(_ newExposureDuration: CMTime) {
        attributes.cameraExposure.duration = newExposureDuration
    }
}

// MARK: - Changing ISO
extension CameraManager {
    func changeISO(_ newISO: Float) throws { if let device = getDevice(attributes.cameraPosition), device.isExposureModeSupported(.custom), newISO != attributes.cameraExposure.iso {
        let newISO = min(max(newISO, device.activeFormat.minISO), device.activeFormat.maxISO)

        try changeISO(newISO, device)
        updateISO(newISO)
    }}
}
private extension CameraManager {
    func changeISO(_ newISO: Float, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.setExposureModeCustom(duration: attributes.cameraExposure.duration, iso: newISO)
    }}
    func updateISO(_ newISO: Float) {
        attributes.cameraExposure.iso = newISO
    }
}

// MARK: - Changing Exposure Target Bias
extension CameraManager {
    func changeExposureTargetBias(_ newExposureTargetBias: Float) throws { if let device = getDevice(attributes.cameraPosition), device.isExposureModeSupported(.custom), newExposureTargetBias != attributes.cameraExposure.targetBias {
        let newExposureTargetBias = min(max(newExposureTargetBias, device.minExposureTargetBias), device.maxExposureTargetBias)

        try changeExposureTargetBias(newExposureTargetBias, device)
        updateExposureTargetBias(newExposureTargetBias)
    }}
}
private extension CameraManager {
    func changeExposureTargetBias(_ newExposureTargetBias: Float, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.setExposureTargetBias(newExposureTargetBias)
    }}
    func updateExposureTargetBias(_ newExposureTargetBias: Float) {
        attributes.cameraExposure.targetBias = newExposureTargetBias
    }
}

// MARK: - Changing Camera HDR Mode
extension CameraManager {
    func changeHDRMode(_ newHDRMode: CameraHDRMode) throws { if let device = getDevice(attributes.cameraPosition), newHDRMode != attributes.hdrMode {
        try changeHDRMode(newHDRMode, device)
        updateHDRMode(newHDRMode)
    }}
}
private extension CameraManager {
    func changeHDRMode(_ newHDRMode: CameraHDRMode, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.hdrMode = newHDRMode
    }}
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
    func changeFrameRate(_ newFrameRate: Int32) throws { if let device = getDevice(attributes.cameraPosition), newFrameRate != attributes.frameRate {
        try checkNewFrameRate(newFrameRate, device)
        try updateFrameRate(newFrameRate, device)
        updateFrameRate(newFrameRate)
    }}
}
private extension CameraManager {
    func checkNewFrameRate(_ newFrameRate: Int32, _ device: AVCaptureDevice) throws { let newFrameRate = Double(newFrameRate), maxFrameRate = device.activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 60
        if newFrameRate < 15 { throw CameraManagerError.incorrectFrameRate }
        if newFrameRate > maxFrameRate { throw CameraManagerError.incorrectFrameRate }
    }
    func updateFrameRate(_ newFrameRate: Int32, _ device: AVCaptureDevice) throws { try withLockingDeviceForConfiguration(device) { device in
        device.activeVideoMinFrameDuration = .init(value: 1, timescale: newFrameRate)
        device.activeVideoMaxFrameDuration = .init(value: 1, timescale: newFrameRate)
    }}
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
        animateGridVisibilityChange(shouldShowGrid)
        updateGridVisibility(shouldShowGrid)
    }}
}
private extension CameraManager {
    func animateGridVisibilityChange(_ shouldShowGrid: Bool) { UIView.animate(withDuration: 0.32) { [self] in
        cameraGridView.alpha = shouldShowGrid ? 1 : 0
    }}
    func updateGridVisibility(_ shouldShowGrid: Bool) {
        attributes.isGridVisible = shouldShowGrid
    }
}

// MARK: - Capturing Output
extension CameraManager {
    func captureOutput() { if !isChanging { switch attributes.outputType {
        case .photo: capturePhoto()
        case .video: toggleVideoRecording()
    }}}
}

// MARK: Photo
private extension CameraManager {
    func capturePhoto() {
        let settings = getPhotoOutputSettings()

        d.parent = self
        configureOutput(photoOutput)
        photoOutput?.capturePhoto(with: settings, delegate: d)
        performCaptureAnimation()
    }
}
private extension CameraManager {
    func getPhotoOutputSettings() -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = attributes.flashMode.get()
        return settings
    }
    func performCaptureAnimation() {
        let view = createCaptureAnimationView()
        cameraView.addSubview(view)

        animateCaptureView(view)
    }
}
private extension CameraManager {
    func createCaptureAnimationView() -> UIView {
        let view = UIView()
        view.frame = cameraView.frame
        view.backgroundColor = .black
        view.alpha = 0
        return view
    }
    func animateCaptureView(_ view: UIView) {
        UIView.animate(withDuration: captureAnimationDuration) { view.alpha = 1 }
        UIView.animate(withDuration: captureAnimationDuration, delay: captureAnimationDuration) { view.alpha = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2 * captureAnimationDuration) { view.removeFromSuperview() }
    }
}
private extension CameraManager {
    var captureAnimationDuration: Double { 0.1 }
}

// MARK: Video
private extension CameraManager {
    func toggleVideoRecording() { switch videoOutput?.isRecording {
        case false: startRecording()
        default: stopRecording()
    }}
}
private extension CameraManager {
    func startRecording() { if let url = prepareUrlForVideoRecording() {
        configureOutput(videoOutput)
        videoOutput?.startRecording(to: url, recordingDelegate: self)
        storeLastFrame()
        updateIsRecording(true)
        startRecordingTimer()
    }}
    func stopRecording() {
        presentLastFrame()
        videoOutput?.stopRecording()
        updateIsRecording(false)
        stopRecordingTimer()
    }
}
private extension CameraManager {
    func prepareUrlForVideoRecording() -> URL? {
        FileManager.prepareURLForVideoOutput()
    }
    func storeLastFrame() {
        guard let texture = cameraMetalView.currentDrawable?.texture,
              let ciImage = CIImage(mtlTexture: texture, options: nil),
              let cgImage = cameraMetalView.ciContext.createCGImage(ciImage, from: ciImage.extent)
        else { return }

        firstRecordedFrame = UIImage(cgImage: cgImage, scale: 1.0, orientation: attributes.deviceOrientation.toImageOrientation())
    }
    func updateIsRecording(_ value: Bool) {
        attributes.isRecording = value
    }
    func startRecordingTimer() {
        try? timer
            .publish(every: 1) { [self] in attributes.recordingTime = $0 }
            .start()
    }
    func presentLastFrame() {
        attributes.capturedMedia = .init(data: firstRecordedFrame)
    }
    func stopRecordingTimer() {
        timer.reset()
    }
}

extension CameraManager: @preconcurrency AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Swift.Error)?) { Task {
        attributes.capturedMedia = try await .create(videoData: outputFileURL, filters: attributes.cameraFilters)
    }}
}

// MARK: - Handling Device Rotation
private extension CameraManager {
    func handleAccelerometerUpdates(_ data: CMAccelerometerData?, _ error: Swift.Error?) { if let data, error == nil {
        let newDeviceOrientation = fetchDeviceOrientation(data.acceleration)
        updateDeviceOrientation(newDeviceOrientation)
        updateUserBlockedScreenRotation()
        updateFrameOrientation()
        redrawGrid()
    }}
}
private extension CameraManager {
    func fetchDeviceOrientation(_ acceleration: CMAcceleration) -> AVCaptureVideoOrientation { switch acceleration {
        case let acceleration where acceleration.x >= 0.75: .landscapeLeft
        case let acceleration where acceleration.x <= -0.75: .landscapeRight
        case let acceleration where acceleration.y <= -0.75: .portrait
        case let acceleration where acceleration.y >= 0.75: .portraitUpsideDown
        default: attributes.deviceOrientation
    }}
    func updateDeviceOrientation(_ newDeviceOrientation: AVCaptureVideoOrientation) { if newDeviceOrientation != attributes.deviceOrientation {
        attributes.deviceOrientation = newDeviceOrientation
    }}
    func updateUserBlockedScreenRotation() {
        let newUserBlockedScreenRotation = getNewUserBlockedScreenRotation()
        updateUserBlockedScreenRotation(newUserBlockedScreenRotation)
    }
    func updateFrameOrientation() { if UIDevice.current.orientation != .portraitUpsideDown {
        let newFrameOrientation = getNewFrameOrientation(orientationLocked ? .portrait : UIDevice.current.orientation)
        updateFrameOrientation(newFrameOrientation)
    }}
    func redrawGrid() { if !orientationLocked {
        cameraGridView?.draw(.zero)
    }}
}
private extension CameraManager {
    func getNewUserBlockedScreenRotation() -> Bool { switch attributes.deviceOrientation.rawValue == UIDevice.current.orientation.rawValue {
        case true: false
        case false: !orientationLocked
    }}
    func updateUserBlockedScreenRotation(_ newUserBlockedScreenRotation: Bool) { if newUserBlockedScreenRotation != attributes.userBlockedScreenRotation {
        attributes.userBlockedScreenRotation = newUserBlockedScreenRotation
    }}
    func getNewFrameOrientation(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation { switch attributes.cameraPosition {
        case .back: getNewFrameOrientationForBackCamera(orientation)
        case .front: getNewFrameOrientationForFrontCamera(orientation)
    }}
    func updateFrameOrientation(_ newFrameOrientation: CGImagePropertyOrientation) { if newFrameOrientation != frameOrientation {
        let shouldAnimate = shouldAnimateFrameOrientationChange(newFrameOrientation) && isRunning

        animateFrameOrientationChangeIfNeeded(shouldAnimate)
        changeFrameOrientation(shouldAnimate, newFrameOrientation)
    }}
}
private extension CameraManager {
    func getNewFrameOrientationForBackCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation { switch orientation {
        case .portrait: attributes.mirrorOutput ? .leftMirrored : .right
        case .landscapeLeft: attributes.mirrorOutput ? .upMirrored : .up
        case .landscapeRight: attributes.mirrorOutput ? .downMirrored : .down
        default: attributes.mirrorOutput ? .leftMirrored : .right
    }}
    func getNewFrameOrientationForFrontCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation { switch orientation {
        case .portrait: attributes.mirrorOutput ? .right : .leftMirrored
        case .landscapeLeft: attributes.mirrorOutput ? .down : .downMirrored
        case .landscapeRight: attributes.mirrorOutput ? .up : .upMirrored
        default: attributes.mirrorOutput ? .right : .leftMirrored
    }}
    func shouldAnimateFrameOrientationChange(_ newFrameOrientation: CGImagePropertyOrientation) -> Bool {
        let backCameraOrientations: [CGImagePropertyOrientation] = [.left, .right, .up, .down],
            frontCameraOrientations: [CGImagePropertyOrientation] = [.leftMirrored, .rightMirrored, .upMirrored, .downMirrored]
        return (backCameraOrientations.contains(newFrameOrientation) && backCameraOrientations.contains(frameOrientation))
            || (frontCameraOrientations.contains(frameOrientation) && frontCameraOrientations.contains(newFrameOrientation))
    }
    func animateFrameOrientationChangeIfNeeded(_ shouldAnimate: Bool) { if shouldAnimate {
        UIView.animate(withDuration: 0.2) { [self] in cameraView.alpha = 0 }
        UIView.animate(withDuration: 0.3, delay: 0.2) { [self] in cameraView.alpha = 1 }
    }}
    func changeFrameOrientation(_ shouldAnimate: Bool, _ newFrameOrientation: CGImagePropertyOrientation) { DispatchQueue.main.asyncAfter(deadline: .now() + (shouldAnimate ? 0.1 : 0)) { [self] in
        frameOrientation = newFrameOrientation
    }}
}

// MARK: - Handling Observers
private extension CameraManager {
    @objc func handleSessionWasInterrupted() {
        attributes.torchMode = .off
        updateIsRecording(false)
        stopRecordingTimer()
    }
}

// MARK: - Modifiers
extension CameraManager {
    var hasFlash: Bool { getDevice(attributes.cameraPosition)?.hasFlash ?? false }
    var hasTorch: Bool { getDevice(attributes.cameraPosition)?.hasTorch ?? false }
}

// MARK: - Helpers
private extension CameraManager {
    func configureOutput(_ output: AVCaptureOutput?) { if let connection = output?.connection(with: .video), connection.isVideoMirroringSupported {
        connection.isVideoMirrored = attributes.mirrorOutput ? attributes.cameraPosition != .front : attributes.cameraPosition == .front
        connection.videoOrientation = attributes.deviceOrientation
    }}
    func withLockingDeviceForConfiguration(_ device: AVCaptureDevice, _ action: (AVCaptureDevice) -> ()) throws {
        try device.lockForConfiguration()
        action(device)
        device.unlockForConfiguration()
    }
}
 extension CameraManager {
    var cameraView: UIView { cameraLayer.superview ?? .init() }
    var isChanging: Bool { cameraMetalView.isChanging }
}


// MARK: - Errors
public enum CameraManagerError: Error {
    case microphonePermissionsNotGranted, cameraPermissionsNotGranted
    case cannotSetupInput, cannotSetupOutput, capturedPhotoCannotBeFetched
    case incorrectFrameRate
}
