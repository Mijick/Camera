//
//  DefaultCameraPreview.swift of MijickCameraView
//
//  Created by Tomasz Kurylik
//    - Twitter: https://twitter.com/tkurylik
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//
//  Copyright ©2024 Mijick. Licensed under MIT License.


import SwiftUI
import AVKit

struct DefaultCameraPreview: MCapturedMediaScreen {
    let capturedMedia: MCameraMedia
    let namespace: Namespace.ID
    let retakeAction: () -> ()
    let acceptMediaAction: () -> ()
    @State private var player: AVPlayer = .init()
    @State private var shouldShowContent: Bool = false


    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            createContentView()
            Spacer()
            createButtons()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.mijickBackgroundPrimary).ignoresSafeArea())
        .onAppear(perform: onAppear)
    }
}
private extension DefaultCameraPreview {
    func createContentView() -> some View {
        ZStack {
            if let image = capturedMedia.getImage() { createImageView(image) }
            else if let video = capturedMedia.getVideo() { createVideoView(video) }
            else { EmptyView() }
        }
        .opacity(shouldShowContent ? 1 : 0)
    }
    func createButtons() -> some View {
        HStack(spacing: 32) {
            createRetakeButton()
            createSaveButton()
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
private extension DefaultCameraPreview {
    func createImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .ignoresSafeArea()
    }
    func createVideoView(_ video: URL) -> some View {
        VideoPlayer(player: player)
            .onAppear { onVideoAppear(video) }
    }
    func createRetakeButton() -> some View {
        BottomButton(image: .mijickIconCancel, primary: false, action: retakeAction)
            .matchedGeometryEffect(id: "button-bottom-left", in: namespace)
    }
    func createSaveButton() -> some View {
        BottomButton(image: .mijickIconCheck, primary: true, action: acceptMediaAction)
            .matchedGeometryEffect(id: "button-bottom-right", in: namespace)
    }
}

private extension DefaultCameraPreview {
    func onAppear() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation(.mijickEase) { [self] in shouldShowContent = true }
    }}
    func onVideoAppear(_ url: URL) {
        player = .init(url: url)
        player.play()
    }
}






fileprivate struct BottomButton: View {
    let image: ImageResource
    let primary: Bool
    let action: () -> ()


    var body: some View {
        Button(action: action, label: createButtonLabel).buttonStyle(ButtonScaleStyle())
    }
}
private extension BottomButton {
    func createButtonLabel() -> some View {
        Image(image)
            .resizable()
            .frame(width: 26, height: 26)
            .foregroundColor(iconColor)
            .frame(width: 52, height: 52)
            .background(backgroundColor)
            .mask(Circle())
    }
}
private extension BottomButton {
    var iconColor: Color { switch primary {
        case true: .init(.mijickBackgroundPrimary)
        case false: .init(.mijickBackgroundInverted)
    }}
    var backgroundColor: Color { switch primary {
        case true: .init(.mijickBackgroundInverted)
        case false: .init(.mijickBackgroundSecondary)
    }}
}
