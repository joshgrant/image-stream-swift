//
//  ImageView.swift
//  ImageStream
//
//  Created by Joshua Grant on 3/10/19.
//  Copyright © 2019 Joshua Grant. All rights reserved.
//

import Foundation
import Cocoa
import Vision

struct FacialImage {
    var image: NSImage
    var faces: [VNFaceObservation]
    
    init(image: NSImage, faces: [VNFaceObservation]) {
        self.image = image
        self.faces = faces
    }
}

class View : NSView
{
    // MARK: - Variables
    
    var loopCount: Int = 0
    
    var images: [FacialImage] = []
    
    var queue = DispatchQueue(label: "me.joshgrant.imageStream.queue")
    
    // MARK: Interface outlets
    
    @IBOutlet weak var imageView : ImageView!
    
    // MARK: - View lifecycle
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        imageView.updateDelegate = self
        
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
    
    // MARK: - Utility
    
    func loadImages(from urls: [URL]) {
        let group = DispatchGroup()
        var tempImages: [FacialImage] = []
        for url in urls {
            group.enter()
            let image = loadImage(from: url)
            performVisionRequest(image: image, orientation: .up) { (facialImage, error) in
                if let error = error {
                    print("ERROR: \(error)")
                    group.leave()
                    return
                }
                guard let facialImage = facialImage else {
                    group.leave()
                    return
                }
                
                self.queue.sync {
                    tempImages.append(facialImage)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.images = tempImages
            self.imageView.image = self.images.first?.image // triggers the loop
        }
    }
    
    func loadImage(from url: URL) -> NSImage {
        let image = NSImage(byReferencing: url)
        return image
    }
    
    func performVisionRequest(image: NSImage, orientation: CGImagePropertyOrientation, completion: @escaping ((FacialImage?, Error?) -> Void)) {
        // This is the request...
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            DispatchQueue.main.async {
                guard let results = request.results as? [VNFaceObservation] else { return }
                let facialImage = FacialImage(image: image, faces: results)
                completion(facialImage, nil)
                return
            }
        }
        
        // TODO: Might save a context for faster loading...
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform([request])
            } catch {
                print("Failed to perform request: \(error)")
            }
        }
    }
}

extension View: ImageViewUpdateDelegate
{
    func imageViewDidUpdate()
    {
        loopCount += 1
        
        if loopCount >= images.count
        {
            loopCount = 0
        }
        
        imageView.image = images[loopCount].image
    }
}
