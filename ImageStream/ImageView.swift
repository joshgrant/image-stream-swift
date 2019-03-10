//
//  ImageView.swift
//  ImageStream
//
//  Created by Joshua Grant on 3/10/19.
//  Copyright © 2019 Joshua Grant. All rights reserved.
//

import Foundation
import Cocoa

class ImageView : NSView
{
    @IBOutlet weak var imageView : NSImageView!
    
    var timer : Timer?
    var loopCount: Int = 0
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    func image(number: Int) -> NSImage?
    {
        return NSImage(byReferencingFile: "/Users/formaze/Downloads/image_\(number).jpg")
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        fireTimer()
    }
    
    @objc func updateLoop(timer: Timer)
    {
        loopCount += 1
        
        if loopCount > 27 {
            loopCount = 1
        }
        
        updateImage(i: loopCount)
    }
    
    func updateImage(i: Int)
    {
        imageView.image = image(number: i)
    }
    
    func fireTimer()
    {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateLoop(timer:)), userInfo: nil, repeats: true)
    }
    
    @IBAction func buttonPressed(button: NSButton)
    {
        if (timer?.isValid ?? false) {
            timer?.invalidate()
            timer = nil
        } else {
            fireTimer()
        }
    }
}
