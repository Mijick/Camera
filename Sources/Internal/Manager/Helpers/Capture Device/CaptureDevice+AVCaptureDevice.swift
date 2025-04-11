//
//  CaptureDevice+AVCaptureDevice.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import AVKit

// MARK: Getters
extension AVCaptureDevice: CaptureDevice {
    var minExposureDuration: CMTime { activeFormat.minExposureDuration }
    var maxExposureDuration: CMTime { activeFormat.maxExposureDuration }
    var minISO: Float { activeFormat.minISO }
    var maxISO: Float { activeFormat.maxISO }
    var minFrameRate: Float64? { activeFormat.videoSupportedFrameRateRanges.first?.minFrameRate }
    var maxFrameRate: Float64? { activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate }
    var isVideoHDRSupported: Bool { activeFormat.isVideoHDRSupported }
}

// MARK: Getters & Setters
extension AVCaptureDevice {
    var lightMode: CameraLightMode {
        get { torchMode == .off ? .off : .on }
        set { torchMode = newValue == .off ? .off : .on }
    }
    var hdrMode: CameraHDRMode {
        get {
            if automaticallyAdjustsVideoHDREnabled { return .auto }
            else if isVideoHDREnabled { return .on }
            else { return .off }
        }
        set {
            guard isVideoHDRSupported else { return }
            automaticallyAdjustsVideoHDREnabled = newValue == .auto
            if newValue != .auto { isVideoHDREnabled = newValue == .on }
        }
    }
}
