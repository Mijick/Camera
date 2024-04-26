//
//  MCameraController.swift of MijickCameraView
//
//  Created by Tomasz Kurylik
//    - Twitter: https://twitter.com/tkurylik
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//
//  Copyright ©2024 Mijick. Licensed under MIT License.


import SwiftUI

public struct MCameraController: View {
    @Binding var capturedMedia: MCameraMedia?
    @ObservedObject private var cameraManager: CameraManager = .init(config: .init())
    @State private var cameraError: CameraManager.Error?
    @Namespace private var namespace
    private var config: CameraConfig = .init()


    public init(capturedMedia: Binding<MCameraMedia?>) { self._capturedMedia = capturedMedia }
    public var body: some View {
        ZStack { switch cameraError {
            case .some(let error): createErrorStateView(error)
            case nil: createNormalStateView()
        }}
        .animation(.defaultEase, value: capturedMedia == nil)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }
}
private extension MCameraController {
    func createErrorStateView(_ error: CameraManager.Error) -> some View {
        config.cameraErrorView(error).erased()
    }
    func createNormalStateView() -> some View { ZStack { switch capturedMedia {
        case .some: createCameraPreview()
        case nil: createCameraView()
    }}}
}
private extension MCameraController {
    func createCameraPreview() -> some View {
        config.mediaPreviewView($capturedMedia, namespace).erased()
    }
    func createCameraView() -> some View {
        config.cameraView(cameraManager, $capturedMedia, namespace).erased()
    }
}

private extension MCameraController {
    func onAppear() {
        checkCameraPermissions()
        lockScreenOrientation()
    }
    func onDisappear() {
        unlockScreenOrientation()
    }
}
private extension MCameraController {
    func checkCameraPermissions() {
        do { try cameraManager.checkPermissions() }
        catch { cameraError = error as? CameraManager.Error }
    }
    func lockScreenOrientation() {
        config.appDelegate?.orientationLock = .portrait
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    func unlockScreenOrientation() {
        config.appDelegate?.orientationLock = .all
    }
}



public extension MCameraController {
    func lockOrientation(_ appDelegate: MApplicationDelegate.Type) -> Self { setAndReturnSelf { $0.config.appDelegate = appDelegate } }

}
