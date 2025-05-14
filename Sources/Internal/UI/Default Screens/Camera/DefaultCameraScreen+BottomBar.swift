//
//  DefaultCameraScreen+BottomBar.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI

extension DefaultCameraScreen { struct BottomBar: View {
    let parent: DefaultCameraScreen


    var body: some View {
        ZStack(alignment: .top) {
            createOutputTypeSwitch()
            createButtons()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 44)
        .padding(.horizontal, 32)
    }
}}
private extension DefaultCameraScreen.BottomBar {
    @ViewBuilder func createOutputTypeSwitch() -> some View { if isOutputTypeSwitchActive {
        DefaultCameraScreen.CameraOutputSwitch(parent: parent)
            .offset(y: -80)
    }}
    func createButtons() -> some View {
        ZStack {
            createLightButton()
            createCaptureButton()
            createChangeCameraPositionButton()
        }.frame(height: 72)
    }
}
private extension DefaultCameraScreen.BottomBar {
    @ViewBuilder func createLightButton() -> some View { if isLightButtonActive {
        BottomButton(
            icon: .mijickIconLight,
            iconColor: lightButtonIconColor,
            backgroundColor: .init(.mijickBackgroundSecondary),
            rotationAngle: parent.iconAngle,
            action: changeLightMode
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.scale)
        .accessibilityLabel("Camera light")
        .accessibilityHint("Toggles the camera light on or off.")
        .accessibilityValue(parent.lightMode == .on ? "On" : "Off")
    }}
    @ViewBuilder func createCaptureButton() -> some View { if isCaptureButtonActive {
        DefaultCameraScreen.CaptureButton(
            outputType: parent.cameraOutputType,
            isRecording: parent.isRecording,
            action: parent.captureOutput
        )
        .transition(.scale)
    }}
    @ViewBuilder func createChangeCameraPositionButton() -> some View { if isChangeCameraPositionButtonActive {
        BottomButton(
            icon: .mijickIconChangeCamera,
            iconColor: changeCameraPositionButtonIconColor,
            backgroundColor: .init(.mijickBackgroundSecondary),
            rotationAngle: parent.iconAngle,
            action: changeCameraPosition
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.scale)
        .accessibilityLabel("Camera chooser")
        .accessibilityHint("Switches between front and back cameras.")
        .accessibilityValue(parent.cameraPosition == .front ? "Front camera" : "Back camera")
    }}
}

private extension DefaultCameraScreen.BottomBar {
    func changeLightMode() {
        do { try parent.setLightMode(parent.lightMode.next()) }
        catch {}
    }
    func changeCameraPosition() { Task {
        do { try await parent.setCameraPosition(parent.cameraPosition.next()) }
        catch {}
    }}
}

private extension DefaultCameraScreen.BottomBar {
    var lightButtonIconColor: Color { switch parent.lightMode {
        case .on: .init(.mijickBackgroundYellow)
        case .off: .init(.mijickBackgroundInverted)
    }}
    var changeCameraPositionButtonIconColor: Color { .init(.mijickBackgroundInverted) }
}
private extension DefaultCameraScreen.BottomBar {
    var isOutputTypeSwitchActive: Bool { parent.config.cameraOutputSwitchAllowed && parent.cameraManager.captureSession.isRunning && !parent.isRecording }
    var isLightButtonActive: Bool { parent.config.lightButtonAllowed && parent.hasLight && parent.cameraManager.captureSession.isRunning && !parent.isRecording }
    var isCaptureButtonActive: Bool { parent.config.captureButtonAllowed && parent.cameraManager.captureSession.isRunning }
    var isChangeCameraPositionButtonActive: Bool { parent.config.cameraPositionButtonAllowed && parent.cameraManager.captureSession.isRunning && !parent.isRecording }
}
