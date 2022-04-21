//
//  GroupCallAvatarMenuItem.swift
//  Telegram
//
//  Created by Mike Renoir on 27.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


private final class PhotoOrVideoView: View {
    private let imageView: TransformImageView
    
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?

    private var videoView: NSView?
    
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        photoVideoView?.frame = imageView.frame
        videoView?.frame = imageView.frame
    }
    
    deinit {
    }
    
    func setPeer(_ peer: Peer, peerPhoto: TelegramPeerPhoto?, video: NSView?, account: Account) {
        
        self.videoView = video
        
        if let video = video {
            self.photoVideoPlayer = nil
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
            addSubview(video)
        } else if let first = peerPhoto, let video = first.image.videoRepresentations.last {
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
            
            self.photoVideoView = MediaPlayerView(backgroundThread: true)
            
            addSubview(photoVideoView!, positioned: .above, relativeTo: self.imageView)
        
            self.photoVideoView!.isEventLess = true
            
            self.photoVideoView!.frame = self.imageView.frame
            
            let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
            
            
            let mediaPlayer = MediaPlayer(postbox: account.postbox, reference: MediaResourceReference.standalone(resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
            
            mediaPlayer.actionAtEnd = .loop(nil)
            
            self.photoVideoPlayer = mediaPlayer
            
            if let seekTo = video.startTimestamp {
                mediaPlayer.seek(timestamp: seekTo)
            }
            mediaPlayer.attachPlayerView(self.photoVideoView!)
            mediaPlayer.play()
        } else {
            self.photoVideoPlayer = nil
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
            
            let profileImageRepresentations:[TelegramMediaImageRepresentation]
            if let peer = peer as? TelegramChannel {
                profileImageRepresentations = peer.profileImageRepresentations
            } else if let peer = peer as? TelegramUser {
                profileImageRepresentations = peer.profileImageRepresentations
            } else if let peer = peer as? TelegramGroup {
                profileImageRepresentations = peer.profileImageRepresentations
            } else {
                profileImageRepresentations = []
            }
            
            let id = profileImageRepresentations.first?.resource.id.hashValue ?? Int(peer.id.toInt64())
            let media = peerPhoto?.image ?? TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id(id)), representations: profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    
            
            if let dimension = profileImageRepresentations.last?.dimensions.size {
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: frame.size, intrinsicInsets: NSEdgeInsets())
                self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: false)
                self.imageView.setSignal(chatMessagePhoto(account: account, imageReference: ImageMediaReference.standalone(media: media), peer: peer, scale: self.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                    cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                })
                self.imageView.set(arguments: arguments)
                
                if let reference = PeerReference(peer) {
                    _ = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start()
                }
            } else {
                self.imageView.setSignal(signal: generateEmptyRoundAvatar(self.imageView.frame.size, font: .avatar(90.0), account: account, peer: peer) |> map { TransformImageResult($0, true) })
            }
        }
     
    }
    
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class GroupCallAvatarMenuItem : ContextMenuItem {
    private let peer: Peer
    private let context: AccountContext
    init(_ peer: Peer, context: AccountContext) {
        self.peer = peer
        self.context = context
        super.init("")
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return GroupCallAvatarMenuRowItem(.zero, presentation: presentation, interaction: interaction, peer: peer, context: context)
    }
}


private final class GroupCallAvatarMenuRowItem : AppMenuBasicItem {
    fileprivate let peer: Peer
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction, peer: Peer, context: AccountContext) {
        self.peer = peer
        self.context = context
        super.init(initialSize, presentation: presentation, menuItem: nil, interaction: interaction)
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallAvatarMenuRowView.self
    }
    
    override var effectiveSize: NSSize {
        return NSMakeSize(200, 200)
    }
    
    override var height: CGFloat {
        return 200
    }
}


private final class GroupCallAvatarMenuRowView : AppMenuBasicItemView {
    private let slider: SliderView = SliderView(frame: .zero)
    private let peerPhotosDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(slider)
        slider.layer?.cornerRadius = 4
    }
    
    deinit {
        peerPhotosDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        
        slider.setFrameSize(NSMakeSize(contentSize.width, contentSize.height - 4))
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallAvatarMenuRowItem else {
            return
        }
        
        let peer = item.peer
        let context = item.context
        
        var photos = Array(syncPeerPhotos(peerId: peer.id).prefix(10))
        let signal = peerPhotos(context: context, peerId: peer.id, force: true) |> deliverOnMainQueue
                
        
        slider.frame = NSMakeRect(0, 0, frame.width - 8, frame.height - 4)
        
        let view = PhotoOrVideoView(frame: self.slider.bounds)
        view.setPeer(peer, peerPhoto: nil, video: nil, account: context.account)
        self.slider.addSlide(view)
        
        if photos.isEmpty {
            
            peerPhotosDisposable.set(signal.start(next: { [weak self, weak view] photos in
                guard let `self` = self else {
                    return
                }
                
                var photos = Array(photos.prefix(10))
                
                if !photos.isEmpty {
                    let first = photos.removeFirst()
                    if !first.image.videoRepresentations.isEmpty {
                        photos.insert(first, at: 0)
                        self.slider.removeSlide(view)
                    }
                }
                for photo in photos {
                    let view = PhotoOrVideoView(frame: self.slider.bounds)
                    view.setPeer(peer, peerPhoto: photo, video: nil, account: context.account)
                    self.slider.addSlide(view)
                }
            }))
        } else {
            if !photos.isEmpty {
                let first = photos.removeFirst()
                if !first.image.videoRepresentations.isEmpty {
                    photos.insert(first, at: 0)
                    self.slider.removeSlide(view)
                }
            }
            for photo in photos {
                let view = PhotoOrVideoView(frame: self.slider.bounds)
                view.setPeer(peer, peerPhoto: photo, video: nil, account: context.account)
                self.slider.addSlide(view)
            }
        }    }
}
