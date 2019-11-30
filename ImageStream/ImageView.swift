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
    
    var images: [NSImage] = []
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        guard let window = window else { return }
        
        panel.beginSheetModal(for: window) { (result) in
            if result == .OK
            {
                guard let folder = panel.urls.first else { return }
                
                let fileManager = FileManager.default
                
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: folder.path)
                    
                    let urls = contents.map {
                        return folder.appendingPathComponent($0)
                    }
                    
                    self.loadImages(from: urls)
                    
                } catch {
                    print("None")
                }
            }
        }
    }
    
    func loadImages(from urls: [URL]) {
        var tempImages: [NSImage] = []
        for url in urls {
            let image = loadImage(from: url)
            tempImages.append(image)
        }
        images = tempImages
        fireTimer()
    }
    
    func loadImage(from url: URL) -> NSImage {
        let image = NSImage(byReferencing: url)
        return image
    }
    
    @objc func updateLoop(timer: Timer)
    {
        loopCount += 1
        
        if loopCount >= images.count {
            loopCount = 0
        }
                
        imageView.image = images[loopCount]
    }
    
    func fireTimer()
    {
        timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateLoop(timer:)), userInfo: nil, repeats: true)
    }
}
