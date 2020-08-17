//
//  MGalleryGIFItem.swift
//  TelegramMac
//
//  Created by keepcoder on 16/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit
class MGalleryGIFItem: MGalleryItem {

    private var mediaPlayer: MediaPlayer!
    
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        super.init(context, entry, pagerSize)
        
        let view = self.view
        
        let fileReference = entry.fileReference(media)
       
        self.mediaPlayer = MediaPlayer(postbox: context.account.postbox, reference: fileReference.resourceReference(media.resource), streamable: media.isStreamable, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: false)
        mediaPlayer.actionAtEnd = .loop(nil)

        
        disposable.set(view.get().start(next: { [weak self] view in
            if let view = (view as? MediaPlayerView) {
                self?.mediaPlayer.attachPlayerView(view)
            }
        }))
        
    }
    
    override func appear(for view: NSView?) {
        super.appear(for: view)
        self.mediaPlayer.play()
    }
    
    override func disappear(for view: NSView?) {
        super.disappear(for: view)
        
        self.mediaPlayer.pause()
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        return chatMessageFileStatus(account: context.account, file: media)
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
        case .instantMedia(let media, _):
            return media.media as! TelegramMediaFile
        case let  .photo(_, _, photo, _, _, _, _):
            let video = photo.videoRepresentations.last!
            let file = TelegramMediaFile(fileId: photo.imageId, partialReference: nil, resource: video.resource, previewRepresentations: photo.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [.Video(duration:0, size: PixelDimensions(640, 640), flags: [])])
            
            return file
        default:
            fatalError()
        }
        
        fatalError("")
    }
    
//    override var maxMagnify:CGFloat {
//        return 1.0
//    }

    override func singleView() -> NSView {
        let player = MediaPlayerView(backgroundThread: true)
        player.layerContentsRedrawPolicy = .duringViewResize
        return player
    }
    
    override var sizeValue: NSSize {
        if let size = media.dimensions?.size {
            
            var size = size
            
            if size.width == 0 || size.height == 0 {
                size = NSMakeSize(300, 300)
            }
            
            let aspectRatio = size.width / size.height
            let addition = max(300 - size.width, 300 - size.height)
            
            if addition > 0 {
                size.width += addition * aspectRatio
                size.height += addition
            }
            
            return size.fitted(pagerSize)
        }
        return pagerSize
    }
    
    override func request(immediately: Bool) {
        super.request(immediately: immediately)
        let size = media.dimensions?.size.fitted(pagerSize) ?? sizeValue
        
        let signal:Signal<ImageDataTransformation,NoError> = chatMessageVideo(postbox: context.account.postbox, fileReference: entry.fileReference(media), scale: System.backingScale)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(graphicsThreadPool) |> mapToThrottled { generator -> Signal<CGImage?, NoError> in
            return .single(generator.execute(arguments, generator.data)?.generateImage())
        }
        
    
        path.set(context.account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaGifExt)!)
            }
            return .never()
        })

        self.image.set(result |> map { GPreviewValueClass(.image($0 != nil ? NSImage(cgImage: $0!, size: $0!.backingSize) : nil, nil)) } |> deliverOnMainQueue)
    
        fetch()
    }
    
 
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func fetch() -> Void {
        fetching.set(chatMessageFileInteractiveFetched(account: context.account, fileReference: entry.fileReference(media)).start())
    }

    
}
