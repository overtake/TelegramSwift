//
//  MGalleryPhotoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 15/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

class MGalleryPhotoItem: MGalleryItem {
    
    let media:TelegramMediaImage
    let secureIdAccessContext: SecureIdAccessContext?
    private let representation:TelegramMediaImageRepresentation
    override init(_ account: Account, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        switch entry {
        case .message(let entry):
            if let webpage =  entry.message!.media[0] as? TelegramMediaWebpage {
                if case let .Loaded(content) = webpage.content, let image = content.image {
                    self.media = image
                } else if case let .Loaded(content) = webpage.content, let media = content.file  {
                    let represenatation = TelegramMediaImageRepresentation(dimensions: media.dimensions ?? NSZeroSize, resource: media.resource)
                    var representations = media.previewRepresentations
                    representations.append(represenatation)
                    self.media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, reference: nil)
                    
                } else {
                    fatalError("image for webpage not found")
                }
            } else {
                if let media = entry.message!.media[0] as? TelegramMediaFile {
                    let represenatation = TelegramMediaImageRepresentation(dimensions: media.dimensions ?? NSZeroSize, resource: media.resource)
                    var representations = media.previewRepresentations
                    representations.append(represenatation)
                    self.media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, reference: nil)
                } else {
                    self.media = entry.message!.media[0] as! TelegramMediaImage
                }
            }
            secureIdAccessContext = nil
        case .instantMedia(let media):
            self.media = media.media as! TelegramMediaImage
            secureIdAccessContext = nil
        case let .secureIdDocument(document, _):
            self.media = document.image
            self.secureIdAccessContext = document.context
        default:
            fatalError("photo item not supported entry type")
        }
        
        self.representation = media.representations.last!
        super.init(account, entry, pagerSize)
    }
    
    
    override var sizeValue: NSSize {
        if let largest = media.representations.last {
            if let modifiedSize = modifiedSize {
                return modifiedSize.fitted(pagerSize)
            }
            return largest.dimensions.fitted(pagerSize)
        }
        return NSZeroSize
    }
    
    override func smallestValue(for size: NSSize) -> Signal<NSSize, Void> {
        if let largest = media.representations.last {
            if let modifiedSize = modifiedSize {
                let lhsProportion = modifiedSize.width/modifiedSize.height
                let rhsProportion = largest.dimensions.width/largest.dimensions.height
                
                if lhsProportion != rhsProportion {
                    return .single(modifiedSize.fitted(size))
                }
            }
            return .single(largest.dimensions.fitted(size))
        }
        return .single(pagerSize)
    }
    
    override var status:Signal<MediaResourceStatus, Void> {
        return chatMessagePhotoStatus(account: account, photo: media)
    }
    
    override func request(immediately: Bool) {
        
        let account = self.account
        let media = self.media
        let secureIdAccessContext = self.secureIdAccessContext
        
        let result = size.get() |> mapToSignal { [weak self] size -> Signal<NSSize, Void> in
            if let strongSelf = self {
                return strongSelf.smallestValue(for: size)
            }
            return .complete()
        } |> distinctUntilChanged |> mapToSignal { size -> Signal<CGImage?, Void> in
            return chatGalleryPhoto(account: account, photo: media, scale: System.backingScale, secureIdAccessContext: secureIdAccessContext) |> deliverOn(account.graphicsThreadPool) |> map { transform in
                return transform(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets()))
            }
        }
        
        path.set(account.postbox.mediaBox.resourceData(representation.resource) |> mapToSignal { resource -> Signal<String, Void> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaImageExt)!)
            }
            return .never()
        })
        
        self.image.set(result |> deliverOnMainQueue)

        
        fetch()
    }
    
    override func fetch() -> Void {
        fetching.set(chatMessagePhotoInteractiveFetched(account: account, photo: media).start())
    }
    
    override func cancel() -> Void {
        super.cancel()
        chatMessagePhotoCancelInteractiveFetch(account: account, photo: media)
    }
    
    
}
