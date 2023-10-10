//
//  ChatGiveawayRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 29.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import ObjcUtils
import Postbox
import SwiftSignalKit
import DateUtils
import InAppSettings

final class ChatGiveawayRowItem : ChatRowItem {
    
    
    struct Channel {
        let peer: Peer
        let text: TextViewLayout
        
        var size: NSSize {
            return NSMakeSize(1 + 18 + 5 + text.layoutSize.width + 5, 20)
        }
        var rect: NSRect
    }
    
    let headerText: TextViewLayout
    let participantsText: TextViewLayout
    let winnerText: TextViewLayout
    
    let badge: BadgeNode
    
    let media: TelegramMediaGiveaway
    
    private(set) var channels: [Channel]
    
    let wpPresentation: WPLayoutPresentation

    
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        let isIncoming: Bool = object.message!.isIncoming(context.account, object.renderType == .bubble)

        
        self.wpPresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, object.renderType == .bubble), activity: theme.chat.webPreviewActivity(isIncoming, object.renderType == .bubble), link: theme.chat.linkColor(isIncoming, object.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, object.renderType == .bubble, presentation: theme), renderType: object.renderType)

        
        let media = object.message!.media.first! as! TelegramMediaGiveaway
        self.media = media
        //TODOLANG
        let header_attr = NSMutableAttributedString()
        _ = header_attr.append(string: "**Giveaway Prizes**", color: wpPresentation.text, font: .normal(.text))
        _ = header_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
        _ = header_attr.append(string: "**\(media.quantity)** Telegram Premium", color: wpPresentation.text, font: .normal(.text))
        _ = header_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
        _ = header_attr.append(string: "Subscriptions for \(media.months) months.", color: wpPresentation.text, font: .normal(.text))
        header_attr.detectBoldColorInString(with: .medium(.text))
        self.headerText = .init(header_attr, alignment: .center, alwaysStaticItems: true)
        
        let participants_attr = NSMutableAttributedString()
        _ = participants_attr.append(string: "**Participants**", color: wpPresentation.text, font: .normal(.text))
        _ = participants_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
        _ = participants_attr.append(string: "All subscribers of this channel:", color: wpPresentation.text, font: .normal(.text))
        participants_attr.detectBoldColorInString(with: .medium(.text))
        self.participantsText = .init(participants_attr, alignment: .center, alwaysStaticItems: true)
        
        
        let winners_attr = NSMutableAttributedString()
        _ = winners_attr.append(string: "**Winners Selection Date**", color: wpPresentation.text, font: .normal(.text))
        _ = winners_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
        _ = winners_attr.append(string: "\(stringForFullDate(timestamp: media.untilDate))", color: wpPresentation.text, font: .normal(.text))
        winners_attr.detectBoldColorInString(with: .medium(.text))
        self.winnerText = .init(winners_attr, alignment: .center, alwaysStaticItems: true)
        
        let under = theme.colors.underSelectedColor

        badge = .init(.initialize(string: "X\(media.quantity)", color: under, font: .avatar(.small)), theme.colors.accent, aroundFill: under, additionSize: NSMakeSize(16, 7))
        
        var channels:[Channel] = []
        for peerId in media.channelPeerIds {
            if let peer = object.message?.peers[peerId] {
                channels.append(.init(peer: peer, text: .init(.initialize(string: peer.displayTitle, color: wpPresentation.activity, font: .medium(.text))), rect: .zero))
            }
        }
        self.channels = channels
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
    }
    override var isForceRightLine: Bool {
        return true
    }
    
    var giftAnimation: LocalAnimatedSticker {
        switch media.months {
        case 12:
            return LocalAnimatedSticker.premium_gift_12
        case 6:
            return LocalAnimatedSticker.premium_gift_6
        case 3:
            return LocalAnimatedSticker.premium_gift_3
        default:
            return LocalAnimatedSticker.premium_gift_3
        }
    }
    
    func learnMore() {
        
        guard let message = self.message else {
            return
        }
        let context = self.context
        
        let giveaway = self.media
        
        let signal = context.engine.payments.premiumGiveawayInfo(peerId: message.id.peerId, messageId: message.id)


        _ = showModalProgress(signal: signal, for: context.window).start(next: { info in
            
            guard let info = info else {
                return
            }
            
            let date = stringForFullDate(timestamp: giveaway.untilDate)
            let startDate = stringForFullDate(timestamp: message.timestamp)
            
            let title: String
            let text: String
            var warning: String?
            
            var peerName = ""
            if let peerId = giveaway.channelPeerIds.first, let peer = message.peers[peerId] {
                peerName = peer.compactDisplayTitle
            }
            
            var ok: String = strings().alertOK
            var cancel: String? = nil
            var prizeSlug: String? = nil
            
            var openSlug:(String)->Void = { slug in
                execute(inapp: .gift(link: "", slug: slug, context: context))
            }
  
            switch info {
            case let .ongoing(status):
                title = "About This Giveaway"
                
                
                let intro: String
                if case .almostOver = status {
                    intro = "The giveaway was sponsored by the admins of **\(peerName)**, who acquired **\(giveaway.quantity) Telegram Premium** subscriptions for **\(giveaway.months)** months for its followers."
                } else {
                    intro = "The giveaway is sponsored by the admins of **\(peerName)**, who acquired **\(giveaway.quantity) Telegram Premium** subscriptions for **\(giveaway.months)** months for its followers."
                }
                
                let ending: String
                if case .almostOver = status {
                    if giveaway.flags.contains(.onlyNewSubscribers) {
                        if giveaway.channelPeerIds.count > 1 {
                            ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random users that joined **\(peerName)** and other listed channels after **\(startDate)**."
                        } else {
                            ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random users that joined **\(peerName)** after **\(startDate)**."
                        }
                    } else {
                        if giveaway.channelPeerIds.count > 1 {
                            ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random subscribers of **\(peerName)** and other listed channels."
                        } else {
                            ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random subscribers of **\(peerName)**."
                        }
                    }
                } else {
                    if giveaway.flags.contains(.onlyNewSubscribers) {
                        if giveaway.channelPeerIds.count > 1 {
                            ending = "On **\(date)**, Telegram will automatically select **\(giveaway.quantity)** random users that joined **\(peerName)** and **\(giveaway.channelPeerIds.count - 1)** other listed channels after **\(startDate)**."
                        } else {
                            ending = "On **\(date)**, Telegram will automatically select **\(giveaway.quantity)** random users that joined **\(peerName)** after **\(startDate)**."
                        }
                    } else {
                        if giveaway.channelPeerIds.count > 1 {
                            ending = "On **\(date)**, Telegram will automatically select **\(giveaway.quantity)** random subscribers of **\(peerName)** and **\(giveaway.channelPeerIds.count - 1)** other listed channels."
                        } else {
                            ending = "On **\(date)**, Telegram will automatically select **\(giveaway.quantity)** random subscribers of **\(peerName)**."
                        }
                    }
                }
                
                var participation: String
                switch status {
                case .notQualified:
                    if giveaway.channelPeerIds.count > 1 {
                        participation = "To take part in this giveaway please join the channel **\(peerName)** (**\(giveaway.channelPeerIds.count - 1)** other listed channels) before **\(date)**."
                    } else {
                        participation = "To take part in this giveaway please join the channel **\(peerName)** before **\(date)**."
                    }
                case let .notAllowed(reason):
                    switch reason {
                    case let .joinedTooEarly(joinedOn):
                        let joinDate = stringForFullDate(timestamp: joinedOn)
                        participation = "You are not eligible to participate in this giveaway, because you joined this channel on **\(joinDate)**, which is before the contest started."
                    case let .channelAdmin(adminId):
                        let _ = adminId
                        participation = "You are not eligible to participate in this giveaway, because you are an admin of participating channel (**\(peerName)**)."
                    }
                case .participating:
                    if giveaway.channelPeerIds.count > 1 {
                        participation = "You are participating in this giveaway, because you have joined the channel **\(peerName)** (**\(giveaway.channelPeerIds.count - 1)** other listed channels)."
                    } else {
                        participation = "You are participating in this giveaway, because you have joined the channel **\(peerName)**."
                    }
                case .almostOver:
                    participation = "The giveaway is over, preparing results."
                }
                
                if !participation.isEmpty {
                    participation = "\n\n\(participation)"
                }
                
                text = "\(intro)\n\n\(ending)\(participation)"
            case let .finished(status, finishDate, _, activatedCount):
                let date = stringForFullDate(timestamp: finishDate)
                title = "Giveaway Ended"
                
                let intro = "The giveaway was sponsored by the admins of **\(peerName)**, who acquired **\(giveaway.quantity) Telegram Premium** subscriptions for **\(giveaway.months)** months for its followers."
                
                var ending: String
                if giveaway.flags.contains(.onlyNewSubscribers) {
                    if giveaway.channelPeerIds.count > 1 {
                        ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random users that joined **\(peerName)** and other listed channels after **\(startDate)**."
                    } else {
                        ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random users that joined **\(peerName)** after **\(startDate)**."
                    }
                } else {
                    if giveaway.channelPeerIds.count > 1 {
                        ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random subscribers of **\(peerName)** and other listed channels."
                    } else {
                        ending = "On **\(date)**, Telegram automatically selected **\(giveaway.quantity)** random subscribers of **\(peerName)**."
                    }
                }
                
                if activatedCount > 0 {
                    ending += " \(activatedCount) of the winners already used their gift links."
                }
                
                var result: String
                switch status {
                case .refunded:
                    result = ""
                    warning = "The channel cancelled the prizes by reversing the payment for them."
                    ok = strings().modalOK
                case .notWon:
                    result = "\n\nYou didn't win a prize in this giveaway."
                case let .won(slug):
                    result = "\n\nYou won a prize in this giveaway. 🏆"
                    ok = "View My Prize"
                    cancel = strings().alertCancel
                    prizeSlug = slug
                }
                
                text = "\(intro)\n\n\(ending)\(result)"
            }
            if let cancel = cancel, let prizeSlug = prizeSlug {
                verifyAlert(for: context.window, header: title, information: text, ok: ok, cancel: cancel, successHandler: { _ in
                    openSlug(prizeSlug)
                })
            } else {
                alert(for: context.window, header: title, info: text)
            }
        })
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        
        
        headerText.measure(width: width)
        participantsText.measure(width: width)
        winnerText.measure(width: width)

        let w = max(headerText.layoutSize.width, participantsText.layoutSize.width, winnerText.layoutSize.width)
        
        var height: CGFloat = 100
        height += headerText.layoutSize.height
        height += 10
        height += participantsText.layoutSize.height
        height += 5
        
        //channels
        for channel in channels {
            channel.text.measure(width: w)
        }
        var point: CGPoint = NSMakePoint(0, 0)
        var index = 0
        for (i, channel) in channels.enumerated() {
            if point.x + channel.size.width > width || index == 2 {
                point.x = 0
                point.y = channel.size.height + 5
                index = 0
            }
            channels[i].rect = CGRect(origin: point, size: channel.size)
            point.x = channel.size.width + 5
            index += 1
        }
        
        var lines: [[Channel]] = []
        var current:[Channel] = []
        var y: CGFloat = 0
        for channel in channels {
            if y != channel.rect.minY {
                lines.append(current)
                current.removeAll()
            }
            current.append(channel)
            y = channel.rect.minY
        }
        if !current.isEmpty {
            lines.append(current)
        }
        
        var i: Int = 0
        for line in lines {
            var line_w: CGFloat = line.last!.rect.maxX
            let startX = floorToScreenPixels(System.backingScale, (w - line_w) / 2)
            if line.count == 1 {
                channels[i].rect.origin.x = startX
                i += 1
            } else {
                for (j, _) in line.enumerated() {
                    if j == 0 {
                        channels[i].rect.origin.x = startX
                    } else {
                        channels[i].rect.origin.x = channels[i - 1].rect.maxX + 5
                    }
                    i += 1
                }
            }
        }

        if let last = channels.last {
            height += last.rect.maxY + 10
        }
        
        height += winnerText.layoutSize.height
        height += 10

        height += 30
        
        return NSMakeSize(w, height)
    }
    
    func openChannel(_ peerId: PeerId) {
        chatInteraction.openInfo(peerId, true, nil, nil)
    }
    
    var channelsSize: NSSize {
        var size: NSSize = .zero
        if let last = channels.last {
            return NSMakeSize(contentSize.width, last.rect.maxY)
        }
        return size
    }
    
    override func viewClass() -> AnyClass {
        return ChatGiveawayRowView.self
    }
}


private final class ChatGiveawayRowView: ChatRowView {
    
    private class ChannelView : Control {
        private var channel: ChatGiveawayRowItem.Channel?
        private weak var item: ChatGiveawayRowItem?
        private let avatar = AvatarControl(font: .avatar(7))
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatar)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            avatar.setFrameSize(NSMakeSize(18, 18))
            scaleOnClick = true
            
            self.set(handler: { [weak self] _ in
                if let item = self?.item, let channel = self?.channel {
                    item.openChannel(channel.peer.id)
                }
            }, for: .Click)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ channel: ChatGiveawayRowItem.Channel, item: ChatGiveawayRowItem, presentation: WPLayoutPresentation) {
            self.channel = channel
            self.item = item
            self.avatar.setPeer(account: item.context.account, peer: channel.peer)
            self.textView.update(channel.text)
            self.backgroundColor = presentation.activity.withAlphaComponent(0.2)
            self.setFrameSize(channel.size)
            self.layer?.cornerRadius = frame.height / 2
            
            
        }
        
        override func layout() {
            super.layout()
            avatar.centerY(x: 1)
            textView.centerY(x: avatar.frame.maxX + 5)
        }
    }

    
    private let mediaView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 90, 90))
    private let headerTextView = TextView()
    private let participantsTextView = TextView()
    private let winnerTextView = TextView()
    
    private let badgeView = View()
    
    private let action = TitleButton()
    private let channels = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mediaView)
        addSubview(headerTextView)
        addSubview(participantsTextView)
        addSubview(winnerTextView)
        addSubview(channels)
        addSubview(action)
        
        
        addSubview(badgeView)
        
        headerTextView.userInteractionEnabled = false
        headerTextView.isSelectable = false
        
        participantsTextView.userInteractionEnabled = false
        participantsTextView.isSelectable = false

        winnerTextView.userInteractionEnabled = false
        winnerTextView.isSelectable = false

        
        action.set(handler: { [weak self] _ in
            if let item = self?.item as? ChatGiveawayRowItem {
                item.learnMore()
            }
        }, for: .Click)
    }
    

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatGiveawayRowItem else {
            return
        }
        
        mediaView.update(with: item.giftAnimation.file, size: mediaView.frame.size, context: item.context, table: item.table, parameters: item.giftAnimation.parameters, animated: animated)
        
        headerTextView.update(item.headerText)
        participantsTextView.update(item.participantsText)
        winnerTextView.update(item.winnerText)
        
        item.badge.view = badgeView
        badgeView.setFrameSize(item.badge.size)
        
        channels.setFrameSize(item.channelsSize)
        
        while channels.subviews.count > item.channels.count {
            channels.subviews.last?.removeFromSuperview()
        }
        while channels.subviews.count < item.channels.count {
            channels.addSubview(ChannelView(frame: .zero))
        }
        
        for (i, channel) in item.channels.enumerated() {
            let view = channels.subviews[i] as! ChannelView
            view.update(channel, item: item, presentation: item.wpPresentation)
            view.frame = channel.rect
        }
        
        item.badge.view?.needsDisplay = true
        action.set(font: .medium(.text), for: .Normal)
        action.set(color: item.wpPresentation.activity, for: .Normal)
        //TODOLANG
        action.set(text: "LEARN MORE", for: .Normal)
        action.layer?.cornerRadius = .cornerRadius
        action.layer?.borderWidth = System.pixel
        action.scaleOnClick = true
        action.layer?.borderColor = item.wpPresentation.activity.cgColor
        
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        mediaView.centerX(y: 0)
        badgeView.centerX(y: mediaView.frame.maxY - badgeView.frame.height + 5)
        headerTextView.centerX(y: mediaView.frame.maxY + 10)
        participantsTextView.centerX(y: headerTextView.frame.maxY + 10)
        channels.centerX(y: participantsTextView.frame.maxY + 5)
        winnerTextView.centerX(y: channels.frame.maxY + 10)
        action.frame = NSMakeRect(0, winnerTextView.frame.maxY + 10, contentView.frame.width, 30)
    }
    
    override func contentFrameModifier(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrameModifier(item)
        if item.renderType == .bubble {
            let addition = floorToScreenPixels(backingScaleFactor, (bubbleFrame(item).width - item.bubbleContentInset * 2 - item.additionBubbleInset - rect.width) / 2)
            rect.origin.x += addition
        }
        return rect
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
