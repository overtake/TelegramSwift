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
    fileprivate let peer: EnginePeer?
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let descLayout: TextViewLayout?
    fileprivate let incoming: Bool
    fileprivate let purpose: Star_TransactionPurpose
    
    fileprivate var refund: TextViewLayout?
    fileprivate let arguments: Arguments
    fileprivate let isGift: Bool
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: StarsContext.State.Transaction, peer: EnginePeer?, purpose: Star_TransactionPurpose, arguments: Arguments) {
        self.context = context
        self.transaction = transaction
        self.peer = peer
        self.arguments = arguments
        self.purpose = purpose
        
        self.isGift = purpose.isGift || transaction.flags.contains(.isGift) || transaction.giveawayMessageId != nil || transaction.starGift != nil
        
        var fromProfile: Bool = false
        switch purpose {
        case let .starGift(_, _, _, _, _, _, _, _fromProfile):
            fromProfile = _fromProfile
        default:
            break
        }
        
        let header: String
        let incoming: Bool = transaction.count > 0
        let amount: Int64
        if isGift {
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
                amount = transaction.count
            } else {
                amount = abs(transaction.count)
            }
        } else if transaction.flags.contains(.isReaction) {
            header = strings().starsTransactionPaidReaction
            amount = transaction.count
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
            amount = transaction.count
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
                if !transaction.media.isEmpty {
                    header = strings().starsTransactionMediaPurchase
                } else {
                    header = transaction.title ?? peer?._asPeer().displayTitle ?? ""
                }
            }
            amount = transaction.count
        }
        
        self.incoming = incoming
        
        self.headerLayout = .init(.initialize(string: header, color: theme.colors.text, font: .medium(18)), alignment: .center)
        
        

        
        let attr = NSMutableAttributedString()
        switch purpose {
        case .unavailableGift, .starGift:
            break
        default:
            attr.append(string: "\(incoming && !fromProfile ? "+" : "")\(amount) \(clown)", color: incoming ? theme.colors.greenUI : (amount > 0 ? theme.colors.text : theme.colors.redUI), font: .normal(15))
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
        }
        
        self.infoLayout = .init(attr)
        
        if purpose == .unavailableGift {
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
                case let .starGift(_, convertStars, _, _, _nameHidden, savedToProfile, convertedToStars, _fromProfile):
                    let displayTitle: String
                    switch transaction.peer {
                    case let .peer(peer):
                        displayTitle = peer._asPeer().displayTitle
                    default:
                        displayTitle = peer?._asPeer().compactDisplayTitle ?? ""
                    }
                    let convertStarsString = strings().starListItemCountCountable(Int(convertStars))
                    fromProfile = _fromProfile
                    nameHidden = _nameHidden
                    if incoming {
                        if savedToProfile {
                            text = strings().starsStarGiftTextKeptOnPageIncoming
                        } else if convertedToStars {
                            text = strings().starsStarGiftTextConvertedIncoming(convertStarsString)
                        } else {
                            text = strings().starsStarGiftTextIncoming(convertStarsString)
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
                default:
                    text = strings().starsExampleAppsText
                }
                if !fromProfile {
                    text += " " + strings().starsStarGiftTextLink
                    
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
        return true
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    override var height: CGFloat {
        var height = 10 + 10 + headerLayout.layoutSize.height + 5 + infoLayout.layoutSize.height + 10
        
        if isGift {
            height += 100
        } else {
            height += 80
        }
        
        if let descLayout {
            height += descLayout.layoutSize.height + 5 + 2
        }
        return height
    }
    
    var giftFile: TelegramMediaFile {
        switch purpose {
        case let .starGift(gift, _, _, _, _, _, _, _):
            return gift.file
        case .unavailableGift:
            return self.transaction.starGift?.file ?? LocalAnimatedSticker.bestForStarsGift(abs(transaction.count)).file
        default:
            return LocalAnimatedSticker.bestForStarsGift(abs(transaction.count)).file
        }
    }
    
}

private final class HeaderView : GeneralContainableRowView {
    private var photo: TransformImageView?
    private var avatar: AvatarControl?
    private let control = Control(frame: NSMakeRect(0, 0, 80, 80))
    private let sceneView: GoldenStarSceneView
    private let dismiss = ImageButton()
    private let headerView = TextView()
    private let infoView = InteractiveTextView()
    private var refundView: TextView?
    private let infoContainer: View = View()
    private var outgoingView: ImageView?
    private var descView: TextView?
    private var starBadgeView: ImageView?
    
    private var giftView: InlineStickerView?
    
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
            
            let reference = StarsTransactionReference(peerId: messageId.peerId, id: item.transaction.id, isRefund: item.transaction.flags.contains(.isRefund))
            
            var updateImageSignal: Signal<ImageDataTransformation, NoError>?
            
            if let image = media as? TelegramMediaImage {
                updateImageSignal = chatMessagePhoto(account: item.context.account, imageReference: ImageMediaReference.starsTransaction(transaction: reference, media: image), scale: backingScaleFactor, synchronousLoad: false, autoFetchFullSize: true)
            } else if let file = media as? TelegramMediaFile {
                updateImageSignal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: .starsTransaction(transaction: reference, media: file), scale: backingScaleFactor)
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
        
        self.headerView.update(item.headerLayout)
        self.infoView.set(text: item.infoLayout, context: item.context)
        
        self.dismiss.set(image: theme.icons.modalClose, for: .Normal)
        self.dismiss.sizeToFit()
        self.dismiss.scaleOnClick = true
        self.dismiss.autohighlight = false
        
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.close()
        }, for: .Click)
        
        if item.peer == nil, item.transaction.starGift == nil {
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
        giftView?.centerX(y: -20)
        outgoingView?.center()
        dismiss.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - dismiss.frame.height) / 2)))
        
        
        headerView.centerX(y: (giftView != nil ? 110 : 90) + 20)
        
        infoContainer.centerX(y: headerView.frame.maxY + 5)
        infoView.centerY(x: 0)
        refundView?.centerY(x: infoView.frame.maxX + 4, addition: -1)

        if let descView {
            descView.centerX(y: infoContainer.frame.maxY + 5)
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
    init(context: AccountContext, openPeer:@escaping(PeerId)->Void, copyTransaction:@escaping(String)->Void, openLink:@escaping(String)->Void, previewMedia:@escaping()->Void, openApps: @escaping()->Void, close: @escaping()->Void, openStars:@escaping()->Void, convertStars:@escaping()->Void, displayOnMyPage:@escaping()->Void, seeInProfile: @escaping() ->Void, sendGift:@escaping(PeerId)->Void) {
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
    }
}

private struct State : Equatable {
    var transaction: StarsContext.State.Transaction
    var purpose: Star_TransactionPurpose
    var peer: EnginePeer?
    var paidPeer: EnginePeer?
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
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, transaction: state.transaction, peer: state.peer, purpose: state.purpose, arguments: arguments)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    let done: String
    var convertStarsAmount: Int64? = nil
    var savedToProfile: Bool = false
    switch state.purpose {
    case let .starGift(gift, convertStars, _, _, _, _savedToProfile, converted, _):
        savedToProfile = _savedToProfile
        if state.transaction.count > 0 {
            switch state.transaction.peer {
            case let .peer(peer):
                if peer.id == arguments.context.peerId {
                    if !converted {
                        convertStarsAmount = convertStars
                    }
                    if savedToProfile {
                        done = strings().starTransactionStarGiftHideFromMyPage
                    } else {
                        done = strings().starTransactionStarGiftDisplayOnMyPage
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
        
        let fromPeer: String
        if let messageId = state.transaction.giveawayMessageId {
            fromPeer = "[\(peer._asPeer().compactDisplayTitle)](t.me/c/\(peer.id.id._internalGetInt64Value())/\(messageId.id))"
        } else if peer.id == servicePeerId {
            fromPeer = strings().starTransactionUnknwonUser
        } else {
            fromPeer = "[\(peer._asPeer().compactDisplayTitle)](peer_id_\(peer.id.toInt64()))"
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
        if state.transaction.giveawayMessageId != nil {
            fromText = strings().starTransactionFrom
        } else if peer._asPeer().isUser && state.transaction.count > 0 {
            fromText = strings().starTransactionFrom
        } else if state.transaction.count < 0, state.transaction.starGift != nil {
            fromText = strings().starTransactionFrom
        }  else {
            fromText = strings().starTransactionTo
        }
        
        let badge: InputDataTableBasedItem.Row.Right.Badge?
        if fromText == strings().starTransactionFrom, state.transaction.starGift != nil, peer.id != arguments.context.peerId {
            badge = .init(text: strings().starTransactionSendGift, callback: {
                arguments.sendGift(peer.id)
            })
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
        
        
        switch state.purpose {
        case .starGift:
            switch state.transaction.peer {
            case let .peer(peer):
                
                let toPeer: String
                toPeer = "[\(peer._asPeer().displayTitle)](peer_id_\(peer.id.toInt64()))"
                
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
        let transactionId: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(state.transaction.id)](\(state.transaction.id))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })), alwaysStaticItems: true)
        
        transactionId.interactions.processURL = { inapplink in
            if let inapplink = inapplink as? String {
                arguments.copyTransaction(inapplink)
            }
        }        
        rows.append(.init(left: .init(.initialize(string: strings().starTransactionId, color: theme.colors.text, font: .normal(.text))), right: .init(name: transactionId)))
    }
    
    if state.transaction.giveawayMessageId != nil {
        rows.append(.init(left: .init(.initialize(string: strings().starTransactionGift, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starListItemCountCountable(Int(state.transaction.count)), color: theme.colors.text, font: .normal(.text))))))

        rows.append(.init(left: .init(.initialize(string: strings().starTransactionReason, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starTransactionReasonGiveaway, color: theme.colors.text, font: .normal(.text))))))
    }
    
    
    rows.append(.init(left: .init(.initialize(string: strings().starTransactionDate, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: state.transaction.date), color: theme.colors.text, font: .normal(.text))))))

    
    switch state.purpose {
    case .unavailableGift:
        if let gift = state.transaction.starGift {
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionValue, color: theme.colors.text, font: .normal(.text))), right: InputDataTableBasedItem.Row.Right(name: .init(.initialize(string: gift.price.formattedWithSeparator, color: theme.colors.text, font: .normal(.text))), leftView: { previous in
                
                let imageView = previous as? ImageView ?? ImageView()
                imageView.image = NSImage(resource: .iconStarCurrency).precomposed()
                imageView.setFrameSize(18, 18)
                imageView.contentGravity = .resizeAspectFill
                return imageView
            })))
        }
    case let .starGift(gift, _, text, entities, _, _, _, _):
        
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
    
   
    if done == strings().modalDone {
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

enum Star_TransactionPurpose : Equatable {
    case payment
    case gift
    case unavailableGift
    case starGift(gift: StarGift, convertStars: Int64, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, converted: Bool, fromProfile: Bool)
    
    var isGift: Bool {
        switch self {
        case .gift, .starGift, .unavailableGift:
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
    
    var gift: StarGift? {
        switch self {
        case let .starGift(gift, _, _, _, _, _, _, _):
            return gift
        default:
            return nil
        }
    }
}

func Star_TransactionScreen(context: AccountContext, peer: EnginePeer?, transaction: StarsContext.State.Transaction, purpose: Star_TransactionPurpose = .payment, messageId: MessageId? = nil, profileContext: ProfileGiftsContext? = nil) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    var gallery: GallerySupplyment? = nil
    var getTableView:(()->TableView?)? = nil

    
    let initialState = State(transaction: transaction, purpose: purpose, peer: peer)
    
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
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, openPeer: { peerId in
        context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
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
        let amount = stateValue.with { $0.transaction.count }
        let peer = stateValue.with { $0.peer?._asPeer() }
        if !medias.isEmpty, let peer {
            let message = Message(TelegramMediaPaidContent(amount: amount, extendedMedia: medias.map { .full(media: $0) }), stableId: 0, messageId: .init(peerId: peer.id, namespace: 0, id: 0))
            showPaidMedia(context: context, medias: medias, parent: message, firstIndex: 0, firstStableId: ChatHistoryEntryId.mediaId(0, message), getTableView?(), nil)
        }
    }, openApps: {
        showModal(with: Star_AppExamples(context: context), for: window)
    }, close: {
        close?()
    }, openStars: {
        showModal(with: StarUsePromoController(context: context), for: window)
    }, convertStars: { [weak profileContext] in
        if let messageId, let peer = peer {
            switch purpose {
            case .starGift(_, let convertStars, _, _, _, _, _, _):
                verifyAlert(for: window, header: strings().starTransactionConvertAlertHeader, information: strings().starTransactionConvertAlertInfo(peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(convertStars))), ok: strings().starTransactionConvertAlertOK, successHandler: { _ in
                    if let profileContext {
                        profileContext.convertStarGift(messageId: messageId)
                    } else {
                        _ = context.engine.payments.convertStarGift(messageId: messageId).start()
                    }
                    close?()
                    showModalText(for: window, text: strings().starTransactionStarGiftConvertToStarsAlert)
                    PlayConfetti(for: window, stars: true)
                })
            default:
                break
            }
        }
    }, displayOnMyPage: { [weak profileContext] in
        
        if let messageId {
            switch purpose {
            case .starGift(_, _, _, _, _, let savedToProfile, _, _):
                if let profileContext {
                    profileContext.updateStarGiftAddedToProfile(messageId: messageId, added: !savedToProfile)
                } else {
                    _ = context.engine.payments.updateStarGiftAddedToProfile(messageId: messageId, added: !savedToProfile).startStandalone()
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
        showModal(with: GiftingController(context: context, peerId: peerId), for: window)
        close?()
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
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


