//
//  PeerInfoHeadItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import ColorPalette


fileprivate final class ActionButton : Control {
    fileprivate let imageView: ImageView = ImageView()
    fileprivate let textView: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        
        self.imageView.animates = true
        imageView.isEventLess = true
        textView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        set(handler: { control in
            control.change(opacity: 0.8, animated: true)
        }, for: .Highlight)
        
        set(handler: { control in
            control.change(opacity: 1.0, animated: true)
        }, for: .Normal)
        
        set(handler: { control in
            control.change(opacity: 1.0, animated: true)
        }, for: .Hover)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateAndLayout(item: ActionItem, theme: PresentationTheme) {
        self.imageView.image = item.image
        self.imageView.sizeToFit()
        self.textView.update(item.textLayout)
        
        self.backgroundColor = theme.colors.background
        self.layer?.cornerRadius = 10
        
        self.removeAllHandlers()
        if let subItems = item.subItems, !subItems.isEmpty {
            self.contextMenu = {
                let menu = ContextMenu()
                for sub in subItems {
                    let item = ContextMenuItem(sub.text, handler: sub.action, itemMode: sub.destruct ? .destruct : .normal, itemImage: sub.animation.value)
                    if sub.destruct {
                        menu.addItem(ContextSeparatorItem())
                    }
                    menu.addItem(item)
                }
                return menu
            }
        } else {
            self.contextMenu = nil
            self.set(handler: { [weak item] _ in
                item?.action()
            }, for: .Click)
        }
        
                
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 5)
        textView.centerX(y: frame.height - textView.frame.height - 11)
        
    }
}

extension TelegramPeerPhoto : Equatable {
    public static func ==(lhs: TelegramPeerPhoto, rhs: TelegramPeerPhoto) -> Bool {
        if lhs.date != rhs.date {
            return false
        }
        if !lhs.image.isEqual(to: rhs.image) {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.reference != rhs.reference {
            return false
        }
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        return true
    }
}

fileprivate let actionItemWidth: CGFloat = 135
fileprivate let actionItemInsetWidth: CGFloat = 19

private struct SubActionItem {
    let text: String
    let destruct: Bool
    let action:()->Void
    let animation: LocalAnimatedSticker
    init(text: String, animation: LocalAnimatedSticker, destruct: Bool = false, action:@escaping()->Void) {
        self.text = text
        self.animation = animation
        self.action = action
        self.destruct = destruct
    }
}

private final class ActionItem {
    let text: String
    let destruct: Bool
    let image: CGImage
    let action:()->Void
    let animation: LocalAnimatedSticker
    let subItems:[SubActionItem]?
    
    
    let textLayout: TextViewLayout
    let size: NSSize
    
    init(text: String, image: CGImage, animation: LocalAnimatedSticker, destruct: Bool = false, action: @escaping()->Void, subItems:[SubActionItem]? = nil) {
        self.text = text
        self.image = image
        self.action = action
        self.animation = animation
        self.subItems = subItems
        self.destruct = destruct
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.accent, font: .normal(.text)), alignment: .center)
        self.textLayout.measure(width: actionItemWidth)
        
        self.size = NSMakeSize(actionItemWidth, image.backingSize.height + textLayout.layoutSize.height + 10)
    }
    
}

private func actionItems(item: PeerInfoHeadItem, width: CGFloat, theme: TelegramPresentationTheme) -> [ActionItem] {
    
    var items:[ActionItem] = []
    
    var rowItemsCount: Int = 1
    
    while width - (actionItemWidth + actionItemInsetWidth) > ((actionItemWidth * CGFloat(rowItemsCount)) + (CGFloat(rowItemsCount - 1) * actionItemInsetWidth)) {
        rowItemsCount += 1
    }
    rowItemsCount = min(rowItemsCount, 4)
    
    
 
    if let peer = item.peer as? TelegramUser, let arguments = item.arguments as? UserInfoArguments {
        if !(item.peerView.peers[item.peerView.peerId] is TelegramSecretChat) {
            items.append(ActionItem(text: strings().peerInfoActionMessage, image: theme.icons.profile_message, animation: .menu_show_message, action: arguments.sendMessage))
        }
        if peer.canCall && peer.id != item.context.peerId, !isServicePeer(peer) && !peer.rawDisplayTitle.isEmpty {
            if let cachedData = item.peerView.cachedData as? CachedUserData, cachedData.voiceCallsAvailable {
                items.append(ActionItem(text: strings().peerInfoActionCall, image: theme.icons.profile_call, animation: .menu_call, action: {
                    arguments.call(false)
                }))
            }
        }
        
        let videoConfiguration: VideoCallsConfiguration = VideoCallsConfiguration(appConfiguration: item.context.appConfiguration)
        
        let isVideoPossible: Bool
        switch videoConfiguration.videoCallsSupport {
        case .disabled:
            isVideoPossible = false
        case .full:
            isVideoPossible = true
        case .onlyVideo:
            isVideoPossible = true
        }
        
        
        
        
        if peer.canCall && peer.id != item.context.peerId, !isServicePeer(peer) && !peer.rawDisplayTitle.isEmpty, isVideoPossible {
            if let cachedData = item.peerView.cachedData as? CachedUserData, cachedData.videoCallsAvailable {
                items.append(ActionItem(text: strings().peerInfoActionVideoCall, image: theme.icons.profile_video_call, animation: .menu_video_call, action: {
                    arguments.call(true)
                }))
            }
        }
        let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) ?? false
        items.append(ActionItem(text: value ? strings().peerInfoActionUnmute : strings().peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, animation: .menu_mute, action: {
            arguments.toggleNotifications(value)
        }))
        if !peer.isBot {
            if !(item.peerView.peers[item.peerView.peerId] is TelegramSecretChat), arguments.context.peerId != peer.id, !isServicePeer(peer) && !peer.rawDisplayTitle.isEmpty {
                items.append(ActionItem(text: strings().peerInfoActionSecretChat, image: theme.icons.profile_secret_chat, animation: .menu_lock, action: arguments.startSecretChat))
            }
            if peer.id != item.context.peerId, item.peerView.peerIsContact, peer.phone != nil {
                items.append(ActionItem(text: strings().peerInfoActionShare, image: theme.icons.profile_share, animation: .menu_forward, action: arguments.shareContact))
            }
            if peer.id != item.context.peerId, !peer.isPremium {
                if let cachedData = item.peerView.cachedData as? CachedUserData {
                    if !cachedData.premiumGiftOptions.isEmpty {
                        items.append(ActionItem(text: strings().peerInfoActionGiftPremium, image: theme.icons.profile_share, animation: .menu_gift, action: {
                            arguments.giftPremium(cachedData.premiumGiftOptions)
                        }))
                    }
                }
            }
            if peer.id != item.context.peerId, let cachedData = item.peerView.cachedData as? CachedUserData, item.peerView.peerIsContact {
                items.append(ActionItem(text: (!cachedData.isBlocked ? strings().peerInfoBlockUser : strings().peerInfoUnblockUser), image: !cachedData.isBlocked ? theme.icons.profile_block : theme.icons.profile_unblock, animation: cachedData.isBlocked ? .menu_unblock : .menu_restrict, destruct: true, action: {
                    arguments.updateBlocked(peer: peer, !cachedData.isBlocked, false)
                }))
            }
        } else if let botInfo = peer.botInfo {
            
            if let address = peer.addressName, !address.isEmpty {
                items.append(ActionItem(text: strings().peerInfoBotShare, image: theme.icons.profile_share, animation: .menu_forward, action: {
                    arguments.botShare(address)
                }))
            }
            
            if botInfo.flags.contains(.worksWithGroups) {
                items.append(ActionItem(text: strings().peerInfoBotAddToGroup, image: theme.icons.profile_more, animation: .menu_plus, action: arguments.botAddToGroup))
            }
           
            if let cachedData = item.peerView.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                for command in botInfo.commands {
                    if command.text == "settings" {
                        items.append(ActionItem(text: strings().peerInfoBotSettings, image: theme.icons.profile_more, animation: .menu_plus, action: arguments.botSettings))
                    }
                    if command.text == "help" {
                        items.append(ActionItem(text: strings().peerInfoBotHelp, image: theme.icons.profile_more, animation: .menu_plus, action: arguments.botHelp))
                    }
                    if command.text == "privacy" {
                        items.append(ActionItem(text: strings().peerInfoBotPrivacy, image: theme.icons.profile_more, animation: .menu_plus, action: arguments.botPrivacy))
                    }
                }
                items.append(ActionItem(text: !cachedData.isBlocked ? strings().peerInfoStopBot : strings().peerInfoRestartBot, image: theme.icons.profile_more, animation: .menu_restrict, destruct: true, action: {
                    arguments.updateBlocked(peer: peer, !cachedData.isBlocked, true)
                }))
            }
        }
        
    } else if let peer = item.peer, peer.isSupergroup || peer.isGroup, let arguments = item.arguments as? GroupInfoArguments {
        let access = peer.groupAccess
        
        if access.canAddMembers {
            items.append(ActionItem(text: strings().peerInfoActionAddMembers, image: theme.icons.profile_add_member, animation: .menu_plus, action: {
                arguments.addMember(access.canCreateInviteLink)
            }))
        }
        if let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) {
            items.append(ActionItem(text: value ? strings().peerInfoActionUnmute : strings().peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, animation: value ? .menu_unmuted : .menu_mute, action: {
                arguments.toggleNotifications(value)
            }))
        }
        
        
        if let cachedData = item.peerView.cachedData as? CachedChannelData, let peer = peer as? TelegramChannel {
            if peer.groupAccess.canMakeVoiceChat {
                let isLiveStream = peer.isChannel || peer.flags.contains(.isGigagroup)
                items.append(ActionItem(text: isLiveStream ? strings().peerInfoActionLiveStream : strings().peerInfoActionVoiceChat, image: theme.icons.profile_voice_chat, animation: .menu_video_chat, action: {
                    arguments.makeVoiceChat(cachedData.activeCall, callJoinPeerId: cachedData.callJoinPeerId)
                }))
            }
        } else if let cachedData = item.peerView.cachedData as? CachedGroupData {
            if peer.groupAccess.canMakeVoiceChat {
                items.append(ActionItem(text: strings().peerInfoActionVoiceChat, image: theme.icons.profile_voice_chat, animation: .menu_call, action: {
                    arguments.makeVoiceChat(cachedData.activeCall, callJoinPeerId: cachedData.callJoinPeerId)
                }))
            }
        }
        
        if let cachedData = item.peerView.cachedData as? CachedChannelData {
            if cachedData.statsDatacenterId > 0, cachedData.flags.contains(.canViewStats) {
                items.append(ActionItem(text: strings().peerInfoActionStatistics, image: theme.icons.profile_stats, animation: .menu_statistics, action: {
                    arguments.stats(cachedData.statsDatacenterId)
                }))
            }
        }
        if access.canReport {
            items.append(ActionItem(text: strings().peerInfoActionReport, image: theme.icons.profile_report, animation: .menu_report, destruct: false, action: arguments.report))
        }
        
        
        if let group = peer as? TelegramGroup {
            if case .Member = group.membership {
                items.append(ActionItem(text: strings().peerInfoActionLeave, image: theme.icons.profile_leave, animation: .menu_leave, destruct: true, action: arguments.delete))
            }
        } else if let group = peer as? TelegramChannel {
            if case .member = group.participationStatus {
                items.append(ActionItem(text: strings().peerInfoActionLeave, image: theme.icons.profile_leave, animation: .menu_delete, destruct: true, action: arguments.delete))
            }
        }
        
        
        
    } else if let peer = item.peer as? TelegramChannel, peer.isChannel, let arguments = item.arguments as? ChannelInfoArguments {
        if let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) {
            items.append(ActionItem(text: value ? strings().peerInfoActionUnmute : strings().peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, animation: value ? .menu_unmuted : .menu_mute, action: {
                arguments.toggleNotifications(value)
            }))
        }
        
        
        if let cachedData = item.peerView.cachedData as? CachedChannelData {
            
            switch cachedData.linkedDiscussionPeerId {
            case let .known(peerId):
                if let peerId = peerId {
                    items.append(ActionItem(text: strings().peerInfoActionDiscussion, image: theme.icons.profile_message, animation: .menu_show_message, action: { [weak arguments] in
                        arguments?.peerChat(peerId)
                    }))
                }
            default:
                break
            }
            
            if cachedData.statsDatacenterId > 0, cachedData.flags.contains(.canViewStats) {
                items.append(ActionItem(text: strings().peerInfoActionStatistics, image: theme.icons.profile_stats, animation: .menu_statistics, action: {
                    arguments.stats(cachedData.statsDatacenterId)
                }))
            }
        }
        if let cachedData = item.peerView.cachedData as? CachedChannelData {
            if peer.groupAccess.canMakeVoiceChat {
                items.append(ActionItem(text: strings().peerInfoActionVoiceChat, image: theme.icons.profile_voice_chat, animation: .menu_call, action: {
                    arguments.makeVoiceChat(cachedData.activeCall, callJoinPeerId: cachedData.callJoinPeerId)
                }))
            }
        }
        if let address = peer.addressName, !address.isEmpty {
            items.append(ActionItem(text: strings().peerInfoActionShare, image: theme.icons.profile_share, animation: .menu_share, action: arguments.share))
        }
    
        if peer.groupAccess.canReport {
            items.append(ActionItem(text: strings().peerInfoActionReport, image: theme.icons.profile_report, animation: .menu_report, action: arguments.report))
        }
        
        
        switch peer.participationStatus {
        case .member:
            items.append(ActionItem(text: strings().peerInfoActionLeave, image: theme.icons.profile_leave, animation: .menu_leave, destruct: true, action: arguments.delete))
        default:
            break
        }
    } else if let arguments = item.arguments as? TopicInfoArguments, let data = arguments.threadData {
        
        let value = data.notificationSettings.isMuted
        
        items.append(ActionItem(text: value ? strings().peerInfoActionUnmute : strings().peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, animation: .menu_mute, action: {
            arguments.toggleNotifications(value)
        }))
        
        items.append(ActionItem(text: strings().peerInfoActionShare, image: theme.icons.profile_share, animation: .menu_share, action: arguments.share))

    }
    
    
    if items.count > rowItemsCount {
        var subItems:[SubActionItem] = []
        while items.count > rowItemsCount - 1 {
            let item = items.removeLast()
            subItems.insert(SubActionItem(text: item.text, animation: item.animation, destruct: item.destruct, action: item.action), at: 0)
        }
        if !subItems.isEmpty {
            items.append(ActionItem(text: strings().peerInfoActionMore, image: theme.icons.profile_more, animation: .menu_plus, action: { }, subItems: subItems))
        }
    }
    
    return items
}

class PeerInfoHeadItem: GeneralRowItem {
    override var height: CGFloat {
        let insets = self.viewType.innerInset
        var height: CGFloat = 0
        
        if !editing {
            height = photoDimension + insets.top + insets.bottom + nameLayout.layoutSize.height + statusLayout.layoutSize.height + insets.bottom
            
            if !items.isEmpty {
                let maxActionSize: NSSize = items.max(by: { $0.size.height < $1.size.height })!.size
                height += maxActionSize.height + insets.top
            }
        } else {
            height = photoDimension + insets.top + insets.bottom
        }
        return height
    }
    
    fileprivate var photoDimension:CGFloat {
        return self.threadData != nil ? 60 : 120
    }

    
    fileprivate var statusLayout: TextViewLayout
    fileprivate var nameLayout: TextViewLayout
    
    
    let context: AccountContext
    let peer:Peer?
    let isVerified: Bool
    let isPremium: Bool
    let isScam: Bool
    let isFake: Bool
    let isMuted: Bool
    let peerView:PeerView
    var result:PeerStatusStringResult {
        didSet {
            nameLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
            nameLayout.interactions = globalLinkExecutor
            statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1, alwaysStaticItems: true)
        }
    }
    
    private(set) fileprivate var items: [ActionItem] = []
    
    private let fetchPeerAvatar = DisposableSet()
    private let onlineMemberCountDisposable = MetaDisposable()
    
    fileprivate let editing: Bool
    fileprivate let updatingPhotoState:PeerInfoUpdatingPhotoState?
    fileprivate let updatePhoto:(NSImage?, Control?)->Void
    fileprivate let arguments: PeerInfoArguments
    fileprivate let threadData: MessageHistoryThreadData?

    let canEditPhoto: Bool
    
    
    let peerPhotosDisposable = MetaDisposable()
    
    var photos: [TelegramPeerPhoto] = []
    init(_ initialSize:NSSize, stableId:AnyHashable, context: AccountContext, arguments: PeerInfoArguments, peerView:PeerView, threadData: MessageHistoryThreadData?, viewType: GeneralViewType, editing: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, updatePhoto:@escaping(NSImage?, Control?)->Void = { _, _ in }) {
        let peer = peerViewMainPeer(peerView)
        self.peer = peer
        self.threadData = threadData
        self.peerView = peerView
        self.context = context
        self.editing = editing
        self.arguments = arguments
        self.isVerified = peer?.isVerified ?? false
        self.isPremium = peer?.isPremium ?? false
        self.isScam = peer?.isScam ?? false
        self.isFake = peer?.isFake ?? false
        self.isMuted = peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) ?? false
        self.updatingPhotoState = updatingPhotoState
        self.updatePhoto = updatePhoto
        
        
        let canEditPhoto: Bool
        if let _ = peer as? TelegramUser {
            canEditPhoto = false
        } else if let _ = peer as? TelegramSecretChat {
            canEditPhoto = false
        } else if let peer = peer as? TelegramGroup {
            canEditPhoto = peer.groupAccess.canEditGroupInfo
        } else if let peer = peer as? TelegramChannel {
            canEditPhoto = peer.groupAccess.canEditGroupInfo
        } else {
            canEditPhoto = false
        }
        
        self.canEditPhoto = canEditPhoto && editing
        
        if let peer = peer, threadData == nil {
            if let peerReference = PeerReference(peer) {
                if let largeProfileImage = peer.largeProfileImage {
                    fetchPeerAvatar.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: largeProfileImage.resource)).start())
                }
                if let smallProfileImage = peer.smallProfileImage {
                    fetchPeerAvatar.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource)).start())
                }
            }
        }
        var result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.huge), highlightIfActivity: false), expanded: true)
        
        if let threadData = threadData {
            result = result
                .withUpdatedTitle(threadData.info.title)
                .withUpdatedStatus(strings().peerInfoTopicStatusIn(peer?.displayTitle ?? ""))
        }

        self.result = result
        
        
        nameLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
        statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        
        if let cachedData = peerView.cachedData as? CachedChannelData, threadData == nil {
            let onlineMemberCount:Signal<Int32?, NoError>
            if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: peerView.peerId) |> map(Optional.init) |> deliverOnMainQueue
            } else {
                onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: peerView.peerId)  |> map(Optional.init) |> deliverOnMainQueue
            }
            self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                guard let `self` = self else {
                    return
                }
                var result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.huge)), onlineMemberCount: count)
                if let threadData = threadData {
                    result = result.withUpdatedTitle(threadData.info.title)
                    result = result.withUpdatedStatus(strings().peerInfoTopicStatusIn(peer?.displayTitle ?? ""))
                }
                if result != self.result {
                    self.result = result
                    _ = self.makeSize(self.width, oldWidth: 0)
                    self.redraw(animated: true, options: .effectFade)
                }
            }))
        }
        
        _ = self.makeSize(initialSize.width, oldWidth: 0)
        
        
        if let peer = peer, threadData == nil, peer.hasVideo {
            self.photos = syncPeerPhotos(peerId: peer.id)
            let signal = peerPhotos(context: context, peerId: peer.id) |> deliverOnMainQueue
            var first: Bool = true
            peerPhotosDisposable.set(signal.start(next: { [weak self] photos in
                if self?.photos != photos {
                    self?.photos = photos
                    if !first {
                        self?.redraw(animated: true, options: .effectFade)
                    }
                    first = false
                }
            }))
        }
    }
   
    var isForum: Bool {
        return self.peer?.isForum == true
    }
    var isTopic: Bool {
        return self.isForum && threadData != nil
    }
    
    deinit {
        fetchPeerAvatar.dispose()
        onlineMemberCountDisposable.dispose()
    }

    override func viewClass() -> AnyClass {
        return PeerInfoHeadView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        
        self.items = editing ? [] : actionItems(item: self, width: blockWidth, theme: theme)
        var textWidth = blockWidth - viewType.innerInset.right - viewType.innerInset.left - 10
        if let peer = peer, let controlSize = PremiumStatusControl.controlSize(peer, true) {
            textWidth -= (controlSize.width + 5)
        }
        nameLayout.measure(width: textWidth)
        statusLayout.measure(width: textWidth)

        return success
    }

    
    var stateText: String? {
        if isScam {
            return strings().peerInfoScamWarning
        } else if isFake {
            return strings().peerInfoFakeWarning
        } else if isVerified {
            return strings().peerInfoVerifiedTooltip
        } else if isPremium {
            return strings().peerInfoPremiumTooltip
        }
        return nil
    }
    

    
    fileprivate var nameSize: NSSize {
        var stateHeight: CGFloat = 0
        if let peer = peer, let size = PremiumStatusControl.controlSize(peer, true) {
            stateHeight = max(size.height + 4, nameLayout.layoutSize.height)
        } else {
            stateHeight = nameLayout.layoutSize.height
        }
        var width = nameLayout.layoutSize.width
        if let peer = peer, let size = PremiumStatusControl.controlSize(peer, true)  {
            width += size.width + 5
        }
        return NSMakeSize(width, stateHeight)
    }
    
}

private final class PeerInfoPhotoEditableView : Control {
    private let backgroundView = View()
    private let camera: ImageView = ImageView()
    private var progressView:RadialProgressContainerView?
    private var updatingPhotoState: PeerInfoUpdatingPhotoState?
    private var tempImageView: ImageView?
    var setup: ((NSImage?, Control?)->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(backgroundView)
        addSubview(camera)
        
        camera.image = theme.icons.profile_edit_photo
        camera.sizeToFit()
        camera.center()
        
        camera.isEventLess = true
        
        backgroundView.isEventLess = true
        
        set(handler: { [weak self] _ in
            if self?.updatingPhotoState == nil {
                self?.backgroundView.change(opacity: 0.8, animated: true)
                self?.camera.change(opacity: 0.8, animated: true)
            }
        }, for: .Highlight)
        
        set(handler: { [weak self] _ in
            if self?.updatingPhotoState == nil {
                self?.backgroundView.change(opacity: 1.0, animated: true)
                self?.camera.change(opacity: 1.0, animated: true)
            }
        }, for: .Normal)
        
        set(handler: { [weak self] _ in
            if self?.updatingPhotoState == nil {
                self?.backgroundView.change(opacity: 1.0, animated: true)
                self?.camera.change(opacity: 1.0, animated: true)
            }
        }, for: .Hover)
        
        backgroundView.backgroundColor = .blackTransparent
        backgroundView.frame = bounds
        
        
        set(handler: { [weak self] control in
            if self?.updatingPhotoState == nil {
                self?.setup?(nil, control)
            }
        }, for: .Click)
    }
    
    func updateState(_ updatingPhotoState: PeerInfoUpdatingPhotoState?, animated: Bool) {
        self.updatingPhotoState = updatingPhotoState
        
        userInteractionEnabled = updatingPhotoState == nil
        
        self.camera.change(opacity: updatingPhotoState == nil ? 1.0 : 0.0, animated: true)
        
        if let uploadState = updatingPhotoState {
            if self.progressView == nil {
                self.progressView = RadialProgressContainerView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
                self.progressView!.frame = bounds
                progressView?.proggressBackground.backgroundColor = .clear
                self.addSubview(progressView!)
            }
            progressView?.progress.fetchControls = FetchControls(fetch: {
                updatingPhotoState?.cancel()
            })
            progressView?.progress.state = .Fetching(progress: uploadState.progress, force: false)
            
            if let _ = uploadState.image, self.tempImageView == nil {
                self.tempImageView = ImageView()
                self.tempImageView?.contentGravity = .resizeAspect
                self.tempImageView!.frame = bounds
                self.addSubview(tempImageView!, positioned: .below, relativeTo: backgroundView)
                if animated {
                    self.tempImageView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            self.tempImageView?.image = uploadState.image
        } else {
            if let progressView = self.progressView {
                self.progressView = nil
                if animated {
                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressView] _ in
                        progressView?.removeFromSuperview()
                    })
                } else {
                    progressView.removeFromSuperview()
                }
            }
            if let tempImageView = self.tempImageView {
                self.tempImageView = nil
                if animated {
                    tempImageView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak tempImageView] _ in
                        tempImageView?.removeFromSuperview()
                    })
                } else {
                    tempImageView.removeFromSuperview()
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class NameContainer : View {
    let nameView = TextView()
    var statusControl: PremiumStatusControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(nameView)
    }
    
    func update(_ item: PeerInfoHeadItem, animated: Bool) {
        self.nameView.update(item.nameLayout)
        let context = item.context
        
        if let peer = item.peer {
            let control = PremiumStatusControl.control(peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, isSelected: false, isBig: true, cached: self.statusControl, animated: animated)
            if let control = control {
                self.statusControl = control
                self.addSubview(control)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: animated)
                self.statusControl = nil
            }
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        if let stateText = item.stateText, let control = statusControl, let peerId = item.peer?.id {
            control.userInteractionEnabled = true
            control.scaleOnClick = true
            control.set(handler: { control in
                if item.peer?.emojiStatus != nil {
                    showModal(with: PremiumBoardingController(context: context, source: .profile(peerId)), for: context.window)
                } else {
                    let attr = parseMarkdownIntoAttributedString(stateText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: .white), bold: MarkdownAttributeSet(font: .bold(.text), textColor: .white), link: MarkdownAttributeSet(font: .normal(.text), textColor: nightAccentPalette.link), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, contents)
                    }))
                    if !context.premiumIsBlocked {
                        let interactions = TextViewInteractions(processURL: { content in
                            if let content = content as? String {
                                if content == "premium" {
                                    showModal(with: PremiumBoardingController(context: context, source: .profile(peerId)), for: context.window)
                                }
                            }
                        })
                        tooltip(for: control, text: "", attributedText: attr, interactions: interactions)
                    }
                }
            }, for: .Click)
        } else {
            statusControl?.scaleOnClick = false
            statusControl?.userInteractionEnabled = false
        }
             
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        nameView.centerY(x: 0)
        if let control = statusControl {
            control.centerY(x: nameView.frame.maxX + 5, addition: -1)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class PeerInfoHeadView : GeneralContainableRowView {
    private let photoView: AvatarControl = AvatarControl(font: .avatar(30))
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?

    
    
    private let nameView = NameContainer(frame: .zero)
    private let statusView = TextView()
    private let actionsView = View()
    private var photoEditableView: PeerInfoPhotoEditableView?
    
    
    private var activeDragging: Bool = false {
        didSet {
            self.item?.redraw(animated: true)
        }
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? PeerInfoHeadItem else {
            return super.backdorColor
        }
        return item.editing ? super.backdorColor : .clear
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        
        addSubview(photoView)
        addSubview(nameView)
        addSubview(statusView)
        addSubview(actionsView)
        
        photoView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHeadItem, let peer = item.peer, let _ = peer.largeProfileImage {
                showPhotosGallery(context: item.context, peerId: peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
         registerForDraggedTypes([.tiff, .string, .kUrl, .kFileUrl])
    }
    
    
    override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if activeDragging {
            activeDragging = false
            if let item = item as? PeerInfoHeadItem {
                if let tiff = sender.draggingPasteboard.data(forType: .tiff), let image = NSImage(data: tiff) {
                    item.updatePhoto(image, self.photoEditableView)
                    return true
                } else {
                    let list = sender.draggingPasteboard.propertyList(forType: .kFilenames) as? [String]
                    if  let list = list {
                        if let first = list.first, let image = NSImage(contentsOfFile: first) {
                            item.updatePhoto(image, self.photoEditableView)
                            return true
                        }
                    }
                }
            }
        }
         return false
    }
    
    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let item = item as? PeerInfoHeadItem, !item.editing, let peer = item.peer, peer.groupAccess.canEditGroupInfo {
            if let tiff = sender.draggingPasteboard.data(forType: .tiff), let _ = NSImage(data: tiff) {
                activeDragging = true
            } else {
                let list = sender.draggingPasteboard.propertyList(forType: .kFilenames) as? [String]
                if let list = list {
                    let list = list.filter { path -> Bool in
                        if let size = fs(path) {
                            return size <= 5 * 1024 * 1024
                        }
                        return false
                    }
                    activeDragging = list.count == 1 && NSImage(contentsOfFile: list[0]) != nil
                } else {
                    activeDragging = false
                }
            }
            
        } else {
            activeDragging = false
        }
        return .generic
    }
    override public func draggingExited(_ sender: NSDraggingInfo?) {
        activeDragging = false
    }
    public override func draggingEnded(_ sender: NSDraggingInfo) {
        activeDragging = false
    }
    
    @objc func updatePlayerIfNeeded() {
        let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !isDynamicContentLocked
        if let photoVideoPlayer = photoVideoPlayer {
            if accept {
                photoVideoPlayer.play()
            } else {
                photoVideoPlayer.pause()
            }
        }
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        photoVideoPlayer?.seek(timestamp: 0)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
        updatePlayerIfNeeded()
        updateAnimatableContent()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateListeners()
        updatePlayerIfNeeded()
        updateAnimatableContent()

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
    
    
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PeerInfoHeadItem else {
            return
        }
        
        photoView.centerX(y: item.viewType.innerInset.top)
        nameView.centerX(y: photoView.frame.maxY + item.viewType.innerInset.top)
        statusView.centerX(y: nameView.frame.maxY + 4)
        actionsView.centerX(y: containerView.frame.height - actionsView.frame.height)
        photoEditableView?.centerX(y: item.viewType.innerInset.top)
        
        photoVideoView?.frame = photoView.frame
        
        if let photo = self.inlineTopicPhotoLayer {
            photo.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, containerView.frame.width - item.photoDimension) / 2, item.viewType.innerInset.top, item.photoDimension, item.photoDimension)

        }

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layoutActionItems(_ items: [ActionItem], animated: Bool) {
        
        if !items.isEmpty {
            let maxActionSize: NSSize = items.max(by: { $0.size.height < $1.size.height })!.size
            
            
            while actionsView.subviews.count > items.count {
                actionsView.subviews.removeLast()
            }
            while actionsView.subviews.count < items.count {
                actionsView.addSubview(ActionButton(frame: .zero))
            }
            
            let inset: CGFloat = 0
            
            actionsView.change(size: NSMakeSize(actionItemWidth * CGFloat(items.count) + CGFloat(items.count - 1) * actionItemInsetWidth, maxActionSize.height), animated: animated)
            
            var x: CGFloat = inset
            
            for (i, item) in items.enumerated() {
                let view = actionsView.subviews[i] as! ActionButton
                view.updateAndLayout(item: item, theme: theme)
                view.setFrameSize(NSMakeSize(item.size.width, maxActionSize.height))
                view.change(pos: NSMakePoint(x, 0), animated: false)
                x += maxActionSize.width + actionItemInsetWidth
            }
            
        } else {
            actionsView.removeAllSubviews()
        }
        
    }
    
    private var videoRepresentation: TelegramMediaImage.VideoRepresentation?
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerInfoHeadItem else {
            return
        }
        
        photoView.setFrameSize(NSMakeSize(item.photoDimension, item.photoDimension))
        photoView.setPeer(account: item.context.account, peer: item.peer)

        updatePhoto(item, animated: animated)
        
        photoView.isHidden = item.isTopic
        
        if !item.photos.isEmpty {
            
            if let first = item.photos.first, let video = first.image.videoRepresentations.last, item.updatingPhotoState == nil {
               
                let equal = videoRepresentation?.resource.id == video.resource.id
                
                if !equal {
                    
                    self.photoVideoView?.removeFromSuperview()
                    self.photoVideoView = nil
                    
                    self.photoVideoView = MediaPlayerView(backgroundThread: true)
                    if let photoEditableView = self.photoEditableView {
                        self.addSubview(self.photoVideoView!, positioned: .below, relativeTo: photoEditableView)
                    } else {
                        self.addSubview(self.photoVideoView!)

                    }
                    self.photoVideoView!.isEventLess = true
                    
                    self.photoVideoView!.frame = self.photoView.frame

                    
                    let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                    
                    
                    let reference: MediaResourceReference
                    
                    if let peer = item.peer, let peerReference = PeerReference(peer) {
                        reference = MediaResourceReference.avatar(peer: peerReference, resource: file.resource)
                    } else {
                        reference = MediaResourceReference.standalone(resource: file.resource)
                    }
                    
                    let mediaPlayer = MediaPlayer(postbox: item.context.account.postbox, reference: reference, streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                    
                    mediaPlayer.actionAtEnd = .loop(nil)
                    
                    self.photoVideoPlayer = mediaPlayer
                    
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
                self.videoRepresentation = nil
            }
        } else {
            self.photoVideoPlayer = nil
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
            self.videoRepresentation = nil
        }
        
        
        self.photoVideoView?.layer?.cornerRadius = item.isForum ? self.photoView.frame.height / 3 : self.photoView.frame.height / 2
        
        nameView.change(size: item.nameSize, animated: animated)
        nameView.update(item, animated: animated)
        nameView.change(pos: NSMakePoint(containerView.focus(item.nameSize).minX, nameView.frame.minY), animated: animated)
        
        statusView.update(item.statusLayout)
        
        layoutActionItems(item.items, animated: animated)
        
        
        photoView.userInteractionEnabled = !item.editing
        
        let containerRect: NSRect
        switch item.viewType {
        case .legacy:
            containerRect = self.bounds
        case .modern:
            containerRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, item.height - item.inset.bottom - item.inset.top)
        }

        
        if item.canEditPhoto || self.activeDragging || item.updatingPhotoState != nil {
            if photoEditableView == nil {
                photoEditableView = .init(frame: NSMakeRect(0, 0, item.photoDimension, item.photoDimension))
                addSubview(photoEditableView!)
                if animated {
                    photoEditableView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            photoEditableView?.layer?.cornerRadius = item.isForum ? item.photoDimension / 3 : item.photoDimension / 2
            
            photoEditableView?.updateState(item.updatingPhotoState, animated: animated)
            photoEditableView?.setup = item.updatePhoto
        } else {
            if let photoEditableView = self.photoEditableView {
                self.photoEditableView = nil
                if animated {
                    photoEditableView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak photoEditableView] _ in
                        photoEditableView?.removeFromSuperview()
                    })
                } else {
                    photoEditableView.removeFromSuperview()
                }
            }
        }
        
        containerView.change(size: containerRect.size, animated: animated)
        containerView.change(pos: containerRect.origin, animated: animated)
        containerView.setCorners(item.viewType.corners, animated: animated)
        borderView._change(opacity: item.viewType.hasBorder ? 1.0 : 0.0, animated: animated)
        
        needsLayout = true
        updateListeners()
    }
    
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return photoView
    }
    
    override func copy() -> Any {
        return photoView.copy()
    }
    
    private var inlineTopicPhotoLayer: InlineStickerItemLayer?

    private func updatePhoto(_ item: PeerInfoHeadItem, animated: Bool) {
        let context = item.context
        
        if let threadData = item.threadData {
            let size = NSMakeSize(item.photoDimension, item.photoDimension)
            let current: InlineStickerItemLayer
            if let layer = self.inlineTopicPhotoLayer, layer.file?.fileId.id == threadData.info.icon {
                current = layer
            } else {
                if let layer = inlineTopicPhotoLayer {
                    performSublayerRemoval(layer, animated: animated)
                    self.inlineTopicPhotoLayer = nil
                }
                let info = threadData.info
                if let fileId = info.icon {
                    current = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .loop)
                } else {
                    let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor)
                    current = .init(account: context.account, file: file, size: size, playPolicy: .loop)
                }
                current.superview = containerView
                self.containerView.layer?.addSublayer(current)
                self.inlineTopicPhotoLayer = current
            }
        } else {
            if let layer = inlineTopicPhotoLayer {
                performSublayerRemoval(layer, animated: animated)
                self.inlineTopicPhotoLayer = nil
            }
        }
        self.updateAnimatableContent()
    }
    



    override func updateAnimatableContent() -> Void {
        let checkValue:(InlineStickerItemLayer)->Void = { value in
            if let superview = value.superview {
                var isKeyWindow: Bool = false
                if let window = superview.window {
                    if !window.canBecomeKey {
                        isKeyWindow = true
                    } else {
                        isKeyWindow = window.isKeyWindow
                    }
                }
                value.isPlayable = superview.visibleRect != .zero && isKeyWindow
            }
        }
        if let value = inlineTopicPhotoLayer {
            checkValue(value)
        }
    }
        
}
