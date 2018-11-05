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
    override init(_ account: Account, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        
        self.media = entry.photo!
        super.init(account, entry, pagerSize)
    }
    
    override var sizeValue: NSSize {
        if let largest = media.representationForDisplayAtSize(NSMakeSize(640, 640)) {
            return largest.dimensions.fitted(pagerSize)
        }
        return NSZeroSize
    }
    
    override func smallestValue(for size: NSSize) -> Signal<NSSize, NoError> {
        if let largest = media.representationForDisplayAtSize(NSMakeSize(640, 640)) {
            return .single(largest.dimensions.fitted(size))
        }
        return .single(pagerSize)
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        if let largestRepresentation = media.representationForDisplayAtSize(NSMakeSize(640, 640)) {
            return account.postbox.mediaBox.resourceStatus(largestRepresentation.resource)
        } else {
            return .never()
        }
    }
    
    override func request(immediately: Bool) {
        
        
        let account = self.account
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
            
        } |> mapToSignal { size, orientation -> Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments, ImageOrientation?), NoError> in
            return chatMessagePhoto(account: account, imageReference: entry.imageReference(media), toRepresentationSize: NSMakeSize(640, 640), scale: System.backingScale)
                |> deliverOn(account.graphicsThreadPool)
                |> map { transform in
                    return (transform, TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()), orientation)
                }
        } |> mapToThrottled { (transform, arguments, orientation) -> Signal<CGImage?, NoError> in
            let image = transform(arguments)?.generateImage()
            if let orientation = orientation {
                return .single(image?.createMatchingBackingDataWithImage(orienation: orientation))
            }
            return .single(image)
        }
        

        if let representation = media.representations.last {
            path.set(account.postbox.mediaBox.resourceData(representation.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
                
                if resource.complete {
                    return .single(link(path:resource.path, ext:kMediaImageExt)!)
                }
                return .never()
            })
        }
        
        self.image.set(result |> deliverOnMainQueue)
        
        
        fetch()
    }
    
    override func fetch() -> Void {
        fetching.set(chatMessagePhotoInteractiveFetched(account: account, imageReference: entry.imageReference(media), toRepresentationSize: NSMakeSize(640, 640)).start())
    }
    
    override func cancel() -> Void {
        super.cancel()
        chatMessagePhotoCancelInteractiveFetch(account: account, photo: media)
    }

}
