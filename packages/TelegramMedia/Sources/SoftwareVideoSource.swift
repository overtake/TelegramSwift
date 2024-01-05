//
//  File.swift
//  
//
//  Created by Mike Renoir on 05.01.2024.
//

import Foundation
import MediaPlayer
import AppKit
import TGUIKit
import Accelerate
import CoreMedia

public extension SoftwareVideoSource {
    func preview(size: NSSize, backingScale: Int) -> CGImage? {
        let frameAndLoop = self.readFrame(maxPts: nil)
        if frameAndLoop.0 == nil {
            return nil
        }
        
        guard let frame = frameAndLoop.0 else {
            return nil
        }
        
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        
        let destBytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
        let bufferSize = s.h * DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)

        let memoryData = malloc(bufferSize)!
        let bytes = memoryData.assumingMemoryBound(to: UInt8.self)
        
        let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        let srcData = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        var sourceBuffer = vImage_Buffer(data: srcData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        var destBuffer = vImage_Buffer(data: bytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: destBytesPerRow)
                   
        let _ = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageDoNotTile))
        
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
            memcpy(pixelData, bytes, bufferSize)
        })
    }
}

