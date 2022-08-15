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

import SwiftSignalKit



class AccountInfoItem: GeneralRowItem {
    
    fileprivate let textLayout: TextViewLayout
    fileprivate let activeTextlayout: TextViewLayout
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let titleActiveLayout: TextViewLayout

    fileprivate let context: AccountContext
    fileprivate let peer: TelegramUser
    private(set) var photos: [TelegramPeerPhoto] = []

    private let peerPhotosDisposable = MetaDisposable()
    
    let setStatus:(Control)->Void
    
    init(_ initialSize:NSSize, stableId:AnyHashable, viewType: GeneralViewType, inset: NSEdgeInsets = NSEdgeInsets(left: 30, right: 30), context: AccountContext, peer: TelegramUser, action: @escaping()->Void, setStatus: @escaping(Control)->Void) {
        self.context = context
        self.peer = peer
        self.setStatus = setStatus
        
        let attr = NSMutableAttributedString()
        
        
        let titleAttr: NSMutableAttributedString = NSMutableAttributedString()
        _ = titleAttr.append(string: peer.displayTitle, color: theme.colors.text, font: .medium(.title))
        self.titleLayout = .init(titleAttr, maximumNumberOfLines: 1)
        let activeTitle = titleAttr.mutableCopy() as! NSMutableAttributedString
        activeTitle.addAttribute(.foregroundColor, value: theme.colors.underSelectedColor, range: titleAttr.range)
        self.titleActiveLayout = .init(activeTitle, maximumNumberOfLines: 1)

        if let phone = peer.phone {
            _ = attr.append(string: formatPhoneNumber(phone), color: theme.colors.grayText, font: .normal(.text))
        }
        if let username = peer.username, !username.isEmpty {
            if !attr.string.isEmpty {
                _ = attr.append(string: "\n")
            }
            _ = attr.append(string: "@\(username)", color: theme.colors.grayText, font: .normal(.text))
        }
        
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 4)
        
        let active = attr.mutableCopy() as! NSMutableAttributedString
        active.addAttribute(.foregroundColor, value: theme.colors.underSelectedColor, range: active.range)
        activeTextlayout = TextViewLayout(active, maximumNumberOfLines: 4)
        super.init(initialSize, height: 90, stableId: stableId, viewType: viewType, action: action, inset: inset)
        
        self.photos = syncPeerPhotos(peerId: peer.id)
        let signal = peerPhotos(context: context, peerId: peer.id, force: true) |> deliverOnMainQueue
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
        textLayout.measure(width: width - 140)
        activeTextlayout.measure(width: width - 140)
        
        let hasControl = PremiumStatusControl.hasControl(peer)
        
        self.titleLayout.measure(width: width - 140 - (hasControl ? 35 : 0))
        self.titleActiveLayout.measure(width: width - 140 - (hasControl ? 35 : 0))
        return success
    }
    
    override func viewClass() -> AnyClass {
        return AccountInfoView.self
    }
    
}

private class AccountInfoView : GeneralContainableRowView {
    
    
    private let avatarView:AvatarControl
    private let titleView = TextView()
    private let textView: TextView = TextView()
    private let actionView: ImageView = ImageView()
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?

    private let container = View()
    
    private var statusControl: PremiumStatusControl?
    
    required init(frame frameRect: NSRect) {
        avatarView = AvatarControl(font: .avatar(22.0))
        avatarView.setFrameSize(NSMakeSize(60, 60))
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        avatarView.animated = true
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        addSubview(avatarView)
        addSubview(actionView)
        
        container.addSubview(textView)
        container.addSubview(titleView)
        
        addSubview(container)
        avatarView.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem, let _ = item.peer.largeProfileImage {
                showPhotosGallery(context: item.context, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        
        self.containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
        
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
        playStatusDisposable.dispose()
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var videoRepresentation: TelegramMediaImage.VideoRepresentation?
    private let playStatusDisposable = MetaDisposable()
    
    private func playStatusEffect(_ status: PeerEmojiStatus, context: AccountContext) -> Void {
        
        let animationSize = NSMakeSize(90, 90)
        
//        let reaction: Signal<AvailableReactions.Reaction?, NoError> = context.inlinePacksContext.load(fileId: status.fileId) |> mapToSignal { file in
//            return context.reactions.stateValue |> take(1) |> map { value in
//                let found = value?.reactions.first(where: {
//                    $0.value.fixed == file?.customEmojiText?.fixed
//                })
//                return found
//            }
//        }
//        let signal: Signal<LottieAnimation?, NoError> = reaction
//        |> filter { $0 != nil}
//        |> map {
//            $0!
//        } |> mapToSignal { reaction -> Signal<MediaResourceData, NoError> in
//            if let file = reaction.aroundAnimation {
//                return context.account.postbox.mediaBox.resourceData(file.resource)
//                |> filter { $0.complete }
//                |> take(1)
//            } else {
//                return .complete()
//            }
//        } |> map { data in
//            if let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
//                return LottieAnimation(compressed: data, key: .init(key: .bundle("_status_effect_new_\(status.fileId)"), size: animationSize, backingScale: Int(System.backingScale), mirror: false), cachePurpose: .temporaryLZ4(.effect), playPolicy: .onceEnd)
//            } else {
//                return nil
//            }
//        } |> deliverOnMainQueue
//        
//        playStatusDisposable.set(signal.start(next: { [weak self] animation in
//            if let animation = animation {
//                self?.playAnimation(animation)
//            }
//        }))
    }
    
    private func playAnimation(_ animation: LottieAnimation) {
        guard let control = statusControl else {
            return
        }
        let player = LottiePlayerView(frame: animation.size.bounds)
        
        player.isEventLess = true
        
        animation.triggerOn = (LottiePlayerTriggerFrame.last, { [weak player] in
            player?.removeFromSuperview()
        }, {})
        
        player.set(animation)
        
        let controlRect = container.convert(control.frame, to: item?.table?.contentView)
        
        let rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
        
        player.frame = rect
        
        item?.table?.contentView.addSubview(player)
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let previous = self.item as? AccountInfoItem
        
        
        super.set(item: item)
        
        if let item = item as? AccountInfoItem {
            
            
            let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: item.isSelected, isBig: true, cached: self.statusControl, animated: animated, force: true)
            if let control = control {
                self.statusControl = control
                self.container.addSubview(control)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: animated)
                self.statusControl = nil
            }
            
            if previous?.peer.emojiStatus != item.peer.emojiStatus, let status = item.peer.emojiStatus {
                self.playStatusEffect(status, context: item.context)
            }
            
            if let control = statusControl, item.peer.isPremium {
                control.removeAllHandlers()
                control.userInteractionEnabled = true
                control.set(handler: { [weak item] control in
                    item?.setStatus(control)
                }, for: .Click)
            } else if let control = statusControl {
                control.removeAllHandlers()
                control.userInteractionEnabled = false
            }
        
            
            titleView.update(isSelect ? item.titleActiveLayout : item.titleLayout)
            
            actionView.image = item.isSelected ? nil : theme.icons.generalNext
            actionView.sizeToFit()
            avatarView.setPeer(account: item.context.account, peer: item.peer)
            textView.update(isSelect ? item.activeTextlayout : item.textLayout)
            if !item.photos.isEmpty {
                if let first = item.photos.first, let video = first.image.videoRepresentations.last {
                    let equal = videoRepresentation?.resource.id == video.resource.id
                    if !equal {
                        
                        self.photoVideoView?.removeFromSuperview()
                        self.photoVideoView = nil
                        
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
                        self.videoRepresentation = video
                        updatePlayerIfNeeded()
                    } 
                } else {
                    self.photoVideoPlayer = nil
                    self.photoVideoView?.removeFromSuperview()
                    self.photoVideoView = nil
                }
            } else {
                self.photoVideoPlayer = nil
                self.photoVideoView?.removeFromSuperview()
                self.photoVideoView = nil
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
        
        
        container.setFrameSize(NSMakeSize(max(titleView.frame.width, textView.frame.width + (statusControl != nil ? 35 : 0)), titleView.frame.height + textView.frame.height + 2))
        
        titleView.setFrameOrigin(0, 0)
        textView.setFrameOrigin(0, titleView.frame.maxY + 2)
        
        container.centerY(x: avatarView.frame.maxX + 25)
        
        if let statusControl = statusControl {
            statusControl.setFrameOrigin(titleView.frame.maxX + 3, 0)
        }
        
        actionView.centerY(x: containerView.frame.width - actionView.frame.width - 15)
        photoVideoView?.frame = avatarView.frame
    }
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return avatarView
    }
    
    override func copy() -> Any {
        return avatarView.copy()
    }
    
}

