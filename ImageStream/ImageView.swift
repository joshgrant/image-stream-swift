//
//  ImageView.swift
//  ImageStream
//
//  Created by Joshua Grant on 12/1/19.
//  Copyright © 2019 Joshua Grant. All rights reserved.
//

import Cocoa

class ImageView: NSImageView {
    
    var updateDelegate: ImageViewUpdateDelegate?
    
    override var image: NSImage? {
        get {
            return super.image
        }
        set {
            super.image = newValue
            DispatchQueue.main.async {
                self.updateDelegate?.imageViewDidUpdate()
            }
        }
    }
    
}
