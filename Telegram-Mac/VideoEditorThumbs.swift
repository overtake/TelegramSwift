//
//  VideoEditorThumbs.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/07/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


func generateVideoScrubberThumbs(for asset: AVComposition, composition: AVVideoComposition?, size: NSSize, count: Int, gradually: Bool) -> Signal<([CGImage], Bool), NoError> {
    return Signal { subscriber in
        
        var cancelled = false
        
        let videoDuration = asset.duration
        
        let generator = AVAssetImageGenerator(asset: asset)
        
        var frameForTimes = [NSValue]()
        let sampleCounts = count
        let totalTimeLength = Int(videoDuration.seconds * Double(videoDuration.timescale))
        let step = totalTimeLength / sampleCounts
        
        for i in 0 ..< sampleCounts {
            let cmTime = CMTimeMake(value: Int64(i * step), timescale: Int32(videoDuration.timescale))
            frameForTimes.append(NSValue(time: cmTime))
        }
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size.multipliedByScreenScale()
        
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.videoComposition = composition
        
        var images:[CGImage] = []

        generator.generateCGImagesAsynchronously(forTimes: frameForTimes, completionHandler: { (requestedTime, image, actualTime, result, error) in
            if let image = image, result == .succeeded {
                images.append(image)
            }
            if gradually {
                subscriber.putNext((images, false))
            }
            if images.count == frameForTimes.count, !cancelled {
                subscriber.putNext((images, true))
                subscriber.putCompletion()
            }
        })
        return ActionDisposable { [weak generator] in
            generator?.cancelAllCGImageGeneration()
            cancelled = true
        }
    } |> runOn(.concurrentDefaultQueue())
}
