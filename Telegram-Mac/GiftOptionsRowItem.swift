//
//  GiftOptionsRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TGUIKit
import TelegramCore
import TelegramMedia

extension StarGift {
    var id: Int64 {
        return self.generic?.id ?? self.unique?.id ?? 0
    }
}

private func ribbonOutlineImage(color: NSColor) -> CGImage? {
    if let image = NSImage(named: "GiftRibbon") {
        return generateScaledImage(image: image._cgImage, size: CGSize(width: image.size.width + 8, height: image.size.height + 8), opaque: true, color: color)
    } else {
        return nil
    }
}


struct PremiumPaymentOption : Equatable {
    var title: String
    var desc: String
    var total: String
    var discount: String?
    var months: Int32
    
    var product: PremiumGiftProduct
    var starProduct: PremiumGiftProduct?
    
    var media: LocalAnimatedSticker {
        switch months {
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
    
    var text: NSAttributedString {
        let attr = NSMutableAttributedString()
        attr.append(string: self.title, color: theme.colors.text, font: .medium(.text))
        attr.append(string: "\n")
        attr.append(string: strings().stickersPremium, color: theme.colors.text, font: .normal(.text))
        return attr
    }
}

struct PeerStarGift : Equatable {
    let media: TelegramMediaFile
    let stars: Int64
    let limited: Bool
    let native: StarGift
    
    func totalStars(_ includeUpgrade: Bool, sendMessage: StarsAmount? = nil, count: Int32 = 1) -> Int64 {
        if includeUpgrade {
            switch native {
            case let .generic(gift):
                if let upgradeStars = gift.upgradeStars {
                    return (stars + upgradeStars + (sendMessage?.value ?? 0)) * Int64(count)
                }
            default:
                return (stars + (sendMessage?.value ?? 0)) * Int64(count)
            }
        }
        return (stars + (sendMessage?.value ?? 0)) * Int64(count)
    }
}

final class GiftOptionsRowItem : GeneralRowItem {
    
    struct Option : Equatable {
        
        static func ==(lhs: Option, rhs: Option) -> Bool {
            if lhs.nativePayment != rhs.nativePayment {
                return false
            }
            if lhs.nativeProfileGift != rhs.nativeProfileGift {
                return false
            }
            if lhs.nativeStarGift != rhs.nativeStarGift {
                return false
            }
            if lhs.nativeStarUniqueGift != rhs.nativeStarUniqueGift {
                return false
            }
            if lhs.file != rhs.file {
                return false
            }
            return true
        }
        
        enum TypeValue {
            case price(String)
            case stars(Int64, Bool, Bool)
            case none
        }
        struct Badge {
            let text: String
            let colors: [NSColor]
            let textColor: NSColor
            let outline: Bool
        }
        let file: TelegramMediaFile?
        let image: CGImage?
        let colors: [LottieColor]
        let text: NSAttributedString?
        let type: TypeValue
        let badge: Badge?
        let peer: EnginePeer?
        let invisible: Bool
        let pinned: Bool
        let toggleSelect: Bool?
        
        let priceBadge: TextViewLayout?
        
        var starsPrice: TextViewLayout?
        
        var nativePayment: PremiumPaymentOption?
        var nativeStarGift: PeerStarGift?
        var nativeProfileGift: ProfileGiftsContext.State.StarGift?
        var nativeStarUniqueGift: StarGift.UniqueGift?
        
        var gift: StarGift? {
            return nativeStarUniqueGift.flatMap { .unique($0) } ?? nativeStarGift?.native ?? nativeProfileGift?.gift
        }
        
        static func initialize(_ option: PremiumPaymentOption) -> Option {
            
            var colors: [NSColor] = []
            if theme.colors.isDark {
                colors = [NSColor(0x522124), NSColor(0x653634)]
            } else {
                colors = [theme.colors.redUI.withMultipliedBrightnessBy(1.1), theme.colors.redUI.withMultipliedBrightnessBy(0.9)]
            }
            
            let starsPrice: TextViewLayout?
            if let starOption = option.starProduct {
                let price = NSMutableAttributedString()
                
                price.append(string: strings().giftPremiumPayOrStars(clown + " " + "\(starOption.giftOption.amount)"), color: GOLD, font: .normal(.small))
                price.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
                
                starsPrice = .init(price)
                starsPrice?.measure(width: .greatestFiniteMagnitude)
            } else {
                starsPrice = nil
            }
            
            return .init(file: option.media.file, image: nil, colors: [], text: option.text, type: .price(option.total), badge: option.discount.flatMap { .init(text: $0, colors: colors, textColor: .white, outline: false )}, peer: nil, invisible: false, pinned: false, toggleSelect: nil, priceBadge: nil, starsPrice: starsPrice, nativePayment: option)
        }
        
        
        static func initialize(_ image: CGImage, text: NSAttributedString) -> Option {
            return .init(file: nil, image: image, colors: [], text: text, type: .none, badge: nil, peer: nil, invisible: false, pinned: false, toggleSelect: nil, priceBadge: nil, starsPrice: nil, nativePayment: nil)
        }

        
        static func initialize(_ option: PeerStarGift) -> Option {
            let badge: Badge?
            
            var redColor: [NSColor] = []
            var blueColor: [NSColor] = []
            let greenColor: [NSColor] = [NSColor(0x4bb121), NSColor(0x53d654)]
            let goldColor: [NSColor] = [NSColor(0xea8b01), NSColor(0xfab625)]
            
            if theme.colors.isDark {
                redColor = [NSColor(0x522124), NSColor(0x653634)]
                blueColor = [NSColor(0x142e42), NSColor(0x354f5b)]
            } else {
                redColor = [theme.colors.redUI.withMultipliedBrightnessBy(1.1), theme.colors.redUI.withMultipliedBrightnessBy(0.9)]
                blueColor = [theme.colors.accent.withMultipliedBrightnessBy(1.1), theme.colors.accent.withMultipliedBrightnessBy(0.9)]
            }
            if option.native.generic?.flags.contains(.requiresPremium) == true {
                badge = .init(text: strings().premiumLimitPremium, colors: goldColor, textColor: theme.colors.underSelectedColor, outline: true)
            } else if let availability = option.native.generic?.availability {
                if availability.minResaleStars != nil && option.native.generic?.soldOut != nil {
                    badge = .init(text: strings().giftResale, colors: greenColor, textColor: .white, outline: true)
                } else if availability.remains == 0 {
                    badge = .init(text: strings().giftSoldOut, colors: redColor, textColor: .white, outline: false)
                } else {
                    badge = .init(text: strings().starGiftLimited, colors: blueColor, textColor: theme.colors.underSelectedColor, outline: false)
                }
            } else if let unique = option.native.unique {
                badge = .init(text: "#\(unique.number)", colors: option.native.backdropColor ?? blueColor, textColor: theme.colors.underSelectedColor, outline: false)
            } else {
                badge = nil
            }
            
            
            
            let price: Int64
            let resale: Bool
            let availability = option.native.generic?.availability
            if let minResaleStars = availability?.minResaleStars, option.native.generic?.soldOut != nil {
                price = minResaleStars
                resale = true
            } else {
                price = option.stars
                resale = false
            }
            
            return .init(file: option.media, image: nil, colors: [], text: nil, type: .stars(price, false, resale), badge: badge, peer: nil, invisible: false, pinned: false, toggleSelect: nil, priceBadge: nil, nativeStarGift: option)
        }
        
        static func initialize(_ option: StarGift.UniqueGift, resale: Bool = false, showNumber: Bool = false) -> Option {
            
            let badge: Option.Badge?
            
            var blueColor: [NSColor] = []
            
            if theme.colors.isDark {
                blueColor = [NSColor(0x142e42), NSColor(0x354f5b)]
            } else {
                blueColor = [theme.colors.accent.withMultipliedBrightnessBy(1.1), theme.colors.accent.withMultipliedBrightnessBy(0.9)]
            }
            
            
            if showNumber {
                badge = .init(text: "#\(option.number)", colors: option.backdrop ?? blueColor, textColor: theme.colors.underSelectedColor, outline: false)
            } else {
                badge = nil
            }
            
            return .init(file: option.file!, image: nil, colors: [], text: nil, type: option.resellStars != nil ? .stars(option.resellStars!, true, resale) : .none, badge: badge, peer: nil, invisible: false, pinned: false, toggleSelect: nil, priceBadge: nil, nativeStarUniqueGift: option)
        }
        
        
        static func initialize(_ option: ProfileGiftsContext.State.StarGift, transfrarable: Bool = false, selected: Bool? = nil) -> Option {
            
            var blueColor: [NSColor] = []
            
            if theme.colors.isDark {
                blueColor = [NSColor(0x142e42), NSColor(0x354f5b)]
            } else {
                blueColor = [theme.colors.accent.withMultipliedBrightnessBy(1.1), theme.colors.accent.withMultipliedBrightnessBy(0.9)]
            }
            
            var priceBadge: TextViewLayout? = nil
            
            let badge: Badge?
            if let resellStars = option.gift.unique?.resellStars {
                badge = .init(text: strings().giftSale, colors: [NSColor(0x74b036), NSColor(0x87d151)], textColor: theme.colors.underSelectedColor, outline: false)
                
                let attr = NSMutableAttributedString()
                attr.append(.initialize(string: "\(clown_space)\(resellStars)", color: .white, font: .normal(.text)))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
                
                priceBadge = .init(attr)
                priceBadge?.measure(width: .greatestFiniteMagnitude)
            } else if let availability = option.gift.generic?.availability {
                badge = .init(text: strings().starTransactionAvailabilityOf(1, Int(availability.total).prettyNumber), colors: blueColor, textColor: theme.colors.underSelectedColor, outline: false)
            } else if let unique = option.gift.unique {
                badge = .init(text: "#\(unique.number)", colors: option.gift.backdropColor ?? blueColor, textColor: theme.colors.underSelectedColor, outline: false)
            } else {
                badge = nil
            }
            
            let file: TelegramMediaFile
            switch option.gift {
            case .generic(let gift):
                file = gift.file
            case .unique(let uniqueGift):
                file = uniqueGift.file!
            }            
            return .init(file: file, image: nil, colors: [], text: nil, type: transfrarable ? .price(strings().starNftTransfer) : .none, badge: badge, peer: selected != nil ? nil : option.fromPeer, invisible: selected != nil ? false : !option.savedToProfile, pinned: selected != nil ? false : option.pinnedToTop, toggleSelect: selected, priceBadge: selected != nil ? nil : priceBadge, nativeProfileGift: option)
        }
        
        var height: CGFloat {
            var height: CGFloat = 0
            switch type {
            case .price:
                height = nativeProfileGift != nil ? 135 : 160
            case .stars:
                height = 135
            case .none:
                height = 100
            }
            if let starsPrice {
                height += starsPrice.layoutSize.height + 10
            }
            return height
        }
    }
    
    fileprivate let options: [Option]
    fileprivate let context: AccountContext
    fileprivate let perRowCount: Int
    fileprivate let fitToSize: Bool
    fileprivate let selected: StarGift?
        
    fileprivate let callback:(Option)->Void
    private let _contextMenu:(Option)->[ContextMenuItem]
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, options: [Option], perRowCount: Int = 3, fitToSize: Bool = false, insets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 20), viewType: GeneralViewType = .legacy, callback:@escaping(Option)->Void, selected: StarGift? = nil, contextMenu:@escaping(Option)->[ContextMenuItem] = { _ in return [] }) {
        self.options = options
        self.context = context
        self.callback = callback
        self.perRowCount = perRowCount
        self.fitToSize = fitToSize
        self.selected = selected
        self._contextMenu = contextMenu
        assert(!options.isEmpty)
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: insets)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        
        let itemSize: NSSize
        if self.fitToSize, self.options.count == 1 {
            itemSize = NSMakeSize(width - self.inset.right - self.inset.left, self.height)
        } else {
            let insets = self.inset
            let count = self.fitToSize ? CGFloat(self.options.count) : CGFloat(self.perRowCount)
            let space = self.width - insets.left - insets.right - (10 * CGFloat(count - 1))
            itemSize = NSMakeSize(floorToScreenPixels(space / count), self.height)
        }
        var x: CGFloat = self.inset.left

        for (i, option) in options.enumerated() {
            if location.x > x && location.x < (x + itemSize.width + 10) {
                return .single(_contextMenu(options[i]))
            }
            x += itemSize.width + 10
        }
        
        
        return .single([])
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    override func viewClass() -> AnyClass {
        return GiftOptionsRowView.self
    }
    
    override var height: CGFloat {
        return options[0].height
    }
}

private final class GiftOptionsRowView:  GeneralContainableRowView {
    
    
    private class OptionView : Control {
        
        
        final class InvisibleView : View {
            private let imageView = ImageView()
            private let visualEffect = VisualEffect()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(visualEffect)
                addSubview(imageView)
                imageView.image = NSImage(resource: .menuEyeSlash).precomposed(NSColor.white)
                imageView.sizeToFit()
                layer?.cornerRadius = frameRect.height / 2
                visualEffect.bgColor = NSColor.blackTransparent.withAlphaComponent(0.1)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func layout() {
                super.layout()
                imageView.center()
                visualEffect.frame = bounds
            }
        }
        
        final class PriceBadgeView : VisualEffect {
            private let textView = InteractiveTextView()
            override init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(textView)
                textView.isEventLess = true
                textView.userInteractionEnabled = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(_ layout: TextViewLayout, context: AccountContext) {
                self.textView.set(text: layout, context: context)
                
                setFrameSize(NSMakeSize(layout.layoutSize.width + 10, layout.layoutSize.height + 6))
                
                self.layer?.cornerRadius = self.frame.height / 2
            }
            
            override func layout() {
                super.layout()
                textView.center()
            }
        }
        
        private let sticker = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 80, 80))
        private var imageView: ImageView?
        private var textView: TextView?
        private var badgeView: ImageView?
        private var badgeOutlineView: ImageView?
        private var priceView: PriceView?
        private var starPriceView: StarPriceView?
        private var avatarView: AvatarControl?
        private var invisibleView: InvisibleView?
        private var emoji: PeerInfoSpawnEmojiView?
        private var backgroundView: PeerInfoBackgroundView?
        private var selectionView: View?
        private var starsPrice: InteractiveTextView?
        private var pinnedView: ImageView?
        private var priceBadgeView: PriceBadgeView?
        private let surfaceView: View = View()
        private var premiumSelectView: View?
        private var toggleSelect: SelectingControl?

        private class PriceView: View {
            private let textView = TextView()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(textView)
                textView.userInteractionEnabled = false
                textView.isSelectable = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(text: TextViewLayout) {
                self.textView.update(text)
                self.setFrameSize(NSMakeSize(text.layoutSize.width + 16, text.layoutSize.height + 10))
                self.layer?.cornerRadius = frame.height / 2
                self.needsLayout = true
            }
            override func layout() {
                super.layout()
                self.textView.center()
            }
        }
        
        private class StarPriceView: View {
            private let textView = InteractiveTextView()
            let effect = StarsButtonEffectLayer()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(textView)
                self.layer?.addSublayer(effect)
                textView.userInteractionEnabled = false
                self.layer?.masksToBounds = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(text: TextViewLayout, context: AccountContext) {
                self.textView.set(text: text, context: context)
                self.setFrameSize(NSMakeSize(text.layoutSize.width + 16, text.layoutSize.height + 10))
                self.layer?.cornerRadius = frame.height / 2
                self.layer?.masksToBounds = false
                self.needsLayout = true
                
                
                let rect = self.bounds.insetBy(dx: -5, dy: -5)
                effect.frame = rect
                effect.update(size: rect.size)
            }
            override func layout() {
                super.layout()
                self.textView.center()
            }
        }
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(surfaceView)
            addSubview(sticker)
            
                        
            sticker.userInteractionEnabled = false
            
            surfaceView.backgroundColor = theme.colors.background
            
            surfaceView.layer?.cornerRadius = 10
            
            scaleOnClick = true
            set(handler: { _ in
                
            }, for: .Click)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var option: GiftOptionsRowItem.Option?
        
        func set(option: GiftOptionsRowItem.Option, context: AccountContext, selected: Bool, animated: Bool, callback:@escaping(GiftOptionsRowItem.Option)->Void) {
            
            self.option = option
            
            self.setSingle(handler: { _ in
                callback(option)
            }, for: .Click)
            
            if let file = option.file {
                let parameters = ChatAnimatedStickerMediaLayoutParameters(playPolicy: .framesCount(2), alwaysAccept: true, cache: .temporaryLZ4(.thumb), hidePlayer: false, media: file, colors: option.colors, shimmer: false, thumbAtFrame: 1)
                self.sticker.update(with: file, size: self.sticker.frame.size, context: context, table: nil, parameters: parameters, animated: false)
            }
            
            self.sticker.isHidden = option.file == nil
            
            if let image = option.image {
                let current: ImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = ImageView()
                    self.addSubview(current)
                    self.imageView = current
                    current.isEventLess = true
                }
                current.image = image
                current.sizeToFit()
            } else if let view = self.imageView {
                performSubviewRemoval(view, animated: false)
                self.imageView = nil
            }
            
            if let text = option.text {
                let current: TextView
                if let view = self.textView {
                    current = view
                } else {
                    current = TextView()
                    self.addSubview(current)
                    self.textView = current
                    current.userInteractionEnabled = false
                    current.isSelectable = false
                }
                let textLayout = TextViewLayout(text, alignment: .center)
                textLayout.measure(width: .greatestFiniteMagnitude)
                current.update(textLayout)
            } else if let view = self.textView {
                performSubviewRemoval(view, animated: false)
                self.textView = nil
            }
            
            if let peer = option.peer {
                let current: AvatarControl
                if let view = self.avatarView {
                    current = view
                } else {
                    current = AvatarControl(font: .avatar(8))
                    current.setFrameSize(20, 20)
                    self.addSubview(current)
                    self.avatarView = current
                    current.userInteractionEnabled = false
                }
                current.setPeer(account: context.account, peer: peer._asPeer())
            } else if let avatarView {
                performSubviewRemoval(avatarView, animated: false)
                self.avatarView = nil
            }
            
            switch option.type {
            case .price(let string):
                
                if let view = self.starPriceView {
                    performSubviewRemoval(view, animated: false)
                    self.starPriceView = nil
                }
                
                let current: PriceView
                if let view = self.priceView {
                    current = view
                } else {
                    current = PriceView(frame: .zero)
                    self.addSubview(current)
                    self.priceView = current
                }
                let priceLayout = TextViewLayout(.initialize(string: string, color: option.gift?.unique != nil ? .white : theme.colors.accent, font: .medium(.text)))
                priceLayout.measure(width: .greatestFiniteMagnitude)
                current.backgroundColor = option.gift?.unique != nil ? NSColor.white.withAlphaComponent(0.2) : theme.colors.accent.withAlphaComponent(0.2)
                current.update(text: priceLayout)
                
            case let .stars(int64, plain, addPlus):
                if let view = self.priceView {
                    performSubviewRemoval(view, animated: false)
                    self.priceView = nil
                }
                
                let current: StarPriceView
                if let view = self.starPriceView {
                    current = view
                } else {
                    current = StarPriceView(frame: .zero)
                    self.addSubview(current)
                    self.starPriceView = current
                }
                
                current.effect.isHidden = plain
                
                let attr = NSMutableAttributedString()
                attr.append(string: "\(clown_space)\(int64)" + (addPlus ? "+" : ""), color: plain ? NSColor.white : GOLD, font: .medium(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, color: nil), for: clown)
                let priceLayout = TextViewLayout(attr)
                priceLayout.measure(width: .greatestFiniteMagnitude)
                current.backgroundColor = plain ? NSColor.white.withAlphaComponent(0.2) : GOLD.withAlphaComponent(0.2)
                current.update(text: priceLayout, context: context)
            case .none:
                if let view = self.priceView {
                    performSubviewRemoval(view, animated: false)
                    self.priceView = nil
                }
                if let view = self.starPriceView {
                    performSubviewRemoval(view, animated: false)
                    self.starPriceView = nil
                }
            }
            
            if let badge = option.badge {
                let current: ImageView
                if let view = self.badgeView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current, positioned: .above, relativeTo: self.sticker)
                    self.badgeView = current
                }
                                
                let ribbon = generateGradientTintedImage(image: NSImage(named: "GiftRibbon")?.precomposed(), colors: badge.colors, direction: .diagonal)!
                
                
                current.image = generateGiftBadgeBackground(background: ribbon, text: badge.text, textColor: badge.textColor)
                
                current.sizeToFit()
            } else if let view = badgeView {
                performSubviewRemoval(view, animated: false)
                self.badgeView = nil
            }
            
            

            
            if option.invisible {
                let current: InvisibleView
                if let view = self.invisibleView {
                    current = view
                } else {
                    current = InvisibleView(frame: NSMakeRect(0, 0, 30, 30))
                    addSubview(current)
                    self.invisibleView = current
                }
            } else if let view = self.invisibleView {
                performSubviewRemoval(view, animated: false)
                self.invisibleView = nil
            }
            
            
            if let uniqueGift = option.gift?.unique {
                do {
                    let current:PeerInfoBackgroundView
                    if let view = self.backgroundView {
                        current = view
                    } else {
                        current = PeerInfoBackgroundView(frame: bounds)
                        self.addSubview(current, positioned: .below, relativeTo: sticker)
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
                    current.avatarBackgroundGradientLayer.opacity = 0.5
                    current.layer?.cornerRadius = 10
                }
                do {
                    let current:PeerInfoSpawnEmojiView
                    if let view = self.emoji {
                        current = view
                    } else {
                        current = PeerInfoSpawnEmojiView(frame: bounds)
                        self.addSubview(current, positioned: .below, relativeTo: sticker)
                        self.emoji = current
                    }
                   // current.layer?.masksToBounds = true
                    var patternFile: TelegramMediaFile?
                    var patternColor: NSColor?

                    for attribute in uniqueGift.attributes {
                        switch attribute {
                        case .pattern(_, let file, _):
                            patternFile = file
                        case let .backdrop(_, _, _, _, color, _, _):
                            patternColor = NSColor(UInt32(color)).withAlphaComponent(0.7)
                        default:
                            break
                        }
                    }
                    if let patternFile, let patternColor {
                        current.set(fileId: patternFile.fileId.id, color: patternColor, context: context, animated: false)
                        current.fraction = 0.68
                    }
                }
                
            } else {
                if let view = self.emoji {
                    performSubviewRemoval(view, animated: false)
                    self.emoji = nil
                }
                if let view = self.backgroundView {
                    performSubviewRemoval(view, animated: false)
                    self.backgroundView = nil
                }
            }
            
            if option.pinned {
                let current: ImageView
                if let view = self.pinnedView {
                    current = view
                } else {
                    current = ImageView()
                    self.pinnedView = current
                    addSubview(current)
                }
                current.image = NSImage(resource: .iconChatListPinned).precomposed(.white)
                current.sizeToFit()
            } else if let view = self.pinnedView {
                performSubviewRemoval(view, animated: animated)
                self.pinnedView = nil
            }
            
            
            if let starsPrice = option.starsPrice {
                let current: InteractiveTextView
                if let view = self.starsPrice {
                    current = view
                } else {
                    current = InteractiveTextView()
                    current.userInteractionEnabled = false
                    self.starsPrice = current
                    addSubview(current)
                }
                current.set(text: starsPrice, context: context)
            } else if let view = self.starsPrice {
                performSubviewRemoval(view, animated: animated)
                self.starsPrice = nil
            }
            
            if let priceBadge = option.priceBadge {
                let current: PriceBadgeView
                if let view = self.priceBadgeView {
                    current = view
                } else {
                    current = PriceBadgeView(frame: .zero)
                    self.priceBadgeView = current
                    addSubview(current)
                }
                
                current.update(priceBadge, context: context)
            } else if let view = self.priceBadgeView {
                performSubviewRemoval(view, animated: animated)
                self.priceBadgeView = nil
            }
            
            if selected {
                let current: View
                if let view = selectionView {
                    current = view
                } else {
                    current = View()
                    addSubview(current)
                    self.selectionView = current
                    current.layer?.cornerRadius = 10
                }
                current.layer?.borderColor = theme.colors.background.cgColor
                current.layer?.borderWidth = 3
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else if let selectionView {
                performSubviewRemoval(selectionView, animated: animated)
                self.selectionView = nil
            }
            
            if option.gift?.generic?.flags.contains(.requiresPremium) == true, option.nativeStarGift != nil, let badge = option.badge {
                let current: View
                if let view = premiumSelectView {
                    current = view
                } else {
                    current = View()
                    addSubview(current, positioned: .below, relativeTo: badgeView)
                    self.premiumSelectView = current
                    current.layer?.cornerRadius = 10
                }
                current.layer?.borderColor = badge.colors[0].cgColor
                current.layer?.borderWidth = 1
                
            } else if let premiumSelectView {
                performSubviewRemoval(premiumSelectView, animated: animated)
                self.premiumSelectView = nil
            }
            
            
            if let badge = option.badge, badge.outline {
                let current: ImageView
                if let view = self.badgeOutlineView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current, positioned: .below, relativeTo: self.badgeView)
                    self.badgeOutlineView = current
                }
                                
                let ribbon = ribbonOutlineImage(color: theme.colors.listBackground)
                
                current.image = ribbon
                
                current.sizeToFit()
            } else if let view = badgeOutlineView {
                performSubviewRemoval(view, animated: false)
                self.badgeOutlineView = nil
            }
            
            if let toggleSelect = option.toggleSelect {
                
                let unselected: CGImage = theme.icons.chatToggleUnselected
                let selected: CGImage = theme.icons.chatToggleSelected

                let current: SelectingControl
                if let view = self.toggleSelect {
                    current = view
                } else {
                    current = SelectingControl(unselectedImage: unselected, selectedImage: selected)
                    current.scaleOnClick = true
                    addSubview(current)
                    self.toggleSelect = current
                }
                current.update(unselectedImage: unselected, selectedImage: selected, selected: toggleSelect, animated: animated)
                current.userInteractionEnabled = false
            } else if let view = self.toggleSelect {
                performSubviewRemoval(view, animated: animated)
                self.toggleSelect = nil
            }
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            sticker.centerX(y: priceView != nil ? 0 : 10)
            textView?.centerX(y: sticker.frame.maxY + 5)
            if let badgeView {
                badgeView.setFrameOrigin(frame.width - badgeView.frame.width, 0)
            }
            
            if let toggleSelect {
                toggleSelect.setFrameOrigin(NSMakePoint(5, 5))
            }
            
            if let badgeOutlineView {
                badgeOutlineView.setFrameOrigin(frame.width - badgeOutlineView.frame.width + 4, -2)
            }
            
            var offset: CGFloat = 0
            if let starsPrice {
                starsPrice.centerX(y: frame.height - starsPrice.frame.height - 10)
                offset += starsPrice.frame.height + 10
            }
            
            if let priceView {
                priceView.centerX(y: frame.height - priceView.frame.height - 10 - offset)
            }
            if let starPriceView {
                starPriceView.centerX(y: frame.height - starPriceView.frame.height - 10 - offset)
            }
            if let avatarView {
                avatarView.setFrameOrigin(NSMakePoint(4, 4))
            }
            if let backgroundView {
                backgroundView.frame = NSMakeRect(1, 1, bounds.width - 2, bounds.height - 1)
            }
            if let emoji {
                emoji.frame = bounds.insetBy(dx: 1, dy: 1).offsetBy(dx: 0, dy: 33)
            }
            
            surfaceView.frame = bounds.insetBy(dx: 1, dy: 1)
            
            if let pinnedView {
                pinnedView.setFrameOrigin(NSMakePoint(4, 4))
            }
           
            invisibleView?.center()
            
            if let selectionView {
                selectionView.frame = bounds.insetBy(dx: 3, dy: 3)
            }
            if let premiumSelectView {
                premiumSelectView.frame = bounds.insetBy(dx: 1, dy: 1)
            }
            
            if let imageView {
                imageView.centerX(y: 20)
                if let textView {
                    textView.centerX(y: frame.height - textView.frame.height - 20)
                }
            } else {
                textView?.centerX(y: sticker.frame.maxY + 5)
            }
            
            
            if let priceBadgeView {
                priceBadgeView.centerX(y: frame.height - priceBadgeView.frame.height - 10)
            }
        }
    }
    
    private let content = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(content)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? GiftOptionsRowItem else {
            return
        }
                
        
        let itemSize: NSSize
        if item.fitToSize, item.options.count == 1 {
            itemSize = NSMakeSize(content.frame.width - item.inset.right - item.inset.left, content.frame.height)
        } else {
            let insets = item.inset
            let count = item.fitToSize ? CGFloat(item.options.count) : 3
            let space = content.frame.width - insets.left - insets.right - (10 * CGFloat(count - 1))
            itemSize = NSMakeSize(floor(space / count), content.frame.height)
        }

        while self.content.subviews.count > item.options.count {
            self.content.subviews.last?.removeFromSuperview()
        }
        while self.content.subviews.count < item.options.count {
            self.content.addSubview(OptionView(frame: itemSize.bounds))
        }
        
        layout()
        
        for (i, subview) in content.subviews.enumerated() {
            let view = subview as? OptionView
            if view?.option?.gift?.id != item.options[i].gift?.id {
                if animated {
                    view?.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.35)
                }
            }
            view?.set(option: item.options[i], context: item.context, selected: item.options[i].gift == item.selected && item.selected != nil, animated: animated, callback: item.callback)
        }
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GiftOptionsRowItem else {
            return .clear
        }
        return item.viewType == .legacy ? .clear : super.backdorColor
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GiftOptionsRowItem else {
            return
        }
        
        content.frame = containerView.bounds.insetBy(dx: 0, dy: 0)
        
        let itemSize: NSSize
        if item.fitToSize, item.options.count == 1 {
            itemSize = NSMakeSize(content.frame.width - item.inset.right - item.inset.left, content.frame.height)
        } else {
            let insets = item.inset
            let count = item.fitToSize ? CGFloat(item.options.count) : CGFloat(item.perRowCount)
            let space = content.frame.width - insets.left - insets.right - (10 * CGFloat(count - 1))
            itemSize = NSMakeSize(floor(space / count), content.frame.height)
        }
        var x: CGFloat = item.inset.left

        for (i, subview) in content.subviews.enumerated() {
            let view = subview as? OptionView
            view?.setFrameSize(itemSize)
            subview.setFrameOrigin(x, 0)
            x += subview.frame.width + 10
        }
    }
}
