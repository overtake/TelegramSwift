//
//  Star_TransactionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit



final class Star_TransactionItem : GeneralRowItem {
    fileprivate let context:AccountContext
    fileprivate let transaction: Star_Transaction
    
    fileprivate let amountLayout: TextViewLayout
    fileprivate let nameLayout: TextViewLayout
    fileprivate var descLayout: TextViewLayout?
    fileprivate let dateLayout: TextViewLayout
            
    fileprivate let callback: (Star_Transaction)->Void
    
    fileprivate let preview: TelegramMediaFile?
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, viewType: GeneralViewType, transaction: Star_Transaction, callback: @escaping(Star_Transaction)->Void) {
        self.context = context
        self.transaction = transaction
        self.callback = callback
        
        
        if let gift = transaction.native.starGift {
            self.preview = gift.generic?.file ?? gift.unique?.file
        } else {
            self.preview = nil
        }
       
        let amountAttr = NSMutableAttributedString()
        switch transaction.currency {
        case .stars:
            if transaction.amount.value < 0 {
                amountAttr.append(string: "\(transaction.amount.string(transaction.currency)) \(clown)", color: theme.colors.redUI, font: .medium(.text))
            } else {
                amountAttr.append(string: "+\(transaction.amount.string(transaction.currency)) \(clown)", color: theme.colors.greenUI, font: .medium(.text))
            }
        case .ton:
            if transaction.amount.value < 0 {
                amountAttr.append(string: "\(transaction.amount.string(transaction.currency)) \(clown)", color: theme.colors.redUI, font: .medium(.text))
            } else {
                amountAttr.append(string: "+\(transaction.amount.string(transaction.currency)) \(clown)", color: theme.colors.greenUI, font: .medium(.text))
            }
        }
        switch transaction.currency {
        case .stars:
            amountAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        case .ton:
            amountAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: transaction.amount.value < 0 ? theme.colors.redUI : theme.colors.greenUI, playPolicy: .onceEnd), for: clown)
        }
        
        self.amountLayout = .init(amountAttr)
        
        let name: String
        
        switch transaction.type.source {
        case .appstore:
            name = strings().starListTransactionAppStore
        case .fragment:
            name = strings().starListTransactionFragment
        case .playmarket:
            name = strings().starListTransactionPlayMarket
        case .peer:
            if !transaction.native.media.isEmpty {
                name = strings().starsTransactionMediaPurchase
            } else {
                name = transaction.peer?._asPeer().displayTitle ?? ""
            }
        case .premiumbot:
            name = strings().starListTransactionPremiumBot
        case .ads:
            name = strings().starListTransactionAds
        case .unknown:
            name = strings().starListTransactionUnknown
        case .apiLimitExtension:
            name = strings().starsIntroTransactionTelegramBotApiTitle
        }
        
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        
        var date = stringForFullDate(timestamp: transaction.date)
        if transaction.native.flags.contains(.isRefund) {
            date += " — \(strings().starListRefund)"
        }
        self.dateLayout = .init(.initialize(string: date, color: theme.colors.grayText, font: .normal(.text)))
        
        var descString: String? = nil
        if transaction.native.flags.contains(.isStarGiftResale)  {
            descString = transaction.amount.value < 0 ? strings().starTransactionGiftPurchase : strings().starTransactionGiftSale
        } else if let count = transaction.native.paidMessageCount {
            descString = strings().starTransactionMessageFeeCountable(Int(count))
        } else if let premiumGiftMonths = transaction.native.premiumGiftMonths {
            descString = strings().starsTransactionPremiumFor(Int(premiumGiftMonths))
        }  else if let commission = transaction.native.starrefCommissionPermille {
            descString = strings().starsTransactionCommission("\(commission.decemial.string)%")
        } else if !transaction.native.media.isEmpty {
            switch transaction.native.peer {
            case let .peer(peer):
                descString = peer._asPeer().displayTitle
            default:
                break
            }
        } else if transaction.native.giveawayMessageId != nil {
            descString = strings().starsTransactionReceivedPrize
        } else if transaction.native.starGift != nil {
            descString = strings().starsTransactionGift
        } else if let floodskipNumber = transaction.native.floodskipNumber {
            descString = strings().starTransactionBroadcastMessagesCountable(Int(floodskipNumber)).replacingOccurrences(of: "\(floodskipNumber)", with: floodskipNumber.formattedWithSeparator)
        } else {
            if transaction.native.flags.contains(.isGift) {
                descString = strings().starsTransactionReceivedGift
            } else if transaction.native.flags.contains(.isReaction) {
                descString = strings().starsTransactionPaidReaction
            } else if let period = transaction.native.subscriptionPeriod {
                if period == 30 * 24 * 60 * 60 {
                    descString = strings().starsSubscriptionPeriodMonthly
                } else if period == 7 * 24 * 60 * 60 {
                    descString = strings().starsSubscriptionPeriodWeekly
                } else if period == 1 * 24 * 60 * 60 {
                    descString = strings().starsSubscriptionPeriodDaily
                } else {
                    descString = strings().starsSubscriptionPeriodUnknown
                }
            } else {
                if let desc = transaction.native.description {
                    descString = desc
                } else {
                    if transaction.amount.value > 0 {
                        if transaction.native.flags.contains(.isRefund) {
                            descString = strings().starListRefund
                        } else {
                            descString = strings().starsTransactionTopUp
                        }
                    } else {
                        descString = ""
                    }
                }
            }
           
        }
        
        if let descString {
            self.descLayout = .init(.initialize(string: descString, color: theme.colors.text, font: .normal(.text)))
        }
                
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return TransactionView.self
    }
    
    override var height: CGFloat {
        var height = 7 + nameLayout.layoutSize.height + 4 + dateLayout.layoutSize.height + 7
        if let descLayout {
            height += 2 + descLayout.layoutSize.height
        }
        return max(50, height)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        amountLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)
        dateLayout.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)

        descLayout?.measure(width: blockWidth - 20 - amountLayout.layoutSize.width - 10 - 50)
        return true
    }
}

private final class TransactionView : GeneralContainableRowView {
    private let amountView = InteractiveTextView()
    private let nameView = TextView()
    private let dateView = TextView()
    private var avatar: AvatarControl?
    private var photo: TransformImageView?
    private var avatarImage: ImageView?
    private var descView: TextView?
    
    private var previewView: InlineStickerView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(amountView)
        addSubview(nameView)
        addSubview(dateView)
        
        amountView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.scaleOnClick = true
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? Star_TransactionItem {
                item.callback(item.transaction)
            }
        }, for: .Click)
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Star_TransactionItem else {
            return
        }
        
        amountView.set(text: item.amountLayout, context: item.context)
        dateView.update(item.dateLayout)
        nameView.update(item.nameLayout)
        
        if let media = item.transaction.native.media.first, let messageId = item.transaction.native.paidMessageId {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = avatarImage {
                performSubviewRemoval(view, animated: animated)
                self.avatarImage = nil
            }
            
            let current: TransformImageView
            
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 44, 44))
                current.preventsCapture = true
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                self.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = 10
                        
            let reference = StarsTransactionReference(peerId: messageId.peerId, ton: item.transaction.currency == .ton, id: item.transaction.id, isRefund: item.transaction.native.flags.contains(.isRefund))
            
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
            
        } else if let photo = item.transaction.native.photo {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = avatarImage {
                performSubviewRemoval(view, animated: animated)
                self.avatarImage = nil
            }
            let current: TransformImageView
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 44, 44))
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                self.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = floor(current.frame.height / 2)

            current.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: photo, scale: backingScaleFactor))
    
            _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.standalone(resource: photo.resource)).start()
    
            current.set(arguments: TransformImageArguments(corners: .init(radius: 10), imageSize: photo.dimensions?.size ?? NSMakeSize(44, 44), boundingSize: current.frame.size, intrinsicInsets: .init()))

        } else if let peer = item.transaction.peer {
            if let view = self.photo {
                performSubviewRemoval(view, animated: animated)
                self.photo = nil
            }
            if let view = avatarImage {
                performSubviewRemoval(view, animated: animated)
                self.avatarImage = nil
            }
            let current: AvatarControl
            if let view = self.avatar {
                current = view
            } else {
                current = AvatarControl(font: .avatar(20))
                current.userInteractionEnabled = false
                current.setFrameSize(NSMakeSize(44, 44))
                self.avatar = current
                self.addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: peer._asPeer())
        } else {
            if let view = avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            if let view = photo {
                performSubviewRemoval(view, animated: animated)
                self.photo = nil
            }
            let current: ImageView
            if let view = self.avatarImage {
                current = view
            } else {
                current = ImageView(frame: NSMakeRect(0, 0, 40, 40))
                self.avatarImage = current
                addSubview(current)
            }
            switch item.transaction.type.source {
            case .appstore:
                current.image = NSImage(resource: .iconStarTransactionRowStars).precomposed()
            case .fragment:
                current.image = NSImage(resource: .iconStarTransactionRowFragment).precomposed()
            case .ads:
                current.image = NSImage(resource: .iconStarTransactionRowFragment).precomposed()
            case .playmarket:
                current.image = NSImage(resource: .iconStarTransactionRowAndroid).precomposed()
            case .peer:
                break
            case .premiumbot:
                current.image = NSImage(resource: .iconStarTransactionRowPremiumBot).precomposed()
            case .unknown:
                current.image = NSImage(resource: .iconStarTransactionRowFragment).precomposed()
            case .apiLimitExtension:
                current.image = NSImage(resource: .iconStarTransactionRowPaidBroadcast).precomposed()
            }
        }

        
        if let preview = item.preview {
            
            if let view = self.previewView, view.animateLayer.file?.fileId != preview.fileId {
                performSubviewRemoval(view, animated: animated)
                self.previewView = nil
            }
            
            let current: InlineStickerView
            if let view = self.previewView {
                current = view
            } else {
                current = InlineStickerView(account: item.context.account, file: preview, size: NSMakeSize(18, 18), playPolicy: .onceEnd)
                addSubview(current)
                self.previewView = current
            }
        } else if let view = self.previewView {
            performSubviewRemoval(view, animated: animated)
            self.previewView = nil
        }
        
        if let descLayout = item.descLayout {
            let current: TextView
            if let view = self.descView {
                current = view
            } else {
                current = TextView()
                addSubview(current)
                self.descView = current
                current.userInteractionEnabled = false
                current.isSelectable = false
            }
            current.update(descLayout)
        } else if let descView {
            performSubviewRemoval(descView, animated: animated)
            self.descView = nil
        }
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        amountView.centerY(x: containerView.frame.width - amountView.frame.width - 10)
        avatar?.centerY(x: 10)
        photo?.centerY(x: 10)
        avatarImage?.centerY(x: 10)
        nameView.setFrameOrigin(NSMakePoint(10 + 44 + 10, 7))
        dateView.setFrameOrigin(NSMakePoint(nameView.frame.minX, containerView.frame.height - dateView.frame.height - 7))
        
        
        var offset: CGFloat = 0
        
        if let previewView {
            previewView.setFrameOrigin(NSMakePoint(nameView.frame.minX, dateView.frame.minY - previewView.frame.height - 2))
            
            offset += previewView.frame.width + 4
        }
        
        if let descView {
            descView.setFrameOrigin(NSMakePoint(nameView.frame.minX + offset, dateView.frame.minY - descView.frame.height - 2))
        }

    }
    
    override var additionBorderInset: CGFloat {
        return 44 + 6
    }
}
