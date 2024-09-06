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

struct PremiumPaymentOption : Equatable {
    var title: String
    var desc: String
    var total: String
    var discount: String?
    var months: Int32
    
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
}

final class GiftOptionsRowItem : GeneralRowItem {
    
    struct Option {
        enum TypeValue {
            case price(String)
            case stars(Int64)
        }
        struct Badge {
            let text: String
            let color: NSColor
        }
        let file: TelegramMediaFile
        let text: NSAttributedString?
        let type: TypeValue
        let badge: Badge?
        
        var nativePayment: PremiumPaymentOption?
        var nativeStarGift: PeerStarGift?
        
        static func initialize(_ option: PremiumPaymentOption) -> Option {
            return .init(file: option.media.file, text: option.text, type: .price(option.total), badge: option.discount.flatMap { .init(text: $0, color: theme.colors.redUI )}, nativePayment: option)
        }
        static func initialize(_ option: PeerStarGift) -> Option {
            //TODOLANG
            return .init(file: option.media, text: nil, type: .stars(option.stars), badge: option.limited ? .init(text: "limited", color: theme.colors.accent) : nil, nativeStarGift: option)
        }
        
        var height: CGFloat {
            switch type {
            case .price:
                return 160
            case .stars:
                return 125
            }
        }
    }
    
    fileprivate let options: [Option]
    fileprivate let context: AccountContext
    fileprivate let perRowCount: Int
    fileprivate let fitToSize: Bool
    
    fileprivate let callback:(Option)->Void
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, options: [Option], perRowCount: Int = 3, fitToSize: Bool = false, insets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 20), callback:@escaping(Option)->Void) {
        self.options = options.reversed()
        self.context = context
        self.callback = callback
        self.perRowCount = perRowCount
        self.fitToSize = fitToSize
        super.init(initialSize, stableId: stableId, inset: insets)
    }
    
    override func viewClass() -> AnyClass {
        return GiftOptionsRowView.self
    }
    
    override var height: CGFloat {
        return options[0].height
    }
}

private final class GiftOptionsRowView:  GeneralRowView {
    
    
    private class OptionView : Control {
        private let sticker = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 80, 80))
        private var textView: TextView?
        private var badgeView: ImageView?
        private var priceView: PriceView?
        private var starPriceView: StarPriceView?

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
            private let effect = StarsButtonEffectLayer()
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
            addSubview(sticker)
            
                        
            sticker.userInteractionEnabled = false
            
            backgroundColor = theme.colors.background
            
            layer?.cornerRadius = 10
            
            scaleOnClick = true
            set(handler: { _ in
                
            }, for: .Click)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(option: GiftOptionsRowItem.Option, context: AccountContext, callback:@escaping(GiftOptionsRowItem.Option)->Void) {
            
            self.setSingle(handler: { _ in
                callback(option)
            }, for: .Click)
            
            let parameters = ChatAnimatedStickerMediaLayoutParameters(playPolicy: .onceEnd, alwaysAccept: true, cache: .temporaryLZ4(.thumb), hidePlayer: false, media: option.file, shimmer: false, thumbAtFrame: 1)
            self.sticker.update(with: option.file, size: self.sticker.frame.size, context: context, table: nil, parameters: parameters, animated: false)
            
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
                let priceLayout = TextViewLayout(.initialize(string: string, color: theme.colors.accent, font: .medium(.text)))
                priceLayout.measure(width: .greatestFiniteMagnitude)
                current.backgroundColor = theme.colors.accent.withAlphaComponent(0.2)
                current.update(text: priceLayout)
                
            case .stars(let int64):
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
                let attr = NSMutableAttributedString()
                attr.append(string: "\(clown_space)\(int64)", color: GOLD, font: .medium(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
                let priceLayout = TextViewLayout(attr)
                priceLayout.measure(width: .greatestFiniteMagnitude)
                current.backgroundColor = GOLD.withAlphaComponent(0.2)
                current.update(text: priceLayout, context: context)
            }
            
            if let badge = option.badge {
                let current: ImageView
                if let view = self.badgeView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current, positioned: .below, relativeTo: self.sticker)
                    self.badgeView = current
                }
                current.image = generateGiftBadgeBackground(size: NSMakeSize(frame.width / 2, frame.width / 2), text: badge.text, color: badge.color)
                current.sizeToFit()
            } else if let view = badgeView {
                performSubviewRemoval(view, animated: false)
                self.badgeView = nil
            }

            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            sticker.centerX(y: 0)
            textView?.centerX(y: sticker.frame.maxY + 5)
            badgeView?.setFrameOrigin(frame.width / 2, 0)
            if let priceView {
                priceView.centerX(y: frame.height - priceView.frame.height - 10)
            }
            if let starPriceView {
                starPriceView.centerX(y: frame.height - starPriceView.frame.height - 10)
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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
            itemSize = NSMakeSize(frame.width - item.inset.right - item.inset.left, frame.height)
        } else {
            let insets = item.inset
            let count = CGFloat(item.options.count)
            let space = frame.width - insets.left - insets.right - (10 * CGFloat(item.options.count - 1))
            itemSize = NSMakeSize(floorToScreenPixels(space / count), frame.height)
        }

        while self.subviews.count > item.options.count {
            self.subviews.last?.removeFromSuperview()
        }
        while self.subviews.count < item.options.count {
            self.addSubview(OptionView(frame: itemSize.bounds))
        }
        
        for (i, subview) in subviews.enumerated() {
            let view = subview as? OptionView
            view?.setFrameSize(itemSize)
            view?.set(option: item.options[i], context: item.context, callback: item.callback)
        }
        
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        var x: CGFloat = item.inset.left
        for subview in subviews {
            subview.setFrameOrigin(x, 0)
            x += subview.frame.width + 10
        }
    }
}
