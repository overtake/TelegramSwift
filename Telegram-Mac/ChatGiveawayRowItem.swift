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


private func flagEmoji(countryCode: String) -> String {
    let base : UInt32 = 127397
    var flagString = ""
    for v in countryCode.uppercased().unicodeScalars {
        flagString.unicodeScalars.append(UnicodeScalar(base + v.value)!)
    }
    return flagString
}


final class ChatGiveawayRowItem : ChatRowItem {
    
    
    struct Channel {
        let peer: Peer
        let text: TextViewLayout
        
        var size: NSSize {
            return NSMakeSize(1 + 18 + 5 + text.layoutSize.width + 5, 20)
        }
        var rect: NSRect
    }
    
    class AdditionalPrizes {
        let prizeDescription: TextViewLayout
        let with: TextViewLayout
        let grayColor: NSColor
        var width: CGFloat = 0
        func makeSize(width: CGFloat) {
            self.width = width
            prizeDescription.measure(width: width)
            with.measure(width: .greatestFiniteMagnitude)
        }
        init(prizeDescription: String, textColor: NSColor, grayColor: NSColor) {
            self.grayColor = grayColor
            self.with = .init(.initialize(string: strings().giveawayWith, color: grayColor, font: .normal(.text)), maximumNumberOfLines: 1, alignment: .center)
            
            let attr = NSMutableAttributedString()
            attr.append(string: prizeDescription, color: textColor, font: .normal(.text))
            attr.detectBoldColorInString(with: .medium(.text))
            self.prizeDescription = .init(attr, alignment: .center)
        }
        var size: NSSize {
            return NSMakeSize(width, self.with.layoutSize.height + self.prizeDescription.layoutSize.height + 3)
        }
    }
    
    let headerText: TextViewLayout
    let prizesInfo: TextViewLayout

    let participantsText: TextViewLayout
    let winnerText: TextViewLayout
    let countryText: TextViewLayout?
    let additionalPrizes: AdditionalPrizes?
    let badge: BadgeNode
    
    let media: TelegramMediaGiveaway
    
    private(set) var channels: [Channel]
    
    let givePresentation: WPLayoutPresentation

    
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
        let isIncoming: Bool = object.message!.isIncoming(context.account, object.renderType == .bubble)

        
        let givePresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, object.renderType == .bubble), activity: .init(main: theme.chat.activityColor(isIncoming, object.renderType == .bubble)), link: theme.chat.linkColor(isIncoming, object.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, object.renderType == .bubble, presentation: theme), renderType: object.renderType, pattern: nil)
        self.givePresentation = givePresentation

        
        let media = object.message!.media.first! as! TelegramMediaGiveaway
        self.media = media
        
        
        
        if let prizeDescription = media.prizeDescription {
            self.additionalPrizes = .init(prizeDescription: "**\(media.quantity)** \(prizeDescription)", textColor: theme.chat.textColor(isIncoming, object.renderType == .bubble), grayColor: theme.chat.grayText(isIncoming, object.renderType == .bubble))
        } else {
            self.additionalPrizes = nil
        }
        
        let header_attr = NSMutableAttributedString()
        _ = header_attr.append(string: strings().chatGiveawayMessagePrizeTitle, color: givePresentation.text, font: .medium(.text))
        header_attr.detectBoldColorInString(with: .medium(.text))
        self.headerText = .init(header_attr, alignment: .center, alwaysStaticItems: true)
        
        
        let prizes_info = NSMutableAttributedString()
        _ = prizes_info.append(string: strings().chatGiveawayMessageSubscriptionsCountable(Int(media.quantity)), color: givePresentation.text, font: .normal(.text))
        _ = prizes_info.append(string: "\n", color: givePresentation.text, font: .normal(.text))
        _ = prizes_info.append(string: strings().chatGiveawayMessageMonthsCountable(Int(media.months)), color: givePresentation.text, font: .normal(.text))
        prizes_info.detectBoldColorInString(with: .medium(.text))
        self.prizesInfo = .init(prizes_info, alignment: .center, alwaysStaticItems: true)
        
        
        let participants_attr = NSMutableAttributedString()
        if media.flags.contains(.onlyNewSubscribers) {
            _ = participants_attr.append(string: strings().chatGiveawayMessageParticipantsNew, color: givePresentation.text, font: .normal(.text))
        } else {
            _ = participants_attr.append(string: strings().chatGiveawayMessageParticipants, color: givePresentation.text, font: .normal(.text))
        }
        participants_attr.detectBoldColorInString(with: .medium(.text))
        self.participantsText = .init(participants_attr, alignment: .center, alwaysStaticItems: true)
        
        
        let winners_attr = NSMutableAttributedString()
        _ = winners_attr.append(string: strings().chatGiveawayMessageDateTitle, color: givePresentation.text, font: .medium(.text))
        _ = winners_attr.append(string: "\n", color: givePresentation.text, font: .normal(.text))
        _ = winners_attr.append(string: "\(stringForFullDate(timestamp: media.untilDate))", color: givePresentation.text, font: .normal(.text))
        self.winnerText = .init(winners_attr, alignment: .center, alwaysStaticItems: true)
        
        let countriesText: String
        if !media.countries.isEmpty {
            let locale = appAppearance.locale
            let countryNames: [String] = media.countries.map { id -> String in
                if let countryName = locale.localizedString(forRegionCode: id) {
                    return "\(flagEmoji(countryCode: id))\(countryName)"
                } else {
                    return id
                }
            }
            var countries: String = ""
            if countryNames.count == 1, let country = countryNames.first {
                countries = country
            } else {
                for i in 0 ..< countryNames.count {
                    countries.append(countryNames[i])
                    if i == countryNames.count - 2 {
                        countries.append(strings().chatGiveawayMessageCountriesLastDelimiter)
                    } else if i < countryNames.count - 2 {
                        countries.append(strings().chatGiveawayMessageCountriesDelimiter)
                    }

                }
            }
            countriesText = strings().chatGiveawayMessageCountriesFrom(countries)
        } else {
            countriesText = ""
        }
        
        if !countriesText.isEmpty {
            let country_attr = NSMutableAttributedString()
            _ = country_attr.append(string: countriesText, color: givePresentation.text, font: .normal(.text))
            self.countryText = .init(country_attr, alignment: .center, alwaysStaticItems: true)
        } else {
            self.countryText = nil
        }

        
        let under = theme.colors.underSelectedColor

        badge = .init(.initialize(string: "X\(media.quantity)", color: under, font: .avatar(.small)), theme.colors.accent, aroundFill: theme.chat.bubbleBackgroundColor(isIncoming, object.renderType == .bubble), additionSize: NSMakeSize(16, 7))
        
        var channels:[Channel] = []
        for peerId in media.channelPeerIds {
            if let peer = object.message?.peers[peerId] {
                
                let color = isIncoming || object.renderType == .list ? context.peerNameColors.get(peer.nameColor ?? .blue).main : theme.colors.accentIconBubble_outgoing
                channels.append(.init(peer: peer, text: .init(.initialize(string: peer.displayTitle, color: color, font: .medium(.text)), maximumNumberOfLines: 1), rect: .zero))
            }
        }
        self.channels = channels
        super.init(initialSize, chatInteraction, context, object, theme: theme)
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
            
            let untilDate = stringForFullDate(timestamp: giveaway.untilDate)
            let startDate = stringForFullDate(timestamp: message.timestamp)


            let title: String
            let text: String
            var warning: String?
            
            var peerName = ""
            if let peerId = giveaway.channelPeerIds.first, let peer = message.peers[peerId] {
                peerName = peer.compactDisplayTitle
            }
            
            var ok: String = strings().alertOK
            var disclaimer: String? = nil
            var cancel: String? = nil
            var prizeSlug: String? = nil
            
            var openSlug:(String)->Void = { slug in
                execute(inapp: .gift(link: "", slug: slug, context: context))
            }
            
            var additionalPrize: String = ""
            
            if let prize = giveaway.prizeDescription {
                additionalPrize = strings().giveawayAdditionalPrize(peerName, "\(giveaway.quantity) \(prize)") + "\n\n"
            }
  
            switch info {
            case let .ongoing(start, status):
                let startDate = stringForFullDate(timestamp: start)
                
                title = strings().chatGiveawayInfoTitle
                let intro: String
                if case .almostOver = status {
                    intro = strings().chatGiveawayInfoEndedIntro(peerName, strings().chatGiveawayInfoSubscriptionsCountable(Int(giveaway.quantity)), strings().chatGiveawayInfoMonthsCountable(Int(giveaway.months)))
                } else {
                    intro = strings().chatGiveawayInfoOngoingIntro(peerName, strings().chatGiveawayInfoSubscriptionsCountable(Int(giveaway.quantity)), strings().chatGiveawayInfoMonthsCountable(Int(giveaway.months)))
                }

                
                let ending: String
                if giveaway.flags.contains(.onlyNewSubscribers) {
                    let randomUsers = strings().chatGiveawayInfoRandomUsersCountable(Int(giveaway.quantity))
                    if giveaway.channelPeerIds.count > 1 {
                        ending = strings().chatGiveawayInfoOngoingNewMany(untilDate, randomUsers, peerName, strings().chatGiveawayInfoOtherChannelsCountable(giveaway.channelPeerIds.count - 1), startDate)
                    } else {
                        ending = strings().chatGiveawayInfoOngoingNew(untilDate, randomUsers, peerName, startDate)
                    }
                } else {
                    let randomSubscribers = strings().chatGiveawayInfoRandomSubscribersCountable(Int(giveaway.quantity))
                    if giveaway.channelPeerIds.count > 1 {
                        ending = strings().chatGiveawayInfoOngoingMany(untilDate, randomSubscribers, peerName, strings().chatGiveawayInfoOtherChannelsCountable(giveaway.channelPeerIds.count - 1))
                    } else {
                        ending = strings().chatGiveawayInfoOngoing(untilDate, randomSubscribers, peerName)
                    }
                }

                
                var participation: String
                switch status {
                case .notQualified:
                    if giveaway.channelPeerIds.count > 1 {
                        participation = strings().chatGiveawayInfoNotQualifiedMany(peerName, strings().chatGiveawayInfoOtherChannelsCountable(giveaway.channelPeerIds.count - 1), untilDate)
                    } else {
                        participation = strings().chatGiveawayInfoNotQualified(peerName, untilDate)
                    }
                case let .notAllowed(reason):
                    switch reason {
                    case let .joinedTooEarly(joinedOn):
                        let joinDate = stringForFullDate(timestamp: joinedOn)
                        participation = strings().chatGiveawayInfoNotAllowedJoinedEarly(joinDate)
                    case let .channelAdmin(adminId):
                        let _ = adminId
                        participation = strings().chatGiveawayInfoNotAllowedAdmin(peerName)
                    case .disallowedCountry:
                        participation = strings().chatGiveawayInfoNotAllowedCountry
                    }
                case .participating:
                    if giveaway.channelPeerIds.count > 1 {
                        participation = strings().chatGiveawayInfoParticipatingMany(peerName, strings().chatGiveawayInfoOtherChannelsCountable(giveaway.channelPeerIds.count - 1))
                    } else {
                        participation = strings().chatGiveawayInfoParticipating(peerName)
                    }
                case .almostOver:
                    participation = strings().chatGiveawayInfoAlmostOver
                }
                
                if !participation.isEmpty {
                    participation = "\n\n\(participation)"
                }
                
                text = "\(intro)\n\n\(additionalPrize)\(ending)\(participation)"
            case let .finished(status, start, finish, _, activatedCount):
                let startDate = stringForFullDate(timestamp: start)
                let finishDate = stringForFullDate(timestamp: finish)
                
                title = strings().chatGiveawayInfoEndedTitle
                let intro = strings().chatGiveawayInfoEndedIntro(peerName, strings().chatGiveawayInfoSubscriptionsCountable(Int(giveaway.quantity)), strings().chatGiveawayInfoMonthsCountable(Int(giveaway.months)))
                
                var ending: String
                if giveaway.flags.contains(.onlyNewSubscribers) {
                    let randomUsers = strings().chatGiveawayInfoRandomUsersCountable(Int(giveaway.quantity))
                    if giveaway.channelPeerIds.count > 1 {
                        ending = strings().chatGiveawayInfoEndedNewMany(finishDate, randomUsers, peerName, startDate)
                    } else {
                        ending = strings().chatGiveawayInfoEndedNew(finishDate, randomUsers, peerName, startDate)
                    }
                } else {
                    let randomSubscribers = strings().chatGiveawayInfoRandomSubscribersCountable(Int(giveaway.quantity))
                    if giveaway.channelPeerIds.count > 1 {
                        ending = strings().chatGiveawayInfoEndedMany(finishDate, randomSubscribers, peerName)
                    } else {
                        ending = strings().chatGiveawayInfoEnded(finishDate, randomSubscribers, peerName)
                    }

                }
                
                if activatedCount > 0 {
                    ending += " " + strings().chatGiveawayInfoActivatedLinksCountable(Int(activatedCount))
                }
                
                var result: String
                switch status {
                case .refunded:
                    result = ""
                    warning = strings().chatGiveawayInfoRefunded
                    ok = strings().modalOK
                case .notWon:
                    result = "\n\n" + strings().chatGiveawayInfoDidntWin
                case let .won(slug):
                    result = "\n\n" + strings().chatGiveawayInfoWon("🏆")
                    ok = strings().chatGiveawayInfoViewPrize
                    cancel = strings().alertCancel
                    prizeSlug = slug
                }
                
                text = "\(intro)\n\n\(additionalPrize)\(ending)\(result)"
            }

            if let cancel = cancel, let prizeSlug = prizeSlug {
                verifyAlert(for: context.window, header: title, information: text, ok: ok, cancel: cancel, successHandler: { _ in
                    openSlug(prizeSlug)
                })
            } else {
                alert(for: context.window, header: title, info: text, ok: ok, disclaimer: warning)
            }
        })
    }
    
    override var fixedContentSize: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        
        let width = min(width, 300)
        
        headerText.measure(width: width)
        prizesInfo.measure(width: width)

        participantsText.measure(width: width)
        winnerText.measure(width: width)
        
        let w = max(headerText.layoutSize.width, prizesInfo.layoutSize.width, participantsText.layoutSize.width, winnerText.layoutSize.width)

        
        countryText?.measure(width: w)

        
        var height: CGFloat = 100
        
        height += headerText.layoutSize.height
        height += 5
        
        
        if let additionalPrizes = additionalPrizes {
            additionalPrizes.makeSize(width: w)
            height += additionalPrizes.size.height + 5
        }
        
        height += prizesInfo.layoutSize.height
        height += 10
        
        height += participantsText.layoutSize.height
        height += 5
        
        //channels
        for channel in channels {
            channel.text.measure(width: w - 46)
        }
        var point: CGPoint = NSMakePoint(0, 0)
        var index = 0
        for (i, channel) in channels.enumerated() {
            if point.x + channel.size.width > w || index == 2, point.x != 0 {
                point.x = 0
                point.y += channel.size.height + 5
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
            if y != channel.rect.minY, !current.isEmpty {
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
            let line_w: CGFloat = line.last!.rect.maxX
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
        
        if let countryText = countryText {
            height += countryText.layoutSize.height
            height += 10
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
            avatar.userInteractionEnabled = false 
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
            
            let color = item.context.peerNameColors.get(channel.peer.nameColor ?? .blue)
            
            self.backgroundColor = color.main.withAlphaComponent(0.2)
            self.setFrameSize(channel.size)
            self.layer?.cornerRadius = frame.height / 2
            
            
        }
        
        override func layout() {
            super.layout()
            avatar.centerY(x: 1)
            textView.centerY(x: avatar.frame.maxX + 5)
        }
    }
    
    final class AdditionalPrizesView : View {
        private let text = TextView()
        private let with = TextView()
        private var prizes: ChatGiveawayRowItem.AdditionalPrizes? = nil
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.addSubview(text)
            addSubview(with)
            text.userInteractionEnabled = false
            text.isSelectable = false
            with.userInteractionEnabled = false
            with.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(_ prizes: ChatGiveawayRowItem.AdditionalPrizes) {
            self.prizes = prizes
            self.text.update(prizes.prizeDescription)
            self.with.update(prizes.with)
            needsLayout = true
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            guard let prizes = self.prizes else {
                return
            }
            
            ctx.setFillColor(prizes.grayColor.withAlphaComponent(0.5).cgColor)
            ctx.fill(NSMakeRect(0, with.frame.midY, with.frame.minX - 5, .borderSize))
            ctx.fill(NSMakeRect(with.frame.maxX + 5, with.frame.midY, with.frame.minX - 10, .borderSize))

        }
        
        override func layout() {
            super.layout()
            self.text.centerX(y: 0)
            self.with.centerX(y: self.text.frame.maxY + 3)
        }
    }

    
    private let mediaView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 90, 90))
    private let headerTextView = TextView()
    private let prizezTextView = TextView()

    private let participantsTextView = TextView()
    private let winnerTextView = TextView()
    private var countryText: TextView?
    
    private let badgeView = View()
    
    private let action = TextButton()
    private let channels = View()
    private var additionalPrizes: AdditionalPrizesView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mediaView)
        addSubview(headerTextView)
        addSubview(prizezTextView)
        addSubview(participantsTextView)
        addSubview(winnerTextView)
        addSubview(channels)
        addSubview(action)
        
        
        addSubview(badgeView)
        
        headerTextView.userInteractionEnabled = false
        headerTextView.isSelectable = false
        
        prizezTextView.userInteractionEnabled = false
        prizezTextView.isSelectable = false
        
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
        
        if let additionalPrizes = item.additionalPrizes {
            let current: AdditionalPrizesView
            if let view = self.additionalPrizes {
                current = view
            } else {
                current = AdditionalPrizesView(frame: additionalPrizes.size.bounds)
                addSubview(current)
                self.additionalPrizes = current
            }
            current.set(additionalPrizes)
        } else if let view = self.additionalPrizes {
            performSubviewRemoval(view, animated: animated)
            self.additionalPrizes = nil
        }
        
        mediaView.update(with: item.giftAnimation.file, size: mediaView.frame.size, context: item.context, table: item.table, parameters: item.giftAnimation.parameters, animated: animated)
        
        headerTextView.update(item.headerText)
        prizezTextView.update(item.prizesInfo)
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
        
        if let countryText = item.countryText {
            let current: TextView
            if let view = self.countryText {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.countryText = current
                addSubview(current)
            }
            current.update(countryText)
        } else if let view = self.countryText {
            performSubviewRemoval(view, animated: animated)
            self.countryText = nil
        }
        
        for (i, channel) in item.channels.enumerated() {
            let view = channels.subviews[i] as! ChannelView
            view.update(channel, item: item, presentation: item.givePresentation)
            view.frame = channel.rect
        }
        
        item.badge.view?.needsDisplay = true
        action.set(font: .medium(.text), for: .Normal)
        action.set(color: item.givePresentation.activity.main, for: .Normal)
        action.set(background: item.givePresentation.activity.main.withAlphaComponent(0.1), for: .Normal)
        action.set(text: strings().chatMessageGiveawayLearnMore, for: .Normal)
        action.layer?.cornerRadius = .cornerRadius
        action.scaleOnClick = true
        
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        mediaView.centerX(y: 0)
        badgeView.centerX(y: mediaView.frame.maxY - badgeView.frame.height + 5)
        
        var currentY: CGFloat = mediaView.frame.maxY + 10

        headerTextView.centerX(y: currentY)
        currentY = headerTextView.frame.maxY + 5
        
        if let additionalPrizes = self.additionalPrizes {
            additionalPrizes.centerX(y: currentY)
            currentY = additionalPrizes.frame.maxY + 5
        }
        self.prizezTextView.centerX(y: currentY)
        currentY = self.prizezTextView.frame.maxY + 10
        
        participantsTextView.centerX(y: currentY)
        currentY = participantsTextView.frame.maxY + 5
        channels.centerX(y: currentY)
        
        var y: CGFloat = channels.frame.maxY + 10
        if let countryText = countryText {
            countryText.centerX(y: y)
            y += countryText.frame.height + 10
        }
        winnerTextView.centerX(y: y)
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
