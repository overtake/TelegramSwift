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
import TelegramMedia

final class ChatAvatarView : Control {
    private let avatar: AvatarStoryControl = AvatarStoryControl(font: .avatar(.title), size: NSMakeSize(36, 36))
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?
    private let backgroundView = View()

    private let disposable = MetaDisposable()
    private var storyComponent: AvatarStoryIndicatorComponent?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundView.frame = frameRect.size.bounds
        addSubview(backgroundView)
        avatar.userInteractionEnabled = false
        avatar.setFrameSize(frameRect.size)
        addSubview(avatar)
        
        backgroundView.layer?.cornerRadius = frameRect.height / 2
        
        self.scaleOnClick = true
    }
    private var peer: Peer?
    
    func setPeer(item: ChatRowItem, peer: Peer, storyStats: PeerStoryStats? = nil, message: Message? = nil, size: NSSize? = nil, force: Bool = false, disableForum: Bool = false) {
        
        let context = item.chatInteraction.context
        
        let animated: Bool = self.peer != nil
        
        if let storyStats = storyStats, peer.id != item.context.peerId, message?.id.peerId.namespace == Namespaces.Peer.CloudChannel || message?.id.peerId.namespace == Namespaces.Peer.CloudGroup {
            self.storyComponent = .init(stats: storyStats, presentation: theme)
        } else {
            self.storyComponent = nil
        }
        self.peer = peer
        
        self.avatar.setPeer(account: context.account, peer: peer, message: message, size: size, disableForum: disableForum)
        if peer.isPremium || force, peer.hasVideo, !isLite(.animations) {
            let signal = peerPhotos(context: context, peerId: peer.id) |> deliverOnMainQueue
            var first = true
            self.disposable.set(signal.start(next: { [weak self] photos in
                self?.updatePhotos(photos.map { $0.value }, context: context, peer: peer, animated: !first)
                first = false
            }))
        } else {
            self.updatePhotos([], context: context, peer: peer, animated: animated)
            self.disposable.set(nil)
        }
        
        self.removeAllHandlers()
        self.set(handler: { [weak item, weak self] control in
            if storyStats != nil, let id = message?.id {
                item?.chatInteraction.openChatPeerStories(id, peer.id, { [weak self] signal in
                    self?.setOpenProgress(signal)
                })
            } else if item?.chatInteraction.presentation.state == .selecting {
                item?.chatInteraction.toggleUnderMouseMessage()
            } else {
                item?.openInfo()
            }
        }, for: .Click)
        
        self.toolTip = item.nameHide
    }
    
    func setOpenProgress(_ signal:Signal<Never, NoError>) {
        SetOpenStoryDisposable(self.avatar.pushLoadingStatus(signal: signal))
    }
    
    private var videoRepresentation: TelegramMediaImage.VideoRepresentation?
    
    private func updatePhotos(_ photos: [TelegramPeerPhoto], context: AccountContext, peer: Peer, animated: Bool) {
        
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

                
                let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [], alternativeRepresentations: [])
                
                
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
        
        let transition: ContainedViewLayoutTransition = animated  ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        if let storyComponent = storyComponent {
            avatar.update(component: storyComponent, availableSize: bounds.insetBy(dx: 3, dy: 3).size, transition: transition)
            if let view = self.photoVideoView {
                transition.updateFrame(view: view, frame: bounds.insetBy(dx: 3, dy: 3))
                view.layer?.cornerRadius = self.avatar.radius
            }
        } else {
            avatar.update(component: nil, availableSize: bounds.size, transition: transition)
            if let view = self.photoVideoView {
                transition.updateFrame(view: view, frame: bounds)
                view.layer?.cornerRadius = self.avatar.radius
            }
        }
        backgroundView.backgroundColor = .clear
        updatePlayerIfNeeded()
    }
    
    var storyControl: NSView {
        return avatar
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
        disposable.set(nil)
        NotificationCenter.default.removeObserver(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundView.backgroundColor = .clear
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
}
