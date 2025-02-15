//
//  MCamera+Config.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI

extension MCamera { @MainActor class Config {
    // MARK: Screens
    var cameraScreen: CameraScreenBuilder = DefaultCameraScreen.init
    var capturedMediaScreen: CapturedMediaScreenBuilder? = DefaultCapturedMediaScreen.init
    var errorScreen: ErrorScreenBuilder = DefaultCameraErrorScreen.init

    // MARK: Actions
    var imageCapturedAction: (UIImage, MCamera.Controller) -> () = { _,_ in }
    var videoCapturedAction: (URL, MCamera.Controller) -> () = { _,_ in }
    var closeMCameraAction: () -> () = {}

    // MARK: Others
    var appDelegate: MApplicationDelegate.Type? = nil
    var originalOrientationLock: UIInterfaceOrientationMask = .all
    var isCameraConfigured: Bool = false
}}
