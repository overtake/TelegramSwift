//
//  TransformOutgoingMessageMedia.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Foundation
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

public func transformOutgoingMessageMedia(postbox: Postbox, network: Network, reference: AnyMediaReference, opportunistic: Bool) -> Signal<AnyMediaReference?, NoError> {
    switch reference.media {
    case let file as TelegramMediaFile:
        let signal = Signal<(MediaResourceData, String?), NoError> { subscriber in
            let fetch = fetchedMediaResource(postbox: postbox, reference: reference.resourceReference(file.resource), statsCategory: .file).start() //postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file)).start()
            let dataSignal = resourceType(mimeType: file.mimeType) |> mapToSignal { ext in
                return postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true)) |> map { result in
                    return (result, ext)
                }
            }
            let data = dataSignal.start(next: { next in
                subscriber.putNext(next)
                if next.0.complete {
                    subscriber.putCompletion()
                }
            })
            
            return ActionDisposable {
                fetch.dispose()
                data.dispose()
            }
        }
        
        let result: Signal<(MediaResourceData, String?), NoError>
        if opportunistic {
            result = signal |> take(1)
        } else {
            result = signal
        }
        
        return result
            |> mapToSignal { data -> Signal<AnyMediaReference?, NoError> in
                if data.0.complete {
                    return Signal { subscriber in
                        
                        let resource = (file.resource as? LocalFileReferenceMediaResource)
                        var size = resource?.size
                        
                        if resource == nil {
                            size = Int32(data.0.size)
                        }
                        
                        var thumbImage:CGImage? = nil
                        
                        let thumbedFile:String
                        if let resource = resource {
                            thumbedFile = resource.localFilePath
                        } else {
                            if file.isVideo && file.isAnimated {
                                thumbedFile = data.0.path + ".mp4"
                            } else {
                                thumbedFile = data.0.path.appending(".\(file.fileName?.nsstring.pathExtension ?? data.1 ?? "jpg")")
                            }
                        }
                        
                        try? FileManager.default.linkItem(atPath: data.0.path, toPath: thumbedFile)
                        
                        if file.mimeType.hasPrefix("image/") {
                            
                            if let thumbData = try? Data(contentsOf: URL(fileURLWithPath: thumbedFile)) {
                                let options = NSMutableDictionary()
                                options.setValue(320 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                                
                                if let imageSource = CGImageSourceCreateWithData(thumbData as CFData, nil) {
                                    thumbImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
                                }
                            }
                           
                            
                        } else if file.mimeType.hasPrefix("video/") {
                            let asset = AVAsset(url: URL(fileURLWithPath: thumbedFile))
                            let imageGenerator = AVAssetImageGenerator(asset: asset)
                            imageGenerator.maximumSize = CGSize(width: 320, height: 320)
                            imageGenerator.appliesPreferredTrackTransform = true
                            thumbImage = try? imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
   
                        }
                        
                        if let image = thumbImage {
                            
                            let options = NSMutableDictionary()
                            options.setValue(320 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                            
                            let colorQuality: Float = 0.2
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            
                            let mutableData: CFMutableData = NSMutableData() as CFMutableData
                            if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options) {
                                CGImageDestinationSetProperties(colorDestination, nil)
                                
                                CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                                if CGImageDestinationFinalize(colorDestination) {
                                    let thumbnailResource = LocalFileMediaResource(fileId: arc4random64())
                                    postbox.mediaBox.storeResourceData(thumbnailResource.id, data: mutableData as Data)
                                    subscriber.putNext(AnyMediaReference.standalone(media: file.withUpdatedSize(Int(size ?? 0)).withUpdatedPreviewRepresentations([TelegramMediaImageRepresentation(dimensions: image.size, resource: thumbnailResource)])))
                                    
                                     return EmptyDisposable
                                }
                            }
                        
                        }
                        
                        
                        subscriber.putNext(AnyMediaReference.standalone(media: file.withUpdatedSize(Int(size ?? 0))))
                        subscriber.putCompletion()
                        
                        
                        return EmptyDisposable
                    } |> runOn( opportunistic ? Queue.mainQueue() : Queue.concurrentDefaultQueue())
                } else if opportunistic {
                    return .single(nil)
                } else {
                    return .complete()
                }
        }
    default:
        return .single(nil)
    }
}
