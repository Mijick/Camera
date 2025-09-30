//
//  Public+Manager+CameraManager.swift of MijickCamera
//
//  Created by Addison Hanrattie. Sending ❤️ from US!
//
//  Copyright ©2024 Mijick. All rights reserved.

import SwiftUI

// MARK: Set Captured Media
public extension CameraManager {
    func setCapturedMedia(_ capturedMedia: MCameraMedia?) {
        withAnimation(.mSpring) {
		    attributes.capturedMedia = capturedMedia
        }
    }
}
