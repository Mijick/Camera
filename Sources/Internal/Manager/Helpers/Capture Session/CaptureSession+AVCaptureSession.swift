//
//  CaptureSession+AVCaptureSession.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import AVKit

extension AVCaptureSession: @unchecked @retroactive Sendable {}
extension AVCaptureSession: CaptureSession {
    
    var deviceInputs: [any CaptureDeviceInput] {
        inputs as? [any CaptureDeviceInput] ?? []
    }
    
    func setStabilizationLevel(_ level: AVCaptureVideoStabilizationMode) {
        for connection in self.connections
        where connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = level
        }
    }
}


// MARK: - METHODS



extension AVCaptureSession {
    func stopRunningAndReturnNewInstance() -> any CaptureSession {
        self.stopRunning()
        return AVCaptureSession()
    }
}
extension AVCaptureSession {
    func add(input: (any CaptureDeviceInput)?) throws(MCameraError) {
        guard let input = input as? AVCaptureDeviceInput else { throw .cannotSetupInput }
        if canAddInput(input) { addInput(input) }
    }
    func remove(input: (any CaptureDeviceInput)?) {
        guard let input = input as? AVCaptureDeviceInput else { return }
        removeInput(input)
    }
}
extension AVCaptureSession {
    func add(output: AVCaptureOutput?) throws(MCameraError) {
        guard let output else { throw .cannotSetupOutput }
        if canAddOutput(output) { addOutput(output) }
    }
}
