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

/*
 
 We have a rectangle with another inside. Each set of rectangles has 8 points
 
 o = outer
 t = top
 b = bottom
 l = left
 r = right
 
 otl
 otr
 obl
 obr
 
 itl
 itr
 ibl
 ibr
 
 We want to first scale the image and then move it such that itl, itr, ibl, and ibr are the same for all images
 How do we do this?
 
 Calculate the scale factor:
 
 Given the distance between itl and itr, we will make them all have the same distance (1):
 d = distance
 dit = (itr - itl)
 
 1 / 0.18 = 5.55
 1 / 0.67 = 1.49
 
 Thus, the scale factor is 1 / (itr - itl) OR 1 / width of the inner box.
 
 So, we scale the image.
 
 Next, we need to move the images so the center of the outer box is at the center of the screen.
 
 We calculate the center of the scaled image by (x + width / 2, y + height / 2)
 
 We calculate the center of the frame by (frameWidth / 2, frameHeight / 2)
 
 Then, we set the origin of the image to: (frameCenter - scaledImageCenter)
 
 frame: 100, 100
 frameCenter: 50, 50
 
 face center: 20, 40, (from 100, 100)
 frameCenter - faceCenter = 30, 10
 
 Set the origin of the face image to 30, 10
 
 
 */

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
                print("Failure 4")
                completion(nil, error)
                return
            }
            
            DispatchQueue.main.async {
                guard let results = request.results as? [VNFaceObservation] else {
                    print("Failure 3")
                    completion(nil, nil)
                    return
                }
                
                // Create the new image
                guard let size = image.representations.first?.size else {
                    print("Failure 2")
                    completion(nil, nil)
                    return
                }
                
                guard let boundingBox = results.first?.boundingBox else {
                    print("Failure 1")
                    completion(nil, nil)
                    return
                }
                
                let aspectRatio = size.width / size.height
                let normalAspect = (aspectRatio > 1.0) ? 1.0 : (1 / aspectRatio)
                let scaleFactor = (1 / boundingBox.width) * 0.5 * normalAspect
                
                let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
//                let faceImageCenter = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
//                let faceScale = scaleFactor * size.width
                let faceImageCenter = CGPoint(x: boundingBox.origin.x * newSize.width + (boundingBox.size.width * newSize.width) / 2,
                                              y: boundingBox.origin.y * newSize.height + (boundingBox.size.height * newSize.height) / 2)
                
                let newImage = NSImage.init(size: size, flipped: false) { (rect) -> Bool in
                    
                    let rectCenter = CGPoint(x: rect.width / 2, y: rect.height / 2)
                    let distanceCenters = CGPoint(x: rectCenter.x - faceImageCenter.x,
                                                  y: rectCenter.y - faceImageCenter.y)
                    
                    let drawRect = CGRect(origin: distanceCenters, size: newSize)
                    
                    image.draw(in: drawRect)
                    return true
                }
                
                let facialImage = FacialImage(image: newImage, faces: results)
                completion(facialImage, nil)
                return
            }
        }
        
        // TODO: Might save a context for faster loading...
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failure 5")
            completion(nil, nil)
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform([request])
            } catch {
                print("Failed to perform request: \(error)")
                completion(nil, error)
                return
            }
        }
    }
    
    func centerOfPoints(_ points: [CGPoint]) -> CGPoint {
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        
        for point in points {
            totalX += point.x
            totalY += point.y
        }
        
        let count = points.count
        
        return CGPoint(x: totalX / CGFloat(count),
                       y: totalY / CGFloat(count))
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
