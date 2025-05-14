//
//  DefaultScreen+CloseButton.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import SwiftUI

struct CloseButton: View {
    let action: () -> ()


    var body: some View {
        Button(action: action, label: createButtonLabel)
            .accessibilityLabel("Close")
            .accessibilityHint("Closes the camera")
    }
}
private extension CloseButton {
    func createButtonLabel() -> some View {
        Image(.mijickIconCancel)
            .resizable()
            .frame(width: 24, height: 24)
            .foregroundColor(Color(.mijickBackgroundInverted))
    }
}
