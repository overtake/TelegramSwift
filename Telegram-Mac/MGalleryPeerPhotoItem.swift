//
//  MGalleryPeerPhotoItem.swift
//  Telegram
//
//  Created by keepcoder on 10/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

class MGalleryPeerPhotoItem: MGalleryItem {
    let media:TelegramMediaImage
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        
        self.media = entry.photo!
        super.init(context, entry, pagerSize)
    }
    
    override var sizeValue: NSSize {
        if let largest = media.representationForDisplayAtSize(NSMakeSize(1280, 1280)) {
            return largest.dimensions.fitted(pagerSize)
        }
        return NSZeroSize
    }
    
    override func smallestValue(for size: NSSize) -> Signal<NSSize, NoError> {
        if let largest = media.representationForDisplayAtSize(NSMakeSize(1280, 1280)) {
            return .single(largest.dimensions.fitted(size))
        }
        return .single(pagerSize)
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        if let largestRepresentation = media.representationForDisplayAtSize(NSMakeSize(1280, 1280)) {
            return context.account.postbox.mediaBox.resourceStatus(largestRepresentation.resource)
        } else {
            return .never()
        }
    }
    
    override func request(immediately: Bool) {
        
        
        let context = self.context
        let media = self.media
        let entry = self.entry
        
        let result = combineLatest(size.get(), rotate.get()) |> mapToSignal { [weak self] size, orientation -> Signal<(NSSize, ImageOrientation?), NoError> in
            guard let `self` = self else {return .complete()}
            
            return self.smallestValue(for: size) |> map { size in
                var newSize = size
                if let orientation = orientation {
                    if orientation == .right || orientation == .left {
                        newSize = NSMakeSize(newSize.height, newSize.width)
                    }
                }
                return (newSize, orientation)
            }
            
            } |> mapToSignal { size, orientation -> Signal<CGImage?, NoError> in
                return chatGalleryPhoto(account: context.account, imageReference: entry.imageReference(media), toRepresentationSize: NSMakeSize(1280, 1280), scale: System.backingScale, synchronousLoad: true)
                    |> map { transform in
                        let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
                        if let orientation = orientation {
                            return image?.createMatchingBackingDataWithImage(orienation: orientation)
                        }
                        return image
                }
        }
        
//        let result = combineLatest(size.get(), rotate.get()) |> mapToSignal { [weak self] size, orientation -> Signal<(NSSize, ImageOrientation?), NoError> in
//            guard let `self` = self else {return .complete()}
//
//            return self.smallestValue(for: size) |> map { size in
//                var newSize = size
//                if let orientation = orientation {
//                    if orientation == .right || orientation == .left {
//                        newSize = NSMakeSize(newSize.height, newSize.width)
//                    }
//                }
//                return (newSize, orientation)
//            }
//
//        } |> mapToSignal { size, orientation -> Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments, ImageOrientation?), NoError> in
//            return chatGalleryPhoto(account: context.account, imageReference: entry.imageReference(media), toRepresentationSize: NSMakeSize(640, 640), scale: System.backingScale, secureIdAccessContext: nil, synchronousLoad: true)
//                |> map { transform in
//                    let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
//                    if let orientation = orientation {
//                        return image?.createMatchingBackingDataWithImage(orienation: orientation)
//                    }
//                    return image
//            }
//        }
        

        if let representation = media.representationForDisplayAtSize(NSMakeSize(1280, 1280))  {
            path.set(context.account.postbox.mediaBox.resourceData(representation.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
                
                if resource.complete {
                    return .single(link(path:resource.path, ext:kMediaImageExt)!)
                }
                return .never()
            })
        } 
        
        self.image.set(result |> map { .image($0) } |> deliverOnMainQueue)
        
        
        fetch()
    }
    
    override func fetch() -> Void {
        fetching.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: self.entry.peerPhotoResource()).start())
    }
    
    override func cancel() -> Void {
        super.cancel()
        if let representation = media.representationForDisplayAtSize(NSMakeSize(1280, 1280))  {
            cancelFreeMediaFileInteractiveFetch(context: context, resource: representation.resource)
        }
        fetching.set(nil)
    }

}
