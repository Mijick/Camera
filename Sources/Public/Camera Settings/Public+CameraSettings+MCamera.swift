//
//  Public+CameraSettings+MCamera.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI
import AVKit

// MARK: Initializer
public extension MCamera {
    init() { self.init(manager: .init(
        captureSession: AVCaptureSession(),
        captureDeviceInputType: AVCaptureDeviceInput.self
    ))}
}


// MARK: - METHODS



// MARK: Changing Default Screens
public extension MCamera {
    /**
     Changes the camera screen to a selected one.

     For more details and tips on creating your own **Camera Screen**, see the ``MCameraScreen`` documentation.

     - tip: To hide selected buttons and controls on the screen, use the method with DefaultCameraScreen as argument. For a code example, please refer to Usage -> Default Camera Screen Customization section.


     # Usage

     ## New Camera Screen
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .setCameraScreen(CustomCameraScreen.init)

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```

     ## Default Camera Screen Customization
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .setCameraScreen {
                    DefaultCameraScreen(cameraManager: $0, namespace: $1, closeMCameraAction: $2)
                        .captureButtonAllowed(false)
                        .cameraOutputSwitchAllowed(false)
                        .lightButtonAllowed(false)
                }

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```
     */
    func setCameraScreen(_ builder: @escaping CameraScreenBuilder) -> Self { config.cameraScreen = builder; return self }

    /**
     Changes the captured media screen to a selected one.

     For more details and tips on creating your own **Captured Media Screen**, see the ``MCapturedMediaScreen`` documentation.

     - tip: To disable displaying captured media, call the method with a nil value.


     # Usage

     ## New Captured Media Screen
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .setCapturedMediaScreen(DefaultCapturedMediaScreen.init)

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```

     ## No Captured Media Screen
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .setCapturedMediaScreen(nil)

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```
     */
    func setCapturedMediaScreen(_ builder: CapturedMediaScreenBuilder?) -> Self { config.capturedMediaScreen = builder; return self }

    /**
     Changes the error screen to a selected one.

     For more details and tips on creating your own **Error Screen**, see the ``MCameraErrorScreen`` documentation.


     ## Usage
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .setErrorScreen(CustomCameraErrorScreen.init)

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```
     */
    func setErrorScreen(_ builder: @escaping ErrorScreenBuilder) -> Self { config.errorScreen = builder; return self }
}

// MARK: Changing Initial Values
public extension MCamera {
    /**
     Changes the initial camera output type.

     For available options, please refer to the ``CameraOutputType`` documentation.
     */
    func setCameraOutputType(_ cameraOutputType: CameraOutputType) -> Self { manager.attributes.outputType = cameraOutputType; return self }

    /**
     Changes the initial camera position.

     For available options, please refer to the ``CameraPosition`` documentation.

     - note: If the selected camera position is not available, the camera will not be changed.
     */
    func setCameraPosition(_ cameraPosition: CameraPosition) -> Self { manager.attributes.cameraPosition = cameraPosition; return self }

    /**
     Definies whether the audio source is available.

     If disabled, the camera will not record audio, and will not ask for permission to access the microphone.
     */
    func setAudioAvailability(_ isAvailable: Bool) -> Self { manager.attributes.isAudioSourceAvailable = isAvailable; return self }

    /**
     Changes the initial camera zoom level.

     - note: If the zoom factor is out of bounds, it will be set to the closest available value.
     */
    func setZoomFactor(_ zoomFactor: CGFloat) -> Self { manager.attributes.zoomFactor = zoomFactor; return self }

    /**
     Changes the initial camera flash mode.

     For available options, please refer to the ``CameraFlashMode`` documentation.

     - note: If the selected flash mode is not available, the flash mode will not be changed.
     */
    func setFlashMode(_ flashMode: CameraFlashMode) -> Self { manager.attributes.flashMode = flashMode; return self }

    /**
     Changes the initial light (torch / flashlight) mode.

     For available options, please refer to the ``CameraLightMode`` documentation.

     - note: If the selected light mode is not available, the light mode will not be changed.
     */
    func setLightMode(_ lightMode: CameraLightMode) -> Self { manager.attributes.lightMode = lightMode; return self }

    /**
     Changes the initial camera resolution.

     - important: Changing the resolution may affect the maximum frame rate that can be set.
     */
    func setResolution(_ resolution: AVCaptureSession.Preset) -> Self { manager.attributes.resolution = resolution; return self }

    /**
     Changes the initial camera frame rate.

     - note: Depending on the resolution of the camera and the current specifications of the device, there are some restrictions on the frame rate that can be set.
     If you set a frame rate that exceeds the camera's capabilities, the library will automatically set the closest possible value and show you which value has been set (``MCameraScreen/frameRate``).
     */
    func setFrameRate(_ frameRate: Int32) -> Self { manager.attributes.frameRate = frameRate; return self }

    /**
     Changes the initial camera exposure duration.

     - note: If the exposure duration is out of bounds, it will be set to the closest available value.
     */
    func setCameraExposureDuration(_ duration: CMTime) -> Self { manager.attributes.cameraExposure.duration = duration; return self }

    /**
     Changes the initial camera target bias.

     - note: If the target bias is out of bounds, it will be set to the closest available value.
     */
    func setCameraTargetBias(_ targetBias: Float) -> Self { manager.attributes.cameraExposure.targetBias = targetBias; return self }

    /**
     Changes the initial camera ISO.

     - note: If the ISO is out of bounds, it will be set to the closest available value.
     */
    func setCameraISO(_ iso: Float) -> Self { manager.attributes.cameraExposure.iso = iso; return self }

    /**
     Changes the initial camera exposure mode.

     - note: If the exposure mode is not supported, the exposure mode will not be changed.
     */
    func setCameraExposureMode(_ exposureMode: AVCaptureDevice.ExposureMode) -> Self { manager.attributes.cameraExposure.mode = exposureMode; return self }

    /**
     Changes the initial camera HDR mode.

     For available options, please refer to the ``CameraHDRMode`` documentation.
     */
    func setCameraHDRMode(_ hdrMode: CameraHDRMode) -> Self { manager.attributes.hdrMode = hdrMode; return self }

    /**
     Changes the initial camera filters.

     - important: Setting multiple filters simultaneously can affect the performance of the camera.
     */
    func setCameraFilters(_ filters: [CIFilter]) -> Self { manager.attributes.cameraFilters = filters; return self }

    /**
     Changes the initial mirror output setting.
     */
    func setMirrorOutput(_ shouldMirror: Bool) -> Self { manager.attributes.mirrorOutput = shouldMirror; return self }

    /**
     Changes the initial grid visibility setting.
     */
    func setGridVisibility(_ shouldShowGrid: Bool) -> Self { manager.attributes.isGridVisible = shouldShowGrid; return self }

    /**
     Changes the shape of the focus indicator visible when touching anywhere on the camera screen.
     */
    func setFocusImage(_ image: UIImage) -> Self { manager.cameraMetalView.focusIndicator.image = image; return self }

    /**
     Changes the color of the focus indicator visible when touching anywhere on the camera screen.
     */
    func setFocusImageColor(_ color: UIColor) -> Self { manager.cameraMetalView.focusIndicator.tintColor = color; return self }

    /**
     Changes the size of the focus indicator visible when touching anywhere on the camera.
     */
    func setFocusImageSize(_ size: CGFloat) -> Self { manager.cameraMetalView.focusIndicator.size = size; return self }
}

// MARK: Actions
public extension MCamera {
    /**
     Indicates how the MCamera can be closed.

     ## Usage
     ```swift
     struct ContentView: View {
        @State private var isSheetPresented: Bool = false


        var body: some View {
            Button(action: { isSheetPresented = true }) {
                Text("Click me!")
            }
            .fullScreenCover(isPresented: $isSheetPresented) {
                MCamera()
                    .setResolution(.hd1920x1080)
                    .setCloseMCameraAction { isSheetPresented = false }

                    // MUST BE CALLED!
                    .startSession()
            }
        }
     }
     ```
     */
    func setCloseMCameraAction(_ action: @escaping () -> ()) -> Self { config.closeMCameraAction = action; return self }

    /**
     Defines action that is called when an image is captured.

     MCameraController can be used to perform additional actions related to MCamera, such as closing MCamera or returning to the camera screen.
     See ``Controller`` for more information.

     - note: The action is called immediately if **Captured Media Screen** is nil, otherwise after the user accepts the photo.


     ## Usage
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .onImageCaptured { image, controller in
                    saveImageInGallery(image)
                    controller.reopenCameraScreen()
                }

                // MUST BE CALLED!
                .startSession()
            }
     }
     ```
     */
    func onImageCaptured(_ action: @escaping (UIImage, MCamera.Controller) -> ()) -> Self { config.imageCapturedAction = action; return self }

    /**
     Defines action that is called when a video is captured.

     MCameraController can be used to perform additional actions related to MCamera, such as closing MCamera or returning to the camera screen.
     See ``Controller`` for more information.

     - note: The action is called immediately if **Captured Media Screen** is nil, otherwise after the user accepts the video.


     ## Usage
     ```swift
     struct ContentView: View {
        var body: some View {
            MCamera()
                .onVideoCaptured { video, controller in
                    saveVideoInGallery(video)
                    controller.reopenCameraScreen()
                }

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```
     */
    func onVideoCaptured(_ action: @escaping (URL, MCamera.Controller) -> ()) -> Self { config.videoCapturedAction = action; return self }
}

// MARK: Others
public extension MCamera {
    /**
     Locks the screen in portrait mode when the Camera Screen is active.

     See ``MApplicationDelegate`` for more details.
     - note: Blocks the rotation of the entire screen on which the **MCamera** is located.

     ## Usage
     ```swift
     @main struct App_Main: App {
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

        var body: some Scene {
            WindowGroup(content: ContentView.init)
        }
     }

     // MARK: App Delegate
     class AppDelegate: NSObject, MApplicationDelegate {
        static var orientationLock = UIInterfaceOrientationMask.all

        func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { AppDelegate.orientationLock }
     }

     // MARK: Content View
     struct ContentView: View {
        var body: some View {
            MCamera()
                .lockCameraInPortraitOrientation(AppDelegate.self)

                // MUST BE CALLED!
                .startSession()
        }
     }
     ```
     */
    func lockCameraInPortraitOrientation(_ appDelegate: MApplicationDelegate.Type) -> Self {
        config.appDelegate = appDelegate
        config.originalOrientationLock = appDelegate.orientationLock
        manager.attributes.orientationLocked = true

        return self
    }

    /**
     Starts the camera session.

     - important: This method must be called to start the camera.
     */
    func startSession() -> some View { config.isCameraConfigured = true; return self }
}
