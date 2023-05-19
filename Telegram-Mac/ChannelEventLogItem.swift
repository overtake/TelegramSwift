//
//  ChannelEventLogItem.swift
//  Telegram
//
//  Created by keepcoder on 08/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import DateUtils

private var banHelp:[TelegramChatBannedRightsFlags] {
    var order:[TelegramChatBannedRightsFlags] = []
    order.append(.banSendMessages)
    order.append(.banReadMessages)
    order.append(.banChangeInfo)
    order.append(.banSendMedia)
    order.append(.banSendStickers)
    order.append(.banSendGifs)
    order.append(.banAddMembers)
    order.append(.banPinMessages)
    order.append(.banSendInline)
    order.append(.banSendPolls)
    order.append(.banEmbedLinks)
    return order
}

func rightsHelp(_ peer: Peer) -> (specific: TelegramChatAdminRightsFlags, order: [TelegramChatAdminRightsFlags]) {
    let maskRightsFlags: TelegramChatAdminRightsFlags
    let rightsOrder: [TelegramChatAdminRightsFlags]
    
    if peer.isGroup || peer.isSupergroup || peer.isGigagroup {
        maskRightsFlags = .peerSpecific(peer: .init(peer))
        rightsOrder = [
            .canChangeInfo,
            .canPostMessages,
            .canEditMessages,
            .canDeleteMessages,
            .canAddAdmins,
            .canBeAnonymous
        ]
    } else {
        maskRightsFlags = .peerSpecific(peer: .init(peer))
        rightsOrder = [
            .canChangeInfo,
            .canDeleteMessages,
            .canBanUsers,
            .canInviteUsers,
            .canPinMessages,
            .canManageTopics,
            .canManageCalls,
            .canAddAdmins,
            .canBeAnonymous
        ]
    }
    return (specific: maskRightsFlags, order: rightsOrder)
}

private struct ServiceEventLogMessagePanel {
    let header:TextViewLayout
    let content:TextViewLayout
    
    var height: CGFloat {
        return header.layoutSize.height + content.layoutSize.height + 2
    }
}

private let defaultContentInset: NSEdgeInsets = NSEdgeInsets(left: 20, right: 20, top: 6, bottom: 6)

private class ServiceEventLogMessageContentItem {
    let peer:Peer
    let chatInteraction:ChatInteraction
    let name:TextViewLayout
    let date:TextViewLayout
    let content:TextViewLayout
    let panel:ServiceEventLogMessagePanel?
    private var _width:CGFloat = 0
    init(peer:Peer, chatInteraction:ChatInteraction, name: TextViewLayout, date: TextViewLayout, content: TextViewLayout, panel: ServiceEventLogMessagePanel? = nil) {
        self.peer = peer
        self.name = name
        self.date = date
        self.content = content
        self.panel = panel
        self.chatInteraction = chatInteraction
        self.content.interactions = globalLinkExecutor
        self.name.interactions = globalLinkExecutor
        self.date.interactions = globalLinkExecutor
        self.panel?.content.interactions = globalLinkExecutor
        self.panel?.header.interactions = globalLinkExecutor
    }
    func measure(_ width: CGFloat) {
        _width = width
        let contentInset:CGFloat = 36 + 10
        name.measure(width: width - contentInset)
        date.measure(width: .greatestFiniteMagnitude)
        content.measure(width: width - contentInset - date.layoutSize.width)
        panel?.header.measure(width: width - contentInset - date.layoutSize.width)
        panel?.content.measure(width: width - contentInset - date.layoutSize.width)
    }
    
    var contentSize: NSSize {
        return NSMakeSize(_width - date.layoutSize.width, content.layoutSize.height)
    }
    var panelSize: NSSize {
        if let panel = panel {
            return NSMakeSize(_width, panel.height)
        }
        return NSZeroSize
    }
    
    var height: CGFloat {
        var height:CGFloat = 0
        height += name.layoutSize.height
        height += 2
        height += content.layoutSize.height
        if let panel = panel {
            height += defaultContentInset.top
            height += panel.header.layoutSize.height + 2
            height += panel.content.layoutSize.height
        }
        
        return (max(36, height))
    }
}


private class ServiceEventLogMessagePanelView : View {
    private let headerView = TextView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        headerView.isSelectable = false
        textView.isSelectable = false
        addSubview(headerView)
        addSubview(textView)
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.accent.cgColor)
        let radius:CGFloat = 1.0
        ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
        ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
    }
    
    override func layout() {
        super.layout()
        headerView.update(headerView.textLayout, origin: NSMakePoint(8, 0))
        textView.update(textView.textLayout, origin: NSMakePoint(8, headerView.frame.maxY + 2))
    }
    
    func update(with panel: ServiceEventLogMessagePanel) {
        headerView.update(panel.header)
        textView.update(panel.content)
        
    }
    
    func updateColors(_ color: NSColor) {
        backgroundColor = color
        headerView.backgroundColor = color
        textView.backgroundColor = color
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class ServiceEventLogMessageContainerView : View {
    fileprivate let avatar: AvatarControl = AvatarControl(font: .avatar(.short))
    fileprivate let name:TextView = TextView()
    fileprivate let date:TextView = TextView()
    fileprivate let container:View = View()
    fileprivate let messageContent:TextView = TextView()
    fileprivate var contentItem:ServiceEventLogMessageContentItem?
    fileprivate var panelView: ServiceEventLogMessagePanelView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(36, 36)
        name.isSelectable = false
        date.isSelectable = false
        addSubview(avatar)
        addSubview(name)
        addSubview(date)
        addSubview(container)
        
        container.addSubview(messageContent)
    }
    
    func update(with content: ServiceEventLogMessageContentItem, account:Account) {
        self.contentItem = content
        name.update(content.name)
        date.update(content.date)
        avatar.setPeer(account: account, peer: content.peer)
        
        avatar.set(handler: { _ in
            content.chatInteraction.openInfo(content.peer.id, false, nil, nil)
        }, for: .Click)
        
        container.setFrameSize(content.contentSize)
        messageContent.update(content.content)
        
        if let panel = content.panel {
            panelView = ServiceEventLogMessagePanelView(frame: NSZeroRect)
            panelView?.setFrameSize(content.panelSize)
            panelView?.update(with: panel)
            addSubview(panelView!)
        } else {
            panelView?.removeFromSuperview()
            panelView = nil
        }
        
        needsLayout = true
    }
    
    func updateColors(_ color: NSColor) {
        backgroundColor = color
        container.backgroundColor = color
        name.backgroundColor = color
        date.backgroundColor = color
        messageContent.backgroundColor = color
        panelView?.updateColors(color)
        
    }
    
    override func layout() {
        super.layout()
        name.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, 0))
        date.setFrameOrigin(NSMakePoint(frame.width - date.frame.width, 0))
        container.setFrameOrigin(avatar.frame.maxX + 10, name.frame.maxY + 2)
        panelView?.setFrameOrigin(avatar.frame.maxX + 10, container.frame.maxY + 6)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}

class ServiceEventLogItem: TableRowItem {
    
    fileprivate let textLayout:TextViewLayout
    fileprivate var imageArguments:TransformImageArguments?
    fileprivate var image:TelegramMediaImage?
    
    override var height: CGFloat {
        var height = textLayout.layoutSize.height + (defaultContentInset.top + defaultContentInset.bottom)
        
        if let contentMessageItem = contentMessageItem {
            height += contentMessageItem.height
            if textLayout.layoutSize.height > 0 {
                height += defaultContentInset.bottom
            }
        }
        if let _ = image {
            height += 70 + defaultContentInset.top
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return ServiceEventLogRowView.self
    }
    
    
    fileprivate private(set) var contentMessageItem: ServiceEventLogMessageContentItem?
    
    fileprivate let entry: ChannelAdminEventLogEntry
    fileprivate let chatInteraction: ChatInteraction
    fileprivate let isGroup: Bool
    fileprivate let peerId: PeerId
    init(_ initialSize: NSSize, entry: ChannelAdminEventLogEntry, isGroup: Bool, chatInteraction: ChatInteraction) {
        self.entry = entry
        self.isGroup = isGroup
        self.peerId = chatInteraction.peerId
        self.chatInteraction = chatInteraction
        let attributedString = NSMutableAttributedString()
        
        if let peer = entry.peers[entry.event.peerId] {
            
            let contentName = NSMutableAttributedString()
            let date:NSAttributedString = .initialize(string: DateUtils.string(forMessageListDate: entry.event.date), color: theme.colors.grayText, font: .normal(.short))
            var nameColor:NSColor
            
            if chatInteraction.context.peerId == peer.id {
                nameColor = theme.colors.link
            } else {
                let value = abs(Int(peer.id.id._internalGetInt64Value()) % 7)
                nameColor = theme.chat.peerName(value)
            }
            
            let range = contentName.append(string: peer.displayTitle, color: nameColor, font: .medium(.text))
            contentName.add(link: inAppLink.peerInfo(link: "", peerId: peer.id, action: nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor)
            
            
            struct ChangedInfo {
                let prev:String
                let new:String
                let panelText:String?
            }
            
            struct ServiceTextInfo {
                let text:String
                let firstLink:(range:String, link: inAppLink)
                let secondLink:(range:String, link: inAppLink)?
            }
            
            var changedInfo:ChangedInfo? = nil
            var serviceInfo: ServiceTextInfo?
            let peerLink = (range: peer.displayTitle, link: inAppLink.peerInfo(link: "", peerId:peer.id, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo))
            
            switch entry.event.action {
            case let .changeTitle(prev, new):
                changedInfo = ChangedInfo(prev: prev, new: new, panelText: !prev.isEmpty ? strings().eventLogServicePreviousTitle : nil)
                serviceInfo = ServiceTextInfo(text: !isGroup ? strings().channelEventLogServiceTitleUpdated(peer.displayTitle) : strings().groupEventLogServiceTitleUpdated(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                
            case let .changeAbout(prev, new):
                
                let text:String
                if !new.isEmpty {
                    text = !isGroup ? strings().channelEventLogServiceAboutUpdated(peer.displayTitle) : strings().groupEventLogServiceAboutUpdated(peer.displayTitle)
                } else {
                    text = !isGroup ? strings().channelEventLogServiceAboutRemoved(peer.displayTitle) : strings().groupEventLogServiceAboutRemoved(peer.displayTitle)
                }
                
                changedInfo = ChangedInfo(prev: prev, new: new, panelText: !prev.isEmpty ? strings().eventLogServicePreviousDesc : nil)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)

            case let .changeUsername(prev, new):
                
                let text:String
                if !new.isEmpty {
                    text = !isGroup ? strings().channelEventLogServiceLinkUpdated(peer.displayTitle) : strings().groupEventLogServiceLinkUpdated(peer.displayTitle)
                } else {
                    text = !isGroup ? strings().channelEventLogServiceLinkRemoved(peer.displayTitle) : strings().groupEventLogServiceLinkRemoved(peer.displayTitle)
                }
                
                changedInfo = ChangedInfo(prev: "https://t.me/\(prev)", new: new.isEmpty ? "" : "https://t.me/\(new)", panelText: !prev.isEmpty ? strings().eventLogServicePreviousLink : nil)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .changeStickerPack(_, new):
                let text:String
                if let _ = new {
                    text = strings().eventLogServiceChangedStickerSet(peer.displayTitle)
                } else {
                    text = strings().eventLogServiceRemovedStickerSet(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .linkedPeerUpdated(previous, updated):
                let text: String
                var secondaryLink:(range: String, link: inAppLink)?
                if let updated = updated {
                    if isGroup {
                        text = strings().channelEventLogMessageChangedLinkedChannel(peer.displayTitle, updated.displayTitle)
                        secondaryLink = (range: updated.displayTitle, link: inAppLink.peerInfo(link: "", peerId: updated.id, action:nil, openChat: true, postId: nil, callback: chatInteraction.openInfo))
                    } else {
                        text = strings().channelEventLogMessageChangedLinkedGroup(peer.displayTitle, updated.displayTitle)
                        secondaryLink = (range: updated.displayTitle, link: inAppLink.peerInfo(link: "", peerId: updated.id, action:nil, openChat: true, postId: nil, callback: chatInteraction.openInfo))
                    }
                } else if let previous = previous {
                    if isGroup {
                        text = strings().channelEventLogMessageChangedUnlinkedChannel(peer.displayTitle, previous.displayTitle)
                        secondaryLink = (range: previous.displayTitle, link: inAppLink.peerInfo(link: "", peerId: previous.id, action:nil, openChat: true, postId: nil, callback: chatInteraction.openInfo))

                    } else {
                        text = strings().channelEventLogMessageChangedUnlinkedGroup(peer.displayTitle)
                    }
                } else {
                    text = ""
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: secondaryLink)
            case let .participantToggleAdmin(prev, new):
                switch prev.participant {
                case let .member(memberId, _, adminInfo: prevAdminInfo, banInfo: _, rank: prevRank):
                    switch new.participant {
                    case let .member(_, _, adminInfo: newAdminInfo, banInfo: _, rank: newRank):
                        if let memberPeer = entry.peers[memberId] {
                            let message = NSMutableAttributedString()
                   
                            var addedRights = newAdminInfo?.rights.rights ?? []
                            var removedRights:TelegramChatAdminRightsFlags = []
                            if let prevAdminInfo = prevAdminInfo {
                                addedRights = addedRights.subtracting(prevAdminInfo.rights.rights)
                                removedRights = prevAdminInfo.rights.rights.subtracting(newAdminInfo?.rights.rights ?? [])
                            }
                            
                            var justRankUpdated: Bool = false
                            
                            if prevRank != newRank {
                                let rank = newRank ?? strings().chatAdminBadge
                                if removedRights.isEmpty && addedRights.isEmpty {
                                    _ = message.append(string: strings().channelEventLogMessageRankName(memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "", rank), color: theme.colors.text)
                                    justRankUpdated = true
                                }
                            }
                            if !justRankUpdated {
                                _ = message.append(string: prevAdminInfo != nil ? strings().eventLogServicePromotedChanged1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "") : strings().eventLogServicePromoted1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : ""), color: theme.colors.text)
                                
                                
                                for right in rightsHelp(peer).order {
                                    if addedRights.contains(right) {
                                        _ = message.append(string: "\n+ \(right.localizedString)", color: theme.colors.text)
                                    }
                                }
                                if !removedRights.isEmpty {
                                    for right in rightsHelp(peer).order {
                                        if removedRights.contains(right) {
                                            _ = message.append(string: "\n- \(right.localizedString)", color: theme.colors.text)
                                        }
                                    }
                                }
                                
                                if prevRank != newRank {
                                    if let rank = newRank, !rank.isEmpty {
                                        _ = message.append(string: "\n" + strings().channelEventLogServicePlusTitle(rank), color: theme.colors.text)
                                    } else {
                                        _ = message.append(string: "\n" + strings().channelEventLogServiceMinusTitle, color: theme.colors.text)
                                    }
                                }
                            }
                        
                            
                            message.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: message.range)
                            message.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                            
                            message.add(link: inAppLink.peerInfo(link: "", peerId: memberId, action: nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: message.string.nsstring.range(of: memberPeer.displayTitle))
                            self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(message))
                            
                        }
                    case let .creator(memberId, _, _):
                        if let memberPeer = entry.peers[memberId] {
                            let message = NSMutableAttributedString()
                            
                            
                            _ = message.append(string: strings().channelEventLogMessageTransferedName1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : ""), color: theme.colors.text)
                            
                            
                            
                            message.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: message.range)
                            message.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                            
                            message.add(link: inAppLink.peerInfo(link: "", peerId: memberId, action: nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: message.string.nsstring.range(of: memberPeer.displayTitle))
                            self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(message))
                            
                        }
                    }
                case let .creator(memberId, prevAdminInfo, prevRank):
                    switch new.participant {
                    case .creator(memberId, let newAdminInfo, let newRank):
                        if let memberPeer = entry.peers[memberId] {
                            let message = NSMutableAttributedString()
                            
                            var addedRights = newAdminInfo?.rights.rights ?? []
                            var removedRights:TelegramChatAdminRightsFlags = []
                            if let prevAdminInfo = prevAdminInfo {
                                addedRights = addedRights.subtracting(prevAdminInfo.rights.rights)
                                removedRights = prevAdminInfo.rights.rights.subtracting(newAdminInfo?.rights.rights ?? [])
                            }
                            
                            var justRankUpdated: Bool = false
                            
                            if prevRank != newRank {
                                let rank = newRank ?? strings().chatAdminBadge
                                if removedRights.isEmpty && addedRights.isEmpty {
                                    _ = message.append(string: strings().channelEventLogMessageRankName(memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "", rank), color: theme.colors.text)
                                    justRankUpdated = true
                                }
                            }
                            if !justRankUpdated {
                                _ = message.append(string: prevAdminInfo != nil ? strings().eventLogServicePromotedChanged1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "") : strings().eventLogServicePromoted1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : ""), color: theme.colors.text)
                                
                                
                                for right in rightsHelp(peer).order {
                                    if addedRights.contains(right) {
                                        _ = message.append(string: "\n+ \(right.localizedString)", color: theme.colors.text)
                                    }
                                }
                                if !removedRights.isEmpty {
                                    for right in rightsHelp(peer).order {
                                        if removedRights.contains(right) {
                                            _ = message.append(string: "\n- \(right.localizedString)", color: theme.colors.text)
                                        }
                                    }
                                }
                                
                                if prevRank != newRank {
                                    if let rank = newRank, !rank.isEmpty {
                                        _ = message.append(string: "\n" + strings().channelEventLogServicePlusTitle(rank), color: theme.colors.text)
                                    } else {
                                        _ = message.append(string: "\n" + strings().channelEventLogServiceMinusTitle, color: theme.colors.text)
                                    }
                                }
                            }
                            
                            
                            message.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: message.range)
                            message.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                            
                            message.add(link: inAppLink.peerInfo(link: "", peerId: memberId, action: nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: message.string.nsstring.range(of: memberPeer.displayTitle))
                            self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(message))
                            
                        }
                    default:
                        break
                    }
                }
            case .deleteMessage:
                serviceInfo = ServiceTextInfo(text: strings().eventLogServiceDeletedMessage(peer.displayTitle), firstLink: peerLink, secondLink: nil)
            case let .editMessage(prev, new):
                if new.effectiveMedia is TelegramMediaImage || new.effectiveMedia is TelegramMediaFile {
                    if !new.media[0].isSemanticallyEqual(to: prev.media[0]) {
                        serviceInfo = ServiceTextInfo(text: strings().eventLogServiceEditedMedia(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                    } else {
                        serviceInfo = ServiceTextInfo(text: strings().eventLogServiceEditedCaption(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                    }
                } else if let media = new.effectiveMedia as? TelegramMediaAction {
                    switch media.action {
                    case let .groupPhoneCall(_, _, _, duration):
                        if let duration = duration {
                            let text: String
                            if new.author?.id == chatInteraction.context.peerId {
                                text = strings().chatServiceVoiceChatFinishedYou(autoremoveLocalized(Int(duration)))
                            } else {
                                text = strings().chatServiceVoiceChatFinished(peer.displayTitle, autoremoveLocalized(Int(duration)))
                            }
                            serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                        }
                    default:
                        serviceInfo = ServiceTextInfo(text: strings().eventLogServiceEditedMessage(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                    }
                } else {
                    serviceInfo = ServiceTextInfo(text: strings().eventLogServiceEditedMessage(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                }
            case let .sendMessage(new):
                if let media = new.effectiveMedia as? TelegramMediaAction {
                    switch media.action {
                    case let .groupPhoneCall(_, _, _, duration):
                        if let duration = duration {
                            let text: String
                            if new.author?.id == chatInteraction.context.peerId {
                                text = strings().chatServiceVoiceChatFinishedYou(autoremoveLocalized(Int(duration)))
                            } else {
                                text = strings().chatServiceVoiceChatFinished(peer.displayTitle, autoremoveLocalized(Int(duration)))
                            }
                            serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                        }
                    default:
                        serviceInfo = ServiceTextInfo(text: strings().eventLogServicePostMessage(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                    }
                } else {
                    serviceInfo = ServiceTextInfo(text: strings().eventLogServicePostMessage(peer.displayTitle), firstLink: peerLink, secondLink: nil)
                }
            case let .participantToggleBan(prev, new):
                switch prev.participant {
                case let .member(memberId, _, adminInfo: _, banInfo: prevBanInfo, rank: _):
                    switch new.participant {
                    case let .member(_, _, adminInfo: _, banInfo: newBanInfo, rank: _):
                        let message = NSMutableAttributedString()
                        if let memberPeer = entry.peers[memberId] {
                            
                            var addedRights = newBanInfo?.rights.flags ?? []
                            var removedRights:TelegramChatBannedRightsFlags = []
                            if let prevBanInfo = prevBanInfo {
                                addedRights = addedRights.subtracting(prevBanInfo.rights.flags)
                                removedRights = prevBanInfo.rights.flags.subtracting(newBanInfo?.rights.flags ?? [])
                            }
                            
                            let text:String
                            
                            if !addedRights.contains(.banReadMessages) {
                                
                                if let _ = prevBanInfo {
                                    if let newBanInfo = newBanInfo {
                                        text = newBanInfo.rights.untilDate != .max && newBanInfo.rights.untilDate != 0 ? strings().eventLogServiceDemotedChangedUntil1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "", newBanInfo.rights.formattedUntilDate) : strings().eventLogServiceDemotedChanged1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "")
                                    } else {
                                        text = strings().eventLogServiceDemotedChanged1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "")
                                    }
                                } else {
                                    if let newBanInfo = newBanInfo {
                                        text = newBanInfo.rights.untilDate != .max && newBanInfo.rights.untilDate != 0 ? strings().eventLogServiceDemotedUntil1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "", newBanInfo.rights.formattedUntilDate) : strings().eventLogServiceDemoted1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "")
                                    } else {
                                        text = strings().eventLogServiceDemotedChanged1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "")
                                    }
                                }
                            } else {
                                text = strings().eventLogServiceBanned1(memberPeer.displayTitle, memberPeer.addressName != nil ? "(@\(memberPeer.addressName!))" : "")
                            }
                            
                            _ = message.append(string: text, color: theme.colors.text)
                            
                            
                            if !addedRights.contains(.banReadMessages) {
                                for right in banHelp {
                                    if addedRights.contains(right) {
                                        _ = message.append(string: "\n- \(right.localizedString)", color: theme.colors.text)
                                    }
                                }
                                if !removedRights.isEmpty {
                                    for right in banHelp {
                                        if removedRights.contains(right) {
                                            _ = message.append(string: "\n+ \(right.localizedString)", color: theme.colors.text)
                                        }
                                    }
                                }
                            }
                            message.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: message.range)
                            message.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                            
                            message.add(link: inAppLink.peerInfo(link: "", peerId: memberId, action: nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: message.string.nsstring.range(of: memberPeer.displayTitle))
                            self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(message))
                            
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            case .updatePinned(let message):
                serviceInfo = ServiceTextInfo(text: message != nil ? strings().eventLogServiceUpdatePinned(peer.displayTitle) : strings().eventLogServiceRemovePinned(peer.displayTitle), firstLink: peerLink, secondLink: nil)
            case let .toggleInvites(value):
                let text:String
                if value {
                    text = strings().groupEventLogServiceEnableInvites(peer.displayTitle)
                } else {
                    text = strings().groupEventLogServiceDisableInvites(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .toggleSignatures(value):
                let text:String
                if value {
                    text = strings().channelEventLogServiceEnableSignatures(peer.displayTitle)
                } else {
                    text = strings().channelEventLogServiceDisableSignatures(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .changePhoto(_, new):
                let text:String
                if new.0.isEmpty {
                    text = isGroup ? strings().groupEventLogServicePhotoRemoved(peer.displayTitle) : strings().channelEventLogServicePhotoRemoved(peer.displayTitle)
                } else {
                    text = isGroup ? strings().groupEventLogServicePhotoUpdated(peer.displayTitle) : strings().channelEventLogServicePhotoUpdated(peer.displayTitle)
                    
                    let size = NSMakeSize(70, 70)
                    imageArguments = TransformImageArguments(corners: ImageCorners(radius: size.width / 2), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                    image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: new.0, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case .participantLeave:
                let text:String = isGroup ? strings().groupEventLogServiceUpdateLeft(peer.displayTitle) : strings().channelEventLogServiceUpdateLeft(peer.displayTitle)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case .participantJoin:
                let text:String = isGroup ? strings().groupEventLogServiceUpdateJoin(peer.displayTitle) : strings().channelEventLogServiceUpdateJoin(peer.displayTitle)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .updateSlowmode(_, newValue):
                let text:String = newValue == nil || newValue == 0 ? strings().channelEventLogServiceDisabledSlowMode(peer.displayTitle) : strings().channelEventLogServiceSetSlowMode1(peer.displayTitle, autoremoveLocalized(Int(newValue!)))
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .updateDefaultBannedRights(prev, new):
                let message = NSMutableAttributedString()
                _ = message.append(string: strings().eventLogServiceChangedDefaultsRights, color: theme.colors.text)
                var addedRights = new.flags
                var removedRights:TelegramChatBannedRightsFlags = []
                addedRights = addedRights.subtracting(prev.flags)
                removedRights = prev.flags.subtracting(new.flags)
                
                for right in banHelp {
                    if addedRights.contains(right) {
                        _ = message.append(string: "\n- \(right.localizedString)", color: theme.colors.text)
                    }
                }
                if !removedRights.isEmpty {
                    for right in banHelp {
                        if removedRights.contains(right) {
                            _ = message.append(string: "\n+ \(right.localizedString)", color: theme.colors.text)
                        }
                    }
                }
                
                message.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: message.range)
                self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(message))
            case .startGroupCall:
                let text = strings().channelAdminLogStartedVoiceChat(peer.displayTitle)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case .endGroupCall:
                let text = strings().channelAdminLogEndedVoiceChat(peer.displayTitle)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .groupCallUpdateParticipantMuteStatus(peerId, isMuted):
                if let secondary = entry.peers[peerId] {
                    let secondaryLink = (range: secondary.displayTitle, link: inAppLink.peerInfo(link: "", peerId: secondary.id, action:nil, openChat: true, postId: nil, callback: chatInteraction.openInfo))
                    let text: String
                    if isMuted {
                        text = strings().channelAdminLogMutedParticipant(peer.displayTitle, secondary.displayTitle)
                    } else {
                        text = strings().channelAdminLogUnmutedMutedParticipant(peer.displayTitle, secondary.displayTitle)
                    }
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: secondaryLink)
                }
            case let .updateGroupCallSettings(joinMuted):
                let text: String
                if joinMuted {
                    text = strings().channelAdminLogMutedNewMembers(peer.displayTitle)
                } else {
                    text = strings().channelAdminLogAllowedNewMembersToSpeak(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .deleteExportedInvitation(invite):
                if let invite = invite._invitation {
                    let text = strings().channelAdminLogDeletedInviteLink(peer.displayTitle, invite.link.replacingOccurrences(of: "https://", with: ""))
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                }
            case let .editExportedInvitation(_, invite):
                if let invite = invite._invitation {
                    let text = strings().channelAdminLogEditedInviteLink(peer.displayTitle, invite.link.replacingOccurrences(of: "https://", with: ""))
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                }
            case let .revokeExportedInvitation(invite):
                if let invite = invite._invitation {
                    let text = strings().channelAdminLogRevokedInviteLink(peer.displayTitle, invite.link.replacingOccurrences(of: "https://", with: ""))
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                }
            case let .participantJoinedViaInvite(invite):
                if let invite = invite._invitation {
                    let text = strings().channelAdminLogJoinedViaInviteLink(peer.displayTitle, invite.link.replacingOccurrences(of: "https://", with: ""))
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                }
            case let  .participantJoinByRequest(invite, peerId):
                
                if let secondary = entry.peers[peerId], let invite = invite._invitation {
                    let secondaryLink = (range: secondary.displayTitle, link: inAppLink.peerInfo(link: "", peerId: secondary.id, action:nil, openChat: true, postId: nil, callback: chatInteraction.openInfo))
                    let text = strings().channelAdminLogJoinedViaRequest(peer.displayTitle, invite.link.replacingOccurrences(of: "https://", with: ""), secondary.displayTitle)
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: secondaryLink)
                }
            case let .changeHistoryTTL(_, updatedValue):
                let text: String
                if let updatedValue = updatedValue, updatedValue > 0 {
                    text = strings().channelAdminLogMessageChangedAutoremoveTimeoutSet(peer.displayTitle, timeIntervalString(Int(updatedValue)))
                } else {
                    text = strings().channelAdminLogMessageChangedAutoremoveTimeoutRemove(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .changeAvailableReactions(_, updatedValue):
                var text: String = ""
                switch updatedValue {
                case .all:
                    text = strings().channelAdminLogReactionsEnabled(peer.displayTitle)
                case .limited(let array):
                    let emojiString = array.map { $0.string.fixed }.joined(separator: ", ")
                    text = strings().channelAdminLogAllowedReactionsUpdated(peer.displayTitle, emojiString)
                case .empty:
                    text = strings().channelAdminLogReactionsDisabled(peer.displayTitle)
                }
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .createTopic(info):
                let text = strings().channelEventLogServiceTopicCreated(peer.displayTitle, info.title)
                serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
            case let .editTopic(prevInfo, newInfo):
                if prevInfo.info.title != newInfo.info.title {
                    let text = strings().channelEventLogServiceTopicEdited(peer.displayTitle, newInfo.info.title)
                    serviceInfo = ServiceTextInfo(text: text, firstLink: peerLink, secondLink: nil)
                }
            default:
                break
            }
            //
            if let serviceInfo = serviceInfo {
                _ = attributedString.append(string: serviceInfo.text, color: theme.colors.grayText, font: .normal(.text))
                
                let range = attributedString.string.nsstring.range(of: serviceInfo.firstLink.range)
                attributedString.add(link: serviceInfo.firstLink.link, for: range)
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(.text), range: range)
                if let second = serviceInfo.secondLink {
                    let range = attributedString.string.nsstring.range(of: second.range)
                    attributedString.add(link: second.link, for: range)
                    attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(.text), range: range)
                }
                
            }
            
            if let changedInfo = changedInfo {
                
    
                let newContentAttributed = NSMutableAttributedString()
                _ = newContentAttributed.append(string: changedInfo.new, color: theme.colors.text, font: .normal(.text))
                newContentAttributed.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                
                let prevContentAttributed = NSMutableAttributedString()
                _ = prevContentAttributed.append(string: changedInfo.prev, color: theme.colors.text, font: .normal(12.5))
                prevContentAttributed.detectLinks(type: [.Mentions, .Hashtags], context: chatInteraction.context, color: theme.colors.link, openInfo: chatInteraction.openInfo, hashtag: nil, command: nil)
                
                let panel:ServiceEventLogMessagePanel?
                if let _ = changedInfo.panelText {
                    panel = ServiceEventLogMessagePanel(header: TextViewLayout(.initialize(string: changedInfo.panelText, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1), content: TextViewLayout(prevContentAttributed))
                } else {
                    panel = nil
                }
                self.contentMessageItem = ServiceEventLogMessageContentItem(peer: peer, chatInteraction: chatInteraction, name: TextViewLayout(contentName, maximumNumberOfLines: 1), date: TextViewLayout(date), content: TextViewLayout(newContentAttributed), panel: panel)
            }
        }
        
        textLayout = TextViewLayout(attributedString, alignment: .center)
        textLayout.interactions = globalLinkExecutor
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return entry.event.id
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - (defaultContentInset.left + defaultContentInset.right))
        contentMessageItem?.measure(width - (defaultContentInset.left + defaultContentInset.right))
        return success
    }
}

private class ServiceEventLogRowView : TableRowView {
    private let textView: TextView = TextView()
    private var imageView:TransformImageView?
    private var messageContent:ServiceEventLogMessageContainerView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
    }
    
    override var backdorColor: NSColor {
        return theme.colors.chatBackground
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
        messageContent?.updateColors(backdorColor)
    }
    
    
    override func layout() {
        super.layout()
        textView.update(textView.textLayout)
        textView.centerX(y: defaultContentInset.top)
        
        let contentInset: CGFloat = (textView.frame.height != 0 ?textView.frame.maxY : 0) + defaultContentInset.top

        if let item = item as? ServiceEventLogItem, let arguments = item.imageArguments {
            imageView?.set(arguments: arguments)
        }
        
        imageView?.centerX(y: contentInset)
        if let messageContent = messageContent {
            messageContent.setFrameOrigin(defaultContentInset.left, contentInset)
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let messageContent = messageContent {
            messageContent.setFrameSize(frame.width - (defaultContentInset.left + defaultContentInset.right), messageContent.frame.height)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        if let item = item as? ServiceEventLogItem {
            textView.update(item.textLayout)
            
            if let content = item.contentMessageItem {
                if messageContent == nil {
                    messageContent = ServiceEventLogMessageContainerView(frame: NSZeroRect)
                }
                messageContent?.update(with: content, account: item.chatInteraction.context.account)
                messageContent?.setFrameSize(frame.width - (defaultContentInset.left + defaultContentInset.right), content.height)
                addSubview(messageContent!)
            } else {
                messageContent?.removeFromSuperview()
                messageContent = nil
            }
            
            if let image = item.image {
                if imageView == nil {
                    self.imageView = TransformImageView()
                    imageView?.setFrameSize(NSMakeSize(70, 70))
                    self.addSubview(imageView!)
                }
                
                imageView?.setSignal(chatMessagePhoto(account: item.chatInteraction.context.account, imageReference: ImageMediaReference.standalone(media: image), toRepresentationSize:NSMakeSize(100,100), scale: backingScaleFactor))
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
            
        }
        needsLayout = true
        super.set(item: item, animated: animated)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


class ChannelEventLogEditedPanelItem : TableRowItem {
    private let _stableId:Int64 = arc4random64()
    private let previous:Message
    fileprivate let panel:ServiceEventLogMessagePanel
    fileprivate weak var associatedItem:ChatRowItem?
    init(_ initialSize: NSSize, previous:Message, item:ChatRowItem) {
        self.previous = previous
        self.associatedItem = item
        let header = TextViewLayout(.initialize(string: strings().channelEventLogOriginalMessage, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
        
        let text = TextViewLayout(.initialize(string: previous.text.isEmpty ? strings().channelEventLogEmpty : previous.text, color: theme.colors.text, font: .italic(.text)))
       
        panel = ServiceEventLogMessagePanel(header: header, content: text)
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        _ = associatedItem?.makeSize(width, oldWidth: oldWidth)
        if let item = associatedItem {
            
            panel.content.measure(width: item.blockWidth - 8)
            panel.header.measure(width: item.blockWidth - 8)
        }
       
        return success
    }
    
    override var height: CGFloat {
        return panel.height + 6
    }
    
    override func viewClass() -> AnyClass {
        return ChannelEventLogEditedPanelView.self
    }
}

class ChannelEventLogEditedPanelView : TableRowView {
    private let panel:ServiceEventLogMessagePanelView = ServiceEventLogMessagePanelView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(panel)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.chatBackground
    }
    
    override func updateColors() {
        super.updateColors()
        panel.backgroundColor = backdorColor
        panel.updateColors(backdorColor)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        if let item = item as? ChannelEventLogEditedPanelItem, let associatedItem = item.associatedItem {
            panel.update(with: item.panel)
            panel.setFrameSize(associatedItem.blockWidth, item.panel.height)
            panel.setFrameOrigin(associatedItem.contentOffset.x, 0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
