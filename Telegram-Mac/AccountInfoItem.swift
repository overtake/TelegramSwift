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
import Reactions
import SwiftSignalKit
import TelegramMedia


class AccountInfoItem: GeneralRowItem {
    
    fileprivate let textLayout: TextViewLayout
    fileprivate let activeTextlayout: TextViewLayout
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let titleActiveLayout: TextViewLayout

    fileprivate let context: AccountContext
    let peer: TelegramUser
    let storyStats: EngineStorySubscriptions.Item?
    private(set) var photos: [TelegramPeerPhoto] = []

    
    private let peerPhotosDisposable = MetaDisposable()
    
    let setStatus:(Control, TelegramUser)->Void
    
    let avatarStoryIndicator: AvatarStoryIndicatorComponent?
    let openStory:(StoryInitialIndex?)->Void
    init(_ initialSize:NSSize, stableId:AnyHashable, viewType: GeneralViewType, inset: NSEdgeInsets = NSEdgeInsets(left: 20, right: 20), context: AccountContext, peer: TelegramUser, storyStats: EngineStorySubscriptions.Item?, action: @escaping()->Void, setStatus: @escaping(Control, TelegramUser)->Void, openStory:@escaping(StoryInitialIndex?)->Void) {
        self.context = context
        self.peer = peer
        self.storyStats = storyStats
        self.setStatus = setStatus
        self.openStory = openStory
        let attr = NSMutableAttributedString()
        
        if let storyStats = storyStats, storyStats.storyCount > 0 {
            self.avatarStoryIndicator = .init(story: storyStats, presentation: theme)
        } else {
            self.avatarStoryIndicator = nil
        }
        
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
        
        self.photos = syncPeerPhotos(peerId: peer.id).map { $0.value }
        let signal = peerPhotos(context: context, peerId: peer.id) |> deliverOnMainQueue
        peerPhotosDisposable.set(signal.start(next: { [weak self] photos in
            self?.photos = photos.map { $0.value }
            self?.noteHeightOfRow()
        }))
        
    }
    
    func openPeerStory() {
        let table = self.table
        self.openStory(.init(peerId: peer.id, id: nil, messageId: nil, takeControl: { [weak table] peerId, _, storyId in
            var view: NSView?
            table?.enumerateItems(with: { item in
                if let item = item as? AccountInfoItem {
                    view = (item.view as? AccountInfoView)?.takeStoryControl()
                }
                return view == nil
            })
            return view
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
        
        self.titleLayout.measure(width: width - 140 - (hasControl ? 45 : 0))
        self.titleActiveLayout.measure(width: width - 140 - (hasControl ? 45 : 0))
        return success
    }
    
    override func viewClass() -> AnyClass {
        return AccountInfoView.self
    }
    
    var statusControl: Control? {
        return (self.view as? AccountInfoView)?.statusControl
    }
    
}

private class AccountInfoView : GeneralContainableRowView {
    
    
    private let avatarView:AvatarControl
    private let titleView = TextView()
    private let textView: TextView = TextView()
    private let actionView: ImageView = ImageView()
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?
    private var storyStateView: AvatarStoryIndicatorComponent.IndicatorView?

    private let container = View()
    private let avatarContainer = Control()
    
    fileprivate var statusControl: PremiumStatusControl?
    
    required init(frame frameRect: NSRect) {
        avatarView = AvatarControl(font: .avatar(22.0))
        avatarView.setFrameSize(NSMakeSize(60, 60))
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        avatarView.animated = true
        
        avatarContainer.scaleOnClick = true
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        avatarContainer.addSubview(avatarView)
        addSubview(avatarContainer)
        addSubview(actionView)
        
        container.addSubview(textView)
        container.addSubview(titleView)
        
        addSubview(container)
        avatarContainer.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem {
                if let stories = item.storyStats, stories.storyCount > 0 {
                    item.openPeerStory()
                } else if let _ = item.peer.largeProfileImage {
                    showPhotosGallery(context: item.context, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
                }
            }
        }, for: .Click)
        
        avatarContainer.contextMenu = { [weak self] in
            if let item = self?.item as? AccountInfoItem, let storyStats = item.storyStats, storyStats.storyCount > 0 {
                let menu = ContextMenu()
                menu.addItem(ContextMenuItem(strings().peerInfoContextOpenPhoto, handler: { [weak item] in
                    if let item = item {
                        if let _ = item.peer.largeProfileImage {
                            showPhotosGallery(context: item.context, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
                        }
                    }
                }, itemImage: MenuAnimation.menu_shared_media.value))
                return menu
            }
            return nil
        }
        
        self.avatarView.userInteractionEnabled = false
        
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
        playStatusDisposable.dispose()
        removeNotificationListeners()
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var videoRepresentation: TelegramMediaImage.VideoRepresentation?
    private let playStatusDisposable = MetaDisposable()
    
    private func playStatusEffect(_ status: PeerEmojiStatus, context: AccountContext) -> Void {
        
        
    }
    
    private func playAnimation(_  status: Reactions.InteractiveStatus, context: AccountContext) {
        guard let control = statusControl, visibleRect != .zero, window != nil else {
            return
        }
        guard let fileId = status.fileId else {
            return
        }
        
        control.isHidden = true
        
        let play:(NSView, TableRowItem)->Void = { [weak control] container, item in
            
            guard let control = control else {
                return
            }
            control.isHidden = false
            control.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3, bounce: true)
            let player = CustomReactionEffectView(frame: NSMakeSize(160, 160).bounds, context: context, fileId: fileId)
            
            player.isEventLess = true
            
            player.triggerOnFinish = { [weak player] in
                player?.removeFromSuperview()
            }
                    
            let controlRect = container.convert(control.frame, to: item.table?.contentView)
            
            let rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
            
            player.frame = rect
            
            item.table?.contentView.addSubview(player)
        }
        if let item = self.item {
            if let fromRect = status.rect {
                let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: control.frame.size)
                
                let toRect = control.convert(control.frame.size.bounds, to: nil)
                
                let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
                let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
                
                let completed: (Bool)->Void = { [weak self] _ in
                    DispatchQueue.main.async {
                        if let item = self?.item, let container = self?.container {
                            play(container, item)
                            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                        }
                    }
                }
                parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
            } else {
                play(self.container, item)
            }
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? AccountInfoItem {
            
            var interactiveStatus: Reactions.InteractiveStatus? = nil
            if visibleRect != .zero, window != nil, let interactive = item.context.reactions.interactiveStatus, !item.context.isLite(.emoji_effects) {
                interactiveStatus = interactive
            }
            if let view = self.statusControl, interactiveStatus != nil, interactiveStatus?.fileId != nil {
                performSubviewRemoval(view, animated: animated, duration: 0.3)
                self.statusControl = nil
            }
            
            let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: item.isSelected, isBig: true, cached: self.statusControl, animated: animated)
                        
            if let control = control {
                self.statusControl = control
                self.container.addSubview(control)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: animated)
                self.statusControl = nil
            }
            if let interactive = interactiveStatus {
                self.playAnimation(interactive, context: item.context)
            }
            
            if let control = statusControl, item.peer.isPremium {
                control.removeAllHandlers()
                control.userInteractionEnabled = true
                control.set(handler: { [weak item] control in
                    if let user = item?.peer {
                        item?.setStatus(control, user)
                    }
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
                        avatarContainer.addSubview(self.photoVideoView!)
                        self.photoVideoView!.isEventLess = true
                        self.photoVideoView!.frame = self.avatarView.frame
                        
                        let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                        
                        let mediaPlayer = MediaPlayer(postbox: item.context.account.postbox, userLocation: .peer(item.context.peerId), userContentType: .avatar, reference: MediaResourceReference.standalone(resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                        
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
            
            if let component = item.avatarStoryIndicator {
                let current: AvatarStoryIndicatorComponent.IndicatorView
                let isNew: Bool
                if let view = self.storyStateView {
                    current = view
                    isNew = false
                } else {
                    current = AvatarStoryIndicatorComponent.IndicatorView(frame: NSMakeRect(0, 0, 60, 60))
                    self.storyStateView = current
                    avatarContainer.addSubview(current)
                    isNew = true
                }
                current.update(component: component, availableSize: NSMakeSize(54, 54), transition: .immediate)
                
                if animated, isNew {
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                self.avatarView._change(size: NSMakeSize(54, 54), animated: animated)
                self.photoVideoView?._change(size: NSMakeSize(54, 54), animated: animated)
                                
                
                if let photoVideoView = photoVideoView {
                    photoVideoView.layer?.cornerRadius = photoVideoView.frame.height / 2
                }
                
                self.avatarView._change(pos: NSMakePoint(3, 3), animated: animated)
                self.photoVideoView?._change(pos: NSMakePoint(3, 3), animated: animated)


            } else if let view = self.storyStateView {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.storyStateView = nil
                
                self.avatarView._change(size: NSMakeSize(60, 60), animated: animated)
                self.photoVideoView?._change(size: NSMakeSize(60, 60), animated: animated)
                
                self.avatarView._change(pos: .zero, animated: animated)
                self.photoVideoView?._change(pos: .zero, animated: animated)

                
                if let photoVideoView = photoVideoView {
                    photoVideoView.layer?.cornerRadius = photoVideoView.frame.height / 2
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
        avatarContainer.setFrameSize(NSMakeSize(60, 60))
        avatarContainer.centerY(x:16)
        
        let h: CGFloat = statusControl != nil ? 6 : 0
        
        container.setFrameSize(NSMakeSize(max(titleView.frame.width, textView.frame.width + (statusControl != nil ? 40 : 0)), titleView.frame.height + textView.frame.height + 2 + h))
        
        titleView.setFrameOrigin(0, h)
        textView.setFrameOrigin(0, titleView.frame.maxY + 2)
        
        container.centerY(x: avatarView.frame.maxX + 25)
        
        if let statusControl = statusControl {
            statusControl.setFrameOrigin(titleView.frame.maxX + 3, 3)
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
    
    
    func takeStoryControl() -> NSView? {
        return self.avatarView
    }
    
}

