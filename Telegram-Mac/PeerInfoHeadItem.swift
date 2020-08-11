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
import SyncCore


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
        _ = self.imageView.sizeToFit()
        self.textView.update(item.textLayout)
        
        self.removeAllHandlers()
        if let subItems = item.subItems {
            self.set(handler: { control in
                showPopover(for: control, with: SPopoverViewController(items: subItems.map { SPopoverItem($0.text, $0.action, nil, $0.destruct ? theme.colors.redUI : theme.colors.text) }, visibility: 10), edge: .maxY, inset: NSMakePoint(-33, -60))
            }, for: .Down)
        } else {
            self.set(handler: { [weak item] _ in
                item?.action()
            }, for: .Click)
        }
        
                
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 0)
        
        let bottomInset = floorToScreenPixels(backingScaleFactor, ((frame.height - imageView.frame.maxY - 10) - textView.frame.height) / 2)
        textView.centerX(y: (imageView.frame.maxY + 10) + bottomInset)
    }
}

fileprivate let photoDimension:CGFloat = 100
fileprivate let actionItemWidth: CGFloat = 70
fileprivate let actionItemInsetWidth: CGFloat = 20

private struct SubActionItem {
    let text: String
    let destruct: Bool
    let action:()->Void
    init(text: String, destruct: Bool = false, action:@escaping()->Void) {
        self.text = text
        self.action = action
        self.destruct = destruct
    }
}

private final class ActionItem {
    let text: String
    let destruct: Bool
    let image: CGImage
    let action:()->Void
    
    let subItems:[SubActionItem]?
    
    
    let textLayout: TextViewLayout
    let size: NSSize
    
    init(text: String, image: CGImage, destruct: Bool = false, action: @escaping()->Void, subItems:[SubActionItem]? = nil) {
        self.text = text
        self.image = image
        self.action = action
        self.subItems = subItems
        self.destruct = destruct
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.accent, font: .normal(.text)), alignment: .center)
        self.textLayout.measure(width: actionItemWidth)
        
        self.size = NSMakeSize(actionItemWidth, image.backingSize.height + 10 + textLayout.layoutSize.height)
    }
    
}

private func actionItems(item: PeerInfoHeadItem, width: CGFloat, theme: TelegramPresentationTheme) -> [ActionItem] {
    
    var items:[ActionItem] = []
    
    var rowItemsCount: Int = 1
    
    while width - actionItemWidth * 2 > actionItemWidth * CGFloat(rowItemsCount) + CGFloat(rowItemsCount + 1) * actionItemInsetWidth {
        rowItemsCount += 1
    }
    rowItemsCount = min(rowItemsCount, 4)
    
    
 
    if let peer = item.peer as? TelegramUser, let arguments = item.arguments as? UserInfoArguments {
        if !(item.peerView.peers[item.peerView.peerId] is TelegramSecretChat) {
            items.append(ActionItem(text: L10n.peerInfoActionMessage, image: theme.icons.profile_message, action: arguments.sendMessage))
        }
        if peer.canCall && peer.id != item.context.peerId, !isServicePeer(peer) && !peer.rawDisplayTitle.isEmpty {
            if let cachedData = item.peerView.cachedData as? CachedUserData, cachedData.voiceCallsAvailable {
                items.append(ActionItem(text: L10n.peerInfoActionCall, image: theme.icons.profile_call, action: {
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
                items.append(ActionItem(text: L10n.peerInfoActionVideoCall, image: theme.icons.profile_video_call, action: {
                    arguments.call(true)
                }))
            }
        }
        let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) ?? false
        items.append(ActionItem(text: value ? L10n.peerInfoActionUnmute : L10n.peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, action: arguments.toggleNotifications))
        if !peer.isBot {
            if !(item.peerView.peers[item.peerView.peerId] is TelegramSecretChat), arguments.context.peerId != peer.id, !isServicePeer(peer) && !peer.rawDisplayTitle.isEmpty {
                items.append(ActionItem(text: L10n.peerInfoActionSecretChat, image: theme.icons.profile_secret_chat, action: arguments.startSecretChat))
            }
            if peer.id != item.context.peerId, item.peerView.peerIsContact {
                items.append(ActionItem(text: L10n.peerInfoActionShare, image: theme.icons.profile_share, action: arguments.shareContact))
            }
            if peer.id != item.context.peerId, let cachedData = item.peerView.cachedData as? CachedUserData, item.peerView.peerIsContact {
                items.append(ActionItem(text: (!cachedData.isBlocked ? L10n.peerInfoBlockUser : L10n.peerInfoUnblockUser), image: !cachedData.isBlocked ? theme.icons.profile_block : theme.icons.profile_unblock, destruct: true, action: {
                    arguments.updateBlocked(peer: peer, !cachedData.isBlocked, false)
                }))
            }
        } else if let botInfo = peer.botInfo {
            
            if let address = peer.addressName, !address.isEmpty {
                items.append(ActionItem(text: L10n.peerInfoBotShare, image: theme.icons.profile_share, action: {
                    arguments.botShare(address)
                }))
            }
            
            if botInfo.flags.contains(.worksWithGroups) {
                items.append(ActionItem(text: L10n.peerInfoBotAddToGroup, image: theme.icons.profile_more, action: arguments.botAddToGroup))
            }
           
            if let cachedData = item.peerView.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                for command in botInfo.commands {
                    if command.text == "settings" {
                        items.append(ActionItem(text: L10n.peerInfoBotSettings, image: theme.icons.profile_more, action: arguments.botSettings))
                    }
                    if command.text == "help" {
                        items.append(ActionItem(text: L10n.peerInfoBotHelp, image: theme.icons.profile_more, action: arguments.botHelp))
                    }
                    if command.text == "privacy" {
                        items.append(ActionItem(text: L10n.peerInfoBotPrivacy, image: theme.icons.profile_more, action: arguments.botPrivacy))
                    }
                }
                items.append(ActionItem(text: !cachedData.isBlocked ? L10n.peerInfoStopBot : L10n.peerInfoRestartBot, image: theme.icons.profile_more, destruct: true, action: {
                    arguments.updateBlocked(peer: peer, !cachedData.isBlocked, true)
                }))
            }
        }
        
    } else if let peer = item.peer, peer.isSupergroup || peer.isGroup, let arguments = item.arguments as? GroupInfoArguments {
        let access = peer.groupAccess
        
        if access.canAddMembers {
            items.append(ActionItem(text: L10n.peerInfoActionAddMembers, image: theme.icons.profile_add_member, action: {
                arguments.addMember(access.canCreateInviteLink)
            }))
        }
        if let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) {
            items.append(ActionItem(text: value ? L10n.peerInfoActionUnmute : L10n.peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, action: arguments.toggleNotifications))
        }
        
        if let cachedData = item.peerView.cachedData as? CachedChannelData {
            if cachedData.statsDatacenterId > 0 {
                items.append(ActionItem(text: L10n.peerInfoActionStatistics, image: theme.icons.profile_stats, action: {
                    arguments.stats(cachedData.statsDatacenterId)
                }))
            }
        }
        
        if let group = peer as? TelegramGroup {
            if case .Member = group.membership {
                items.append(ActionItem(text: L10n.peerInfoActionLeave, image: theme.icons.profile_leave, destruct: true, action: arguments.delete))
            }
        } else if let group = peer as? TelegramChannel {
            if case .member = group.participationStatus {
                items.append(ActionItem(text: L10n.peerInfoActionLeave, image: theme.icons.profile_leave, destruct: true, action: arguments.delete))
            }
        }
        
        
        if access.canReport {
            items.append(ActionItem(text: L10n.peerInfoActionReport, image: theme.icons.profile_report, destruct: true, action: arguments.report))
        }
    } else if let peer = item.peer as? TelegramChannel, peer.isChannel, let arguments = item.arguments as? ChannelInfoArguments {
        if let value = item.peerView.notificationSettings?.isRemovedFromTotalUnreadCount(default: false) {
            items.append(ActionItem(text: value ? L10n.peerInfoActionUnmute : L10n.peerInfoActionMute, image: value ? theme.icons.profile_unmute : theme.icons.profile_mute, action: arguments.toggleNotifications))
        }
        
        if let cachedData = item.peerView.cachedData as? CachedChannelData {
            if cachedData.statsDatacenterId > 0 {
                items.append(ActionItem(text: L10n.peerInfoActionStatistics, image: theme.icons.profile_stats, action: {
                    arguments.stats(cachedData.statsDatacenterId)
                }))
            }
        }
        if let address = peer.addressName, !address.isEmpty {
            items.append(ActionItem(text: L10n.peerInfoActionShare, image: theme.icons.profile_share, action: arguments.share))
        }
        if peer.groupAccess.canReport {
            items.append(ActionItem(text: L10n.peerInfoActionReport, image: theme.icons.profile_report, action: arguments.report))
        }
        switch peer.participationStatus {
        case .member:
            items.append(ActionItem(text: L10n.peerInfoActionLeave, image: theme.icons.profile_leave, destruct: true, action: arguments.delete))
        default:
            break
        }
    }
    
    
    if items.count > rowItemsCount {
        var subItems:[SubActionItem] = []
        while items.count > rowItemsCount - 1 {
            let item = items.removeLast()
            subItems.insert(SubActionItem(text: item.text, destruct: item.destruct, action: item.action), at: 0)
        }
        if !subItems.isEmpty {
            items.append(ActionItem(text: L10n.peerInfoActionMore, image: theme.icons.profile_more, action: { }, subItems: subItems))
        }
    }
    
    return items
}

class PeerInfoHeadItem: GeneralRowItem {
    override var height: CGFloat {
        let insets = self.viewType.innerInset
        var height: CGFloat = 0
        if !editing {
            height = photoDimension + insets.top + insets.bottom + nameLayout.layoutSize.height + 4 + statusLayout.layoutSize.height + insets.bottom
            
            if !items.isEmpty {
                let maxActionSize: NSSize = items.max(by: { $0.size.height < $1.size.height })!.size
                height += maxActionSize.height + insets.top
            }
        } else {
            height = photoDimension + insets.top + insets.bottom
        }
        return height
    }
    
    fileprivate var statusLayout: TextViewLayout
    fileprivate var nameLayout: TextViewLayout
    
    
    let context: AccountContext
    let peer:Peer?
    let isVerified: Bool
    let isScam: Bool
    let peerView:PeerView
    var result:PeerStatusStringResult {
        didSet {
            nameLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
            statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1, alwaysStaticItems: true)
        }
    }
    
    private(set) fileprivate var items: [ActionItem] = []
    
    private let fetchPeerAvatar = DisposableSet()
    private let onlineMemberCountDisposable = MetaDisposable()
    
    fileprivate let editing: Bool
    fileprivate let updatingPhotoState:PeerInfoUpdatingPhotoState?
    fileprivate let updatePhoto:(NSImage?)->Void
    fileprivate let arguments: PeerInfoArguments
    
    let canEditPhoto: Bool
    
    
    let peerPhotosDisposable = MetaDisposable()
    
    var photos: [TelegramPeerPhoto] = []
    
    init(_ initialSize:NSSize, stableId:AnyHashable, context: AccountContext, arguments: PeerInfoArguments, peerView:PeerView, viewType: GeneralViewType, editing: Bool, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, updatePhoto:@escaping(NSImage?)->Void = { _ in }) {
        let peer = peerViewMainPeer(peerView)
        self.peer = peer
        self.peerView = peerView
        self.context = context
        self.editing = editing
        self.arguments = arguments
        self.isVerified = peer?.isVerified ?? false
        self.isScam = peer?.isScam ?? false
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
        
        if let peer = peer {
            if let peerReference = PeerReference(peer) {
                if let largeProfileImage = peer.largeProfileImage {
                    fetchPeerAvatar.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: largeProfileImage.resource)).start())
                }
                if let smallProfileImage = peer.smallProfileImage {
                    fetchPeerAvatar.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource)).start())
                }
            }
            
        }
        self.result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.huge), highlightIfActivity: false), expanded: true)
        nameLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
        statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        
        if let cachedData = peerView.cachedData as? CachedChannelData {
            let onlineMemberCount:Signal<Int32?, NoError>
            if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: peerView.peerId)  |> map(Optional.init) |> deliverOnMainQueue
            } else {
                onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: peerView.peerId)  |> map(Optional.init) |> deliverOnMainQueue
            }
            self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                guard let `self` = self else {
                    return
                }
                self.result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.huge)), onlineMemberCount: count)
                _ = self.makeSize(self.width, oldWidth: 0)
                self.redraw()
            }))
        }
        
        _ = self.makeSize(initialSize.width, oldWidth: 0)
        
        
        if let peer = peer {
            self.photos = syncPeerPhotos(peerId: peer.id)
            let signal = peerPhotos(account: context.account, peerId: peer.id, force: true) |> deliverOnMainQueue
            peerPhotosDisposable.set(signal.start(next: { [weak self] photos in
                self?.photos = photos
                self?.redraw()
            }))
        }
        
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
        
        self.items = actionItems(item: self, width: width, theme: theme)
        let textWidth = blockWidth - viewType.innerInset.right - viewType.innerInset.left - (isScam ? theme.icons.chatScam.backingSize.width + 5 : 0) - (isVerified ? theme.icons.peerInfoVerifyProfile.backingSize.width + 5 : 0)
        nameLayout.measure(width: textWidth)
        statusLayout.measure(width: textWidth)

        return success
    }
    
    fileprivate var nameSize: NSSize {
        let stateHeight = max((isScam ? theme.icons.chatScam.backingSize.height : 0), (isVerified ? theme.icons.peerInfoVerifyProfile.backingSize.height : 0))
        let width = nameLayout.layoutSize.width + (isScam ? theme.icons.chatScam.backingSize.width + 5 : 0) + (isVerified ? theme.icons.peerInfoVerifyProfile.backingSize.width + 5 : 0)
        return NSMakeSize(width, max(nameLayout.layoutSize.height, stateHeight))
    }
    
}

private final class PeerInfoPhotoEditableView : Control {
    private let backgroundView = View()
    private let camera: ImageView = ImageView()
    private var progressView:RadialProgressContainerView?
    private var updatingPhotoState: PeerInfoUpdatingPhotoState?
    private var tempImageView: ImageView?
    var setup: ((NSImage?)->Void)?
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
        
        
        set(handler: { [weak self] _ in
            if self?.updatingPhotoState == nil {
                self?.setup?(nil)
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
    var stateImage: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(nameView)
    }
    
    func update(_ item: PeerInfoHeadItem) {
        self.nameView.update(item.nameLayout)
        
        if item.isScam || item.isVerified {
            if stateImage == nil {
                stateImage = ImageView()
                addSubview(stateImage!)
            }
            
            stateImage?.image = item.isScam ? theme.icons.chatScam : theme.icons.peerInfoVerifyProfile
            _ = stateImage?.sizeToFit()
        } else {
            stateImage?.removeFromSuperview()
            stateImage = nil
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        nameView.centerY(x: 0)
        stateImage?.centerY(x: nameView.frame.maxX + 5)
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
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        photoView.setFrameSize(NSMakeSize(photoDimension, photoDimension))
        
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
                    item.updatePhoto(image)
                    return true
                } else {
                    let list = sender.draggingPasteboard.propertyList(forType: .kFilenames) as? [String]
                    if  let list = list {
                        if let first = list.first, let image = NSImage(contentsOfFile: first) {
                            item.updatePhoto(image)
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
                            return size <= 2000 * 1024 * 1024
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
    
    
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PeerInfoHeadItem else {
            return
        }
        
        photoView.centerX(y: item.viewType.innerInset.top)
        nameView.centerX(y: photoView.frame.maxY + item.viewType.innerInset.top)
        statusView.centerX(y: nameView.frame.maxY + 4)
        actionsView.centerX(y: statusView.frame.maxY + item.viewType.innerInset.top)
        photoEditableView?.centerX(y: item.viewType.innerInset.top)
        
        photoVideoView?.frame = photoView.frame
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
            
            let inset: CGFloat = actionItemInsetWidth
            
            actionsView.change(size: NSMakeSize(actionItemWidth * CGFloat(items.count) + CGFloat(items.count + 1) * inset, maxActionSize.height), animated: animated)
            
            var x: CGFloat = inset
            
            for (i, item) in items.enumerated() {
                let view = actionsView.subviews[i] as! ActionButton
                view.updateAndLayout(item: item, theme: theme)
                view.setFrameSize(NSMakeSize(item.size.width, maxActionSize.height))
                view.change(pos: NSMakePoint(x, 0), animated: false)
                x += maxActionSize.width + inset
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
        
        
        photoView.setPeer(account: item.context.account, peer: item.peer)
        
        if !item.photos.isEmpty {
            
            if let first = item.photos.first, let video = first.image.videoRepresentations.last, item.updatingPhotoState == nil {
               
                let equal = videoRepresentation?.resource.id.isEqual(to: video.resource.id) ?? false
                
                if !equal {
                    
                    self.photoVideoView?.removeFromSuperview()
                    self.photoVideoView = nil
                    
                    self.photoVideoView = MediaPlayerView(backgroundThread: true)
                    self.photoVideoView!.layer?.cornerRadius = self.photoView.frame.height / 2
                    if let photoEditableView = self.photoEditableView {
                        self.addSubview(self.photoVideoView!, positioned: .below, relativeTo: photoEditableView)
                    } else {
                        self.addSubview(self.photoVideoView!)

                    }
                    self.photoVideoView!.isEventLess = true
                    
                    self.photoVideoView!.frame = self.photoView.frame

                    
                    let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: first.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                    
                    
                    let mediaPlayer = MediaPlayer(postbox: item.context.account.postbox, reference: MediaResourceReference.standalone(resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                    
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
            }
        } else {
            self.photoVideoPlayer = nil
            self.photoVideoView?.removeFromSuperview()
            self.photoVideoView = nil
        }
        nameView.setFrameSize(item.nameSize)
        nameView.update(item)
        
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
                photoEditableView = .init(frame: NSMakeRect(0, 0, photoDimension, photoDimension))
                photoEditableView?.layer?.cornerRadius = photoDimension / 2
                addSubview(photoEditableView!)
                if animated {
                    photoEditableView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
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
    
}
