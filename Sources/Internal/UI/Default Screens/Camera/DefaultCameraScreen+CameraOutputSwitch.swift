//
//  DefaultCameraScreen+CameraOutputSwitch.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI

extension DefaultCameraScreen { struct CameraOutputSwitch: View {
    let parent: DefaultCameraScreen


    var body: some View {
        HStack(spacing: 4) {
            createOutputTypeButton(.video)
            createOutputTypeButton(.photo)
        }
        .padding(8)
        .background(Color(.mijickBackgroundPrimary50))
        .mask(Capsule())
    }
}}
private extension DefaultCameraScreen.CameraOutputSwitch {
    func createOutputTypeButton(_ outputType: CameraOutputType) -> some View {
        let a11yValue: LocalizedStringKey = switch outputType {
            case .photo: "Photo"
            case .video: "Video"
        }
        let a11yHint: LocalizedStringKey = switch outputType {
            case .photo: "Switch to video mode"
            case .video: "Switch to photo mode"
        }
        
        return Button(icon: getOutputTypeButtonIcon(outputType), active: isOutputTypeButtonActive(outputType)) {
            parent.setOutputType(outputType)
        }
        .rotationEffect(parent.iconAngle)
        .accessibilityLabel("Camera type")
        .accessibilityValue(a11yValue)
        .accessibilityHint(a11yHint)
    }
}

private extension DefaultCameraScreen.CameraOutputSwitch {
    func getOutputTypeButtonIcon(_ outputType: CameraOutputType) -> ImageResource { switch outputType {
        case .photo: return .mijickIconPhoto
        case .video: return .mijickIconVideo
    }}
    func isOutputTypeButtonActive(_ outputType: CameraOutputType) -> Bool {
        outputType == parent.cameraOutputType
    }
}


// MARK: Button
fileprivate struct Button: View {
    let icon: ImageResource
    let active: Bool
    let action: () -> ()


    var body: some View {
        SwiftUI.Button(action: action, label: createButtonLabel).buttonStyle(ButtonScaleStyle())
    }
}
private extension Button {
    func createButtonLabel() -> some View {
        Image(icon)
            .resizable()
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(iconColor)
            .padding(8)
            .background(Color(.mijickBackgroundSecondary))
            .mask(Circle())
    }
}
private extension Button {
    var iconSize: CGFloat { switch active {
        case true: 28
        case false: 20
    }}
    var iconColor: Color { switch active {
        case true: .init(.mijickBackgroundYellow)
        case false: .init(.mijickTextTertiary)
    }}
}
