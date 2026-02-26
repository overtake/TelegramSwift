//
//  Star_Transaction.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit
import DateUtils
import CurrencyFormat

extension StarGift.UniqueGift {
    var file: TelegramMediaFile? {
        for attribute in self.attributes {
            inner: switch attribute {
            case .model(_, let file, _):
                return file
            default:
                break inner
            }
        }
        return nil
    }
    var pattern: TelegramMediaFile? {
        for attribute in self.attributes {
            inner: switch attribute {
            case let .pattern(_, file, _):
                return file
            default:
                break
            }
        }
        return nil
    }
    var patternColor: NSColor? {
        for attribute in self.attributes {
            inner: switch attribute {
            case let .backdrop(_, _, _, _, patternColor, _, _):
                return NSColor(UInt32(patternColor))
            default:
                break inner
            }
        }
        return nil
    }
    var backdrop: [NSColor]? {
        for attribute in self.attributes {
            inner: switch attribute {
            case let .backdrop(_, _, innerColor, outerColor, _, _, _):
                return [NSColor(UInt32(innerColor)), NSColor(UInt32(outerColor))]
            default:
                break inner
            }
        }
        return nil
    }
    
    var link: String {
        return "https://t.me/nft/\(self.title.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "’", with: ""))-\(self.number)"
    }
}

private final class GallerySupplyment : InteractionContentViewProtocol {
    private weak var tableView: TableView?
    init(tableView: TableView) {
        self.tableView = tableView
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if let tableView = tableView {
            let item = tableView.item(stableId: InputDataEntryId.custom(_id_header))
            return item?.view?.interactionContentView(for: stableId, animateIn: animateIn)
        }
        return nil
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let transaction: StarsContext.State.Transaction
    fileprivate let currency: CurrencyAmount.Currency
    fileprivate let peer: EnginePeer?
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let descLayout: TextViewLayout?
    fileprivate let incoming: Bool
    fileprivate let purpose: Star_TransactionPurpose
    
    fileprivate var refund: TextViewLayout?
    fileprivate let arguments: Arguments
    fileprivate let isGift: Bool
    fileprivate let uniqueGift: StarGift.UniqueGift?
    
    fileprivate private(set) var authorLayout: TextViewLayout?
    fileprivate private(set) var authorPeer: Peer?
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: StarsContext.State.Transaction, currency: CurrencyAmount.Currency, peer: EnginePeer?, purpose: Star_TransactionPurpose, arguments: Arguments, author: Peer?) {
        self.context = context
        self.transaction = transaction
        self.currency = currency
        self.peer = peer
        self.arguments = arguments
        self.purpose = purpose
        
        self.isGift = purpose.isGift || transaction.flags.contains(.isGift) || transaction.giveawayMessageId != nil || transaction.starGift != nil
        
                
        if let gift = transaction.starGift {
            switch gift {
            case let .unique(unique):
                self.uniqueGift = unique
            default:
                self.uniqueGift = nil
            }
        } else {
            self.uniqueGift = nil
        }
        
        let upgraded: Bool
        
        var fromProfile: Bool = false
        switch purpose {
        case let .starGift(_, _, _, _, _, _, _, _fromProfile, _upgraded, _, _, _, _, _, _, _):
            fromProfile = _fromProfile
            upgraded = _upgraded
        default:
            upgraded = false
        }
        
        let header: String
        let incoming: Bool = transaction.count.amount.value > 0
        let amount: Double
        
        if let uniqueGift {
            header = uniqueGift.title
            if purpose.isStarGift {
                amount = transaction.count.amount.totalValue
            } else {
                amount = abs(transaction.count.amount.totalValue)
            }
        } else if isGift {
            
            if let author {
                self.authorLayout = .init(
                    .initialize(
                        string: strings().starTransactionReleasedBy(author.addressName ?? ""),
                        color: theme.colors.grayText,
                        font: .normal(.text)
                    ),
                    maximumNumberOfLines: 1,
                    truncationType: .middle
                )
            } else {
                self.authorLayout = nil
            }
            self.authorPeer = author
            
            if purpose == .unavailableGift {
                header = strings().giftUnavailable
            } else if transaction.giveawayMessageId != nil {
                header = strings().starsTransactionReceivedPrize
            } else {
                if fromProfile {
                    header = strings().starsTransactionGift
                } else {
                    header = incoming ? strings().starsTransactionReceivedGift : strings().starsTransactionSentGift
                }
            }
            if purpose.isStarGift {
                amount = transaction.count.amount.totalValue
            } else {
                amount = abs(transaction.count.amount.totalValue)
            }
        } else if transaction.flags.contains(.isReaction) {
            header = strings().starsTransactionPaidReaction
            amount = transaction.count.amount.totalValue
        } else if let period = transaction.subscriptionPeriod {
            if period == 30 * 24 * 60 * 60 {
                header = strings().starsSubscriptionPeriodMonthly
            } else if period == 7 * 24 * 60 * 60 {
                header = strings().starsSubscriptionPeriodWeekly
            } else if period == 1 * 24 * 60 * 60 {
                header = strings().starsSubscriptionPeriodDaily
            } else {
                header = strings().starsSubscriptionPeriodUnknown
            }
            amount = transaction.count.amount.totalValue
        } else if let commission = transaction.starrefCommissionPermille, transaction.starrefPeerId == nil {
            header = strings().starsTransactionCommission("\(commission.decemial.string)%")
            amount = transaction.count.amount.totalValue
        } else {
            switch transaction.peer {
            case .appStore:
                header = strings().starListTransactionAppStore
            case .fragment:
                header = strings().starListTransactionFragment
            case .playMarket:
                header = strings().starListTransactionPlayMarket
            case .premiumBot:
                header = strings().starListTransactionPremiumBot
            case .ads:
                header = strings().starListTransactionAds
            case .unsupported:
                header = strings().starListTransactionUnknown
            case .peer:
                if let count = transaction.paidMessageCount {
                    header = strings().starTransactionMessageFeeCountable(Int(count))
                } else if !transaction.media.isEmpty {
                    header = strings().starsTransactionMediaPurchase
                } else {
                    header = transaction.title ?? peer?._asPeer().displayTitle ?? ""
                }
            case .apiLimitExtension:
                header = strings().starsIntroTransactionTelegramBotApiTitle
            }
            amount = transaction.count.amount.totalValue
        }
        
        self.incoming = incoming
        
        self.headerLayout = .init(.initialize(string: header, color: uniqueGift != nil ? .white : theme.colors.text, font: .medium(18)), alignment: .center)
        
        

        
        let attr = NSMutableAttributedString()
        if let uniqueGift {
            attr.append(string: strings().starTransactionGiftCollectible("#\(uniqueGift.number)"), color: NSColor.white.withAlphaComponent(0.6), font: .normal(.text))
            
            if transaction.flags.contains(.isStarGiftResale) {
                attr.append(string: "\n\n", color: NSColor.white.withAlphaComponent(0.6), font: .normal(.text))
                attr.append(string: "\(incoming && !fromProfile ? "+" : "")\(amount) \(clown)", color: theme.colors.text, font: .medium(15))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)

            }
        } else {
            switch purpose {
            case .unavailableGift, .starGift:
                break
            default:
                if purpose == .tonGift || currency == .ton {
                    let formatted = formatCurrencyAmount(Int64(amount), currency: TON).prettyCurrencyNumberUsd + " " + TON
                    attr.append(string: "\(incoming && !fromProfile ? "+" : "")\(formatted) \(clown)", color: incoming ? theme.colors.greenUI : (amount > 0 ? theme.colors.greenUI : theme.colors.redUI), font: .normal(15))
                    attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: amount > 0 ? theme.colors.greenUI : theme.colors.redUI), for: clown)
                } else {
                    attr.append(string: "\(incoming && !fromProfile ? "+" : "")\(amount) \(clown)", color: incoming ? theme.colors.greenUI : (amount > 0 ? theme.colors.text : theme.colors.redUI), font: .normal(15))
                    attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
                }
            }
        }
        
        self.infoLayout = .init(attr, alignment: .center)
        if transaction.paidMessageCount != nil, let commission = transaction.starrefCommissionPermille?.decemial {
            let text = strings().starTransactionMessageFeeInfo("\((100 - commission).string)%")
            
            let textAttr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })).mutableCopy() as! NSMutableAttributedString
            
            textAttr.detectBoldColorInString(with: .medium(.text))
            
            self.descLayout = .init(textAttr, alignment: .center)
            
        } else if let premiumGiftMonths = transaction.premiumGiftMonths {
            let text = strings().starsTransactionPremiumFor(Int(premiumGiftMonths))
            self.descLayout = .init(.initialize(string: text, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else if upgraded {
            self.descLayout = nil
        } else if let _ = uniqueGift {
            self.descLayout = nil
        } else if purpose == .unavailableGift {
            self.descLayout = .init(.initialize(string: strings().giftSoldOutError, color: theme.colors.redUI, font: .normal(.text)), alignment: .center)
        } else if !transaction.media.isEmpty {
            
            var description: String = ""
            
            let videoCount = transaction.media.filter {
                $0 is TelegramMediaFile
            }.count
            let photoCount = Int(transaction.media.count - videoCount)
            
            if photoCount > 0 && videoCount > 0 {
                description = strings().starsTransferMediaAnd(strings().starsTransferPhotosCountable(photoCount), strings().starsTransferVideosCountable(videoCount))
            } else if photoCount > 0 {
                if photoCount > 1 {
                    description += strings().starsTransferPhotosCountable(photoCount)
                } else {
                    description += strings().starsTransferSinglePhoto
                }
            } else if videoCount > 0 {
                if videoCount > 1 {
                    description += strings().starsTransferVideosCountable(videoCount)
                } else {
                    description += strings().starsTransferSingleVideo
                }
            }
            self.descLayout = .init(.initialize(string: description, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else if let floodskipNumber = transaction.floodskipNumber {
            let string = strings().starTransactionBroadcastMessagesCountable(Int(floodskipNumber)).replacingOccurrences(of: "\(floodskipNumber)", with: floodskipNumber.formattedWithSeparator)
            self.descLayout = .init(.initialize(string: string, color: theme.colors.text, font: .normal(.text)), alignment: .center)

        } else if let desc = transaction.description {
            self.descLayout = .init(.initialize(string: desc, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else if isGift && purpose.isGift {
            if purpose == .unavailableGift {
                self.descLayout = .init(.initialize(string: strings().giftSoldOutError, color: theme.colors.redUI, font: .normal(.text)), alignment: .center)
            } else {
                var text: String
                var fromProfile: Bool = false
                var nameHidden: Bool = false
                switch purpose {
                case let .starGift(_, convertStars, _, _, _nameHidden, savedToProfile, convertedToStars, _fromProfile, _, _, _, _, sender, _, _, _):
                    let displayTitle: String
                    switch transaction.peer {
                    case let .peer(peer):
                        displayTitle = peer._asPeer().displayTitle
                    default:
                        displayTitle = peer?._asPeer().compactDisplayTitle ?? ""
                    }
                    if let convertStars {
                        let convertStarsString = strings().starListItemCountCountable(Int(convertStars))
                        fromProfile = _fromProfile
                        nameHidden = _nameHidden
                        if incoming {
                            if savedToProfile {
                                if let _ = sender {
                                    text = strings().starsStarGiftTextKeptOnPageIncomingGifts
                                } else {
                                    text = strings().starsStarGiftTextKeptOnPageIncoming
                                }
                            } else if convertedToStars {
                                if let _ = sender {
                                    text = strings().giftViewKeepUpgradeOrConvertDescriptionChannel(convertStarsString)
                                } else {
                                    text = strings().starsStarGiftTextConvertedIncoming(convertStarsString)
                                }
                            } else {
                                if let _ = sender {
                                    text = strings().giftViewKeepOrConvertDescriptionChannel(convertStarsString)
                                } else {
                                    text = strings().starsStarGiftTextIncoming(convertStarsString)
                                }
                            }
                        } else {
                            if savedToProfile {
                                text = strings().starsStarGiftTextKeptOnPageOutgoing(displayTitle)
                            } else if convertedToStars {
                                text = strings().starsStarGiftTextConvertedOutgoing(displayTitle, convertStarsString)
                            } else {
                                text = strings().starsStarGiftTextOutgoing(displayTitle, convertStarsString)
                            }
                        }
                    } else {
                        text = strings().starsStarGiftTextKeepOrHide
                    }
                    
                default:
                    if purpose == .tonGift || currency == .ton {
                        text = strings().starTransactionTonDescription
                    } else {
                        text = strings().starsExampleAppsText
                    }
                }
                if !fromProfile {
                    if purpose != .tonGift && currency != .ton {
                        text += " " + strings().starsStarGiftTextLink
                    }
                    
                    let textAttr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, contents)
                    })).mutableCopy() as! NSMutableAttributedString
                    
                    if nameHidden, incoming {
                        textAttr.append(string: "\n\n")
                        textAttr.append(string: strings().starTransactionStarGiftAnonymous, color: theme.colors.grayText, font: .normal(.text))
                    }
                    
                    self.descLayout = .init(textAttr, alignment: .center)
                } else if nameHidden, incoming, !fromProfile {
                    let textAttr = NSMutableAttributedString()
                    textAttr.append(string: strings().starTransactionStarGiftAnonymous, color: theme.colors.grayText, font: .normal(.text))
                    self.descLayout = .init(textAttr, alignment: .center)
                } else {
                    self.descLayout = nil
                }
            }
            
            
        } else {
            self.descLayout = nil
        }
        
        self.descLayout?.interactions.processURL = { url in
            if let url = url as? String {
                if url == "apps" {
                    arguments.openApps()
                } else if url == "stars" {
                    arguments.openStars()
                } else if url == "changeFee" {
                    arguments.changeFee()
                }
            }
        }
        
        if transaction.flags.contains(.isRefund) {
            self.refund = .init(.initialize(string: strings().starListRefund, color: theme.colors.greenUI, font: .medium(.text)), alignment: .center)
            self.refund?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.refund = nil
        }
        
        super.init(initialSize, stableId: stableId, viewType: .legacy, inset: .init())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.headerLayout.measure(width: width - 40)
        self.infoLayout.measure(width: width - 40)
        self.descLayout?.measure(width: width - 40)
        
        self.authorLayout?.measure(width: width - 40)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    override var height: CGFloat {
        var height = 10 + 10 + headerLayout.layoutSize.height + 5 + infoLayout.layoutSize.height + 10
        
        if isGift {
            height += 120
        } else {
            height += 80
        }
        
        if let descLayout {
            height += descLayout.layoutSize.height + 5 + 2
        }
        if let uniqueGift {
            height += 10
        }
        
        if let authorLayout {
            height += authorLayout.layoutSize.height
            height += 5
        }
        
        return height
    }
    
    var giftFile: TelegramMediaFile {
        switch purpose {
        case let .starGift(gift, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            switch gift {
            case let .generic(gift):
                return gift.file
            case let .unique(gift):
                return gift.file ?? LocalAnimatedSticker.bestForStarsGift(abs(transaction.count.amount.value)).file
            }
        case .unavailableGift:
            return self.transaction.starGift?.generic?.file ?? LocalAnimatedSticker.bestForStarsGift(abs(transaction.count.amount.value)).file
        case .tonGift:
            return LocalAnimatedSticker.bestForTonGift(abs(transaction.count.amount.value)).file
        default:
            if currency == .ton {
                return LocalAnimatedSticker.bestForTonGift(abs(transaction.count.amount.value)).file
            }
            if transaction.flags.contains(.isStarGiftResale) {
                return self.transaction.starGift?.generic?.file ?? self.transaction.starGift?.unique?.file ?? LocalAnimatedSticker.bestForStarsGift(abs(transaction.count.amount.value)).file
            } else {
                return LocalAnimatedSticker.bestForStarsGift(abs(transaction.count.amount.value)).file
            }
        }
    }
    
}

private final class HeaderView : GeneralContainableRowView {
    private var photo: TransformImageView?
    private var avatar: AvatarControl?
    private let control = Control(frame: NSMakeRect(0, 0, 80, 80))
    private let sceneView: GoldenStarSceneView
    private let dismiss = ImageButton()
    private var actions: ImageButton?
    private let headerView = TextView()
    private let infoView = InteractiveTextView()
    private var refundView: TextView?
    private let infoContainer: View = View()
    private var outgoingView: ImageView?
    private var descView: TextView?
    private var starBadgeView: ImageView?
    private var authorView: TextView?
    
    private var giftView: InlineStickerView?
    
    private var emoji: PeerInfoSpawnEmojiView?
    private var backgroundView: PeerInfoBackgroundView?

    
    required init(frame frameRect: NSRect) {
        self.sceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, frameRect.width, 150))
        super.init(frame: frameRect)
        addSubview(sceneView)
        addSubview(headerView)
        addSubview(control)
        infoContainer.addSubview(infoView)
        addSubview(dismiss)

        control.layer?.masksToBounds = false
        
        self.sceneView.sceneBackground = theme.colors.listBackground
        
        addSubview(infoContainer)
        
        sceneView.hideStar()
        
        control.scaleOnClick = true
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.arguments.previewMedia()
            }
        }, for: .Click)
        
        self.layer?.masksToBounds = false

    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        return photo ?? self.control
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        sceneView.isHidden = item.uniqueGift != nil
        
        
        if let uniqueGift = item.uniqueGift {
            do {
                let current:PeerInfoBackgroundView
                if let view = self.backgroundView {
                    current = view
                } else {
                    current = PeerInfoBackgroundView(frame: NSMakeRect(0, 0, 180, 180))
                    self.addSubview(current, positioned: .below, relativeTo: self.subviews.first)
                    self.backgroundView = current
                }
                var colors: [NSColor] = []

                for attribute in uniqueGift.attributes {
                    switch attribute {
                    case let .backdrop(_, _, innerColor, outerColor, _, _, _):
                        colors = [NSColor(UInt32(innerColor)), NSColor(UInt32(outerColor))]
                    default:
                        break
                    }
                }
                current.gradient = colors
            }
            do {
                let current:PeerInfoSpawnEmojiView
                if let view = self.emoji {
                    current = view
                } else {
                    current = PeerInfoSpawnEmojiView(frame: NSMakeRect(0, 0, 180, 180))
                    self.addSubview(current, positioned: .above, relativeTo: self.backgroundView)
                    self.emoji = current
                }
                
                var patternFile: TelegramMediaFile?
                var patternColor: NSColor?

                for attribute in uniqueGift.attributes {
                    switch attribute {
                    case .pattern(_, let file, _):
                        patternFile = file
                    case let .backdrop(_, _, _, _, color, _, _):
                        patternColor = NSColor(UInt32(color)).withAlphaComponent(0.3)
                    default:
                        break
                    }
                }
                if let patternFile, let patternColor {
                    current.set(fileId: patternFile.fileId.id, color: patternColor, context: item.context, animated: animated)
                }
            }
            
            do {
                let current: ImageButton
                if let view = self.actions {
                    current = view
                } else {
                    current = ImageButton()
                    addSubview(current)
                    self.actions = current
                    current.autohighlight = false
                    current.scaleOnClick = true
                }
                current.set(image: NSImage.init(resource: .iconChatActions).precomposed(.white), for: .Normal)
                current.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
                
                current.contextMenu = {
                    let menu = ContextMenu()
                    
                    menu.addItem(ContextMenuItem(strings().contextCopy, handler: {
                        item.arguments.copyNftLink(uniqueGift)
                    }, itemImage: MenuAnimation.menu_copy_link.value))
                    
                    menu.addItem(ContextMenuItem(strings().storyMyInputShare, handler: {
                        item.arguments.shareNft(uniqueGift)
                    }, itemImage: MenuAnimation.menu_share.value))
                    
                    if case let .peerId(peerId) = uniqueGift.owner, peerId == item.arguments.context.peerId {
                        menu.addItem(ContextMenuItem(strings().giftTransferConfirmationTransferFree, handler: {
                            item.arguments.transferUnqiue(uniqueGift)
                        }, itemImage: MenuAnimation.menu_replace.value))
                    }
                    return menu
                }
            }
                        
        } else {
            if let view = self.emoji {
                performSubviewRemoval(view, animated: animated)
                self.emoji = nil
            }
            if let view = self.backgroundView {
                performSubviewRemoval(view, animated: animated)
                self.backgroundView = nil
            }
        }
        
        
        if item.isGift {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = self.photo {
                performSubviewRemoval(view, animated: animated)
                self.photo = nil
            }
            if let view = self.starBadgeView {
                performSubviewRemoval(view, animated: animated)
                self.starBadgeView = nil
            }
            let current: InlineStickerView
            
            if let view = self.giftView {
                current = view
            } else {
                current = InlineStickerView(account: item.context.account, file: item.giftFile, size: NSMakeSize(130, 130), isPlayable: true, playPolicy: .onceEnd, controlContent: false, ignorePreview: true)
                control.addSubview(current)
                self.giftView = current
            }
            
        } else if let media = item.transaction.media.first, let messageId = item.transaction.paidMessageId {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = self.starBadgeView {
                performSubviewRemoval(view, animated: animated)
                self.starBadgeView = nil
            }
            if let view = self.giftView {
                performSubviewRemoval(view, animated: animated)
                self.giftView = nil
            }
            let current: TransformImageView
            
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 80, 80))
                current.preventsCapture = true
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                control.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = 10
            
            let reference = StarsTransactionReference(peerId: messageId.peerId, ton: item.transaction.count.currency == .ton, id: item.transaction.id, isRefund: item.transaction.flags.contains(.isRefund))
            
            var updateImageSignal: Signal<ImageDataTransformation, NoError>?
            
            if let image = media as? TelegramMediaImage {
                updateImageSignal = chatMessagePhoto(account: item.context.account, imageReference: ImageMediaReference.starsTransaction(transaction: reference, media: image), scale: backingScaleFactor, synchronousLoad: false, autoFetchFullSize: true)
            } else if let file = media as? TelegramMediaFile {
                updateImageSignal = chatMessageVideo(account: item.context.account, fileReference: .starsTransaction(transaction: reference, media: file), scale: backingScaleFactor)
            }

            if let updateImageSignal {
                current.setSignal(updateImageSignal, isProtected: true)
            }
            
            var dimensions: NSSize = current.frame.size
            
            if let image = media as? TelegramMediaImage {
                dimensions = image.representationForDisplayAtSize(PixelDimensions(current.frame.size))?.dimensions.size ?? current.frame.size
            } else if let file = media as? TelegramMediaFile {
                dimensions = file.dimensions?.size ?? current.frame.size
            }
        
            current.set(arguments: TransformImageArguments(corners: .init(radius: 10), imageSize: dimensions, boundingSize: current.frame.size, intrinsicInsets: .init()))
            
        } else if let photo = item.transaction.photo {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = self.giftView {
                performSubviewRemoval(view, animated: animated)
                self.giftView = nil
            }
            if let view = self.starBadgeView {
                performSubviewRemoval(view, animated: animated)
                self.starBadgeView = nil
            }
            let current: TransformImageView
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 80, 80))
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                control.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = floor(current.frame.height / 2)

            current.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: photo, scale: backingScaleFactor))
    
            _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.standalone(resource: photo.resource)).start()
    
            current.set(arguments: TransformImageArguments(corners: .init(radius: 10), imageSize: photo.dimensions?.size ?? NSMakeSize(80, 80), boundingSize: current.frame.size, intrinsicInsets: .init()))

            
        } else {
            if let view = self.photo {
                performSubviewRemoval(view, animated: animated)
                self.photo = nil
            }
            if let view = self.giftView {
                performSubviewRemoval(view, animated: animated)
                self.giftView = nil
            }
            let current: AvatarControl
            if let view = self.avatar {
                current = view
            } else {
                current = AvatarControl(font: .avatar(20))
                current.setFrameSize(NSMakeSize(80, 80))
                self.avatar = current
                control.addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: item.peer?._asPeer())
            
            if item.transaction.subscriptionPeriod != nil {
                let starBadgeView: ImageView
                if let view = self.starBadgeView {
                    starBadgeView = view
                } else {
                    starBadgeView = ImageView()
                    self.starBadgeView = starBadgeView
                    control.addSubview(starBadgeView)
                }
                starBadgeView.image = theme.icons.avatar_star_badge_large_gray
                starBadgeView.sizeToFit()

                let avatarFrame = current.frame
                let avatarBadgeSize = starBadgeView.frame.size
                let avatarBadgeFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX - avatarBadgeSize.width + 4, y: avatarFrame.maxY - avatarBadgeSize.height), size: avatarBadgeSize)

                starBadgeView.frame = avatarBadgeFrame
            } else {
                if let view = self.starBadgeView {
                    performSubviewRemoval(view, animated: animated)
                    self.starBadgeView = nil
                }
            }
        }
        
        
        if let authorLayout = item.authorLayout, let author = item.authorPeer {
            let current: TextView
            if let view = self.authorView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = true
                current.scaleOnClick = true
                current.isSelectable = false
                self.authorView = current
                self.addSubview(current)
            }
            current.update(authorLayout)
            
            let context = item.context
            
            current.setSingle(handler: { [weak item] view in
                if let event = NSApp.currentEvent {
                    let data = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: author.id),
                        TelegramEngine.EngineData.Item.Peer.AboutText(id: author.id)
                    ) |> take(1) |> deliverOnMainQueue
                    
                    _ = data.start(next: { [weak view, weak item] data in
                        
                        guard let peer = data.0, let view = view else {
                            return
                        }
                        
                        var firstBlock:[ContextMenuItem] = []
                        var secondBlock:[ContextMenuItem] = []
                        let thirdBlock: [ContextMenuItem] = []
                        
                        firstBlock.append(GroupCallAvatarMenuItem(peer._asPeer(), context: context))
                        
                        firstBlock.append(ContextMenuItem(peer._asPeer().displayTitle, handler: {
                            item?.arguments.openPeer(peer.id)
                        }, itemImage: MenuAnimation.menu_open_profile.value))
                        
                        if let username = peer.addressName {
                            firstBlock.append(ContextMenuItem("\(username)", handler: {
                                item?.arguments.openPeer(peer.id)
                            }, itemImage: MenuAnimation.menu_atsign.value))
                        }
                        
                        switch data.1 {
                        case let .known(about):
                            if let about = about, !about.isEmpty {
                                firstBlock.append(ContextMenuItem(about, handler: {
                                    item?.arguments.openPeer(peer.id)
                                }, itemImage: MenuAnimation.menu_bio.value, removeTail: false, overrideWidth: 200))
                            }
                        default:
                            break
                        }
                        
                        let blocks:[[ContextMenuItem]] = [firstBlock,
                                                          secondBlock,
                                                          thirdBlock].filter { !$0.isEmpty }
                        var items: [ContextMenuItem] = []

                        for (i, block) in blocks.enumerated() {
                            if i != 0 {
                                items.append(ContextSeparatorItem())
                            }
                            items.append(contentsOf: block)
                        }
                        
                        let menu = ContextMenu()
                        
                        for item in items {
                            menu.addItem(item)
                        }
                        AppMenu.show(menu: menu, event: event, for: view)
                    })
                }
            }, for: .Click)
        } else if let view = self.authorView {
            performSubviewRemoval(view, animated: animated)
            self.authorView = nil
        }
        
        self.headerView.update(item.headerLayout)
        self.infoView.set(text: item.infoLayout, context: item.context)
        
        self.dismiss.set(image: item.uniqueGift != nil ? NSImage(resource: .iconChatSearchCancel).precomposed(NSColor.white) : theme.icons.modalClose, for: .Normal)
        self.dismiss.sizeToFit()
        self.dismiss.scaleOnClick = true
        self.dismiss.autohighlight = false
        
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.close()
        }, for: .Click)
        
        if item.peer == nil, !item.isGift {
            let current: ImageView
            if let view = self.outgoingView {
                current = view
            } else {
                current = ImageView()
                control.addSubview(current)
                self.outgoingView = current
            }
            switch item.transaction.peer {
            case .appStore:
                current.image = NSImage(resource: .iconStarTransactionPreviewAppStore).precomposed()
            case .fragment:
                current.image = NSImage(resource: .iconStarTransactionPreviewFragment).precomposed()
            case .playMarket:
                current.image = NSImage(resource: .iconStarTransactionPreviewAndroid).precomposed()
            case .peer:
                break
            case .premiumBot:
                current.image = NSImage(resource: .iconStarTransactionPreviewPremiumBot).precomposed()
            case .unsupported:
                current.image = NSImage(resource: .iconStarTransactionPreviewUnknown).precomposed()
            case .ads:
                current.image = NSImage(resource: .iconStarTransactionPreviewFragment).precomposed()
            case .apiLimitExtension:
                current.image = NSImage(resource: .iconStarTransactionRowPaidBroadcast).precomposed()
            }
            current.setFrameSize(NSMakeSize(80, 80))
        } else if let view = self.outgoingView {
            performSubviewRemoval(view, animated: animated)
            self.outgoingView = nil
        }
        
        if let descLayout = item.descLayout {
            let current: TextView
            if let view = self.descView {
                current = view
            } else {
                current = TextView()
                self.addSubview(current)
                self.descView = current
            }
            current.update(descLayout)
        } else if let view = self.descView {
            performSubviewRemoval(view, animated: animated)
            self.descView = nil
        }
        
        if let refundLayout = item.refund {
            let current: TextView
            if let view = self.refundView {
                current = view
            } else {
                current = TextView()
                infoContainer.addSubview(current)
                self.refundView = current
            }
            current.update(refundLayout)
            current.setFrameSize(NSMakeSize(current.frame.width + 6, current.frame.height + 4))
            current.layer?.cornerRadius = .cornerRadius
            current.background = theme.colors.greenUI.withAlphaComponent(0.2)
        } else if let view = self.refundView {
            performSubviewRemoval(view, animated: animated)
            self.refundView = nil
        }
        
        infoContainer.setFrameSize(NSMakeSize(infoContainer.subviewsWidthSize.width + 4, infoContainer.subviewsWidthSize.height + 2))
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        sceneView.centerX(y: 0)
        
        control.centerX(y: 20)
        
        avatar?.center()
        photo?.center()
        giftView?.centerX(y: -10)
        outgoingView?.center()
        dismiss.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - dismiss.frame.height) / 2)))
        
        
        if let actions {
            actions.setFrameOrigin(NSMakePoint(frame.width - actions.frame.width - 10, floorToScreenPixels((50 - actions.frame.height) / 2)))
        }
        
        headerView.centerX(y: (giftView != nil ? 130 : 90) + 20)
        
        var offset: CGFloat = 0
        if let authorView {
            authorView.centerX(y: headerView.frame.maxY + 5)
            offset += authorView.frame.height + 5
        }

        
        infoContainer.centerX(y: headerView.frame.maxY + 5 + offset)
        infoView.centerY(x: 0)
        refundView?.centerY(x: infoView.frame.maxX + 4, addition: -1)

        if let descView {
            descView.centerX(y: infoContainer.frame.maxY + 5)
        }
        
        if let emoji {
            emoji.centerX(y: 20)
        }
        if let backgroundView {
            backgroundView.frame = bounds
        }
    }
    
    
}

private final class Arguments {
    let context: AccountContext
    let openPeer:(PeerId)->Void
    let copyTransaction:(String)->Void
    let openLink:(String)->Void
    let previewMedia:()->Void
    let openApps:()->Void
    let openStars:()->Void
    let close: ()->Void
    let convertStars:()->Void
    let displayOnMyPage:()->Void
    let seeInProfile: () ->Void
    let sendGift:(PeerId)->Void
    let openAffiliate:()->Void
    let upgrade:()->Void
    let transferUnqiue:(StarGift.UniqueGift)->Void
    let copyNftLink:(StarGift.UniqueGift)->Void
    let shareNft:(StarGift.UniqueGift)->Void
    let startWearing:(StarGift.UniqueGift)->Void
    let changeFee:()->Void
    init(context: AccountContext, openPeer:@escaping(PeerId)->Void, copyTransaction:@escaping(String)->Void, openLink:@escaping(String)->Void, previewMedia:@escaping()->Void, openApps: @escaping()->Void, close: @escaping()->Void, openStars:@escaping()->Void, convertStars:@escaping()->Void, displayOnMyPage:@escaping()->Void, seeInProfile: @escaping() ->Void, sendGift:@escaping(PeerId)->Void, openAffiliate:@escaping()->Void, upgrade:@escaping()->Void, transferUnqiue:@escaping(StarGift.UniqueGift)->Void, copyNftLink:@escaping(StarGift.UniqueGift)->Void, shareNft:@escaping(StarGift.UniqueGift)->Void, startWearing:@escaping(StarGift.UniqueGift)->Void, changeFee:@escaping()->Void) {
        self.context = context
        self.openPeer = openPeer
        self.copyTransaction = copyTransaction
        self.openLink = openLink
        self.previewMedia = previewMedia
        self.openApps = openApps
        self.close = close
        self.openStars = openStars
        self.convertStars = convertStars
        self.displayOnMyPage = displayOnMyPage
        self.seeInProfile = seeInProfile
        self.sendGift = sendGift
        self.openAffiliate = openAffiliate
        self.upgrade = upgrade
        self.transferUnqiue = transferUnqiue
        self.copyNftLink = copyNftLink
        self.shareNft = shareNft
        self.startWearing = startWearing
        self.changeFee = changeFee
    }
}

private struct State : Equatable {
    var transaction: StarsContext.State.Transaction
    var currency: CurrencyAmount.Currency
    var purpose: Star_TransactionPurpose
    var peer: EnginePeer?
    var paidPeer: EnginePeer?
    var starrefPeer: EnginePeer?
    var ownerPeer: EnginePeer?
    var starsState: StarsContext.State?
    var author: EnginePeer?
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_rows = InputDataIdentifier("_id_rows")
private let _id_button = InputDataIdentifier("_id_button")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
   // entries.append(.sectionId(sectionId, type: .customModern(10)))
   // sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, transaction: state.transaction, currency: state.currency, peer: state.peer, purpose: state.purpose, arguments: arguments, author: state.author?._asPeer())
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    let isIncoming: Bool
    switch state.transaction.peer {
    case let .peer(peer):
        isIncoming = peer.id == arguments.context.peerId
    default:
        isIncoming = state.transaction.count.amount.value > 0
    }
    
    let done: String
    var convertStarsAmount: Int64? = nil
    var savedToProfile: Bool = false
    switch state.purpose {
    case let .starGift(gift, convertStars, _, _, _, _savedToProfile, converted, _, upgraded, _, _, _, sender, _, _, _):
        savedToProfile = _savedToProfile
        
        if state.transaction.count.amount.value > 0 || isIncoming, !upgraded {
            switch state.transaction.peer {
            case let .peer(peer):
                if peer.id == arguments.context.peerId {
                    if !converted {
                        convertStarsAmount = convertStars
                    }
                    if savedToProfile {
                        if let _ = sender {
                            done = strings().starTransactionStarGiftChannelHideFromMyPage
                        } else {
                            done = strings().starTransactionStarGiftHideFromMyPage
                        }
                    } else {
                        if let _ = sender {
                            done = strings().starTransactionStarGiftChannelDisplayOnMyPage
                        } else {
                            done = strings().starTransactionStarGiftDisplayOnMyPage
                        }
                    }
                } else {
                    done = strings().modalDone
                }
            default:
                done = strings().modalDone
            }
            
        } else {
            done = strings().modalDone
        }
    default:
        done = strings().modalDone
    }
    
  
    
    
    var rows: [InputDataTableBasedItem.Row] = []
    
    if let peer = state.peer {
        
        
        if state.transaction.flags.contains(.isStarGiftResale) {
            let reasonText = state.transaction.count.amount.value > 0 ? strings().starTransactionGiftSale : strings().starTransactionGiftPurchase
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionReason, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: reasonText, color: theme.colors.text, font: .normal(.text))))))
                        
        } else if let _ = state.transaction.starrefCommissionPermille, state.transaction.paidMessageCount == nil {
            
            let affiliate: TextViewLayout = .init(parseMarkdownIntoAttributedString(strings().starTransactionReasonAffiliate, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), maximumNumberOfLines: 1, alwaysStaticItems: true)
            
            affiliate.interactions.processURL = { url in
                if let url = url as? String {
                    if url.hasPrefix("affiliate") {
                        arguments.openAffiliate()
                    }
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionReason, color: theme.colors.text, font: .normal(.text))), right: .init(name: affiliate)))

        }
        
        let fromPeer: String
        
       
        if let messageId = state.transaction.giveawayMessageId {
            fromPeer = "[\(peer._asPeer().compactDisplayTitle)](t.me/c/\(peer.id.id._internalGetInt64Value())/\(messageId.id))"
        } else if peer.id == servicePeerId {
            fromPeer = strings().starTransactionUnknwonUser
        } else {
            let escaped = escapeMarkdownSpecialCharacters(in: peer._asPeer().compactDisplayTitle)
            fromPeer = "[\(escaped)](peer_id_\(peer.id.toInt64()))"
        }
        
        let from: TextViewLayout = .init(parseMarkdownIntoAttributedString(fromPeer, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })), maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        from.interactions.processURL = { url in
            if let url = url as? String {
                if url.hasPrefix("peer_id_") {
                    arguments.openPeer(peer.id)
                } else {
                    arguments.openLink(url)
                }
            }
        }
        
        let fromText: String
        if state.transaction.flags.contains(.isStarGiftResale) {
            fromText = state.transaction.count.amount.value < 0 ? strings().starTransactionFrom : strings().starTransactionTo
        } else if case .unique = state.transaction.starGift {
            fromText = strings().starTransactionOwner
        } else if let _ = state.transaction.starrefCommissionPermille, state.transaction.paidMessageCount == nil {
            fromText = state.transaction.starrefPeerId == nil ? strings().starTransactionMiniApp : strings().starTransacitonReferredUser
        } else if state.transaction.giveawayMessageId != nil {
            fromText = strings().starTransactionFrom
        } else if peer._asPeer().isUser && state.transaction.count.amount.value > 0 {
            fromText = strings().starTransactionFrom
        } else if state.transaction.count.amount.value < 0, state.transaction.starGift != nil {
            fromText = strings().starTransactionFrom
        } else {
            fromText = strings().starTransactionTo
        }
        
        let badge: InputDataTableBasedItem.Row.Right.Badge?
        
        if case let .unique(gift) = state.transaction.starGift, case let .peerId(peerId) = gift.owner, arguments.context.peerId == peerId {
            badge = .init(text: strings().giftUniqueTransfer, callback: {
                arguments.transferUnqiue(gift)
            })
        } else if fromText == strings().starTransactionFrom, state.transaction.starGift != nil, peer.id != arguments.context.peerId {
            if state.ownerPeer?._asPeer().isChannel == false {
                badge = .init(text: strings().starTransactionSendGift, callback: {
                    arguments.sendGift(peer.id)
                })
            } else {
                badge = nil
            }
        } else {
            badge = nil
        }
        rows.append(.init(left: .init(.initialize(string: fromText, color: theme.colors.text, font: .normal(.text))), right: .init(name: from, leftView: { previous in
            if peer.id == servicePeerId {
                let control: ImageView
                if let previous = previous as? ImageView {
                    control = previous
                } else {
                    control = ImageView(frame: NSMakeRect(0, 0, 20, 20))
                }
                control.image = NSImage(resource: .iconStarTransactionAnonymous).precomposed()
                return control
            } else {
                let control: AvatarControl
                if let previous = previous as? AvatarControl {
                    control = previous
                } else {
                    control = AvatarControl(font: .avatar(6))
                }
                control.setFrameSize(NSMakeSize(20, 20))
                control.setPeer(account: arguments.context.account, peer: peer._asPeer())
                return control
            }
            
        }, badge: badge)))
        
        if let commission = state.transaction.starrefCommissionPermille, state.transaction.count.amount.value > 0, state.transaction.flags.contains(.isStarGiftResale) {
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionCommission, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: "\(commission.decemial.string)%", color: theme.colors.text, font: .normal(.text))))))
        }
        
        if let starrefPeer = state.starrefPeer, state.transaction.paidMessageCount == nil, !state.transaction.flags.contains(.isStarGiftResale) {
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionMiniApp, color: theme.colors.text, font: .normal(.text))), right: .init(name: from, leftView: { previous in
                let control: AvatarControl
                if let previous = previous as? AvatarControl {
                    control = previous
                } else {
                    control = AvatarControl(font: .avatar(6))
                }
                control.setFrameSize(NSMakeSize(20, 20))
                control.setPeer(account: arguments.context.account, peer: starrefPeer._asPeer())
                return control
            }, badge: badge)))
            
            
            if let commission = state.transaction.starrefCommissionPermille {
                rows.append(.init(left: .init(.initialize(string: strings().starTransactionCommission, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: "\(commission.decemial.string)%", color: theme.colors.text, font: .normal(.text))))))
            }
        }
        
        
        switch state.purpose {
        case .starGift:
            switch state.transaction.peer {
            case let .peer(peer):
                
                let toPeer: String
                let escaped = escapeMarkdownSpecialCharacters(in: peer._asPeer().compactDisplayTitle)
                toPeer = "[\(escaped)](peer_id_\(peer.id.toInt64()))"

                let to: TextViewLayout = .init(parseMarkdownIntoAttributedString(toPeer, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, contents)
                })), maximumNumberOfLines: 1, alwaysStaticItems: true)
                
                to.interactions.processURL = { url in
                    if let url = url as? String {
                        if url.hasPrefix("peer_id_") {
                            arguments.openPeer(peer.id)
                        } else {
                            arguments.openLink(url)
                        }
                    }
                }
                switch state.purpose {
                case .starGift:
                    break
                default:
                    rows.append(.init(left: .init(.initialize(string: strings().starTransactionTo, color: theme.colors.text, font: .normal(.text))), right: .init(name: to, leftView: { previous in
                        if peer.id == servicePeerId {
                            let control: ImageView
                            if let previous = previous as? ImageView {
                                control = previous
                            } else {
                                control = ImageView(frame: NSMakeRect(0, 0, 20, 20))
                            }
                            control.image = NSImage(resource: .iconStarTransactionAnonymous).precomposed()
                            return control
                        } else {
                            let control: AvatarControl
                            if let previous = previous as? AvatarControl {
                                control = previous
                            } else {
                                control = AvatarControl(font: .avatar(6))
                            }
                            control.setFrameSize(NSMakeSize(20, 20))
                            control.setPeer(account: arguments.context.account, peer: peer._asPeer())
                            return control
                        }
                    })))
                }
                
            default:
                break
            }
        default:
            break
        }
        
        if let messageId = state.transaction.paidMessageId, let peer = state.paidPeer {
            
            let link: String
            if let address = peer.addressName {
                link = "t.me/\(address)/\(messageId.id)"
            } else {
                link = "t.me/c/\(peer.id.id._internalGetInt64Value())/\(messageId.id)"
            }
            
            let messageIdText: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(link)](\(link))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), alwaysStaticItems: true)

            messageIdText.interactions.processURL = { inapplink in
                if let inapplink = inapplink as? String {
                    arguments.openLink(inapplink)
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: state.transaction.flags.contains(.isReaction) ? strings().starTransactionReactionId :  strings().starTransactionMessageId, color: theme.colors.text, font: .normal(.text))), right: .init(name: messageIdText)))

        }
    } else if state.transaction.flags.contains(.isGift) {
        if state.purpose != .unavailableGift {
            let fromPeer: String = strings().starTransactionUnknwonUser
            
            let from: TextViewLayout = .init(parseMarkdownIntoAttributedString(fromPeer, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), maximumNumberOfLines: 1, alwaysStaticItems: true)
            
            from.interactions.processURL = { url in
                if let url = url as? String {
                    arguments.openLink(url)
                }
            }
            
            let fromText: String = strings().starTransactionFrom
            
            rows.append(.init(left: .init(.initialize(string: fromText, color: theme.colors.text, font: .normal(.text))), right: .init(name: from, leftView: { previous in
                let control: ImageView
                if let previous = previous as? ImageView {
                    control = previous
                } else {
                    control = ImageView(frame: NSMakeRect(0, 0, 20, 20))
                }
                control.image = NSImage(resource: .iconStarTransactionAnonymous).precomposed()
                return control
            })))
        }
    }
    
    if !state.transaction.id.isEmpty, state.transaction.giveawayMessageId == nil {
        let transactionId: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(state.transaction.id.prefixWithDots(30, mode: .middle))](\(state.transaction.id))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })), alwaysStaticItems: true)
        
        transactionId.interactions.processURL = { inapplink in
            if let inapplink = inapplink as? String {
                arguments.copyTransaction(inapplink)
            }
        }        
        rows.append(.init(left: .init(.initialize(string: strings().starTransactionId, color: theme.colors.text, font: .normal(.text))), right: .init(name: transactionId)))
        
        
        if let transactionUrl = state.transaction.transactionUrl {
            let transactionId: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(transactionUrl.prefixWithDots(40))](\(transactionUrl))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), alwaysStaticItems: true)
            
            transactionId.interactions.processURL = { inapplink in
                if let inapplink = inapplink as? String {
                    arguments.openLink(inapplink)
                }
            }
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionTransactionUrl, color: theme.colors.text, font: .normal(.text))), right: .init(name: transactionId)))
        }
        
    }
    
    if state.transaction.giveawayMessageId != nil {
        rows.append(.init(left: .init(.initialize(string: strings().starTransactionGift, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starListItemCountCountable(Int(state.transaction.count.amount.value)), color: theme.colors.text, font: .normal(.text))))))

        rows.append(.init(left: .init(.initialize(string: strings().starTransactionReason, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starTransactionReasonGiveaway, color: theme.colors.text, font: .normal(.text))))))
    }
    
    if case .unavailableGift = state.purpose {
    } else {
        rows.append(.init(left: .init(.initialize(string: strings().starTransactionDate, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: state.transaction.date), color: theme.colors.text, font: .normal(.text))))))
    }
    

    
    switch state.purpose {
    case .unavailableGift:
        if let gift = state.transaction.starGift?.generic {
            
            if let soldOut = gift.soldOut {
                rows.append(.init(left: .init(.initialize(string: strings().starTransactionFirstSale, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: soldOut.firstSale), color: theme.colors.text, font: .normal(.text))))))
                
                rows.append(.init(left: .init(.initialize(string: strings().starTransactionLastSale, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: soldOut.lastSale), color: theme.colors.text, font: .normal(.text))))))

            }

            
            
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionValue, color: theme.colors.text, font: .normal(.text))), right: InputDataTableBasedItem.Row.Right(name: .init(.initialize(string: gift.price.formattedWithSeparator, color: theme.colors.text, font: .normal(.text))), leftView: { previous in
                
                let imageView = previous as? ImageView ?? ImageView()
                imageView.image = NSImage(resource: .iconStarCurrency).precomposed()
                imageView.setFrameSize(18, 18)
                imageView.contentGravity = .resizeAspectFill
                return imageView
            })))
            
            
        }
    case let .starGift(gift, _, text, entities, _, _, _, _, upgraded, _, _, _, _, _, _, _):
        
        if let gift = gift.generic, !upgraded {
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionValue, color: theme.colors.text, font: .normal(.text))), right: InputDataTableBasedItem.Row.Right(name: .init(.initialize(string: gift.price.formattedWithSeparator, color: theme.colors.text, font: .normal(.text))), leftView: { previous in
                
                let imageView = previous as? ImageView ?? ImageView()
                imageView.image = NSImage(resource: .iconStarCurrency).precomposed()
                imageView.setFrameSize(18, 18)
                imageView.contentGravity = .resizeAspectFill
                return imageView
            }, badge: convertStarsAmount != nil ? .init(text: strings().starTransactionSaleForCountable(Int(convertStarsAmount!)), callback: arguments.convertStars) : nil)))
            
            if let availability = gift.availability {
                rows.append(.init(left: .init(.initialize(string: strings().starTransactionAvailability, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starTransactionAvailabilityOfLeft(Int(availability.remains).formattedWithSeparator, Int(availability.total).formattedWithSeparator), color: theme.colors.text, font: .normal(.text))))))
            }
            
            if savedToProfile, case let .peer(peer) = state.transaction.peer, arguments.context.peerId == peer.id || peer._asPeer().groupAccess.canManageGifts {
                
                let badge: InputDataTableBasedItem.Row.Right.Badge = .init(text: strings().starTransactionVisibilityHide, callback: arguments.displayOnMyPage)
                
                rows.append(.init(left: .init(.initialize(string: strings().starTransactionVisibility, color: theme.colors.text, font: .normal(.text))), right: InputDataTableBasedItem.Row.Right(name: .init(.initialize(string: strings().starTransactionVisibilityInfo, color: theme.colors.text, font: .normal(.text))), badge: badge)))
            }
        }

        
        switch gift {
        case let .unique(gift):
            for attr in gift.attributes {
                switch attr {
                case .model(let name, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueModel, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
                case .pattern(let name, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueSymbol, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
                case .backdrop(let name, _, _, _, _, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueBackdrop, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
                default:
                    break
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionAvailability, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starTransactionGiftUpgradeIssued(Int(gift.availability.issued).formattedWithSeparator, Int(gift.availability.total).formattedWithSeparator), color: theme.colors.text, font: .normal(.text))))))
            
        default:
            break
        }
        
      
        if let _ = gift.generic?.upgradeStars, !state.purpose.isUpgraded, state.transaction.count.amount.value > 0 {
            if let owner = state.ownerPeer, owner.id == arguments.context.peerId || owner._asPeer().groupAccess.isCreator {
                rows.append(.init(left: .init(.initialize(string: strings().giftViewStatus, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().giftViewStatusNonUnique, color: theme.colors.text, font: .normal(.text))), badge: .init(text: strings().giftViewStatusUpgrade, callback: arguments.upgrade))))
            } else if case let .peer(peer) = state.transaction.peer, peer._asPeer().groupAccess.isCreator {
                rows.append(.init(left: .init(.initialize(string: strings().giftViewStatus, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().giftViewStatusNonUnique, color: theme.colors.text, font: .normal(.text))), badge: .init(text: strings().giftViewStatusUpgrade, callback: arguments.upgrade))))
            }
        }
        
        if let text {
            
            let attr = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities ?? [])], for: text, message: nil, context: arguments.context, fontSize: theme.fontSize, openInfo: { _, _, _, _ in }, textColor: theme.colors.text, isDark: theme.colors.isDark, bubbled: true).mutableCopy() as! NSMutableAttributedString
            
            InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: entities ?? [], isPremium: arguments.context.isPremium)

            rows.append(.init(left: nil, right: .init(name: .init(attr))))
        }
        
        
    default:
        break
    }
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_rows, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return InputDataTableBasedItem(initialSize, stableId: stableId, viewType: .singleItem, rows: rows, context: arguments.context)
    }))
    index += 1
    
    

  
    if done != strings().modalDone, savedToProfile {
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().starTransactionStarGiftSeeInProfile, linkHandler: { _ in
            arguments.seeInProfile()
        }), data: .init(color: theme.colors.listGrayText, viewType: .modern(position: .single, insets: .init()), fontSize: 13, centerViewAlignment: true, alignment: .center)))
        index += 1

    }
    
   
    if done == strings().modalDone, state.purpose != .tonGift, state.currency != .ton {
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().starTransactionTos, linkHandler: arguments.openLink), data: .init(color: theme.colors.listGrayText, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
        index += 1
    } else {
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
    }

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return GeneralActionButtonRowItem(initialSize, stableId: stableId, text: done, viewType: .legacy, action: {
            if convertStarsAmount != nil {
                arguments.displayOnMyPage()
            } else {
                arguments.close()
            }
        }, inset: .init(left: 10, right: 10))
    }))
    

    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    return entries
}

extension StarGift {
    var generic: StarGift.Gift? {
        switch self {
        case let .generic(gift):
            return gift
        case .unique:
            return nil
        }
    }
    var unique: StarGift.UniqueGift? {
        switch self {
        case .generic:
            return nil
        case let .unique(unique):
            return unique
        }
    }
    
    var backdropColor: [NSColor]? {
        if let unique {
            for attribute in unique.attributes {
                switch attribute {
                case .backdrop(_, _, let innerColor, let outerColor, let patternColor, _, _):
                    return [NSColor(UInt32(innerColor)), NSColor(UInt32(outerColor))]
                default:
                    break
                }
            }
        }
        return nil
    }
}

enum Star_TransactionPurpose : Equatable {
    case payment
    case gift
    case tonGift
    case unavailableGift
    case starGift(gift: StarGift, convertStars: Int64?, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, converted: Bool, fromProfile: Bool, upgraded: Bool, transferStars: Int64?, canExportDate: Int32?, reference: StarGiftReference?, sender: EnginePeer?, saverId: Int64?, canTransferDate: Int32?, canResaleDate: Int32?)
    
    var isGift: Bool {
        switch self {
        case .gift, .starGift, .unavailableGift, .tonGift:
            return true
        default:
            return false
        }
    }
    var isStarGift: Bool {
        switch self {
        case .starGift:
            return true
        default:
            return false
        }
    }
    
    var isUpgraded: Bool {
        switch self {
        case let .starGift(_, _, _, _, _, _, _, _, upgraded, _, _, _, _, _, _, _):
            return upgraded
        default:
            return false
        }
    }
    
    var sender: EnginePeer? {
        switch self {
        case let .starGift(_, _, _, _, _, _, _, _, _, _, _, _, sender, _, _, _):
            return sender
        default:
            return nil
        }
    }
    
    var gift: StarGift? {
        switch self {
        case let .starGift(gift, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            return gift
        default:
            return nil
        }
    }
}

func Star_TransactionScreen(context: AccountContext, fromPeerId: PeerId, peer: EnginePeer?, transaction: StarsContext.State.Transaction, purpose: Star_TransactionPurpose = .payment, reference: StarGiftReference? = nil, profileContext: ProfileGiftsContext? = nil, currency: CurrencyAmount.Currency = .stars) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    var gallery: GallerySupplyment? = nil
    var getTableView:(()->TableView?)? = nil

    
    let initialState = State(transaction: transaction, currency: currency, purpose: purpose, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    if let paidMessageId = transaction.paidMessageId {
        actionsDisposable.add(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: paidMessageId.peerId)).start(next: { peer in
            updateState { current in
                var current = current
                current.paidPeer = peer
                return current
            }
        }))
    }
    
    if case let .unique(gift) = transaction.starGift, case let .peerId(peerId) = gift.owner {
        actionsDisposable.add(combineLatest(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: fromPeerId))).start(next: { peer, ownerPeer in
            updateState { current in
                var current = current
                current.peer = peer
                current.ownerPeer = ownerPeer
                return current
            }
        }))
    } else {
        switch transaction.peer {
        case .peer(let enginePeer):
            updateState { current in
                var current = current
                current.ownerPeer = enginePeer
                return current
            }
        default:
            break
        }
    }
    
    if let starrefPeerId = transaction.starrefPeerId {
        actionsDisposable.add(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: starrefPeerId)).start(next: { peer in
            updateState { current in
                var current = current
                current.starrefPeer = peer
                return current
            }
        }))
    }
    
    let authorPeer: Signal<EnginePeer?, NoError>
    if let authorId = transaction.starGift?.releasedBy {
        authorPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: authorId))
    } else {
        authorPeer = .single(nil)
    }
    
    actionsDisposable.add(combineLatest(context.starsContext.state, authorPeer).startStrict(next: { state, authorPeer in
        updateState { current in
            var current = current
            current.starsState = state
            current.author = authorPeer
            return current
        }
    }))
    
    
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, openPeer: { peerId in
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
        close?()
    }, copyTransaction: { string in
        copyToClipboard(string)
        showModalText(for: window, text: strings().starTransactionCopied)
    }, openLink: { link in
        execute(inapp: inApp(for: link.nsstring, context: context, openInfo: { peerId, _, messageId, _ in
            if let messageId = messageId {
                let signal = context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .cloud(skipLocal: false)) |> filter {
                    switch $0 {
                    case .progress:
                        return false
                    default:
                        return true
                    }
                } |> take(1)
                _ = showModalProgress(signal: signal, for: window).startStandalone(next: { result in
                    switch result {
                    case let .result(messages):
                        if let _ = messages.first {
                            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(messageId.peerId), focusTarget: .init(messageId: messageId)))
                             closeAllModals()
                        } else {
                            showModalText(for: window, text: strings().chatOpenMessageNotExist)
                        }
                    default:
                        break
                    }
                })
            }
        }))
    }, previewMedia: {
        let medias = stateValue.with { $0.transaction.media }
        let amount = stateValue.with { $0.transaction.count.amount }
        let peer = stateValue.with { $0.peer?._asPeer() }
        if !medias.isEmpty, let peer {
            let message = Message(TelegramMediaPaidContent(amount: amount.value, extendedMedia: medias.map { .full(media: $0) }), stableId: 0, messageId: .init(peerId: peer.id, namespace: 0, id: 0))
            showPaidMedia(context: context, medias: medias, parent: message, firstIndex: 0, firstStableId: ChatHistoryEntryId.mediaId(0, message), getTableView?(), nil)
        }
    }, openApps: {
        showModal(with: Star_AppExamples(context: context), for: window)
    }, close: {
        close?()
    }, openStars: {
        showModal(with: StarUsePromoController(context: context), for: window)
    }, convertStars: { [weak profileContext] in
        if let reference, let peer = peer {
            switch purpose {
            case .starGift(_, let convertStars, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                
                if let convertStars {
                    let period_max = context.appConfiguration.getGeneralValue("stargifts_convert_period_max", orElse: 300) + (transaction.date - Int32(context.timeDifference))
                    
                    let dateFormatter = makeNewDateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none

                    let until = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(period_max)))

                    if period_max > context.timestamp {
                        verifyAlert(for: window, header: strings().starTransactionConvertAlertHeader, information: strings().starTransactionConvertAlertInfoUntil(peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(convertStars)), until), ok: strings().starTransactionConvertAlertOK, successHandler: { _ in
                            
                            if let profileContext {
                                profileContext.convertStarGift(reference: reference)
                            } else {
                                _ = context.engine.payments.convertStarGift(reference: reference).start()
                            }
                            close?()
                            showModalText(for: window, text: strings().starTransactionStarGiftConvertToStarsAlert)
                            PlayConfetti(for: window, stars: true)
                        })
                    } else {
                        showModalText(for: window, text: strings().starTransactionConvertAlertTooLate)
                    }
                }
               
            default:
                break
            }
        }
    }, displayOnMyPage: { [weak profileContext] in
        
        if let reference {
            switch purpose {
            case .starGift(_, _, _, _, _, let savedToProfile, _, _, _, _, _, _, _, _, _, _):
                if let profileContext {
                    profileContext.updateStarGiftAddedToProfile(reference: reference, added: !savedToProfile)
                } else {
                    _ = context.engine.payments.updateStarGiftAddedToProfile(reference: reference, added: !savedToProfile).startStandalone()
                }
                if !savedToProfile {
                    showModalText(for: window, text: strings().starTransactionStarGiftDisplayOnPageAlert)
                    PlayConfetti(for: window, stars: true)
                } else {
                    showModalText(for: window, text: strings().starTransactionStarGiftHideFromMyPageAlert)
                }
                close?()
            default:
                break
            }
        }
    }, seeInProfile: {
        closeAllModals(window: window)
        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: context.peerId, mediaMode: .gifts)
    }, sendGift: { peerId in
        showModal(with: GiftingController(context: context, peerId: peerId, isBirthday: false), for: window)
        close?()
    }, openAffiliate: {
        close?()
        context.bindings.rootNavigation().push(Affiliate_PeerController(context: context, peerId: fromPeerId, onlyDemo: false))
    }, upgrade: {
        if let gift = transaction.starGift, let id = gift.generic?.id, let peer, let reference {
            _ = showModalProgress(signal: context.engine.payments.starGiftUpgradePreview(giftId: id), for: window).startStandalone(next: { attributes in
                close?()
                showModal(with: StarGift_Nft_Controller(context: context, gift: gift, source: .upgrade(peer, attributes, reference), transaction: transaction, giftsContext: profileContext), for: window)
            })
        }
    }, transferUnqiue: { gift in
        
        let state = stateValue.with { $0 }
        
        if let reference, case let .starGift(_, _, _, _, _, _, _, _, _, transferStars, canExportDate, _, _, _, _, _) = purpose {
            
            var additionalItem: SelectPeers_AdditionTopItem?
            if let canExportDate {
                additionalItem = .init(title: strings().giftTransferSendViaBlockchain, color: theme.colors.text, icon: NSImage(resource: .iconSendViaTon).precomposed(flipVertical: true), callback: {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    if currentTime > canExportDate {
                        let data = ModalAlertData(title: nil, info: strings().giftWithdrawText(gift.title + " #\(gift.number)"), description: nil, ok: strings().giftWithdrawProceed, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                            return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: gift, toPeer: .init(context.myPeer!), context: context)
                        }))
                        
                        showModalAlert(for: window, data: data, completion: { result in
                            showModal(with: InputPasswordController(context: context, title: strings().giftWithdrawTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                                return context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: value)
                                |> deliverOnMainQueue
                                |> afterNext { url in
                                    execute(inapp: .external(link: url, false))
                                }
                                |> ignoreValues
                                |> mapError { error in
                                    switch error {
                                    case .invalidPassword:
                                        return .wrong
                                    case .limitExceeded:
                                        return .custom(strings().loginFloodWait)
                                    case .generic:
                                        return .generic
                                    default:
                                        return .custom(strings().monetizationWithdrawErrorText)
                                    }
                                }
                            }), for: context.window)
                        })
                    } else {
                        let delta = canExportDate - currentTime
                        let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                        alert(for: window, header: strings().giftTransferUnlockPendingTitle, info: strings().giftTransferUnlockPendingText(strings().timerDaysCountable(Int(days))))
                    }
                })
            }
            
            _ = selectModalPeers(window: window, context: context, title: strings().giftTransferTitle, behavior: SelectChatsBehavior(settings: [.excludeBots, .contacts, .remote, .channels], limit: 1, additionTopItem: additionalItem)).start(next: { peerIds in
                if let peerId = peerIds.first {
                    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
                    
                    _ = peer.startStandalone(next: { peer in
                        if let peer {
                                                    
                            let info: String
                            let ok: String
                        
            
                            
                            if let convertStars = transferStars, let starsState = state.starsState, starsState.balance.value < convertStars {
                                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: convertStars)), for: window)
                                return
                            }
                            
                            if let stars = transferStars, stars > 0 {
                                info = strings().giftTransferConfirmationText("\(gift.title) #\(gift.number)", peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(stars)))
                                ok = strings().giftTransferConfirmationTransfer + " " + strings().starListItemCountCountable(Int(stars))
                            } else {
                                info = strings().giftTransferConfirmationTextFree("\(gift.title) #\(gift.number)", peer._asPeer().displayTitle)
                                ok = strings().giftTransferConfirmationTransferFree
                            }
                    
                            let data = ModalAlertData(title: nil, info: info, description: nil, ok: ok, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                                return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: gift, toPeer: peer, context: context)
                            }))
                            
                            showModalAlert(for: window, data: data, completion: { result in
                                _ = context.engine.payments.transferStarGift(prepaid: true, reference: reference, peerId: peerId).startStandalone()
                                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                                close?()
                            })
                        }
                    })
                }
            })
        }
        
    }, copyNftLink: { gift in
        copyToClipboard(gift.link)
        showModalText(for: window, text: strings().contextAlertCopied)
    }, shareNft: { gift in
        showModal(with: ShareModalController(ShareLinkObject(context, link: gift.link)), for: window)
    }, startWearing: { gift in
        showModal(with: StarGift_Nft_Controller(context: context, gift: .unique(gift), source: .previewWear(.init(context.myPeer!), gift)), for: window)
    }, changeFee: {
        
        closeAllModals(window: window)
        
        let privacySignal = context.privacy |> take(1) |> deliverOnMainQueue
        
        let _ = (privacySignal
            |> deliverOnMainQueue).startStandalone(next: { info in
            if let info = info {
                context.bindings.rootNavigation().push(MessagesPrivacyController(context: context, noPaidMessages: info.noPaidMessages, globalSettings: info.globalSettings, updated: { noPaidMessages, globalSettings in
                    context.updateMessagesPrivacy(noPaidMessages: noPaidMessages, globalSettings: globalSettings)
                }))
            }
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.didLoad = { controller, _ in
        gallery = .init(tableView: controller.tableView)
        controller.tableView.supplyment = gallery
        getTableView = { [weak controller] in
            return controller?.tableView
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    


//    let modalInteractions = ModalInteractions(acceptTitle: done, accept: {
//        close?()
//    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    modalController._hasBorder = false
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


