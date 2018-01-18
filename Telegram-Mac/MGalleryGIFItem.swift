//
//  MGalleryGIFItem.swift
//  TelegramMac
//
//  Created by keepcoder on 16/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
class MGalleryGIFItem: MGalleryItem {

    override init(_ account: Account, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        super.init(account, entry, pagerSize)
        
        let view = self.view
        let pathSignal = path.get() |> distinctUntilChanged |> deliverOnMainQueue |> mapToSignal { path -> Signal<(String?,GIFPlayerView), Void> in
            return view.get() |> distinctUntilChanged |> map { view in
                return (path,view as! GIFPlayerView)
            }
        }
        disposable.set(pathSignal.start(next: { (path, view) in
            view.set(path: path)
        }))
        
    }
    
    override var status:Signal<MediaResourceStatus, Void> {
        return chatMessageFileStatus(account: account, file: media)
    }
    
    var media:TelegramMediaFile {
        switch entry {
        case .message(let entry):
            if let media = entry.message!.media[0] as? TelegramMediaFile {
                return media
            } else if let media = entry.message!.media[0] as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    return content.file!
                default:
                    fatalError("")
                }
            }
        case .instantMedia(let media):
            return media.media as! TelegramMediaFile
        default:
            fatalError()
        }
        
        fatalError("")
    }
    
    override var maxMagnify:CGFloat {
        return 1.0
    }

    override func singleView() -> NSView {
        let player = GIFPlayerView()
        player.followWindow = false
        return player
    }
    
    override var sizeValue: NSSize {
        if let size = media.dimensions {
            return size.fitted(pagerSize)
        }
        return pagerSize
    }
    
    override func request(immediately: Bool) {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: media.previewRepresentations, reference: nil)
        
        let signal:Signal<(TransformImageArguments) -> DrawingContext?,NoError> = chatMessagePhoto(account: account, photo: image, scale: System.backingScale)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(account.graphicsThreadPool) |> mapToThrottled { transform -> Signal<CGImage?, NoError> in
            return .single(transform(arguments)?.generateImage())
        }
        
    
        path.set(account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, Void> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaGifExt)!)
            }
            return .never()
        })

        self.image.set(result |> deliverOnMainQueue)
    
        fetch()
    }
    
 
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func fetch() -> Void {
        fetching.set(chatMessageFileInteractiveFetched(account: account, file: media).start())
    }

    
}
