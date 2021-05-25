//
//  GroupCallContextMenuHeader.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
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


final class GroupCallContextMenuHeaderView : View {
    private let nameView = TextView()
    private var descView: TextView?
    
    let peerPhotosDisposable = MetaDisposable()


    private let slider: SliderView = SliderView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(slider)
        addSubview(nameView)
        slider.layer?.cornerRadius = 4
        nameView.isSelectable = false
        nameView.userInteractionEnabled = false
    }
    
    deinit {
        peerPhotosDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        slider.frame = NSMakeSize(frame.width, 190).bounds.insetBy(dx: 5, dy: 0)
        nameView.setFrameOrigin(NSMakePoint(14, slider.frame.maxY + 5))
        descView?.setFrameOrigin(NSMakePoint(14, nameView.frame.maxY + 3))
    }
    
    func setPeer(_ peer: Peer, about: String?, account: Account, videos: [NSView]) {

        
        let name = TextViewLayout(.initialize(string: peer.displayTitle, color: GroupCallTheme.customTheme.textColor, font: .medium(.text)), maximumNumberOfLines: 2)
        name.measure(width: frame.width - 28)
        
        nameView.update(name)
        
        if let about = about {
            self.descView = TextView()
            descView?.isSelectable = false
            descView?.userInteractionEnabled = false
            addSubview(self.descView!)
            let desc = TextViewLayout(.initialize(string: about, color: GroupCallTheme.customTheme.grayTextColor, font: .normal(.text)))
            desc.measure(width: frame.width - 28)
            self.descView?.update(desc)

        } else {
            self.descView?.removeFromSuperview()
            self.descView = nil
        }
        
        setFrameSize(NSMakeSize(frame.width, 190 + name.layoutSize.height + 10 + (descView != nil ? descView!.frame.height + 3 : 0)))
        layout()
        
        var photos = Array(syncPeerPhotos(peerId: peer.id).prefix(10))
        let signal = peerPhotos(account: account, peerId: peer.id, force: true) |> deliverOnMainQueue
                
        for video in videos {
            let view = PhotoOrVideoView(frame: self.slider.bounds)
            view.setPeer(peer, peerPhoto: nil, video: video, account: account)
            self.slider.addSlide(view)
        }
        
        
        let view = PhotoOrVideoView(frame: self.slider.bounds)
        view.setPeer(peer, peerPhoto: nil, video: nil, account: account)
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
                    view.setPeer(peer, peerPhoto: photo, video: nil, account: account)
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
                view.setPeer(peer, peerPhoto: photo, video: nil, account: account)
                self.slider.addSlide(view)
            }
        }
        
        
        
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
