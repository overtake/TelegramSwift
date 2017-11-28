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

class ChatListRowView: TableRowView {
    
    private var titleText:TextNode
    private var messageText:TextNode
    private var badgeView:View?
    private var activitiesModel:ChatActivitiesModel?
    private var photo:AvatarControl = AvatarControl(font: .avatar(.custom(22)))
    private var activeDragging:Bool = false
    private var hiddemMessage:Bool = false
    private let peerInputActivitiesDisposable:MetaDisposable = MetaDisposable()
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
                    self.needsDisplay = true
                } else if activitiesModel == nil {
                    activitiesModel = ChatActivitiesModel()
                    addSubview(activitiesModel!.view!)
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
                    self?.needsDisplay = true
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
    
    override var backdorColor: NSColor {
        if let item = item as? ChatListRowItem {
            if item.account.context.layout == .single, item.isSelected {
                return theme.chatList.singleLayoutSelectedBackgroundColor
            }
            if !item.isSelected && activeDragging {
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
        
        ctx.setFillColor(theme.colors.background.cgColor)
        ctx.fill(bounds)
        super.draw(layer, in: ctx)
//
         if let item = self.item as? ChatListRowItem {
        
            if(!item.isSelected) {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(item.pinnedType == .last ? 0 : item.leftInset, NSHeight(layer.bounds) - .borderSize, item.pinnedType == .last ? layer.frame.width : layer.bounds.width - item.leftInset, .borderSize))
                
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(layer.bounds.width - .borderSize, 0, .borderSize, NSHeight(self.frame)))
            }
            
            if let context = item.account.applicationContext as? TelegramApplicationContext {
                if context.layout == .minimisize {
                    return
                }
            }
            
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
                displayLayout.1.draw(NSMakeRect(item.leftInset + addition, item.margin - 1, displayLayout.0.size.width, displayLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                
                
                var mutedInset:CGFloat = item.isSecret ? theme.icons.secretImage.backingSize.width + 2 : 0
                
                if item.isVerified {
                    ctx.draw(highlighted ? theme.icons.verifiedImageSelected : theme.icons.verifiedImage, in: NSMakeRect(displayLayout.0.size.width + item.leftInset + addition + 2, item.margin + 1, theme.icons.verifiedImage.backingSize.width, theme.icons.verifiedImage.backingSize.height))
                    mutedInset += theme.icons.verifiedImage.backingSize.width + 3
                }
                
                if let messageLayout = item.ctxMessageLayout, !hiddemMessage {
                    messageLayout.1.draw(NSMakeRect(item.leftInset, displayLayout.0.size.height + item.margin + 1 , messageLayout.0.size.width, messageLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                }
                
                if item.isMuted {
                    ctx.draw(highlighted ? theme.icons.dialogMuteImageSelected : theme.icons.dialogMuteImage, in: NSMakeRect(item.leftInset + displayLayout.0.size.width + 4 + mutedInset, item.margin + round((displayLayout.0.size.height - theme.icons.dialogMuteImage.backingSize.height) / 2.0) - 1, theme.icons.dialogMuteImage.backingSize.width, theme.icons.dialogMuteImage.backingSize.height))
                }
                
                if let _ = item.mentionsCount {
                    ctx.draw(highlighted ? theme.icons.chatListMentionActive : theme.icons.chatListMention, in: NSMakeRect(frame.width - (item.ctxBadgeNode != nil ? item.ctxBadgeNode!.size.width + item.margin : 0) - theme.icons.chatListMentionActive.backingSize.width - item.margin, frame.height - theme.icons.chatListMention.backingSize.height - item.margin + 1, theme.icons.chatListMention.backingSize.width, theme.icons.chatListMention.backingSize.height))
                }
                
                if let dateLayout = item.ctxDateLayout, !item.hasDraft {
                    let dateX = frame.width - dateLayout.0.size.width - item.margin
                    dateLayout.1.draw(NSMakeRect(dateX, item.margin, dateLayout.0.size.width, dateLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                    
                    if item.isOutMessage {
                        if !item.isFailed {
                            if item.isSending {
                                let outX = dateX - theme.icons.sendingImage.backingSize.width - 4
                                ctx.draw(highlighted ? theme.icons.sendingImageSelected : theme.icons.sendingImage, in: NSMakeRect(outX,item.margin + 2, theme.icons.sendingImage.backingSize.width, theme.icons.sendingImage.backingSize.height))
                            } else {
                                let outX = dateX - theme.icons.outgoingMessageImage.backingSize.width - (item.isRead ? 4.0 : 0.0) - 2
                                ctx.draw(highlighted ? theme.icons.outgoingMessageImageSelected : theme.icons.outgoingMessageImage, in: NSMakeRect(outX, item.margin + 2, theme.icons.outgoingMessageImage.backingSize.width, theme.icons.outgoingMessageImage.backingSize.height))
                                if item.isRead {
                                    ctx.draw(highlighted ? theme.icons.readMessageImageSelected : theme.icons.readMessageImage, in: NSMakeRect(outX + 4, item.margin + 2, theme.icons.readMessageImage.backingSize.width, theme.icons.readMessageImage.backingSize.height))
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
       
        titleText = TextNode();
        messageText = TextNode();
        super.init(frame: frameRect)
        photo.userInteractionEnabled = false
        photo.frame = NSMakeRect(10, 8, 50, 50)
        addSubview(photo)
        self.registerForDraggedTypes([.tiff, .string, .kUrl, .kFilenames])
  
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if activeDragging {
            activeDragging = false
            needsDisplay = true
            let list = sender.draggingPasteboard().propertyList(forType: .kFilenames) as? [String]
            if let item = item as? ChatListRowItem, let context = item.account.applicationContext as? TelegramApplicationContext, let list = list {
                let list = list.filter { path -> Bool in
                    if let size = fileSize(path) {
                        return size <= 1500000000
                    }
                    
                    return false
                }
                if !list.isEmpty {
                    context.mainNavigation?.push(ChatController(account: item.account, peerId: item.peerId, initialAction: .files(list: list, behavior: .automatic)))
                }
            }
            return true
        }
        return false
    }
    
    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let item = item as? ChatListRowItem, let peer = item.peer, peer.canSendMessage {
            activeDragging = true
            needsDisplay = true
        }
        return .generic

    }
    
    override public func draggingExited(_ sender: NSDraggingInfo?) {
        activeDragging = false
        needsDisplay = true
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo?) {
        activeDragging = false
        needsDisplay = true
    }


    override func set(item:TableRowItem, animated:Bool = false) {
        
         super.set(item:item, animated:animated)
                
         if let item = self.item as? ChatListRowItem {
            
            if let peer = item.peer {
                if item.account.peerId == peer.id {
                    let icon = theme.icons.peerSavedMessages
                    photo.setSignal(generateEmptyPhoto(photo.frame.size, type: .icon(colors: (NSColor(0x2a9ef1), NSColor(0x72d5fd)), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photo.frame.size.width - 25, photo.frame.size.height - 25)))), animated: animated)
                } else {
                    photo.setPeer(account: item.account, peer: peer)
                }
            }
            
            if let badgeNode = item.ctxBadgeNode {
                if badgeView == nil {
                    badgeView = View()
                    addSubview(badgeView!)
                }
                badgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = badgeView
                badgeNode.setNeedDisplay()
            } else {
                badgeView?.removeFromSuperview()
                badgeView = nil
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
                            return postbox.modify { modifier -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let peer = modifier.getPeer(peerId) {
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
                        }
                    }))
                
                let inputActivities = self.inputActivities
                self.inputActivities = inputActivities
            }
            
            
         }
        
        needsDisplay = true
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
    }
    
    
    
}
