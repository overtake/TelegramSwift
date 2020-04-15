//
//  MGalleryPeerPhotoItem.swift
//  Telegram
//
//  Created by keepcoder on 10/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit

class MGalleryPeerPhotoItem: MGalleryItem {
    let media:TelegramMediaImage
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        
        self.media = entry.photo!
        super.init(context, entry, pagerSize)
    }
    
    override var sizeValue: NSSize {
        if let largest = media.representationForDisplayAtSize(PixelDimensions(1280, 1280)) {
            return largest.dimensions.size.fitted(pagerSize)
        }
        return NSZeroSize
    }
    
    override func smallestValue(for size: NSSize) -> NSSize {
        if let largest = media.representationForDisplayAtSize(PixelDimensions(1280, 1280)) {
            return largest.dimensions.size.fitted(size)
        }
        return pagerSize
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        if let largestRepresentation = media.representationForDisplayAtSize(PixelDimensions(1280, 1280)) {
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
            var newSize = self.smallestValue(for: size)
            if let orientation = orientation {
                if orientation == .right || orientation == .left {
                    newSize = NSMakeSize(newSize.height, newSize.width)
                }
            }
            return .single((newSize, orientation))
         } |> mapToSignal { size, orientation -> Signal<(NSImage?, ImageOrientation?), NoError> in
            return chatGalleryPhoto(account: context.account, imageReference: entry.imageReference(media), toRepresentationSize: NSMakeSize(1280, 1280), peer: entry.peer, scale: System.backingScale, synchronousLoad: true)
                    |> map { transform in
                        let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
                        if let orientation = orientation {
                            let transformed = image?.createMatchingBackingDataWithImage(orienation: orientation)
                            if let transformed = transformed {
                                return (NSImage(cgImage: transformed, size: transformed.size), orientation)
                            }
                        }
                        if let image = image {
                            return (NSImage(cgImage: image, size: image.size), orientation)
                        } else {
                            return (nil, nil)
                        }
                }
        }

        if let representation = media.representationForDisplayAtSize(PixelDimensions(1280, 1280))  {
            path.set(context.account.postbox.mediaBox.resourceData(representation.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
                
                if resource.complete {
                    return .single(link(path:resource.path, ext:kMediaImageExt)!)
                }
                return .never()
            })
        } 
        
        self.image.set(result |> map { .image($0.0, $0.1) } |> deliverOnMainQueue)
        
        
        fetch()
    }
    
    override func fetch() -> Void {
        fetching.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: self.entry.peerPhotoResource()).start())
    }
    
    override func cancel() -> Void {
        super.cancel()
        if let representation = media.representationForDisplayAtSize(PixelDimensions(1280, 1280))  {
            cancelFreeMediaFileInteractiveFetch(context: context, resource: representation.resource)
        }
        fetching.set(nil)
    }

}
