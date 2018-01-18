//
//  MGalleryExternalVideoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
import AVFoundation
import AVKit



class MGalleryExternalVideoItem: MGalleryVideoItem {
    let content:TelegramMediaWebpageLoadedContent
    private let _media:TelegramMediaImage
    override init(_ account: Account, _ entry:GalleryEntry, _ pagerSize: NSSize) {
        let webpage = entry.message!.media[0] as! TelegramMediaWebpage
        
        var startTime:TimeInterval = 0
        if case let .Loaded(content) = webpage.content {
            self.content = content
            
            
            _ = ObjcUtils._youtubeVideoId(fromText: content.embedUrl, originalUrl: content.url, startTime: &startTime)
            
            self._media = content.image!
        } else {
            fatalError("content for external video not found")
        }
        super.init(account, entry, pagerSize)
        self.startTime = startTime
    
    }
    
    override var status: Signal<MediaResourceStatus, Void> {
        return .single(.Local)
    }
 
    override var sizeValue: NSSize {
        return NSMakeSize(1280, 720).fitted(pagerSize)
    }
    
    override func request(immediately: Bool) {
        
        let signal:Signal<(TransformImageArguments) -> DrawingContext?,NoError> = chatMessagePhoto(account: account, photo: _media, scale: System.backingScale)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(account.graphicsThreadPool) |> mapToThrottled { transform -> Signal<CGImage?, NoError> in
            return .single(transform(arguments)?.generateImage())
        }
        
        self.path.set(sharedVideoLoader.status(for: content) |> mapToSignal { (status) -> Signal<String, Void> in
            if let status = status, case let .loaded(video) = status {
                return .single(video.stream)
            }
            return .complete()
        } |> deliverOnMainQueue)
        
        self.image.set(result |> deliverOnMainQueue)
        
        fetch()
    }
    
    
    
    
    override func fetch() -> Void {
        fetching.set(sharedVideoLoader.fetch(for: content).start())
    }
    
}
