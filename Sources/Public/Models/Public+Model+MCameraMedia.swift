//
//  Public+Model+MCameraMedia.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.

import SwiftUI

// MARK: Getters
public extension MCameraMedia {
    init?(data: Any?) {
        if let image = data as? UIImage {
            self.image = image
            self.video = nil
        } else if let video = data as? URL {
            self.video = video
            self.image = nil
        } else {
            return nil
        }
    }

    /**
     Gets the image from the media object.
     */
    func getImage() -> UIImage? { image }

    /**
     Gets the video URL from the media object.
     */
    func getVideo() -> URL? { video }
}
