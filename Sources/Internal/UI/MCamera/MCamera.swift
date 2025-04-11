//
//  MCamera.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI

/**
 A view that displays a camera with state-specific screens.

 By default, it includes three screens that change depending on the status of the camera; **Error Screen**, **Camera Screen** and **Captured Media Screen**.

 Handles issues related to asking for permissions, and if permissions are not granted, it displays the **Error Screen**.

 Optionally shows the **Captured Media Screen**, which is displayed after the user captures an image or video.


 # Customization
 All of the MCamera's default settings can be changed during initialisation.
 - important: To start a camera session, simply call the ``startSession()`` method. For more details, see the **Usage** section.

 ## Camera Screens
 Use one of the methods below to change the default screens:
    - ``setCameraScreen(_:)``
    - ``setCapturedMediaScreen(_:)``
    - ``setErrorScreen(_:)``

 - tip: To disable displaying captured media, call the ``setCapturedMediaScreen(_:)`` method with a nil value.

 ## Actions after capturing media
 Use one of the methods below to set actions that will be called after capturing media:
    - ``onImageCaptured(_:)``
    - ``onVideoCaptured(_:)``
 - note: If there is no **Captured Media Screen**, the action is called immediately after the media is captured, otherwise it is triggered after the user accepts the captured media in the **Captured Media Screen**.

 ## Camera Configuration
 To change the initial camera settings, use the following methods:
    - ``setCameraOutputType(_:)``
    - ``setCameraPosition(_:)``
    - ``setAudioAvailability(_:)``
    - ``setZoomFactor(_:)``
    - ``setFlashMode(_:)``
    - ``setLightMode(_:)``
    - ``setResolution(_:)``
    - ``setFrameRate(_:)``
    - ``setCameraExposureDuration(_:)``
    - ``setCameraTargetBias(_:)``
    - ``setCameraISO(_:)``
    - ``setCameraExposureMode(_:)``
    - ``setCameraHDRMode(_:)``
    - ``setCameraFilters(_:)``
    - ``setMirrorOutput(_:)``
    - ``setGridVisibility(_:)``
    - ``setFocusImage(_:)``
    - ``setFocusImageColor(_:)``
    - ``setFocusImageSize(_:)``
 - important: Note that if you try to set a value that exceeds the camera's capabilities, the camera will automatically set the closest possible value and show you which value has been set.

 ## Other
 There are other methods that you can use to customize your experience:
    - ``setCloseMCameraAction(_:)``
    - ``lockCameraInPortraitOrientation(_:)``

 # Usage
 ```swift
 struct ContentView: View {
    var body: some View {
        MCamera()
            .setCameraFilters([.init(name: "CISepiaTone")!])
            .setCameraPosition(.back)
            .setCameraOutputType(.video)
            .setAudioAvailability(false)
            .setResolution(.hd4K3840x2160)
            .setFrameRate(30)
            .setZoomFactor(1.2)
            .setCameraISO(3)
            .setCameraTargetBias(1.2)
            .setLightMode(.on)
            .setFlashMode(.auto)

            // MUST BE CALLED!
            .startSession()
    }
 }
 ```
 */
public struct MCamera: View {
    @ObservedObject var manager: CameraManager
    @Namespace var namespace
    var config: Config = .init()

    
    public var body: some View { if config.isCameraConfigured {
        ZStack(content: createContent)
            .onDisappear(perform: onDisappear)
            .onChange(of: manager.attributes.capturedMedia, perform: onCapturedMediaChange)
    }}
}
private extension MCamera {
    @ViewBuilder func createContent() -> some View {
        if let error = manager.attributes.error { createErrorScreen(error) }
        else if let capturedMedia = manager.attributes.capturedMedia, config.capturedMediaScreen != nil { createCapturedMediaScreen(capturedMedia) }
        else { createCameraScreen() }
    }
}
private extension MCamera {
    func createErrorScreen(_ error: MCameraError) -> some View {
        config.errorScreen(error, config.closeMCameraAction).erased()
    }
    func createCapturedMediaScreen(_ media: MCameraMedia) -> some View {
        config.capturedMediaScreen?(media, namespace, onCapturedMediaRejected, onCapturedMediaAccepted)
            .erased()
            .onAppear(perform: onCaptureMediaScreenAppear)
    }
    func createCameraScreen() -> some View {
        config.cameraScreen(manager, namespace, config.closeMCameraAction)
            .erased()
            .onAppear(perform: onCameraAppear)
            .onDisappear(perform: onCameraDisappear)
    }
}


// MARK: - ACTIONS



// MARK: MCamera
private extension MCamera {
    func onDisappear() {
        lockScreenOrientation(nil)
        manager.cancel()
    }
    func onCapturedMediaChange(_ capturedMedia: MCameraMedia?) {
        guard let capturedMedia, config.capturedMediaScreen == nil else { return }
        notifyUserOfMediaCaptured(capturedMedia)
    }
}
private extension MCamera {
    func lockScreenOrientation(_ orientation: UIInterfaceOrientationMask?) {
        config.appDelegate?.orientationLock = orientation ?? config.originalOrientationLock
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    func notifyUserOfMediaCaptured(_ capturedMedia: MCameraMedia) {
        if let image = capturedMedia.getImage() { config.imageCapturedAction(image, .init(mCamera: self)) }
        else if let video = capturedMedia.getVideo() { config.videoCapturedAction(video, .init(mCamera: self)) }
    }
}

// MARK: Camera Screen
private extension MCamera {
    func onCameraAppear() { Task {
        do {
            try await manager.setup()
            lockScreenOrientation(.portrait)
        } catch { print("(MijickCamera) ERROR DURING SETUP: \(error)") }
    }}
    func onCameraDisappear() {
        manager.cancel()
    }
}

// MARK: Captured Media Screen
private extension MCamera {
    func onCaptureMediaScreenAppear() {
        lockScreenOrientation(nil)
    }
    func onCapturedMediaRejected() {
        manager.setCapturedMedia(nil)
    }
    func onCapturedMediaAccepted() {
        guard let capturedMedia = manager.attributes.capturedMedia else { return }
        notifyUserOfMediaCaptured(capturedMedia)
    }
}
