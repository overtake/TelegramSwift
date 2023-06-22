//
//  ChatAvatarView.swift
//  Telegram
//
//  Created by Mike Renoir on 22.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


final class ChatAvatarView : Control {
    private let avatar: AvatarControl = AvatarControl(font: .avatar(.title))
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer? 

    private let disposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.userInteractionEnabled = false
        avatar.setFrameSize(frameRect.size)
        addSubview(avatar)
    }
    
    func setPeer(context: AccountContext, peer: Peer, message: Message? = nil, size: NSSize? = nil, force: Bool = false, disableForum: Bool = false) {
        self.avatar.setPeer(account: context.account, peer: peer, message: message, size: size, disableForum: disableForum)
        if peer.isPremium || force, peer.hasVideo, !isLite(.animations) {
            let signal = peerPhotos(context: context, peerId: peer.id) |> deliverOnMainQueue
            disposable.set(signal.start(next: { [weak self] photos in
                self?.updatePhotos(photos.map { $0.value }, context: context, peer: peer)
            }))
        }
    }
    
    private var videoRepresentation: TelegramMediaImage.VideoRepresentation?
    
    private func updatePhotos(_ photos: [TelegramPeerPhoto], context: AccountContext, peer: Peer) {
        
        if let first = photos.first, let video = first.image.videoRepresentations.first {
            let equal = videoRepresentation?.resource.id == video.resource.id
            
            if !equal {
                
                self.photoVideoView?.removeFromSuperview()
                self.photoVideoView = nil
                
                self.photoVideoView = MediaPlayerView(backgroundThread: true)
                self.photoVideoView!.layer?.cornerRadius = self.avatar.frame.height / 2
                
                self.addSubview(self.photoVideoView!, positioned: .above, relativeTo: self.avatar)

                self.photoVideoView!.isEventLess = true
                
                self.photoVideoView!.frame = self.avatar.frame

                
                let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                
                
                let reference: MediaResourceReference
                
                if let peerReference = PeerReference(peer) {
                    reference = MediaResourceReference.avatar(peer: peerReference, resource: file.resource)
                } else {
                    reference = MediaResourceReference.standalone(resource: file.resource)
                }
                
                let mediaPlayer = MediaPlayer(postbox: context.account.postbox, userLocation: .peer(peer.id), userContentType: .avatar, reference: reference, streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                
                mediaPlayer.actionAtEnd = .loop(nil)
                
                self.photoVideoPlayer = mediaPlayer
                
                if let seekTo = video.startTimestamp {
                    mediaPlayer.seek(timestamp: seekTo)
                }
                mediaPlayer.attachPlayerView(self.photoVideoView!)
                self.videoRepresentation = video
            }
        } else {
            self.photoVideoPlayer = nil
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
            self.videoRepresentation = nil
        }
        updatePlayerIfNeeded()
    }
    
    @objc func updatePlayerIfNeeded() {
        let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect)
        if let photoVideoPlayer = photoVideoPlayer {
            if accept {
                photoVideoPlayer.play()
            } else {
                photoVideoPlayer.pause()
            }
        }
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: enclosingScrollView?.contentView)
        } else {
            removeNotificationListeners()
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    deinit {
        if superview != nil {
            var bp = 0
            bp += 1
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
