//
//  CaptureSession+MockCaptureSession.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import AVKit

extension MockCaptureSession: @unchecked Sendable {}
class MockCaptureSession: NSObject, CaptureSession {
    func setStabilizationLevel(_ level: AVCaptureVideoStabilizationMode) { }
    required override init() {}
    // MARK: Attributes
    var isRunning: Bool { _isRunning }
    var deviceInputs: [any CaptureDeviceInput] { _deviceInputs }
    var outputs: [AVCaptureOutput] { _outputs }
    var sessionPreset: AVCaptureSession.Preset = .cif352x288

    // MARK: Private Attributes
    private var _isRunning: Bool = false
    private var _deviceInputs: [any CaptureDeviceInput] = []
    private var _outputs: [AVCaptureOutput] = []
}


// MARK: - METHODS



extension MockCaptureSession {
    func startRunning() { Task { @MainActor in
        _isRunning = true
    }}
    func stopRunningAndReturnNewInstance() -> any CaptureSession {
        _isRunning = false
        return MockCaptureSession()
    }
}
extension MockCaptureSession {
    func add(input: (any CaptureDeviceInput)?) throws(MCameraError) {
        guard let input = input as? MockDeviceInput, !_deviceInputs.contains(where: { input == $0 }) else { throw .cannotSetupInput }
        _deviceInputs.append(input)
    }
    func remove(input: (any CaptureDeviceInput)?) {
        guard let input = input as? MockDeviceInput, let index = _deviceInputs.firstIndex(where: { $0.device.uniqueID == input.device.uniqueID }) else { return }
        _deviceInputs.remove(at: index)
    }
}
extension MockCaptureSession {
    func add(output: AVCaptureOutput?) throws(MCameraError) {
        guard let output, !outputs.contains(output) else { throw .cannotSetupOutput }
        _outputs.append(output)
    }
}
