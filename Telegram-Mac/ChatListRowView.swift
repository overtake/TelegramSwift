//
//  TGDialogRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox



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
                    guard let item = item, let chatLocation = item.chatLocation else {return}
                    item.context.sharedContext.bindings.rootNavigation().push(ChatController(context: item.context, chatLocation: chatLocation, initialAction: .files(list: [path], behavior: .automatic)))
                })
            } else {
                let list = sender.draggingPasteboard.propertyList(forType: .kFilenames) as? [String]
                if let item = item, let list = list {
                    let list = list.filter { path -> Bool in
                        if let size = fs(path) {
                            return size <= 1500 * 1024 * 1024
                        }
                        return false
                    }
                    if !list.isEmpty, let chatLocation = item.chatLocation {
                        item.context.sharedContext.bindings.rootNavigation().push(ChatController(context: item.context, chatLocation: chatLocation, initialAction: .files(list: list, behavior: .automatic)))
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

private final class ChatListExpandView: View {
    private let titleView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false

        self.addSubview(titleView)
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let titleLayout = TextViewLayout(.initialize(string: L10n.chatListArchivedChats, color: theme.colors.grayText, font: .medium(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
        titleLayout.measure(width: .greatestFiniteMagnitude)
        titleView.update(titleLayout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        titleView.center()
    }
    
    func animateOnce() {
        titleView.layer?.animateScaleSpring(from: 0.7, to: 1, duration: 0.35, removeOnCompletion: true, bounce: true, completion: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChatListRowView: TableRowView, ViewDisplayDelegate, RevealTableView {
    
    private let revealLeftView: View = View()
    
    private var internalDelta: CGFloat?
    
    private let revealRightView: View = View()
    private var titleText:TextNode = TextNode()
    private var messageText:TextNode = TextNode()
    private var badgeView:View?
    private var additionalBadgeView:View?
    
    private var activeImage: ImageView?
    
    private var previewView: TransformImageView?

    private var activitiesModel:ChatActivitiesModel?
    private var photo:AvatarControl = AvatarControl(font: .avatar(22))
    private var hiddemMessage:Bool = false
    private let peerInputActivitiesDisposable:MetaDisposable = MetaDisposable()
    private var removeControl:ImageButton? = nil
    private var animatedView: RowAnimateView?
    private var archivedPhoto: LAnimationButton?
    private let containerView: ChatListDraggingContainerView = ChatListDraggingContainerView(frame: NSZeroRect)
    private var expandView: ChatListExpandView?
    private var revealActionInvoked: Bool = false {
        didSet {
            animateOnceAfterDelta = true
        }
    }
    var endRevealState: SwipeDirection? {
        didSet {
            internalDelta = nil
            if let oldValue = oldValue, endRevealState == nil  {
                switch oldValue {
                case .left, .right:
                    revealActionInvoked = true
                    completeReveal(direction: .none)
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
     if item.isSelected && item.context.sharedContext.layout != .single {
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
                let oldValue = oldValue?.1.map {
                    ChatListInputActivity($0, $1)
                }
                
                if inputActivities.1.isEmpty {
                    activitiesModel?.clean()
                    activitiesModel?.view?.removeFromSuperview()
                    activitiesModel = nil
                    self.hiddemMessage = false
                    containerView.needsDisplay = true
                } else if activitiesModel == nil {
                    activitiesModel = ChatActivitiesModel()
                    containerView.addSubview(activitiesModel!.view!)
                }
                
                
                let activity:ActivitiesTheme
                if item.isSelected && item.context.sharedContext.layout != .single {
                    activity = theme.activity(key: 10 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activitySelectedColor, backgroundColor: theme.chatList.selectedBackgroundColor)
                } else if item.isSelected {
                    activity = theme.activity(key: 11 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityPinnedColor, backgroundColor: theme.chatList.singleLayoutSelectedBackgroundColor)
                } else if self.containerView.activeDragging || item.isHighlighted {
                    activity = theme.activity(key: 13 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityColor, backgroundColor: theme.chatList.activeDraggingBackgroundColor)
                } else if item.isFixedItem {
                    activity = theme.activity(key: 12 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityPinnedColor, backgroundColor: theme.chatList.pinnedBackgroundColor)
                } else if contextMenu != nil {
                    activity = theme.activity(key: 13 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityContextMenuColor, backgroundColor: theme.chatList.contextMenuBackgroundColor)
                } else {
                    activity = theme.activity(key: 14 + (theme.dark ? 10 : 20), foregroundColor: theme.chatList.activityColor, backgroundColor: theme.colors.background)
                }
                if oldValue != item.activities || activity != activitiesModel?.theme {
                    activitiesModel?.update(with: inputActivities, for: item.messageWidth, theme:  activity, layout: { [weak self] show in
                        if let item = self?.item as? ChatListRowItem, let displayLayout = item.ctxDisplayLayout {
                            self?.activitiesModel?.view?.setFrameOrigin(item.leftInset, displayLayout.0.size.height + item.margin + 3)
                        }
                        self?.hiddemMessage = show
                        self?.containerView.needsDisplay = true
                    })
                }
              
                
                activitiesModel?.view?.isHidden = item.context.sharedContext.layout == .minimisize
            } else {
                activitiesModel?.clean()
                activitiesModel?.view?.removeFromSuperview()
                activitiesModel = nil
                hiddemMessage = false
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
            self.animatedView = RowAnimateView(frame:bounds)
            self.animatedView?.isEventLess = true
            containerView.addSubview(animatedView!)
            animatedView?.backgroundColor = theme.colors.focusAnimationColor
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
            if item.isCollapsed {
                return theme.colors.grayBackground
            }
            if item.isHighlighted && !item.isSelected {
                return theme.chatList.activeDraggingBackgroundColor
            }
            if item.context.sharedContext.layout == .single, item.isSelected {
                return theme.chatList.singleLayoutSelectedBackgroundColor
            }
            if !item.isSelected && containerView.activeDragging {
                return theme.chatList.activeDraggingBackgroundColor
            }
            if item.isFixedItem && !item.isSelected {
                return theme.chatList.pinnedBackgroundColor
            }
            
            return item.isSelected ? theme.chatList.selectedBackgroundColor : contextMenu != nil ? theme.chatList.contextMenuBackgroundColor : theme.colors.background
        }
        return theme.colors.background
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {

        super.draw(layer, in: ctx)
        
//
         if let item = self.item as? ChatListRowItem {
            if !item.isSelected {
                
                if layer != containerView.layer {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
                } else {
                    
                    if item.context.sharedContext.layout == .minimisize {
                        return
                    }
                    
                    if backingScaleFactor == 1.0 {
                        ctx.setFillColor(backdorColor.cgColor)
                        ctx.fill(layer.bounds)
                    }
                    
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.isLastPinned ? 0 : item.leftInset, NSHeight(layer.bounds) - .borderSize, item.isLastPinned ? layer.frame.width : layer.bounds.width - item.leftInset, .borderSize))
                }
            }
            
            if item.context.sharedContext.layout == .minimisize {
                return
            }
            
            if layer == containerView.layer {
                
                let highlighted = item.isSelected && item.context.sharedContext.layout != .single
                
                
                if item.ctxBadgeNode == nil && (item.isPinned || item.isLastPinned) {
                    ctx.draw(highlighted ? theme.icons.pinnedImageSelected : theme.icons.pinnedImage, in: NSMakeRect(frame.width - theme.icons.pinnedImage.backingSize.width - item.margin, frame.height - theme.icons.pinnedImage.backingSize.height - (item.margin + 1), theme.icons.pinnedImage.backingSize.width, theme.icons.pinnedImage.backingSize.height))
                }
                
                if let displayLayout = item.ctxDisplayLayout {
                    
                    var addition:CGFloat = 0
                    if item.isSecret {
                        ctx.draw(highlighted ? theme.icons.secretImageSelected : theme.icons.secretImage, in: NSMakeRect(item.leftInset, item.margin + 3, theme.icons.secretImage.backingSize.width, theme.icons.secretImage.backingSize.height))
                        addition += theme.icons.secretImage.backingSize.height
                        
                    }
                    displayLayout.1.draw(NSMakeRect(item.leftInset + addition, item.margin - 1, displayLayout.0.size.width, displayLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    
                    
                    var mutedInset:CGFloat = item.isSecret ? theme.icons.secretImage.backingSize.width + 2 : 0
                    
                    if item.isVerified {
                        ctx.draw(highlighted ? theme.icons.verifyDialogActive : theme.icons.verifyDialog, in: NSMakeRect(displayLayout.0.size.width + item.leftInset + addition - 2, item.margin - 3, 24, 24))
                        mutedInset += 15 + 3
                    }
                    
                    if item.isScam {
                        ctx.draw(highlighted ? theme.icons.scamActive : theme.icons.scam, in: NSMakeRect(displayLayout.0.size.width + item.leftInset + addition + 2, item.margin + 1, theme.icons.scam.backingSize.width, theme.icons.scam.backingSize.height))
                        mutedInset += theme.icons.scam.backingSize.width + 3
                    }
                    var messageOffset: CGFloat = 0
                    if let chatNameLayout = item.ctxChatNameLayout, !hiddemMessage {
                        chatNameLayout.1.draw(NSMakeRect(item.leftInset, displayLayout.0.size.height + item.margin + 1, chatNameLayout.0.size.width, chatNameLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        messageOffset += chatNameLayout.0.size.height + 2
                    }
                    if let messageLayout = item.ctxMessageLayout, !hiddemMessage {
                        messageLayout.1.draw(NSMakeRect(item.leftInset, displayLayout.0.size.height + item.margin + 1 + messageOffset, messageLayout.0.size.width, messageLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    }
                    
                    if item.isMuted {
                        ctx.draw(highlighted ? theme.icons.dialogMuteImageSelected : theme.icons.dialogMuteImage, in: NSMakeRect(item.leftInset + displayLayout.0.size.width + 4 + mutedInset, item.margin + round((displayLayout.0.size.height - theme.icons.dialogMuteImage.backingSize.height) / 2.0) - 1, theme.icons.dialogMuteImage.backingSize.width, theme.icons.dialogMuteImage.backingSize.height))
                    }
                    
                    if let _ = item.mentionsCount {
                        let icon: CGImage
                        if item.associatedGroupId == .root {
                            icon = highlighted ? theme.icons.chatListMentionActive : theme.icons.chatListMention
                        } else {
                            icon = highlighted ? theme.icons.chatListMentionArchivedActive : theme.icons.chatListMentionArchived
                        }
                        ctx.draw(icon, in: NSMakeRect(frame.width - (item.ctxBadgeNode != nil ? item.ctxBadgeNode!.size.width + item.margin : 0) - icon.backingSize.width - item.margin, frame.height - icon.backingSize.height - (item.margin + 1), icon.backingSize.width, icon.backingSize.height)) 
                    }
                    
                    if let dateLayout = item.ctxDateLayout, !item.hasDraft {
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
        
        
        addSubview(revealRightView)
        addSubview(revealLeftView)
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        photo.userInteractionEnabled = false
        photo.frame = NSMakeRect(10, 10, 50, 50)
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
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
        self.containerView.background = backdorColor
        expandView?.backgroundColor = theme.colors.grayBackground
    }

    override func set(item:TableRowItem, animated:Bool = false) {
        
        let oldItem = self.item as? ChatListRowItem
        
        if let item = item as? ChatListRowItem {
            if item.isCollapsed {
                if expandView == nil {
                    expandView = ChatListExpandView(frame: NSMakeRect(0, frame.height, frame.width, item.height))
                    self.addSubview(expandView!, positioned: .below, relativeTo: containerView)
                }
                expandView?.updateLocalizationAndTheme(theme: theme)
            }
        }
        
         let wasHidden: Bool = (self.item as? ChatListRowItem)?.isCollapsed ?? false
         super.set(item:item, animated:animated)
        
                
         if let item = item as? ChatListRowItem {
            
            
            var updateImageSignal: Signal<ImageDataTransformation, NoError>?
            if let contentImageMedia = item.contentImageMedia {
                if let oldContentImageMedia = oldItem?.contentImageMedia, contentImageMedia.isSemanticallyEqual(to: oldContentImageMedia) {
                } else {
                    if let message = item.message {
                        if let image = contentImageMedia as? TelegramMediaImage {
                            updateImageSignal = mediaGridMessagePhoto(account: item.context.account, imageReference: .message(message: MessageReference(message), media: image), scale: backingScaleFactor)
                        } else if let file = contentImageMedia as? TelegramMediaFile {
                            updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, fileReference: .message(message: MessageReference(message), media: file), scale: backingScaleFactor)
                        }
                    }
                }
            }

            if  let dimensions = item.contentDimensions {
                let previewView: TransformImageView
                if let current = self.previewView {
                    previewView = current
                } else {
                    previewView = TransformImageView()
                    previewView.setFrameSize(NSMakeSize(18, 18))
                    self.previewView = previewView
                    self.containerView.addSubview(previewView)
                }
                if let updateImageSignal = updateImageSignal {
                    previewView.setSignal(updateImageSignal)
                }
                
                let contentImageSize = CGSize(width: 18.0, height: 18.0)
                                
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: dimensions.aspectFilled(contentImageSize), boundingSize: contentImageSize, intrinsicInsets: NSEdgeInsets())
                
                previewView.set(arguments: arguments)
                
            } else {
                previewView?.removeFromSuperview()
                previewView = nil
            }
            
            
            if item.isCollapsed != wasHidden {
                expandView?.change(pos: NSMakePoint(0, item.isCollapsed ? 0 : item.height), animated: animated)
                containerView.change(pos: NSMakePoint(0, item.isCollapsed ? -70 : 0), animated: !revealActionInvoked && animated)
            }

            if let isOnline = item.isOnline, item.context.sharedContext.layout != .minimisize {
                if isOnline {
                    var animate: Bool = false
                    if activeImage == nil {
                        activeImage = ImageView()
                        self.containerView.addSubview(activeImage!)
                        animate = true
                    }
                    guard let activeImage = self.activeImage else { return }
                    activeImage.image = item.isSelected && item.context.sharedContext.layout != .single ? theme.icons.hintPeerActiveSelected : theme.icons.hintPeerActive
                    activeImage.sizeToFit()

                    activeImage.setFrameOrigin(photo.frame.maxX - activeImage.frame.width - 3, photo.frame.maxY - 12)

                    if animated && animate {
                        activeImage.layer?.animateAlpha(from: 0.5, to: 1.0, duration: 0.2)
                        activeImage.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
                    }
                } else {
                    if animated {
                        let activeImage = self.activeImage
                        self.activeImage = nil
                        activeImage?.layer?.animateAlpha(from: 1, to: 0.5, duration: 0.2)
                        activeImage?.layer?.animateScaleSpring(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak activeImage] completed in
                            activeImage?.removeFromSuperview()
                        })
                    } else {
                        activeImage?.removeFromSuperview()
                        activeImage = nil
                    }
                }
            } else {
                activeImage?.removeFromSuperview()
                activeImage = nil
            }
            
            
            containerView.item = item
            if self.animatedView != nil && self.animatedView?.stableId != item.stableId {
                self.animatedView?.removeFromSuperview()
                self.animatedView = nil
            }
            
            
            photo.setState(account: item.context.account, state: item.photo)

            if item.isSavedMessage {
                self.archivedPhoto?.removeFromSuperview()
                self.archivedPhoto = nil
                let icon = theme.icons.searchSaved
                photo.setState(account: item.context.account, state: .Empty)
                photo.setSignal(generateEmptyPhoto(photo.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photo.frame.size.width - 20, photo.frame.size.height - 20)), cornerRadius: nil)) |> map {($0, false)})
            } else if case .ArchivedChats = item.photo {
                if self.archivedPhoto == nil {
                    self.archivedPhoto = LAnimationButton(animation: "archiveAvatar", size: NSMakeSize(46, 46), offset: NSMakeSize(0, 0))
                    containerView.addSubview(self.archivedPhoto!, positioned: .above, relativeTo: self.photo)
                }
                self.archivedPhoto?.frame = self.photo.frame
                self.archivedPhoto?.userInteractionEnabled = false
                self.archivedPhoto?.set(keysToColor: ["box2.box2.Fill 1"], color: item.archiveStatus?.isHidden == false ? theme.colors.revealAction_accent_background : theme.colors.grayForeground)
                self.archivedPhoto?.background = item.archiveStatus?.isHidden == false ? theme.colors.revealAction_accent_background : theme.colors.grayForeground
                self.archivedPhoto?.layer?.cornerRadius = photo.frame.height / 2

                let animateArchive = item.animateArchive && animated
                if animateArchive {
                    archivedPhoto?.loop()
                    if item.isCollapsed {
                        self.expandView?.animateOnce()
                    }
                }
                
             //   let icon = theme.icons.archivedChats
                photo.setState(account: item.context.account, state: .Empty)
              //  photo.setSignal(generateEmptyPhoto(photo.frame.size, type: .icon(colors: (theme.colors.grayForeground, theme.colors.grayForeground), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photo.frame.size.width - 17, photo.frame.size.height - 17)), cornerRadius: nil)) |> map {($0, false)})
            } else {
                self.archivedPhoto?.removeFromSuperview()
                self.archivedPhoto = nil
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
            
            if let badgeNode = item.ctxAdditionalBadgeNode {
                if additionalBadgeView == nil {
                    additionalBadgeView = View()
                    containerView.addSubview(additionalBadgeView!)
                }
                additionalBadgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = additionalBadgeView
                badgeNode.setNeedDisplay()
            } else {
                additionalBadgeView?.removeFromSuperview()
                additionalBadgeView = nil
            }
            
            if let peerId = item.peerId {
                let activities = item.activities.map {
                    ($0.peer.peer, $0.activity)
                }
                self.inputActivities = (peerId, activities)
            } else {
                self.inputActivities = nil
            }
         }
        
        if let _ = endRevealState {
            initRevealState()
        }
        containerView.needsDisplay = true
        
        containerView.customHandler.layout = { [weak self] _ in
            guard let `self` = self else { return }
            
            if let item = self.item as? ChatListRowItem, let displayLayout = item.ctxDisplayLayout {
                self.activitiesModel?.view?.setFrameOrigin(item.leftInset, displayLayout.0.size.height + item.margin + 3)
                
                var additionalOffset: CGFloat = 0
                
                if let badgeNode = item.ctxAdditionalBadgeNode {
                    self.additionalBadgeView?.setFrameOrigin(self.containerView.frame.width - badgeNode.size.width - item.margin, self.containerView.frame.height - badgeNode.size.height - (item.margin + 1))
                    additionalOffset += (badgeNode.size.width + item.margin)
                }
                
                if let badgeNode = item.ctxBadgeNode {
                    self.badgeView?.setFrameOrigin(self.containerView.frame.width - badgeNode.size.width - item.margin - additionalOffset, self.containerView.frame.height - badgeNode.size.height - (item.margin + 1))
                }
                if let activeImage = self.activeImage {
                    activeImage.setFrameOrigin(self.photo.frame.maxX - activeImage.frame.width - 3, self.photo.frame.maxY - 12)
                }
            }
        }
        
        containerView.needsLayout = true
        revealActionInvoked = false
        needsDisplay = true
        needsLayout = true
    }
    
    func initRevealState() {
        guard let item = item as? ChatListRowItem, endRevealState == nil else {return}
        
        revealLeftView.removeAllSubviews()
        revealRightView.removeAllSubviews()
        
        revealLeftView.backgroundColor = backdorColor
        revealRightView.backgroundColor = backdorColor
        
        if item.groupId == .root {
            
            let unreadBackground = !item.markAsUnread ? theme.colors.revealAction_inactive_background : theme.colors.revealAction_accent_background
            let unreadForeground = !item.markAsUnread ? theme.colors.revealAction_inactive_foreground : theme.colors.revealAction_accent_foreground

            let unread: LAnimationButton = LAnimationButton(animation: !item.markAsUnread ? "anim_read" : "anim_unread", size: NSMakeSize(frame.height, frame.height), keysToColor: !item.markAsUnread ? nil : ["Oval.Oval.Stroke 1"], color: unreadBackground, offset: NSMakeSize(0, 0), autoplaySide: .right)
            let unreadTitle = TextViewLabel()
            unreadTitle.attributedString = .initialize(string: !item.markAsUnread ? L10n.chatListSwipingRead : L10n.chatListSwipingUnread, color: unreadForeground, font: .medium(12))
            unreadTitle.sizeToFit()
            unread.addSubview(unreadTitle)
            unread.set(background: unreadBackground, for: .Normal)
            unread.customHandler.layout = { [weak unreadTitle] view in
                if let unreadTitle = unreadTitle {
                    unreadTitle.centerX(y: view.frame.height - unreadTitle.frame.height - 10)
                }
            }
            
            let mute: LAnimationButton = LAnimationButton(animation: item.isMuted ? "anim_unmute" : "anim_mute", size: NSMakeSize(frame.height, frame.height), keysToColor: item.isMuted ? nil : ["un Outlines.Group 1.Stroke 1"], color: theme.colors.revealAction_neutral2_background, offset: NSMakeSize(0, 0), autoplaySide: .right)
            let muteTitle = TextViewLabel()
            muteTitle.attributedString = .initialize(string: item.isMuted ? L10n.chatListSwipingUnmute : L10n.chatListSwipingMute, color: theme.colors.revealAction_neutral2_foreground, font: .medium(12))
            muteTitle.sizeToFit()
            mute.addSubview(muteTitle)
            mute.set(background: theme.colors.revealAction_neutral2_background, for: .Normal)
            mute.customHandler.layout = { [weak muteTitle] view in
                if let muteTitle = muteTitle {
                    muteTitle.centerX(y: view.frame.height - muteTitle.frame.height - 10)
                }
            }
            
            
            let pin: LAnimationButton = LAnimationButton(animation: !item.isPinned ? "anim_pin" : "anim_unpin", size: NSMakeSize(frame.height, frame.height), keysToColor: !item.isPinned ? nil : ["un Outlines.Group 1.Stroke 1"], color: theme.colors.revealAction_constructive_background, offset: NSMakeSize(0, 0), autoplaySide: .left)
            let pinTitle = TextViewLabel()
            pinTitle.attributedString = .initialize(string: !item.isPinned ? L10n.chatListSwipingPin : L10n.chatListSwipingUnpin, color: theme.colors.revealAction_constructive_foreground, font: .medium(12))
            pinTitle.sizeToFit()
            pin.addSubview(pinTitle)
            pin.set(background: theme.colors.revealAction_constructive_background, for: .Normal)
            pin.customHandler.layout = { [weak pinTitle] view in
                if let pinTitle = pinTitle {
                    pinTitle.centerX(y: view.frame.height - pinTitle.frame.height - 10)
                }
            }
            
            pin.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                item.togglePinned()
                self?.endRevealState = nil
            }, for: .Click)
            unread.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                item.toggleUnread()
                self?.endRevealState = nil
            }, for: .Click)
            
            
            
            
            
            
            let archive: LAnimationButton = LAnimationButton(animation: item.associatedGroupId != .root ? "anim_unarchive" : "anim_archive", size: item.associatedGroupId != .root ? NSMakeSize(45, 45) : NSMakeSize(frame.height, frame.height), keysToColor: ["box2.box2.Fill 1"], color: theme.colors.revealAction_inactive_background, offset: NSMakeSize(0, item.associatedGroupId != .root ? 9.0 : 0.0), autoplaySide: .left)
            let archiveTitle = TextViewLabel()
            archiveTitle.attributedString = .initialize(string: item.associatedGroupId != .root ? L10n.chatListSwipingUnarchive : L10n.chatListSwipingArchive, color: theme.colors.revealAction_inactive_foreground, font: .medium(12))
            archiveTitle.sizeToFit()
            archive.addSubview(archiveTitle)
            archive.set(background: theme.colors.revealAction_inactive_background, for: .Normal)
            archive.customHandler.layout = { [weak archiveTitle] view in
                if let archiveTitle = archiveTitle {
                    archiveTitle.centerX(y: view.frame.height - archiveTitle.frame.height - 10)
                }
            }
            
            
            
            
            let delete: LAnimationButton = LAnimationButton(animation: "anim_delete", size: NSMakeSize(frame.height, frame.height), keysToColor: nil, offset: NSMakeSize(0, 0), autoplaySide: .left)
            let deleteTitle = TextViewLabel()
            deleteTitle.attributedString = .initialize(string: L10n.chatListSwipingDelete, color: theme.colors.revealAction_destructive_foreground, font: .medium(12))
            deleteTitle.sizeToFit()
            delete.addSubview(deleteTitle)
            delete.set(background: theme.colors.revealAction_destructive_background, for: .Normal)
            delete.customHandler.layout = { [weak deleteTitle] view in
                if let deleteTitle = deleteTitle {
                    deleteTitle.centerX(y: view.frame.height - deleteTitle.frame.height - 10)
                }
            }
            
            
            archive.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                self?.endRevealState = nil
                item.toggleArchive()
            }, for: .Click)
            
            mute.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                self?.endRevealState = nil
                item.toggleMuted()
            }, for: .Click)
            
            delete.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                self?.endRevealState = nil
                item.delete()
            }, for: .Click)
            
            
            revealRightView.addSubview(pin)

            revealRightView.addSubview(delete)
            
            if item.filter == nil {
                revealRightView.addSubview(archive)
            }
            
            
            
            revealLeftView.addSubview(mute)
            revealLeftView.addSubview(unread)
            
            
            
            revealLeftView.backgroundColor = unreadBackground
            revealRightView.backgroundColor = item.filter == nil ? theme.colors.revealAction_inactive_background : theme.colors.revealAction_destructive_background
            
            
            unread.setFrameSize(frame.height, frame.height)
            mute.setFrameSize(frame.height, frame.height)
            
            
            archive.setFrameSize(frame.height, frame.height)
            pin.setFrameSize(frame.height, frame.height)
            delete.setFrameSize(frame.height, frame.height)
            
            delete.setFrameOrigin(archive.frame.maxX, 0)
            archive.setFrameOrigin(delete.frame.maxX, 0)
            
            
            mute.setFrameOrigin(unread.frame.maxX, 0)
            
            
            revealRightView.setFrameSize(rightRevealWidth, frame.height)
            revealLeftView.setFrameSize(leftRevealWidth, frame.height)
        } else {
            
            
            let collapse: LAnimationButton = LAnimationButton(animation: "anim_hide", size: NSMakeSize(frame.height, frame.height), keysToColor: ["Path 2.Path 2.Fill 1"], color: theme.colors.revealAction_inactive_background, offset: NSMakeSize(0, 0), autoplaySide: .left)
            let collapseTitle = TextViewLabel()
            collapseTitle.attributedString = .initialize(string: L10n.chatListRevealActionCollapse, color: theme.colors.revealAction_inactive_foreground, font: .medium(12))
            collapseTitle.sizeToFit()
            collapse.addSubview(collapseTitle)
            collapse.set(background: theme.colors.revealAction_inactive_background, for: .Normal)
            collapse.customHandler.layout = { [weak collapseTitle] view in
                if let collapseTitle = collapseTitle {
                    collapseTitle.centerX(y: view.frame.height - collapseTitle.frame.height - 10)
                }
            }
            
            collapse.setFrameSize(frame.height, frame.height)
            revealRightView.addSubview(collapse)
            revealRightView.backgroundColor = theme.colors.revealAction_inactive_background
            revealRightView.setFrameSize(rightRevealWidth, frame.height)
            
            collapse.set(handler: { [weak self] _ in
                guard let item = self?.item as? ChatListRowItem else {return}
                item.collapseOrExpandArchive()
                self?.endRevealState = nil
            }, for: .Click)
            
            
            
            if let archiveStatus = item.archiveStatus {
                

                let hideOrPin: LAnimationButton
                let hideOrPinTitle = TextViewLabel()

                switch archiveStatus {
                case .hidden:
                    hideOrPin = LAnimationButton(animation: "anim_hide", size: NSMakeSize(frame.height, frame.height), keysToColor: ["Path 2.Path 2.Fill 1"], color: theme.colors.revealAction_accent_background, offset: NSMakeSize(0, 0), autoplaySide: .left, rotated: true)
                    hideOrPinTitle.attributedString = .initialize(string: L10n.chatListRevealActionPin, color: theme.colors.revealAction_accent_foreground, font: .medium(12))
                    hideOrPin.set(background: theme.colors.revealAction_accent_background, for: .Normal)
                default:
                    hideOrPin = LAnimationButton(animation: "anim_hide", size: NSMakeSize(frame.height, frame.height), keysToColor: ["Path 2.Path 2.Fill 1"], color: theme.colors.revealAction_inactive_background, offset: NSMakeSize(0, 0), autoplaySide: .left, rotated: false)
                    hideOrPinTitle.attributedString = .initialize(string: L10n.chatListRevealActionHide, color: theme.colors.revealAction_inactive_foreground, font: .medium(12))
                    hideOrPin.set(background: theme.colors.revealAction_inactive_background, for: .Normal)
                }
                
                hideOrPinTitle.sizeToFit()
                hideOrPin.addSubview(hideOrPinTitle)
                hideOrPin.customHandler.layout = { [weak hideOrPinTitle] view in
                    if let hideOrPinTitle = hideOrPinTitle {
                        hideOrPinTitle.centerX(y: view.frame.height - hideOrPinTitle.frame.height - 10)
                    }
                }
                
                hideOrPin.setFrameSize(frame.height, frame.height)
                revealLeftView.addSubview(hideOrPin)
                revealLeftView.backgroundColor = item.archiveStatus?.isHidden == true ? theme.colors.revealAction_accent_background : theme.colors.revealAction_inactive_background
                revealLeftView.setFrameSize(leftRevealWidth, frame.height)
                
                hideOrPin.set(handler: { [weak self] _ in
                    guard let item = self?.item as? ChatListRowItem else {return}
                    item.toggleHideArchive()
                    self?.endRevealState = nil
                }, for: .Click)
                
            }
            
            
        }
        

    }
    
    var additionalRevealDelta: CGFloat {
        let additionalDelta: CGFloat
        if let state = endRevealState {
            switch state {
            case .left:
                additionalDelta = -leftRevealWidth
            case .right:
                additionalDelta = rightRevealWidth
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

    var rightRevealWidth: CGFloat {
        return revealRightView.subviewsSize.width
    }
    
    var leftRevealWidth: CGFloat {
        return revealLeftView.subviewsSize.width
    }
    
    private var animateOnceAfterDelta: Bool = true
    func moveReveal(delta: CGFloat) {
        
        
        if revealLeftView.subviews.isEmpty && revealRightView.subviews.isEmpty {
            initRevealState()
        }
      
        self.internalDelta = delta
        
        let delta = delta// - additionalRevealDelta
        
        containerView.change(pos: NSMakePoint(delta, containerView.frame.minY), animated: false)
        revealLeftView.change(pos: NSMakePoint(min(-leftRevealWidth + delta, 0), revealLeftView.frame.minY), animated: false)
        revealRightView.change(pos: NSMakePoint(frame.width + delta, revealRightView.frame.minY), animated: false)
        
        
        revealLeftView.change(size: NSMakeSize(max(leftRevealWidth, delta), revealLeftView.frame.height), animated: false)
        
        revealRightView.change(size: NSMakeSize(max(rightRevealWidth, abs(delta)), revealRightView.frame.height), animated: false)

        
        
        if delta > 0, !revealLeftView.subviews.isEmpty {
            let action = revealLeftView.subviews.last!
            
            let subviews = revealLeftView.subviews
            let leftPercent: CGFloat = max(min(delta / leftRevealWidth, 1), 0)

            if delta > frame.width - (frame.width / 3) {
                if animateOnceAfterDelta {
                    animateOnceAfterDelta = false
                    action.layer?.animatePosition(from: NSMakePoint(-(revealLeftView.frame.width - action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                    
                    for i in 0 ..< subviews.count - 1 {
                        let action = revealLeftView.subviews[i]
                        action.layer?.animatePosition(from: NSMakePoint(-(action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                    }
                    
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                }
                
                for i in 0 ..< subviews.count - 1 {
                    revealLeftView.subviews[i].setFrameOrigin(NSMakePoint(revealLeftView.frame.width, 0))
                }
                
                action.setFrameOrigin(NSMakePoint((revealLeftView.frame.width - action.frame.width), action.frame.minY))

                
            } else {
                
                 if !animateOnceAfterDelta {
                    animateOnceAfterDelta = true
                    action.layer?.animatePosition(from: NSMakePoint(revealLeftView.frame.width - action.frame.width - (leftRevealWidth - action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                  
                    for i in stride(from: revealLeftView.subviews.count - 1, to: 0, by: -1) {
                        let action = revealLeftView.subviews[i]
                        action.layer?.animatePosition(from: NSMakePoint((action.frame.width), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                    }
                    
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                }
                if subviews.count == 1 {
                    action.setFrameOrigin(NSMakePoint(min(revealLeftView.frame.width - action.frame.width, 0), action.frame.minY))
                } else {
                    action.setFrameOrigin(NSMakePoint(action.frame.width - action.frame.width * leftPercent, action.frame.minY))
                    for i in 0 ..< subviews.count - 1 {
                        let action = subviews[i]
                        subviews[i].setFrameOrigin(NSMakePoint(revealLeftView.frame.width - action.frame.width, 0))
                    }
                }
            }
        }
        
        var rightPercent: CGFloat = delta / rightRevealWidth
        if rightPercent < 0, !revealRightView.subviews.isEmpty {
            rightPercent = 1 - min(1, abs(rightPercent))
            let subviews = revealRightView.subviews
            

            let action = subviews.last!
            
            if rightPercent == 0 , delta < 0 {
                if delta + action.frame.width * CGFloat(max(1, revealRightView.subviews.count - 1)) - 35 < -frame.midX {
                    if animateOnceAfterDelta {
                        animateOnceAfterDelta = false
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        action.layer?.animatePosition(from: NSMakePoint((revealRightView.frame.width - rightRevealWidth), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                        
                        for i in 0 ..< subviews.count - 1 {
                            subviews[i].layer?.animatePosition(from: NSMakePoint((subviews[i].frame.width * CGFloat(i + 1)), subviews[i].frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                        }
                        
                    }
                    
                    for i in 0 ..< subviews.count - 1 {
                         subviews[i].setFrameOrigin(NSMakePoint(-subviews[i].frame.width, 0))
                    }
                    
                    action.setFrameOrigin(NSMakePoint(0, action.frame.minY))
                    
                } else {
                    if !animateOnceAfterDelta {
                        animateOnceAfterDelta = true
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

                        action.layer?.animatePosition(from: NSMakePoint(-(revealRightView.frame.width - rightRevealWidth), action.frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                        
                        for i in 0 ..< subviews.count - 1 {
                            subviews[i].layer?.animatePosition(from: NSMakePoint(-(subviews[i].frame.width * CGFloat(i + 1)), subviews[i].frame.minY), to: NSMakePoint(0, 0), duration: 0.2, timingFunction: CAMediaTimingFunctionName.spring, removeOnCompletion: true, additive: true)
                        }
                        
                    }
                    action.setFrameOrigin(NSMakePoint((revealRightView.frame.width - action.frame.width), action.frame.minY))
                    
                    for i in 0 ..< subviews.count - 1 {
                        subviews[i].setFrameOrigin(NSMakePoint(CGFloat(i) * subviews[i].frame.width, 0))
                    }
                }
            } else {
                for (i, subview) in subviews.enumerated() {
                    let i = CGFloat(i)
                    subview.setFrameOrigin(subview.frame.width * i - subview.frame.width * i * rightPercent, 0)
                }
//                subviews[0].setFrameOrigin(0, 0)
//                subviews[1].setFrameOrigin(subviews[0].frame.width - subviews[1].frame.width * rightPercent, 0)
//                subviews[2].setFrameOrigin((subviews[0].frame.width * 2) - (subviews[2].frame.width * 2) * rightPercent, 0)
            }
        }
    }
    
    func completeReveal(direction: SwipeDirection) {
        self.endRevealState = direction
        
        if revealLeftView.subviews.isEmpty || revealRightView.subviews.isEmpty {
            initRevealState()
        }

        
        let updateRightSubviews:(Bool) -> Void = { [weak self] animated in
            guard let `self` = self else {return}
            let subviews = self.revealRightView.subviews
            var x: CGFloat = 0
            for subview in subviews {
                if subview != subviews.last {
                    subview._change(pos: NSMakePoint(x, 0), animated: animated, timingFunction: .spring)
                    x += subview.frame.width
                } else {
                    subview._change(pos: NSMakePoint(self.rightRevealWidth - subview.frame.width, 0), animated: animated, timingFunction: .spring)
                }
            }
        }
        
        let updateLeftSubviews:(Bool) -> Void = { [weak self] animated in
            guard let `self` = self else {return}
            let subviews = self.revealLeftView.subviews
            var x: CGFloat = 0
            for subview in subviews.reversed() {
                subview._change(pos: NSMakePoint(x, 0), animated: animated, timingFunction: .spring)
                x += subview.frame.width
            }
        }
        
        let failed:(@escaping(Bool)->Void)->Void = { [weak self] completion in
            guard let `self` = self else {return}
            self.containerView.change(pos: NSMakePoint(0, self.containerView.frame.minY), animated: true, timingFunction: .spring)
            self.revealLeftView.change(pos: NSMakePoint(-self.revealLeftView.frame.width, self.revealLeftView.frame.minY), animated: true, timingFunction: .spring)
            self.revealRightView.change(pos: NSMakePoint(self.frame.width, self.revealRightView.frame.minY), animated: true, timingFunction: .spring, completion: completion)
            
            updateRightSubviews(true)
            updateLeftSubviews(true)
            self.endRevealState = nil
        }
       
        let animateRightLongReveal:(@escaping(Bool)->Void)->Void = { [weak self] completion in
            guard let `self` = self else {return}
            updateRightSubviews(true)
            self.endRevealState = nil
            let duration: Double = 0.2

            self.containerView.change(pos: NSMakePoint(-self.containerView.frame.width, self.containerView.frame.minY), animated: true, duration: duration, timingFunction: .spring)
            self.revealRightView.change(size: NSMakeSize(self.frame.width + self.rightRevealWidth, self.revealRightView.frame.height), animated: true, duration: duration, timingFunction: .spring)
            self.revealRightView.change(pos: NSMakePoint(-self.rightRevealWidth, self.revealRightView.frame.minY), animated: true, duration: duration, timingFunction: .spring, completion: completion)
            
        }
        
        
       
        
        switch direction {
        case let .left(state):
            
            if revealLeftView.subviews.isEmpty {
                failed( { [weak self] _ in
                    self?.revealRightView.removeAllSubviews()
                    self?.revealLeftView.removeAllSubviews()
                } )
                return
            }
            
            switch state {
            case .success:
                
                let invokeLeftAction = containerX > frame.width - (frame.width / 3)

                let duration: Double = 0.2

                containerView.change(pos: NSMakePoint(leftRevealWidth, containerView.frame.minY), animated: true, duration: duration, timingFunction: .spring)
                revealLeftView.change(size: NSMakeSize(leftRevealWidth, revealLeftView.frame.height), animated: true, duration: duration, timingFunction: .spring)
                
                revealRightView.change(pos: NSMakePoint(frame.width, revealRightView.frame.minY), animated: true)
                updateLeftSubviews(true)
                
                var last = self.revealLeftView.subviews.last as? Control
                
                revealLeftView.change(pos: NSMakePoint(0, revealLeftView.frame.minY), animated: true, duration: duration, timingFunction: .spring, completion: { [weak self] completed in
                    if completed, invokeLeftAction {
                        last?.send(event: .Click)
                        last = nil
                        self?.needsLayout = true
                    }
                })
            case .failed:
                failed( { [weak self] _ in
                    self?.revealRightView.removeAllSubviews()
                    self?.revealLeftView.removeAllSubviews()
                } )
            default:
                break
            }
        case let .right(state):
            
            if revealRightView.subviews.isEmpty {
                failed( { [weak self] _ in
                    self?.revealRightView.removeAllSubviews()
                    self?.revealLeftView.removeAllSubviews()
                } )
                return
            }
            
            switch state {
            case .success:
                let invokeRightAction = containerX + revealRightView.subviews.last!.frame.minX < -frame.midX
                
                var last = self.revealRightView.subviews.last as? Control

                
                if invokeRightAction {
                    if self.revealRightView.subviews.count < 3 {
                        failed({ completed in
                            if invokeRightAction {
                                DispatchQueue.main.async {
                                    last?.send(event: .Click)
                                    last = nil
                                }
                            }
                        })
                    } else {
                        animateRightLongReveal({ completed in
                            if invokeRightAction {
                                DispatchQueue.main.async {
                                    last?.send(event: .Click)
                                    last = nil
                                }
                            }
                        })
                    }
                    
                } else {
                    revealRightView.change(pos: NSMakePoint(frame.width - rightRevealWidth, revealRightView.frame.minY), animated: true, timingFunction: .spring)
                    revealRightView.change(size: NSMakeSize(rightRevealWidth, revealRightView.frame.height), animated: true, timingFunction: .spring)
                    containerView.change(pos: NSMakePoint(-rightRevealWidth, containerView.frame.minY), animated: true, timingFunction: .spring)
                    revealLeftView.change(pos: NSMakePoint(-leftRevealWidth, revealLeftView.frame.minY), animated: true, timingFunction: .spring)
                    
                    
                    let handler = (revealRightView.subviews.last as? Control)?.removeLastHandler()
                    (revealRightView.subviews.last as? Control)?.set(handler: { control in
                        var _control:Control? = control
                        animateRightLongReveal({ completed in
                            if let control = _control {
                                DispatchQueue.main.async {
                                    handler?(control)
                                    _control = nil
                                }
                               
                            }
                        })
                    }, for: .Click)
                    
                }
               updateRightSubviews(true)
            case .failed:
                failed( { [weak self] _ in
                    self?.revealRightView.removeAllSubviews()
                    self?.revealLeftView.removeAllSubviews()
                } )
            default:
                break
            }
        default:
            self.endRevealState = nil
            failed( { [weak self] _ in
                self?.revealRightView.removeAllSubviews()
                self?.revealLeftView.removeAllSubviews()
            } )
        }
        //
    }
    
    deinit {
        peerInputActivitiesDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
       
        guard let item = item as? ChatListRowItem else { return }
        
        expandView?.frame = NSMakeRect(0, item.isCollapsed ? 0 : item.height, frame.width - .borderSize, frame.height)
        
        if let delta = internalDelta {
            moveReveal(delta: delta)
        } else {
            let additionalDelta: CGFloat
            if let state = endRevealState {
                switch state {
                case .left:
                    additionalDelta = -leftRevealWidth
                case .right:
                    additionalDelta = rightRevealWidth
                case .none:
                    additionalDelta = 0
                }
            } else {
                additionalDelta = 0
            }
            
            containerView.frame = NSMakeRect(-additionalDelta, item.isCollapsed ? -70 : 0, frame.width - .borderSize, 70)
            revealLeftView.frame = NSMakeRect(-leftRevealWidth - additionalDelta, 0, leftRevealWidth, frame.height)
            revealRightView.frame = NSMakeRect(frame.width - additionalDelta, 0, rightRevealWidth, frame.height)
            
            
            if let displayLayout = item.ctxDisplayLayout, let previewView = previewView {
                var offset: CGFloat = 0
                if let chatName = item.ctxChatNameLayout {
                    offset += chatName.0.size.height + 1
                }
                previewView.setFrameOrigin(NSMakePoint(item.leftInset, displayLayout.0.size.height + item.margin + 1 + offset))
            }
        }
    }
    
    
}
