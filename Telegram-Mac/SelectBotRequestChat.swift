//
//  SelectBotRequestChat.swift
//  Telegram
//
//  Created by Mike Renoir on 12.01.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

private final class SelectBotRequestEmptyItem: GeneralRowItem {
    fileprivate let requirements: TextViewLayout
    fileprivate let title: TextViewLayout
    let context: AccountContext
    let button: String
    let callback:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, requirements: NSAttributedString, button: String, callback:@escaping()->Void, context: AccountContext) {
        self.requirements = .init(requirements.trimmed)
        self.title = .init(.initialize(string: strings().choosePeerRequirementsTitle, color: theme.colors.text, font: .medium(.title)))
        self.context = context
        self.button = button
        self.callback = callback
        super.init(initialSize, stableId: stableId)
        _ = makeSize(width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        requirements.measure(width: width - 60)
        title.measure(width: width - 60)

        return true
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        } else {
            return 300
        }
    }
    
    override func viewClass() -> AnyClass {
        return SelectBotRequestEmptyView.self
    }
}

private final class SelectBotRequestEmptyView: GeneralRowView {
    private let requirements = TextView()
    private let titleView = TextView()
    private let imageView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSMakeSize(120, 120).bounds)
    private final class CreateView : Control {
        private let gradient = View()
        private let shimmer = ShimmerEffectView()
        private let textView = TextView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            addSubview(shimmer)
            shimmer.isStatic = true
            container.addSubview(textView)
            addSubview(container)
            scaleOnClick = true
            
            gradient.backgroundColor = theme.colors.accent
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            
            
            gradient.frame = bounds
            shimmer.frame = bounds
            
            shimmer.updateAbsoluteRect(bounds, within: frame.size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: bounds, cornerRadius: frame.height / 2)], horizontal: true, size: frame.size)
            
            container.center()
            textView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(animated: Bool, text: String) -> NSSize {
           
            
            let layout = TextViewLayout(.initialize(string: text, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
                        
            container.setFrameSize(layout.layoutSize)
            
            let size = NSMakeSize(container.frame.width + 100, 40)
            
            needsLayout = true
            
            self.layer?.cornerRadius = 10
            return size
        }
    }

    private let button = CreateView(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(titleView)
        addSubview(requirements)
        addSubview(button)
        requirements.userInteractionEnabled = false
        requirements.isSelectable = false
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false

        
    }
    
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 20)
        titleView.centerX(y: imageView.frame.maxY + 20)
        requirements.centerX(y: titleView.frame.maxY + 5)
        button.centerX(y: requirements.frame.maxY + 20)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        guard let item = item as? SelectBotRequestEmptyItem else {
            return
        }
        requirements.update(item.requirements)
        titleView.update(item.title)
        
        let sticker: LocalAnimatedSticker = .duck_empty
        
        imageView.update(with: sticker.file, size: NSMakeSize(120, 120), context: item.context, parent: nil, table: item.table, parameters: sticker.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
        let size = button.update(animated: animated, text: item.button)
        button.isHidden = item.button.isEmpty
        button.setFrameSize(size)
        button.removeAllHandlers()
        button.set(handler: { [weak item] _ in
            item?.callback()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

 class SelectChatComplicated : SelectChatsBehavior {
    private let peerType: ReplyMarkupButtonRequestPeerType
    private let context: AccountContext
    
    var createGroup:(()->Void)?
    var createChannel:(()->Void)?

    
     init(peerType: ReplyMarkupButtonRequestPeerType, context: AccountContext, limit: Int32) {
        self.peerType = peerType
        self.context = context
        super.init(settings: [.remote, .contacts], limit: limit)
    }
     
     override func limitReached() {
         alert(for: context.window, info: strings().selectPeersLimitReached("\(limit)"))
     }
    
    override func filterPeer(_ peer: Peer) -> Bool {
        switch peerType {
        case let .user(user):
            if (!peer.isUser && !peer.isBot) || peer.isDeleted {
                return false
            }
            if let isBot = user.isBot {
                if isBot {
                    if !peer.isBot {
                        return false
                    }
                } else {
                    if peer.isBot {
                        return false
                    }
                }
            } else if peer.isBot {
                return false
            }
            if let isPremium = user.isPremium {
                if isPremium {
                    if !peer.isPremium {
                        return false
                    }
                } else {
                    if peer.isPremium {
                        return false
                    }
                }
            }
            return true
        case let .group(group):
            let isGroup = peer.isGroup || peer.isSupergroup || peer.isGigagroup
            
            if !isGroup {
                return false
            }
            
            if group.isCreator {
                if !peer.groupAccess.isCreator {
                    return false
                }
            }
            if let hasUsername = group.hasUsername {
                let username = peer.usernames.first(where: { $0.isActive })?.username ?? peer.username
                if hasUsername {
                    if username == nil {
                        return false
                    }
                } else {
                    if username != nil {
                        return false
                    }
                }
            }
            if let isForum = group.isForum {
                if isForum {
                    if !peer.isForum {
                        return false
                    }
                } else {
                    if peer.isForum {
                        return false
                    }
                }
            }
            if group.botParticipant {
                if !peer.groupAccess.canAddMembers {
                    return false
                }
            }
            if let userAdminRights = group.userAdminRights {
                if let peer = peer as? TelegramChannel {
                    let intersection = userAdminRights.rights.intersection(peer.adminRights?.rights ?? [])
                    if intersection != userAdminRights.rights {
                        return false
                    }
                } else if peer.isAdmin {
                    return true
                } else {
                    return false
                }
            }
            return true
        case let .channel(channel):
            
            if !peer.isChannel {
                return false
            }
            
            if channel.isCreator {
                if !peer.groupAccess.isCreator {
                    return false
                }
            }
            if let hasUsername = channel.hasUsername {
                let username = peer.usernames.first(where: { $0.isActive })?.username ?? peer.username
                if hasUsername {
                    if username == nil {
                        return false
                    }
                } else {
                    if username != nil {
                        return false
                    }
                }
            }
            if let userAdminRights = channel.userAdminRights {
                if let peer = peer as? TelegramChannel {
                    let intersection = userAdminRights.rights.intersection(peer.adminRights?.rights ?? [])
                    if intersection != userAdminRights.rights {
                        return false
                    }
                } else {
                    return false
                }
            }
            return true
        }
    }
    
    override func makeEntries(_ peers: [Peer], _ presence: [PeerId : PeerPresence], isSearch: Bool) -> [SelectPeerEntry] {
        let context = self.context
        var entries: [SelectPeerEntry] = []
        let peerType = self.peerType
        let requirements = NSMutableAttributedString()
        
        switch peerType {
        case .user(let user):
            if let isPremium = user.isPremium {
                if isSearch {
                    requirements.append(string: strings().choosePeerRequirementsTitle, color: theme.colors.listGrayText, font: .medium(.text))
                    requirements.append(string: "\n", font: .medium(.text))
                }
                if isPremium {
                    requirements.append(string: strings().choosePeerRequirementsUserPremium, color: theme.colors.grayText, font: .normal(.text))
                } else {
                    requirements.append(string: strings().choosePeerRequirementsUserNonPremium, color: theme.colors.grayText, font: .normal(.text))
                }
            }
        case .group(let group):
            if group.userAdminRights != nil || group.isForum != nil || group.isCreator || group.hasUsername != nil {
                if isSearch {
                    requirements.append(string: strings().choosePeerRequirementsTitle, color: theme.colors.listGrayText, font: .medium(.text))
                }

                if let hasUsername = group.hasUsername {
                    requirements.append(string: "\n", font: .medium(.text))
                    if hasUsername {
                        requirements.append(string: strings().choosePeerRequirementsGroupPublic, color: theme.colors.grayText, font: .normal(.text))
                    } else {
                        requirements.append(string: strings().choosePeerRequirementsGroupPrivate, color: theme.colors.grayText, font: .normal(.text))
                    }
                }
                if group.isCreator {
                    requirements.append(string: "\n", font: .medium(.text))
                    requirements.append(string: strings().choosePeerRequirementsGroupOwner, color: theme.colors.grayText, font: .normal(.text))
                }
                if let isForum = group.isForum {
                    requirements.append(string: "\n", font: .medium(.text))
                    if isForum {
                        requirements.append(string: strings().choosePeerRequirementsGroupForum, color: theme.colors.grayText, font: .normal(.text))
                    } else {
                        requirements.append(string: strings().choosePeerRequirementsGroupNonForum, color: theme.colors.grayText, font: .normal(.text))
                    }
                }
                if let userAdminRights = group.userAdminRights {
                    
                    let all: [TelegramChatAdminRightsFlags] = [.canChangeInfo, .canPostMessages, .canManageDirect, .canEditMessages, .canDeleteMessages, .canPostStories, .canEditStories, .canDeleteStories, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canBeAnonymous, .canManageCalls, .canManageTopics]
                    
                    var texts: [String] = []
                    for right in all {
                        if userAdminRights.rights.contains(right) {
                            texts.append(stringForRight(right: right, isGroup: true, defaultBannedRights: nil))
                        }
                    }
                    if !texts.isEmpty {
                        requirements.append(string: "\n", font: .medium(.text))
                        requirements.append(string: strings().choosePeerRequirementsGroupAdminRights(texts.joined(separator: ", ")), color: theme.colors.grayText, font: .normal(.text))
                    }
                }
            }
        case .channel(let channel):
            if channel.userAdminRights != nil || channel.isCreator || channel.hasUsername != nil {
                if isSearch {
                    requirements.append(string: strings().choosePeerRequirementsTitle, color: theme.colors.listGrayText, font: .medium(.text))
                }
                if let hasUsername = channel.hasUsername {
                    requirements.append(string: "\n", font: .medium(.text))
                    if hasUsername {
                        requirements.append(string: strings().choosePeerRequirementsChannelPublic, color: theme.colors.grayText, font: .normal(.text))
                    } else {
                        requirements.append(string: strings().choosePeerRequirementsChannelPrivate, color: theme.colors.grayText, font: .normal(.text))
                    }
                }
                if channel.isCreator {
                    requirements.append(string: "\n", font: .medium(.text))
                    requirements.append(string: strings().choosePeerRequirementsChannelOwner, color: theme.colors.grayText, font: .normal(.text))
                }
                if let botRights = channel.botAdminRights {
                    
                    let all: [TelegramChatAdminRightsFlags] = [.canChangeInfo, .canPostMessages, .canManageDirect, .canEditMessages, .canDeleteMessages, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canBeAnonymous, .canManageCalls, .canManageTopics]
                    
                    var texts: [String] = []
                    for right in all {
                        if botRights.rights.contains(right) {
                            texts.append(stringForRight(right: right, isGroup: true, defaultBannedRights: nil))
                        }
                    }
                    if !texts.isEmpty {
                        requirements.append(string: "\n", font: .medium(.text))
                        requirements.append(string: strings().choosePeerRequirementsChannelAdminRights(texts.joined(separator: ", ")), color: theme.colors.grayText, font: .normal(.text))
                    }
                }
            }
        }
        
        
        var index:Int32 = 0
        for value in peers {
            if filterPeer(value) {
                entries.append(.peer(SelectPeerValue(peer: value, presence: presence[value.id], subscribers: nil, ignoreStatus: true), index, true))
                index += 1
            }
        }
        
        if entries.isEmpty, !isSearch {
            let button: String
            switch peerType {
            case .channel:
                button = strings().choosePeerRequirementsGroupCreate
            case .group:
                button = strings().choosePeerRequirementsChannelCreate
            case .user:
                button = ""
            }
            entries.append(.empty(GeneralRowItem.Theme(), nil, { initialSize, stableId in
                return SelectBotRequestEmptyItem(initialSize, stableId: stableId, requirements: requirements, button: button, callback: { [weak self] in
                    switch peerType {
                    case .channel:
                        self?.createChannel?()
                    case .group:
                        self?.createGroup?()
                    default:
                        break
                    }
                }, context: context)
            }))
        }
        
        
        if !requirements.string.isEmpty, isSearch {
            if entries.isEmpty {
                entries.append(.searchEmpty(.init(), theme.icons.emptySearch))
            }
            entries.insert(.requirements(requirements), at: 0)
            struct CreateTuple {
                let icon: CGImage
                let name: String
                let action: (()->Void)?
            }
            let tuple: CreateTuple?

            switch peerType {
            case .group:
                tuple = .init(icon: theme.icons.select_peer_create_group, name: strings().choosePeerRequirementsGroupCreate, action: self.createGroup)
            case .channel:
                tuple = .init(icon: theme.icons.select_peer_create_channel, name: strings().choosePeerRequirementsChannelCreate, action: self.createChannel)
            default:
                tuple = nil
            }
            if let tuple = tuple {
                entries.append(.actionButton(tuple.name, tuple.icon, 0, GeneralRowItem.Theme(), { _ in
                    tuple.action?()
                }, true, theme.colors.accent))
            }
        }
               
      
        return entries.sorted(by: <)
    }
}

func selectSpecificPeer(context: AccountContext, peerType: ReplyMarkupButtonRequestPeerType, messageId: MessageId, buttonId: Int32, maxQuantity: Int32) {
    let title: String
    switch peerType {
    case let .user(user):
        if let isBot = user.isBot {
            if isBot {
                if maxQuantity > 1 {
                    title = strings().choosePeerTitleBotMultiple
                } else {
                    title = strings().choosePeerTitleBot
                }
            } else {
                if maxQuantity > 1 {
                    title = strings().choosePeerTitleUserMultiple
                } else {
                    title = strings().choosePeerTitleUser
                }
            }
        } else {
            if maxQuantity > 1 {
                title = strings().choosePeerTitleUserMultiple
            } else {
                title = strings().choosePeerTitleUser
            }
        }
    case .group:
        title = strings().choosePeerTitleGroup
    case .channel:
        title = strings().choosePeerTitleChannel
    }
    
    let invoke:([PeerId])->Void = { peerIds in
        
        let signal = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: peerIds)
        _ = showModalProgress(signal: signal, for: context.window).start(error: { error in
            showModalText(for: context.window, text: strings().unknownError)
        })
        
        
    }
    
    let behaviour = SelectChatComplicated(peerType: peerType, context: context, limit: maxQuantity)
    
    behaviour.createGroup = {
        var requires: CreateGroupRequires = []
        switch peerType {
        case let .group(group):
            if let username = group.hasUsername {
                if username {
                    requires.insert(.username)
                }
            }
            if let isForum = group.isForum {
                if isForum {
                    requires.insert(.forum)
                }
            }
        default:
            break
        }
        closeAllModals(window: context.window)
        createGroupDirectly(with: context, selectedPeers: [messageId.peerId], requires: requires, onCreate: { peerId in
            invoke([peerId])
        })
    }
    behaviour.createChannel = {
        var requires: CreateChannelRequires = []
        switch peerType {
        case let .channel(channel):
            if let username = channel.hasUsername {
                if username {
                    requires.insert(.username)
                }
            }
        default:
            break
        }
        context.bindings.rootNavigation().push(CreateChannelController(context: context, requires: requires, onComplete: { peerId, completed in
            if completed {
                navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(peerId))
                invoke([peerId])
            }
        }))
        closeAllModals(window: context.window)
    }
    _ = selectModalPeers(window: context.window, context: context, title: title, limit: maxQuantity, behavior: behaviour).start(next: { peerIds in
        invoke(peerIds)

    })
}
