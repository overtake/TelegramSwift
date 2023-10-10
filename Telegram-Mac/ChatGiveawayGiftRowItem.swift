//
//  ChatGiveawayGiftRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 02.10.2023.
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

final class ChatGiveawayGiftRowItem : ChatRowItem {
    
    
    struct GiftData {
        let slug: String
        let fromGiveaway: Bool
        let boostPeerId: PeerId?
        let months: Int32
    }
    
    let headerText: TextViewLayout
    let infoText: TextViewLayout
    let winnerText: TextViewLayout
    
    let data: GiftData
    
    
    let wpPresentation: WPLayoutPresentation

    
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        let isIncoming: Bool = object.message!.isIncoming(context.account, object.renderType == .bubble)

        
        self.wpPresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, object.renderType == .bubble), activity: theme.chat.webPreviewActivity(isIncoming, object.renderType == .bubble), link: theme.chat.linkColor(isIncoming, object.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, object.renderType == .bubble, presentation: theme), renderType: object.renderType)

        
        
        
        let media = object.message!.media.first! as! TelegramMediaAction
        
        
        
        switch media.action {
        case let .giftCode(slug, fromGiveaway, boostPeerId, months):
            self.data = .init(slug: slug, fromGiveaway: fromGiveaway, boostPeerId: boostPeerId, months: months)
        default:
            fatalError()
        }
        
        let channelName: String?
        let channelId: PeerId?
        if let peerId = self.data.boostPeerId, let peer = object.message?.peers[peerId] {
            channelName = peer.displayTitle
            channelId = peer.id
        } else {
            channelName = nil
            channelId = nil
        }
        
        //TODOLANG
        let header_attr = NSMutableAttributedString()
        _ = header_attr.append(string: "**Congratulations**", color: wpPresentation.text, font: .normal(.text))
        header_attr.detectBoldColorInString(with: .medium(.text))
        self.headerText = .init(header_attr, alignment: .center, alwaysStaticItems: true)
        
        let info_attr = NSMutableAttributedString()
        _ = info_attr.append(string: "You won a prize in a giveaway", color: wpPresentation.text, font: .normal(.text))
        if let channelName = channelName, let peerId = channelId {
            _ = info_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
            info_attr.append(string: "organized by ", color: wpPresentation.text, font: .normal(.text))
            let range = info_attr.append(string: "\(channelName)", color: wpPresentation.text, font: .medium(.text))
            info_attr.addAttribute(.link, value: "https://t.me/c/\(peerId)", range: range)
            info_attr.detectBoldColorInString(with: .medium(.text))
        }
        self.infoText = .init(info_attr, alignment: .center, alwaysStaticItems: true)
        
        
        
        let winners_attr = NSMutableAttributedString()
        _ = winners_attr.append(string: "Your prize is a **Telegram Premium**", color: wpPresentation.text, font: .normal(.text))
        _ = winners_attr.append(string: "\n", color: wpPresentation.text, font: .normal(.text))
        _ = winners_attr.append(string: "subscription for \(data.months) months", color: wpPresentation.text, font: .normal(.text))
        winners_attr.detectBoldColorInString(with: .medium(.text))
        self.winnerText = .init(winners_attr, alignment: .center, alwaysStaticItems: true)
        
        let under = theme.colors.underSelectedColor

        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
        self.infoText.interactions.processURL = { [weak self] _ in
            if let channelId = channelId {
                self?.openChannel(channelId)
            }
        }
    }
    override var isForceRightLine: Bool {
        return true
    }
    
    var giftAnimation: LocalAnimatedSticker {
        switch data.months {
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
    
    func openLink() {
        execute(inapp: .gift(link: "", slug: data.slug, context: context))
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        
        
        headerText.measure(width: width)
        infoText.measure(width: width)
        winnerText.measure(width: width)

        let w = max(headerText.layoutSize.width, infoText.layoutSize.width, winnerText.layoutSize.width)
        
        var height: CGFloat = 100
        height += headerText.layoutSize.height
        height += 10
        height += infoText.layoutSize.height
        height += 10
        
        height += winnerText.layoutSize.height
        height += 10
        
        height += 40
        
        return NSMakeSize(w, height)
    }
    
    override var height: CGFloat {
        return contentSize.height + 5
    }
    
    func openChannel(_ peerId: PeerId) {
        chatInteraction.openInfo(peerId, true, nil, nil)
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatGiveawayGiftRowItemView.self
    }
}


private final class ChatGiveawayGiftRowItemView: TableRowView {
    
    private let mediaView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 90, 90))
    private let headerTextView = TextView()
    private let infoTextView = TextView()
    private let winnerTextView = TextView()
    
    private let container: View = View()
    
    
    private let action = TitleButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(mediaView)
        container.addSubview(headerTextView)
        container.addSubview(infoTextView)
        container.addSubview(winnerTextView)
        container.addSubview(action)
        
                
        headerTextView.userInteractionEnabled = false
        headerTextView.isSelectable = false
        
        infoTextView.isSelectable = false

        winnerTextView.userInteractionEnabled = false
        winnerTextView.isSelectable = false

        action.set(handler: { [weak self] _ in
            if let item = self?.item as? ChatGiveawayGiftRowItem {
                item.openLink()
            }
        }, for: .Click)
    }
    

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatGiveawayGiftRowItem else {
            return
        }
        
        mediaView.update(with: item.giftAnimation.file, size: mediaView.frame.size, context: item.context, table: item.table, parameters: item.giftAnimation.parameters, animated: animated)
        
        headerTextView.update(item.headerText)
        infoTextView.update(item.infoText)
        winnerTextView.update(item.winnerText)
        
        container.backgroundColor = theme.colors.background
        
        container.layer?.cornerRadius = 10
        
        action.set(font: .medium(.text), for: .Normal)
        action.set(color: item.wpPresentation.activity, for: .Normal)
        //TODOLANG
        action.set(text: "Open Gift Link", for: .Normal)
        action.layer?.borderWidth = System.pixel
        action.scaleOnClick = true
        action.layer?.borderColor = item.wpPresentation.activity.cgColor
        action.sizeToFit(NSMakeSize(20, 10))
        
        action.layer?.cornerRadius = action.frame.height / 2

    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        
        guard let item = item as? ChatGiveawayGiftRowItem else {
            return
        }
        container.frame = focus(NSMakeSize(item.contentSize.width + 20, item.contentSize.height))
        
        mediaView.centerX(y: 0)
        headerTextView.centerX(y: mediaView.frame.maxY + 10)
        infoTextView.centerX(y: headerTextView.frame.maxY + 10)
        winnerTextView.centerX(y: infoTextView.frame.maxY + 10)
        action.centerX(y: winnerTextView.frame.maxY + 10)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
