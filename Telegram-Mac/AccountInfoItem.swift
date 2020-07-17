//
//  AccountInfoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit



class AccountInfoItem: GeneralRowItem {
    
    fileprivate let textLayout: TextViewLayout
    fileprivate let activeTextlayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let peer: TelegramUser
    private(set) var photos: [TelegramPeerPhoto] = []

    private let peerPhotosDisposable = MetaDisposable()
    
    init(_ initialSize:NSSize, stableId:AnyHashable, context: AccountContext, peer: TelegramUser, action: @escaping()->Void) {
        self.context = context
        self.peer = peer
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: peer.displayTitle, color: theme.colors.text, font: .medium(.title))
        if let phone = peer.phone {
            _ = attr.append(string: "\n")
            _ = attr.append(string: formatPhoneNumber(phone), color: theme.colors.grayText, font: .normal(.text))
        }
        if let username = peer.username, !username.isEmpty {
            _ = attr.append(string: "\n")
            _ = attr.append(string: "@\(username)", color: theme.colors.grayText, font: .normal(.text))
        }
        
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 4)
        
        let active = attr.mutableCopy() as! NSMutableAttributedString
        active.addAttribute(.foregroundColor, value: theme.colors.underSelectedColor, range: active.range)
        activeTextlayout = TextViewLayout(active, maximumNumberOfLines: 4)
        super.init(initialSize, height: 90, stableId: stableId, action: action)
        
        let signal = peerPhotos(account: context.account, peerId: peer.id, force: true) |> deliverOnMainQueue
        peerPhotosDisposable.set(signal.start(next: { [weak self] photos in
            self?.photos = photos
            self?.redraw()
        }))
        
    }
    
    deinit {
        peerPhotosDisposable.dispose()
    }
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 100)
        activeTextlayout.measure(width: width - 100)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return AccountInfoView.self
    }
    
}

class AccountInfoView : TableRowView {
    
    
    private let avatarView:AvatarControl
    private let textView: TextView = TextView()
    private let actionView: ImageView = ImageView()
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?

    
    required init(frame frameRect: NSRect) {
        avatarView = AvatarControl(font: .avatar(22.0))
        avatarView.setFrameSize(NSMakeSize(60, 60))
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        avatarView.animated = true
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(avatarView)
        addSubview(actionView)
        addSubview(textView)
        
        avatarView.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem, let _ = item.peer.largeProfileImage {
                showPhotosGallery(context: item.context, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        
    }
    
    override func mouseUp(with event: NSEvent) {
        if let item = item as? AccountInfoItem, mouseInside() {
            item.action()
        }
    }
    
    override var backdorColor: NSColor {
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
        
    @objc func updatePlayerIfNeeded() {
        let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect)
        if accept {
            photoVideoPlayer?.play()
        } else {
            photoVideoPlayer?.pause()
        }
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        photoVideoPlayer?.seek(timestamp: 0)
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
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: item?.table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: item?.table?.view)
        } else {
            removeNotificationListeners()
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        removeNotificationListeners()
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? AccountInfoItem {
            
            actionView.image = item.isSelected ? nil : theme.icons.generalNext
            actionView.sizeToFit()
            avatarView.setPeer(account: item.context.account, peer: item.peer)
            textView.update(isSelect ? item.activeTextlayout : item.textLayout)
            if !item.photos.isEmpty {
                if let first = item.photos.first, let video = first.image.videoRepresentations.last {
                    if self.photoVideoView == nil {
                        
                        self.photoVideoView = MediaPlayerView()
                        self.photoVideoView!.layer?.cornerRadius = self.avatarView.frame.height / 2
                        self.addSubview(self.photoVideoView!)
                        self.photoVideoView!.isEventLess = true
                        self.photoVideoView!.frame = self.avatarView.frame
                        
                        let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                        
                        let mediaPlayer = MediaPlayer(postbox: item.context.account.postbox, reference: MediaResourceReference.standalone(resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                        
                        mediaPlayer.actionAtEnd = .loop(nil)
                        
                        self.photoVideoPlayer = mediaPlayer
                        
                        mediaPlayer.play()
                        
                        if let seekTo = video.startTimestamp {
                            mediaPlayer.seek(timestamp: seekTo)
                        }
                        
                        mediaPlayer.attachPlayerView(self.photoVideoView!)
                        
                    } else {
                        self.photoVideoView?.removeFromSuperview()
                        self.photoVideoView = nil
                    }
                } else {
                    self.photoVideoView?.removeFromSuperview()
                    self.photoVideoView = nil
                }
            }
            needsDisplay = true
            needsLayout = true
        }
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
    }
    
    override func layout() {
        super.layout()
        avatarView.centerY(x:16)
        textView.centerY(x: avatarView.frame.maxX + 25)
        actionView.centerY(x: frame.width - actionView.frame.width - 10)
        photoVideoView?.frame = avatarView.frame
    }
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return avatarView
    }
    
    override func copy() -> Any {
        return avatarView.copy()
    }
    
}

