//
//  VideoEditorThumbs.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/07/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TGUIKit

func generateVideoScrubberThumbs(for asset: AVComposition, composition: AVVideoComposition?, size: NSSize, count: Int, gradually: Bool, blur: Bool) -> Signal<([CGImage], Bool), NoError> {
    return Signal { subscriber in
        
        var cancelled = false
        
        let videoDuration = asset.duration
        
        let generator = AVAssetImageGenerator(asset: asset)
        
        let size = size.multipliedByScreenScale()
        
        var frameForTimes = [NSValue]()
        let sampleCounts = count
        let totalTimeLength = Int(videoDuration.seconds * Double(videoDuration.timescale))
        let step = totalTimeLength / sampleCounts
        
        for i in 0 ..< sampleCounts {
            let cmTime = CMTimeMake(value: Int64(i * step), timescale: Int32(videoDuration.timescale))
            frameForTimes.append(NSValue(time: cmTime))
        }
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.videoComposition = composition
        
        var images:[(image: CGImage, fake: Bool)] = []
        
        var blurred: CGImage?

        generator.generateCGImagesAsynchronously(forTimes: frameForTimes, completionHandler: { (requestedTime, image, actualTime, result, error) in
            if let image = image, result == .succeeded {
                images.removeAll(where: { $0.fake })
                images.append((image: image, fake: false))
                if images.count < count, let image = images.first?.image, blur {
                    if blurred == nil {
                        let thumbnailContext = DrawingContext(size: size, scale: 1.0)
                        thumbnailContext.withFlippedContext { c in
                            c.interpolationQuality = .none
                            c.draw(image, in: CGRect(origin: CGPoint(), size: size))
                        }
                        telegramFastBlurMore(Int32(size.width), Int32(size.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                        blurred = thumbnailContext.generateImage()
                    }
                    if let image = blurred {
                        while images.count < count {
                            images.append((image: image, fake: true))
                        }
                    }
                }
                
            }
            if gradually {
                subscriber.putNext((images.map { $0.image }, false))
            }
            if images.filter({ !$0.fake }).count == frameForTimes.count, !cancelled {
                subscriber.putNext((images.map { $0.image }, true))
                subscriber.putCompletion()
            }
        })
        return ActionDisposable { [weak generator] in
            Queue.concurrentBackgroundQueue().async {
                generator?.cancelAllCGImageGeneration()
                cancelled = true
            }
        }
    } |> runOn(.concurrentBackgroundQueue())
}
func generateVideoAvatarPreview(for asset: AVComposition, composition: AVVideoComposition?, highSize: NSSize, lowSize: NSSize, at seconds: Double) -> Signal<(CGImage?, CGImage?), NoError> {
    return Signal { subscriber in
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        let highSize = highSize.multipliedByScreenScale()
        imageGenerator.maximumSize = highSize
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.videoComposition = composition
        let highRes = try? imageGenerator.copyCGImage(at: CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000), actualTime: nil)

    
        subscriber.putNext((highRes, highRes))
        subscriber.putCompletion()
        
        return ActionDisposable { 
        }
    } |> runOn(.concurrentDefaultQueue())
}
