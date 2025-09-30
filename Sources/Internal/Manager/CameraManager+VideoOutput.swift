//
//  CameraManager+VideoOutput.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


@preconcurrency import AVKit
import SwiftUI
import MijickTimer

@MainActor class CameraManagerVideoOutput: NSObject {
    private(set) weak var parent: CameraManager?
    private(set) var output: AVCaptureMovieFileOutput = .init()
    private(set) var timer: MTimer = .init(.camera)
    private(set) var recordingTime: MTime = .zero
    private(set) var firstRecordedFrame: UIImage?
}

// MARK: Setup
extension CameraManagerVideoOutput {
    func setup(parent: CameraManager) throws(MCameraError) {
        self.parent = parent
        try parent.captureSession.add(output: output)
    }
}

// MARK: Reset
extension CameraManagerVideoOutput {
    func reset() {
        timer.reset()
    }
}


// MARK: - CAPTURE VIDEO



// MARK: Toggle
extension CameraManagerVideoOutput {
    func toggleRecording() { switch output.isRecording {
        case true: stopRecording()
        case false: startRecording()
    }}
}

// MARK: Start Recording
private extension CameraManagerVideoOutput {
    func startRecording() {
        guard let url = prepareUrlForVideoRecording() else { return }

        configureOutput()
        storeLastFrame()
        output.startRecording(to: url, recordingDelegate: self)
        startRecordingTimer()
        parent?.objectWillChange.send()
    }
}
private extension CameraManagerVideoOutput {
    func prepareUrlForVideoRecording() -> URL? {
        FileManager.prepareURLForVideoOutput()
    }
    func configureOutput() {
        guard let connection = output.connection(with: .video),
              connection.isVideoMirroringSupported,
              let parent
        else { return }

        connection.isVideoMirrored = parent.attributes.mirrorOutput ? parent.attributes.cameraPosition != .front : parent.attributes.cameraPosition == .front
        connection.videoOrientation = parent.attributes.deviceOrientation
    }
    func storeLastFrame() {
        guard let texture = parent?.cameraMetalView.currentDrawable?.texture,
              let ciImage = CIImage(mtlTexture: texture, options: nil),
              let cgImage = parent?.cameraMetalView.ciContext.createCGImage(ciImage, from: ciImage.extent),
              let orientation = parent?.attributes.deviceOrientation.toImageOrientation()
        else { return }

        firstRecordedFrame = UIImage(
            cgImage: cgImage,
            scale: 1.0,
            orientation: orientation
        )
    }
    func startRecordingTimer() { try? timer
        .publish(every: 1) { [self] in
            guard let parent else {
                timer.cancel()
                return
            }

            recordingTime = $0
            parent.objectWillChange.send()
        }
        .start()
    }
}

// MARK: Stop Recording
private extension CameraManagerVideoOutput {
    func stopRecording() {
        presentLastFrame()
        output.stopRecording()
        timer.reset()
    }
}
private extension CameraManagerVideoOutput {
    func presentLastFrame() {
        let firstRecordedFrame = MCameraMedia(data: firstRecordedFrame)
        parent?.setCapturedMedia(firstRecordedFrame)
    }
}

// MARK: Receive Data
extension CameraManagerVideoOutput: @preconcurrency AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        guard let cameraFilters = parent?.attributes.cameraFilters else { return }
        Task {
            let videoURL = try await prepareVideo(outputFileURL: outputFileURL, cameraFilters: cameraFilters)
            let capturedVideo = MCameraMedia(data: videoURL)
            
            await Task.sleep(seconds: Animation.duration)
            parent?.setCapturedMedia(capturedVideo)
        }
    }
}
private extension CameraManagerVideoOutput {
    func prepareVideo(outputFileURL: URL, cameraFilters: [CIFilter]) async throws -> URL {
        if cameraFilters.isEmpty { return outputFileURL }

        let asset = AVAsset(url: outputFileURL)
        let videoComposition = try await AVVideoComposition.applyFilters(to: asset) { self.applyFiltersToVideo($0, cameraFilters) }
        let fileUrl = FileManager.prepareURLForVideoOutput()
        let exportSession = prepareAssetExportSession(asset, fileUrl, videoComposition)

        try await exportVideo(exportSession, fileUrl)
        return fileUrl ?? outputFileURL
    }
}
private extension CameraManagerVideoOutput {
    nonisolated func applyFiltersToVideo(_ request: AVAsynchronousCIImageFilteringRequest, _ filters: [CIFilter]) {
        let videoFrame = prepareVideoFrame(request, filters)
        request.finish(with: videoFrame, context: nil)
    }
    nonisolated func exportVideo(_ exportSession: AVAssetExportSession?, _ fileUrl: URL?) async throws { if let fileUrl {
        if #available(iOS 18, *) { try await exportSession?.export(to: fileUrl, as: .mov) }
        else { await exportSession?.export() }
    }}
}
private extension CameraManagerVideoOutput {
    nonisolated func prepareVideoFrame(_ request: AVAsynchronousCIImageFilteringRequest, _ filters: [CIFilter]) -> CIImage { request
        .sourceImage
        .clampedToExtent()
        .applyingFilters(filters)
    }
    nonisolated func prepareAssetExportSession(_ asset: AVAsset, _ fileUrl: URL?, _ composition: AVVideoComposition?) -> AVAssetExportSession? {
        let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080)
        export?.outputFileType = .mov
        export?.outputURL = fileUrl
        export?.videoComposition = composition
        return export
    }
}


// MARK: - HELPERS
fileprivate extension MTimerID {
    static let camera: MTimerID = .init(rawValue: "mijick-camera")
}
