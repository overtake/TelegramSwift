//
//  TGDialogRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

private class ChatListDraggingContainerView : View {
    fileprivate var item: ChatListRowItem?
    fileprivate var activeDragging:Bool = false
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.tiff, .string, .kUrl, .kFileUrl])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if activeDragging {
            activeDragging = false
            needsDisplay = true
            if let tiff = sender.draggingPasteboard.data(forType: .tiff), let image = NSImage(data: tiff) {
                _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak item] path in
                    guard let item = item else {return}
                    item.account.context.mainNavigation?.push(ChatController(account: item.account, chatLocation: .peer(item.peerId), initialAction: .files(list: [path], behavior: .automatic)))
                })
            } else {
                let list = sender.draggingPasteboard.propertyList(forType: .kFilenames) as? [String]
                if let item = item, let context = item.account.applicationContext as? TelegramApplicationContext, let list = list {
                    let list = list.filter { path -> Bool in
                        if let size = fs(path) {
                            return size <= 1500 * 1024 * 1024
                        }
                        return false
                    }
                    if !list.isEmpty {
                        context.mainNavigation?.push(ChatController(account: item.account, chatLocation: .peer(item.peerId), initialAction: .files(list: list, behavior: .automatic)))
                    }
                }
            }
            
            
            return true
        }
        return false
    }
    
    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let item = item, let peer = item.peer, peer.canSendMessage, mouseInside() {
            activeDragging = true
            needsDisplay = true
        }
        superview?.draggingEntered(sender)
        return .generic
        
    }
    
    override public func draggingExited(_ sender: NSDraggingInfo?) {
        activeDragging = false
        needsDisplay = true
        superview?.draggingExited(sender)
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo) {
        activeDragging = false
        needsDisplay = true
        superview?.draggingEnded(sender)
    }
}

class ChatListRowView: TableRowView, ViewDisplayDelegate, SwipingTableView {
    
    private let swipingLeftView: View = View()
    private let swipingRightView: View = View()
    
    private var titleText:TextNode = TextNode()
    private var messageText:TextNode = TextNode()
    private var badgeView:View?
    private var activitiesModel:ChatActivitiesModel?
    private var photo:AvatarControl = AvatarControl(font: .avatar(22))
    private var hiddemMessage:Bool = false
    private let peerInputActivitiesDisposable:MetaDisposable = MetaDisposable()
    private var removeControl:ImageButton? = nil
    private var animatedView: ChatRowAnimateView?
    private let containerView: ChatListDraggingContainerView = ChatListDraggingContainerView(frame: NSZeroRect)
    var endSwipingState: SwipeDirection? {
        didSet {
            if let oldValue = oldValue, endSwipingState == nil  {
                switch oldValue {
                case .left, .right:
                    completeSwiping(direction: .none)
                default:
                    break
                }
            }
        }
    }
    override var isFlipped: Bool {
        return true
    }
    
    /*
     let theme:ChatActivitiesTheme
     if item.isSelected && item.account.context.layout != .single {
     theme = ChatActivitiesWhiteTheme()
     } else if item.isSelected || item.isPinned {
     theme = ChatActivitiesTheme(backgroundColor: .grayUI)
     } else if contextMenu != nil {
     theme = ChatActivitiesTheme(backgroundColor: .grayBackground)
     } else {
     theme = ChatActivitiesBlueTheme()
     }

 */
    
    var inputActivities:(PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let inputActivities = inputActivities, let item = item as? ChatListRowItem {
                
                if inputActivities.1.isEmpty {
                    activitiesModel?.clean()
                    activitiesModel?.view?.removeFromSuperview()
                    activitiesModel = nil
                    self.needsLayout = true
                    self.hiddemMessage = false
                    containerView.needsDisplay = true
                } else if activitiesModel == nil {
                    activitiesModel = ChatActivitiesModel()
                    containerView.addSubview(activitiesModel!.view!)
                }
                
                let activity:ActivitiesTheme
                if item.isSelected && item.account.context.layout != .single {
                    activity = theme.activity(key: 10 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activitySelectedColor, backgroundColor: theme.chatList.selectedBackgroundColor)
                } else if item.isSelected {
                    activity = theme.activity(key: 11 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityPinnedColor, backgroundColor: theme.chatList.singleLayoutSelectedBackgroundColor)
                } else if item.pinnedType != .none {
                    activity = theme.activity(key: 12 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityPinnedColor, backgroundColor: theme.chatList.pinnedBackgroundColor)
                } else if contextMenu != nil {
                    activity = theme.activity(key: 13 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityContextMenuColor, backgroundColor: theme.chatList.contextMenuBackgroundColor)
                } else {
                    activity = theme.activity(key: 14 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityColor, backgroundColor: theme.colors.background)
                }
                
                activitiesModel?.update(with: inputActivities, for: item.messageWidth, theme:  activity, layout: { [weak self] show in
                    self?.needsLayout = true
                    self?.hiddemMessage = show
                    self?.containerView.needsDisplay = true
                })
                
                activitiesModel?.view?.isHidden = item.account.context.layout == .minimisize
            } else {
                activitiesModel?.clean()
                activitiesModel?.view?.removeFromSuperview()
                activitiesModel = nil
            }
        }
    }
    
    override func onShowContextMenu() {
        super.onShowContextMenu()
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
    }
    
    override func onCloseContextMenu() {
        super.onCloseContextMenu()
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
    }
    
    
    override func focusAnimation(_ innerId: AnyHashable?) {
        
        if animatedView == nil {
            self.animatedView = ChatRowAnimateView(frame:bounds)
            self.animatedView?.isEventLess = true
            containerView.addSubview(animatedView!)
            animatedView?.backgroundColor = NSColor(0x68A8E2)
            animatedView?.layer?.opacity = 0
            
        }
        animatedView?.stableId = item?.stableId
        
        
        let animation: CABasicAnimation = makeSpringAnimation("opacity")
        
        animation.fromValue = animatedView?.layer?.presentation()?.opacity ?? 0
        animation.toValue = 0.5
        animation.autoreverses = true
        animation.isRemovedOnCompletion = true
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
            if completed {
                self?.animatedView?.removeFromSuperview()
                self?.animatedView = nil
            }
        })
        animation.isAdditive = false
        
        animatedView?.layer?.add(animation, forKey: "opacity")
        
    }
    
    override var backdorColor: NSColor {
        if let item = item as? ChatListRowItem {
            if item.isHighlighted && !item.isSelected {
                return theme.colors.grayForeground
            }
            if item.account.context.layout == .single, item.isSelected {
                return theme.chatList.singleLayoutSelectedBackgroundColor
            }
            if !item.isSelected && containerView.activeDragging {
                return theme.chatList.activeDraggingBackgroundColor
            }
            if item.pinnedType != .none && !item.isSelected {
                return theme.chatList.pinnedBackgroundColor
            }
            return item.isSelected ? theme.chatList.selectedBackgroundColor : contextMenu != nil ? theme.chatList.contextMenuBackgroundColor : theme.colors.background
        }
        return theme.colors.background
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
       // ctx.setFillColor(theme.colors.background.cgColor)
       // ctx.fill(bounds)
        super.draw(layer, in: ctx)
//
         if let item = self.item as? ChatListRowItem {
            
           
            
            if !item.isSelected {
                
                if layer != containerView.layer {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
                } else {
                    
                    if let context = item.account.applicationContext as? TelegramApplicationContext {
                        if context.layout == .minimisize {
                            return
                        }
                    }
                    
                    if backingScaleFactor == 1.0 {
                        ctx.setFillColor(backdorColor.cgColor)
                        ctx.fill(layer.bounds)
                    }
                    
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.pinnedType == .last ? 0 : item.leftInset, NSHeight(layer.bounds) - .borderSize, item.pinnedType == .last ? layer.frame.width : layer.bounds.width - item.leftInset, .borderSize))
                }
            }
            
            if let context = item.account.applicationContext as? TelegramApplicationContext {
                if context.layout == .minimisize {
                    return
                }
            }
            
            if layer == containerView.layer {
                
                let highlighted = item.isSelected && item.account.context.layout != .single
                
                
                if item.ctxBadgeNode == nil && (item.pinnedType == .some || item.pinnedType == .last) {
                    ctx.draw(highlighted ? theme.icons.pinnedImageSelected : theme.icons.pinnedImage, in: NSMakeRect(frame.width - theme.icons.pinnedImage.backingSize.width - item.margin, frame.height - theme.icons.pinnedImage.backingSize.height - item.margin + 1, theme.icons.pinnedImage.backingSize.width, theme.icons.pinnedImage.backingSize.height))
                }
                
                if let displayLayout = item.ctxDisplayLayout {
                    
                    var addition:CGFloat = 0
                    if item.isSecret {
                        ctx.draw(item.isSelected ? theme.icons.secretImageSelected : theme.icons.secretImage, in: NSMakeRect(item.leftInset, item.margin + 3, theme.icons.secretImage.backingSize.width, theme.icons.secretImage.backingSize.height))
                        addition += theme.icons.secretImage.backingSize.height
                        
                    }
                    displayLayout.1.draw(NSMakeRect(item.leftInset + addition, item.margin - 1, displayLayout.0.size.width, displayLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    
                    
                    var mutedInset:CGFloat = item.isSecret ? theme.icons.secretImage.backingSize.width + 2 : 0
                    
                    if item.isVerified {
                        ctx.draw(highlighted ? theme.icons.verifiedImageSelected : theme.icons.verifiedImage, in: NSMakeRect(displayLayout.0.size.width + item.leftInset + addition + 2, item.margin + 1, theme.icons.verifiedImage.backingSize.width, theme.icons.verifiedImage.backingSize.height))
                        mutedInset += theme.icons.verifiedImage.backingSize.width + 3
                    }
                    
                    if let messageLayout = item.ctxMessageLayout, !hiddemMessage {
                        messageLayout.1.draw(NSMakeRect(item.leftInset, displayLayout.0.size.height + item.margin + 1 , messageLayout.0.size.width, messageLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    }
                    
                    if item.isMuted {
                        ctx.draw(highlighted ? theme.icons.dialogMuteImageSelected : theme.icons.dialogMuteImage, in: NSMakeRect(item.leftInset + displayLayout.0.size.width + 4 + mutedInset, item.margin + round((displayLayout.0.size.height - theme.icons.dialogMuteImage.backingSize.height) / 2.0) - 1, theme.icons.dialogMuteImage.backingSize.width, theme.icons.dialogMuteImage.backingSize.height))
                    }
                    
                    if let _ = item.mentionsCount {
                        ctx.draw(highlighted ? theme.icons.chatListMentionActive : theme.icons.chatListMention, in: NSMakeRect(frame.width - (item.ctxBadgeNode != nil ? item.ctxBadgeNode!.size.width + item.margin : 0) - theme.icons.chatListMentionActive.backingSize.width - item.margin, frame.height - theme.icons.chatListMention.backingSize.height - item.margin + 1, theme.icons.chatListMention.backingSize.width, theme.icons.chatListMention.backingSize.height))
                    }
                    
                    if let dateLayout = item.ctxDateLayout, !item.hasDraft, item.state == .plain {
                        let dateX = frame.width - dateLayout.0.size.width - item.margin
                        dateLayout.1.draw(NSMakeRect(dateX, item.margin, dateLayout.0.size.width, dateLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        
                        if !item.isFailed {
                            if item.isSending {
                                let outX = dateX - theme.icons.sendingImage.backingSize.width - 4
                                ctx.draw(highlighted ? theme.icons.sendingImageSelected : theme.icons.sendingImage, in: NSMakeRect(outX,item.margin + 2, theme.icons.sendingImage.backingSize.width, theme.icons.sendingImage.backingSize.height))
                            } else {
                                if item.isOutMessage {
                                    let outX = dateX - theme.icons.outgoingMessageImage.backingSize.width - (item.isRead ? 4.0 : 0.0) - 2
                                    ctx.draw(highlighted ? theme.icons.outgoingMessageImageSelected : theme.icons.outgoingMessageImage, in: NSMakeRect(outX, item.margin + 2, theme.icons.outgoingMessageImage.backingSize.width, theme.icons.outgoingMessageImage.backingSize.height))
                                    if item.isRead {
                                        ctx.draw(highlighted ? theme.icons.readMessageImageSelected : theme.icons.readMessageImage, in: NSMakeRect(outX + 4, item.margin + 2, theme.icons.readMessageImage.backingSize.width, theme.icons.readMessageImage.backingSize.height))
                                    }
                                }
                            }
                        } else {
                            let outX = dateX - theme.icons.errorImageSelected.backingSize.width - 4
                            ctx.draw(highlighted ? theme.icons.errorImageSelected : theme.icons.errorImage, in: NSMakeRect(outX,item.margin, theme.icons.errorImage.backingSize.width, theme.icons.errorImage.backingSize.height))
                        }
                        
                    }
                }
            }
        }
 
    }
    


    required init(frame frameRect: NSRect) {
       
        
        super.init(frame: frameRect)
        
        addSubview(swipingRightView)
        addSubview(swipingLeftView)
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        photo.userInteractionEnabled = false
        photo.frame = NSMakeRect(10, 8, 50, 50)
        containerView.addSubview(photo)
        addSubview(containerView)
        
        containerView.displayDelegate = self
        containerView.frame = bounds
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        needsDisplay = true
        updateColors()
        return .generic
        
    }
    
    override public func draggingExited(_ sender: NSDraggingInfo?) {
        needsDisplay = true
        updateColors()
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo) {
        needsDisplay = true
        updateColors()
    }

    override func updateColors() {
        super.updateColors()
    }

    override func set(item:TableRowItem, animated:Bool = false) {
        
        
         super.set(item:item, animated:animated)
                
         if let item = self.item as? ChatListRowItem {
            containerView.item = item
            if self.animatedView != nil && self.animatedView?.stableId != item.stableId {
                self.animatedView?.removeFromSuperview()
                self.animatedView = nil
            }
            
            
            photo.setState(account: item.account, state: item.photo)

            if item.isSavedMessage {
                let icon = theme.icons.searchSaved
                photo.setSignal(generateEmptyPhoto(photo.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photo.frame.size.width - 20, photo.frame.size.height - 20)))) |> map {($0, false)})
            } 
            if let badgeNode = item.ctxBadgeNode {
                if badgeView == nil {
                    badgeView = View()
                    containerView.addSubview(badgeView!)
                }
                badgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = badgeView
                badgeNode.setNeedDisplay()
            } else {
                badgeView?.removeFromSuperview()
                badgeView = nil
            }

            switch item.state {
            case .plain:
                if let removeControl = removeControl {
                    removeControl.change(pos: NSMakePoint(frame.width, removeControl.frame.minY), animated: animated, completion: { [weak self] completed in
                        if completed {
                            self?.removeControl?.removeFromSuperview()
                            self?.removeControl = nil
                        }
                    })
                    removeControl.change(opacity: 0, animated: animated)
                }
                
            case let .deletable(onRemove, _):
                var isNew: Bool = false
                if removeControl == nil {
                    removeControl = ImageButton()
                    removeControl?.autohighlight = false
                    removeControl?.set(image: theme.icons.deleteItem, for: .Normal)
                    removeControl?.frame = NSMakeRect(frame.width, 0, 60, frame.height)
                    removeControl?.layer?.opacity = 0
                    containerView.addSubview(removeControl!)
                    isNew = true
                }
                guard let removeControl = removeControl else {return}
                removeControl.removeAllHandlers()
                removeControl.set(handler: { [weak item] _ in
                    if let location = item?.chatLocation {
                        onRemove(location)
                    }
                }, for: .Click)
                let f = focus(removeControl.frame.size)
                removeControl.change(pos: NSMakePoint(frame.width - removeControl.frame.width, f.minY), animated: isNew && animated)
                removeControl.change(opacity: 1, animated: isNew && animated)
                
            }
            
            if !(item is ChatListMessageRowItem) {
                let postbox = item.account.postbox
                let peerId = item.peerId
                
                let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
                self.peerInputActivitiesDisposable.set((item.account.peerInputActivities(peerId: peerId)
                    |> mapToSignal { activities -> Signal<[(Peer, PeerInputActivity)], NoError> in
                        var foundAllPeers = true
                        var cachedResult: [(Peer, PeerInputActivity)] = []
                        previousPeerCache.with { dict -> Void in
                            for (peerId, activity) in activities {
                                if let peer = dict[peerId] {
                                    cachedResult.append((peer, activity))
                                } else {
                                    foundAllPeers = false
                                    break
                                }
                            }
                        }
                        if foundAllPeers {
                            return .single(cachedResult)
                        } else {
                            return postbox.transaction { transaction -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let peer = transaction.getPeer(peerId) {
                                        result.append((peer, activity))
                                        peerCache[peerId] = peer
                                    }
                                }
                                _ = previousPeerCache.swap(peerCache)
                                return result
                            }
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self, weak item] activities in
                        if item?.account.peerId != item?.peerId {
                            self?.inputActivities = (peerId, activities)
                        } else {
                            self?.inputActivities = (peerId, [])
                        }
                    }))
                
                let inputActivities = self.inputActivities
                self.inputActivities = inputActivities
                
                
            }
            
            
         }
        
        if let _ = endSwipingState {
            initSwipingState()
        }
        
        containerView.needsDisplay = true
        needsDisplay = true
    }
    
    func initSwipingState() {
        guard let item = item as? ChatListRowItem else {return}
        
        swipingLeftView.removeAllSubviews()
        swipingRightView.removeAllSubviews()
        
        
        let unread: TitleButton = TitleButton()
        unread.setFrameSize(frame.height, frame.height)
        unread.autohighlight = false
        unread.direction = .top
        
        swipingLeftView.addSubview(unread)
        
        unread.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChatListRowItem else {return}
            item.toggleUnread()
            self?.endSwipingState = nil
        }, for: .Click)
        
        
        let pin: TitleButton = TitleButton()
        let mute: TitleButton = TitleButton()
        let delete: TitleButton = TitleButton()
        
      
        
        pin.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChatListRowItem else {return}
            item.togglePinned()
            self?.endSwipingState = nil
        }, for: .Click)
        
        mute.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChatListRowItem else {return}
            item.toggleMuted()
            self?.endSwipingState = nil
        }, for: .Click)
        
        delete.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChatListRowItem else {return}
            item.delete()
            self?.endSwipingState = nil
        }, for: .Click)
        
        
        pin.autohighlight = false
        mute.autohighlight = false
        delete.autohighlight = false
        
        pin.direction = .top
        mute.direction = .top
        delete.direction = .top
        
        swipingRightView.addSubview(pin)
        swipingRightView.addSubview(mute)
        swipingRightView.addSubview(delete)
        

        
        swipingLeftView.backgroundColor = item.markAsUnread ? theme.chatList.badgeBackgroundColor : theme.colors.grayForeground
        swipingRightView.backgroundColor = theme.colors.redUI
        
        pin.setFrameSize(frame.height, frame.height)
        mute.setFrameSize(frame.height, frame.height)
        delete.setFrameSize(frame.height, frame.height)
        
        mute.setFrameOrigin(pin.frame.maxX, 0)
        delete.setFrameOrigin(mute.frame.maxX, 0)
        
        
        swipingRightView.setFrameSize(rightSwipingWidth, frame.height)
        swipingLeftView.setFrameSize(leftSwipingWidth, frame.height)

        unread.set(color: .white, for: .Normal)
        unread.set(font: .normal(.text), for: .Normal)
        unread.set(text: !item.markAsUnread ? L10n.chatListSwipingRead : L10n.chatListSwipingUnread, for: .Normal)
        unread.set(image: !item.markAsUnread ? theme.icons.chatSwiping_read : theme.icons.chatSwiping_unread, for: .Normal)
        unread.set(background: item.markAsUnread ? theme.chatList.badgeBackgroundColor : theme.colors.grayForeground, for: .Normal)
        _ = unread.sizeToFit(NSZeroSize, NSMakeSize(frame.height, frame.height), thatFit: true)
        
        
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        
        theme.colors.grayForeground.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let pinUnpin = NSColor(hue: hue, saturation: saturation, brightness: brightness * 0.93, alpha: 1.0)
        
        pin.set(color: .white, for: .Normal)
        pin.set(font: .normal(.text), for: .Normal)
        pin.set(text: item.pinnedType == .none ? L10n.chatListSwipingPin : L10n.chatListSwipingUnpin, for: .Normal)
        pin.set(image: item.pinnedType == .none ? theme.icons.chatSwiping_pin : theme.icons.chatSwiping_unpin, for: .Normal)
        pin.set(background: pinUnpin, for: .Normal)
        _ = pin.sizeToFit(NSZeroSize, NSMakeSize(frame.height, frame.height), thatFit: true)
        
        
       
        theme.colors.grayForeground.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let muteUnmute = NSColor(hue: hue, saturation: saturation, brightness: brightness * 0.86, alpha: 1.0)
        
        mute.set(color: .white, for: .Normal)
        mute.set(font: .normal(.text), for: .Normal)
        mute.set(text: item.isMuted ? L10n.chatListSwipingUnmute : L10n.chatListSwipingMute, for: .Normal)
        mute.set(image: item.isMuted ? theme.icons.chatSwiping_unmute : theme.icons.chatSwiping_mute, for: .Normal)
        mute.set(background: muteUnmute, for: .Normal)
        _ = mute.sizeToFit(NSZeroSize, NSMakeSize(frame.height, frame.height), thatFit: true)

        
        
        delete.set(color: .white, for: .Normal)
        delete.set(font: .normal(.text), for: .Normal)
        delete.set(text: L10n.chatListSwipingDelete, for: .Normal)
        delete.set(image: theme.icons.chatSwiping_delete, for: .Normal)
        delete.set(background: theme.colors.redUI, for: .Normal)
        _ = delete.sizeToFit(NSZeroSize, NSMakeSize(frame.height, frame.height), thatFit: true)
        

    }
    
    var additionalSwipingDelta: CGFloat {
        let additionalDelta: CGFloat
        if let state = endSwipingState {
            switch state {
            case .left:
                additionalDelta = -leftSwipingWidth
            case .right:
                additionalDelta = rightSwipingWidth
            case .none:
                additionalDelta = 0
            }
        } else {
            additionalDelta = 0
        }
        return additionalDelta
    }
    
    var containerX: CGFloat {
        return containerView.frame.minX
    }
    
    var width: CGFloat {
        return containerView.frame.width
    }

    var rightSwipingWidth: CGFloat {
        return swipingRightView.subviewsSize.width
    }
    
    var leftSwipingWidth: CGFloat {
        return swipingLeftView.subviewsSize.width
    }
    
    private var animateOnceAfterDelta: Bool = true
    func moveSwiping(delta: CGFloat) {
        
        if swipingLeftView.subviews.isEmpty || swipingRightView.subviews.isEmpty {
            initSwipingState()
        }
      
        let delta = delta// - additionalSwipingDelta
        
        
        containerView.change(pos: NSMakePoint(delta, containerView.frame.minY), animated: false)
        swipingLeftView.change(pos: NSMakePoint(min(-frame.height + delta, 0), swipingLeftView.frame.minY), animated: false)
        swipingRightView.change(pos: NSMakePoint(frame.width + delta, swipingRightView.frame.minY), animated: false)
        
        
        swipingLeftView.change(size: NSMakeSize(max(leftSwipingWidth, delta), swipingLeftView.frame.height), animated: false)
        
        swipingRightView.change(size: NSMakeSize(max(rightSwipingWidth, abs(delta)), swipingRightView.frame.height), animated: false)

        
        if delta > 0 {
            let action = swipingLeftView.subviews[0]
            if delta > frame.width / 2 {
                
                if animateOnceAfterDelta {
                    animateOnceAfterDelta = false
                    action.layer?.animatePosition(from: NSMakePoint(-(swipingLeftView.frame.width - action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                }
                action.setFrameOrigin(NSMakePoint((swipingLeftView.frame.width - action.frame.width), action.frame.minY))
            } else {
                if !animateOnceAfterDelta {
                    animateOnceAfterDelta = true
                    action.layer?.animatePosition(from: NSMakePoint((swipingLeftView.frame.width - action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                }
                action.setFrameOrigin(NSMakePoint(0, action.frame.minY))
                
            }
        }
        
      
        
        
        var rightPercent: CGFloat = delta / rightSwipingWidth
        if rightPercent < 0 {
            rightPercent = 1 - min(1, abs(rightPercent))
            let subviews = swipingRightView.subviews
            subviews[0].setFrameOrigin(0, 0)
            subviews[1].setFrameOrigin(subviews[0].frame.width - subviews[1].frame.width * rightPercent, 0)
            
            let action = subviews[2]
            
            if rightPercent == 0 , delta < 0 {
                if delta + subviews[1].frame.maxX < -frame.midX {
                    if animateOnceAfterDelta {
                        animateOnceAfterDelta = false
                        action.layer?.animatePosition(from: NSMakePoint((swipingRightView.frame.width - rightSwipingWidth), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                    }
                    action.setFrameOrigin(NSMakePoint(subviews[1].frame.maxX, action.frame.minY))
                } else {
                    if !animateOnceAfterDelta {
                        animateOnceAfterDelta = true
                        action.layer?.animatePosition(from: NSMakePoint(-(swipingRightView.frame.width - rightSwipingWidth), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                    }
                    action.setFrameOrigin(NSMakePoint((swipingRightView.frame.width - action.frame.width), action.frame.minY))
                }
            } else {
                subviews[2].setFrameOrigin((subviews[0].frame.width * 2) - (subviews[2].frame.width * 2) * rightPercent, 0)
            }
        }
    }
    
    func completeSwiping(direction: SwipeDirection) {
        self.endSwipingState = direction
        
        if swipingLeftView.subviews.isEmpty || swipingRightView.subviews.isEmpty {
            initSwipingState()
        }
        
         CATransaction.begin()
        
        let updateRightSubviews:(Bool) -> Void = { [weak self] animated in
            guard let `self` = self else {return}
            let subviews = self.swipingRightView.subviews
            subviews[0]._change(pos: NSMakePoint(0, 0), animated: animated)
            subviews[1]._change(pos: NSMakePoint(subviews[0].frame.width, 0), animated: animated)
            subviews[2]._change(pos: NSMakePoint(subviews[0].frame.width * 2, 0), animated: animated)
        }
        
        let failed:(@escaping(Bool)->Void)->Void = { [weak self] completion in
            guard let `self` = self else {return}
            self.containerView.change(pos: NSMakePoint(0, self.containerView.frame.minY), animated: true)
            self.swipingLeftView.change(pos: NSMakePoint(-self.leftSwipingWidth, self.swipingLeftView.frame.minY), animated: true)
            self.swipingRightView.change(pos: NSMakePoint(self.frame.width, self.swipingRightView.frame.minY), animated: true, completion: completion)
            
           updateRightSubviews(true)
            
            self.endSwipingState = nil
        }
       
        
       
        
        switch direction {
        case let .left(state):
            switch state {
            case .success:
                
                let invokeLeftAction = containerX > frame.midX

                
                containerView.change(pos: NSMakePoint(leftSwipingWidth, containerView.frame.minY), animated: true)
                swipingLeftView.change(pos: NSMakePoint(0, swipingLeftView.frame.minY), animated: true, completion: { [weak self] completed in
                    if completed, invokeLeftAction {
                        (self?.swipingLeftView.subviews.first as? Control)?.send(event: .Click)
                    }
                })
                swipingLeftView.change(size: NSMakeSize(leftSwipingWidth, swipingLeftView.frame.height), animated: true)
                swipingRightView.change(pos: NSMakePoint(frame.width, swipingRightView.frame.minY), animated: true)
                updateRightSubviews(true)
            case .failed:
                failed({_ in})
            default:
                break
            }
        case let .right(state):
            switch state {
            case .success:
                
                let invokeRightAction = containerX + swipingRightView.subviews[1].frame.maxX < -frame.midX//delta + subviews[1].frame.maxX < -frame.midX
                if invokeRightAction {
                    failed({ [weak self] completed in
                        if invokeRightAction {
                            (self?.swipingRightView.subviews.last as? Control)?.send(event: .Click)
                        }
                    })
                } else {
                    swipingRightView.change(pos: NSMakePoint(frame.width - rightSwipingWidth, swipingRightView.frame.minY), animated: true)
                    containerView.change(pos: NSMakePoint(-rightSwipingWidth, containerView.frame.minY), animated: true)
                    swipingLeftView.change(pos: NSMakePoint(-leftSwipingWidth, swipingLeftView.frame.minY), animated: true)
                    
                }
                
                
                
                
                updateRightSubviews(true)
            case .failed:
                failed({_ in})
            default:
                break
            }
        default:
            self.endSwipingState = nil
            failed({_ in})
        }
        
        CATransaction.commit()
    }
    
    deinit {
        peerInputActivitiesDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        if let item = self.item as? ChatListRowItem, let displayLayout = item.ctxDisplayLayout {
            self.activitiesModel?.view?.setFrameOrigin(item.leftInset, displayLayout.0.size.height + item.margin + 3)
            
            if let badgeNode = item.ctxBadgeNode {
                badgeView?.setFrameOrigin(self.frame.width - badgeNode.size.width - item.margin, self.frame.height - badgeNode.size.height - item.margin + 1)
            }
        }
        
        let additionalDelta: CGFloat
        if let state = endSwipingState {
            switch state {
            case .left:
                additionalDelta = -leftSwipingWidth
            case .right:
                additionalDelta = rightSwipingWidth
            case .none:
                additionalDelta = 0
            }
        } else {
            additionalDelta = 0
        }
        
        containerView.frame = NSMakeRect(-additionalDelta, 0, frame.width - .borderSize, frame.height)
        swipingLeftView.frame = NSMakeRect(-frame.height - additionalDelta, 0, leftSwipingWidth, frame.height)
        swipingRightView.frame = NSMakeRect(frame.width - additionalDelta, 0, rightSwipingWidth, frame.height)

    }
    
}
