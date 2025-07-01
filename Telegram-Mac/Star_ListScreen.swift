//
//  Star_ListScreen.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit
import CurrencyFormat
import InAppPurchaseManager
import Localization
enum Star_TransactionType : Equatable {
    enum Source : Equatable {
        case peer
        case appstore
        case fragment
        case playmarket
        case premiumbot
        case unknown
        case ads
        case apiLimitExtension
    }
    case incoming(Source)
    case outgoing(Source)
    
    var source: Source {
        switch self {
        case .incoming(let source):
            return source
        case .outgoing(let source):
            return source
        }
    }
    
}
struct Star_Transaction : Equatable {
    let id: String
    let currency: CurrencyAmount.Currency
    let amount: StarsAmount
    let date: Int32
    let name: String
    let peer: EnginePeer?
    let type: Star_TransactionType
    let native: StarsContext.State.Transaction
}

struct Star_Subscription : Equatable {
    enum State : Equatable {
        case active(refulfil: Bool)
        case cancelled(refulfil: Bool)
        case expired
    }
    let id: String
    let peer: EnginePeer
    let amount: StarsAmount
    let date: Int32
    let renewDate: Int32
    let state: State
    let native: StarsContext.State.Subscription
}


private final class FloatingHeaderView : Control {
    private let textView = TextView()
    private let balanceView = InteractiveTextView()
    fileprivate let dismiss = ImageButton()
    required init(frame frameRect: NSRect, currency: CurrencyAmount.Currency, source: Star_ListScreenSource, myBalance: StarsAmount) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(dismiss)
        addSubview(balanceView)
        
        backgroundColor = theme.colors.background
        border = [.Bottom]
        borderColor = theme.colors.border
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        let text: String
        switch source {
        case let .buy(suffix, amount):
            if let amount {
                let need = Int(amount - myBalance.value)
                text = strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator)
            } else {
                text = strings().starListGetStars
            }
            balanceView.isHidden = false
        case let .purchase(_, requested):
            let need = Int(requested - myBalance.value)
            text = strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator)
            balanceView.isHidden = false
        case let .purchaseSubscribe(_, requested):
            let need = Int(requested - myBalance.value)
            text = strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator)
            balanceView.isHidden = false
        case .account:
            switch currency {
            case .stars:
                text = strings().starListTelegramStars
            case .ton:
                text = TON
            }
            balanceView.isHidden = true
        case .reactions:
            text = strings().starListTelegramStars
            balanceView.isHidden = false
        case let .prolongSubscription(_, requested):
            let need = Int(requested - myBalance.value)
            text = strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator)
            balanceView.isHidden = false
        case .gift:
            text = strings().starsGiftTitle
            balanceView.isHidden = true
        }
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
    }
    
    func update(myBalance: StarsAmount, context: AccountContext) {
        
        let balance = NSMutableAttributedString()
        balance.append(string: strings().starListMyBalance(clown + TINY_SPACE, myBalance.value.formattedWithSeparator), color: theme.colors.text, font: .normal(.text))
        balance.detectBoldColorInString(with: .medium(.text))
        balance.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        
        let balanceLayout: TextViewLayout = .init(balance, alignment: .right)
        balanceLayout.measure(width: .greatestFiniteMagnitude)

        self.balanceView.set(text: balanceLayout, context: context)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.center()
        dismiss.centerY(x: 13)
        balanceView.centerY(x: frame.width - balanceView.frame.width - 13)
    }
}

private final class BalanceItem : GeneralRowItem {
    fileprivate let myBalance: StarsAmount
    fileprivate let myBalanceLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let infoLayout: TextViewLayout
    fileprivate let buyMore: ()->Void
    fileprivate let giftStars: ()->Void
    fileprivate let stats: ()->Void
    fileprivate let giftPremiumLayout: TextViewLayout?
    fileprivate let canWithdraw: Bool
    fileprivate let currency: CurrencyAmount.Currency
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, currency: CurrencyAmount.Currency, myBalance: StarsAmount, viewType: GeneralViewType, canWithdraw: Bool, buyMore: @escaping()->Void, giftStars: @escaping()->Void, stats: @escaping()->Void) {
        self.myBalance = myBalance
        self.currency = currency
        self.context = context
        self.buyMore = buyMore
        self.giftStars = giftStars
        self.stats = stats
        self.canWithdraw = canWithdraw
        let attr = NSMutableAttributedString()
        switch currency {
        case .stars:
            attr.append(string: myBalance.value.formattedWithSeparator, color: theme.colors.text, font: .medium(40))
        case .ton:
            attr.append(string: formatCurrencyAmount(myBalance.value, currency: TON).prettyCurrencyNumberUsd, color: theme.colors.text, font: .medium(40))
        }
        self.myBalanceLayout = .init(attr)
        self.myBalanceLayout.measure(width: .greatestFiniteMagnitude)
        
        let infoString: String
        switch currency {
        case .stars:
            infoString = strings().starListYourBalance
        case .ton:
            let usd_rate = context.appConfiguration.getGeneralValueDouble("ton_usd_rate", orElse: 3)
            let value = Double(formatCurrencyAmount(myBalance.value, currency: TON)) ?? 0
            infoString = "~\("\(value * usd_rate)".prettyCurrencyNumberUsd)$"
        }
        
        self.infoLayout = .init(.initialize(string: infoString, color: theme.colors.grayText, font: .normal(.header)))
        self.infoLayout.measure(width: .greatestFiniteMagnitude)
        
        
        switch currency {
        case .stars:
            let giftAttr = NSMutableAttributedString()
            giftAttr.append(string: strings().starsGiftToFriends(clown_space), color: theme.colors.accent, font: .normal(.title))
            giftAttr.insertEmbedded(.embedded(name: "Icon_Gift_Stars", color: theme.colors.accent, resize: false), for: clown)
            self.giftPremiumLayout = TextViewLayout(giftAttr)
        case .ton:
            self.giftPremiumLayout = nil
        }
        
        
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.giftPremiumLayout?.measure(width: blockWidth - 40)
        return true
    }
    
    override var height: CGFloat {
        
        var height: CGFloat = 10 + myBalanceLayout.layoutSize.height + infoLayout.layoutSize.height + 10
        
        if !actionIsHidden {
            height += 40 + 20
        }
        
        if let giftPremiumLayout {
            height += (giftPremiumLayout.layoutSize.height + 10)
        }
        return  height
    }
    
    override func viewClass() -> AnyClass {
        return BalanceView.self
    }
    
    var actionText: String {
        switch currency {
        case .ton:
            #if DEBUG || STABLE || BETA
            return "Add Funds via Fragment"
            #endif
            return ""
        default:
            return self.canWithdraw ? strings().starListTopUp : strings().starListBuyMoreStars
        }
    }
    
    var actionIsHidden: Bool {
        switch currency {
        case .ton:
            #if DEBUG || STABLE || BETA
            return false
            #endif
            return true
        case .stars:
            return false
        }
    }
    
    var currencyFile: TelegramMediaFile {
        switch currency {
        case .stars:
            return LocalAnimatedSticker.star_currency_new.file
        case .ton:
            return LocalAnimatedSticker.ton_logo.file
        }
    }
}

private final class BalanceView: GeneralContainableRowView {
    private let balance = InteractiveTextView()
    private let info = TextView()
    private let action = TextButton()
    private var withdrawAction: TextButton?
    private var star: InlineStickerView?
    private let container = View()
    private var giftStars: InteractiveTextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.addSubview(balance)
        addSubview(container)
        addSubview(info)
        addSubview(action)
        action.autohighlight = false
        action.scaleOnClick = true
        action.layer?.cornerRadius = 10
        
        balance.userInteractionEnabled = false
        info.userInteractionEnabled = false
        info.isSelectable = false
        
       
        
        action.set(handler: { [weak self] _ in
            if let item = self?.item as? BalanceItem {
                item.buyMore()
            }
        }, for: .Click)
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BalanceItem else {
            return
        }
        
        if let giftStars = item.giftPremiumLayout {
            let current: InteractiveTextView
            if let view = self.giftStars {
                current = view
            } else {
                current = InteractiveTextView(frame: giftStars.layoutSize.bounds)
                current.userInteractionEnabled = true
                current.scaleOnClick = true
                self.giftStars = current
                addSubview(current)
            }
            current.set(text: giftStars, context: item.context)
            
            current.setSingle(handler: { [weak self] _ in
                if let item = self?.item as? BalanceItem {
                    item.giftStars()
                }
            }, for: .Click)
            current.set(text: item.giftPremiumLayout, context: item.context)
            
        } else if let view = giftStars {
            performSubviewRemoval(view, animated: animated)
            self.giftStars = nil
        }
        
        
        
        if self.star == nil {
            let view = InlineStickerView(account: item.context.account, file: item.currencyFile, size: NSMakeSize(item.myBalanceLayout.layoutSize.height - 4, item.myBalanceLayout.layoutSize.height - 4))
            self.star = view
            container.addSubview(view)
        }
        
        self.balance.set(text: item.myBalanceLayout, context: item.context)
        self.info.update(item.infoLayout)
        
        container.setFrameSize(container.subviewsWidthSize)
        
        action.set(font: .medium(.text), for: .Normal)
        action.set(color: theme.colors.underSelectedColor, for: .Normal)
        action.set(background: theme.colors.accent, for: .Normal)
        action.set(text: item.actionText, for: .Normal)
        
        action.isHidden = item.actionIsHidden
        
        
        if item.canWithdraw {
            let current: TextButton
            if let view = self.withdrawAction {
                current = view
            } else {
                current = TextButton()
                addSubview(current)
                self.withdrawAction = current
            }
            
            current.set(font: .medium(.text), for: .Normal)
            current.set(color: theme.colors.underSelectedColor, for: .Normal)
            current.set(background: theme.colors.accent, for: .Normal)
            current.set(text: strings().starListWithdraw, for: .Normal)
            current.autohighlight = false
            current.scaleOnClick = true
            current.layer?.cornerRadius = 10
            
            current.setSingle(handler: { [weak item] _ in
                item?.stats()
            }, for: .Click)

        } else if let view = self.withdrawAction {
            performSubviewRemoval(view, animated: animated)
            self.withdrawAction = nil
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        container.centerX(y: 10)
        if let star {
            star.centerY(x: 0, addition: -3)
            balance.centerY(x: star.frame.maxX)
        }
        info.centerX(y: container.frame.maxY)
        
        var inset: CGFloat = 0
        if let giftStars {
            inset = giftStars.frame.height + 10
        }
        
        if let withdrawAction {
            let itemWidth = (containerView.frame.width - 40 - 10) / 2
            action.frame = NSMakeRect(20, containerView.frame.height - 20 - 40 - inset, itemWidth, 40)
            withdrawAction.frame = NSMakeRect(action.frame.maxX + 10, containerView.frame.height - 20 - 40 - inset, itemWidth, 40)
        } else {
            action.frame = NSMakeRect(20, containerView.frame.height - 20 - 40 - inset, containerView.frame.width - 40, 40)
        }
        
        
        if let giftStars {
            giftStars.centerX(y: containerView.frame.height - giftStars.frame.height - 15)
        }
    }
}

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let balance: TextViewLayout
    fileprivate let header: TextViewLayout
    fileprivate let headerText: TextViewLayout
    fileprivate let dismiss: ()->Void
    fileprivate let source: Star_ListScreenSource
    fileprivate let arguments: Arguments
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, currency: CurrencyAmount.Currency, myBalance: StarsAmount, source: Star_ListScreenSource, viewType: GeneralViewType, dismiss: @escaping()->Void, openRecommendedApps: @escaping()->Void, arguments: Arguments) {
        self.context = context
        self.dismiss = dismiss
        self.source = source
        self.arguments = arguments
        let balance = NSMutableAttributedString()
        balance.append(string: strings().starListMyBalance(clown + TINY_SPACE, myBalance.value.formattedWithSeparator), color: theme.colors.text, font: .normal(.text))
        balance.detectBoldColorInString(with: .medium(.text))
        switch currency {
        case .ton:
            balance.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: theme.colors.accent, playPolicy: .onceEnd), for: clown)
        case .stars:
            balance.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        }
        
        self.balance = .init(balance, alignment: .right)
        self.balance.measure(width: .greatestFiniteMagnitude)
        
        let headerAttr = NSMutableAttributedString()
        var headerInfo = NSMutableAttributedString()
        
        switch source {
        case let .buy(suffix, amount):
            if let amount {
                let need = Int(amount - myBalance.value)
                headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            } else {
                headerAttr.append(string: strings().starListGetStars, color: theme.colors.text, font: .medium(.header))
            }
            if let suffix {
                let suffixKey = "Star.Buy.Custom_\(suffix)"
                let text: String = _NSLocalizedString(suffixKey)
                if text == suffixKey {
                    headerInfo.append(string: strings().starListHowMany, color: theme.colors.text, font: .normal(.text))
                } else {
                    headerInfo.append(string: _NSLocalizedString("Star.Buy.Custom_\(suffix)"), color: theme.colors.text, font: .normal(.text))
                }
            } else {
                headerInfo.append(string: strings().starListHowMany, color: theme.colors.text, font: .normal(.text))
            }
        case let .purchase(peer, requested):
            let need = Int(requested - myBalance.value)
            headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starListBuyAndUse(peer._asPeer().displayTitle), color: theme.colors.text, font: .normal(.text))
        case .account:
            switch currency {
            case .stars:
                headerAttr.append(string: strings().starListTelegramStars, color: theme.colors.text, font: .medium(.header))
                headerInfo.append(string: strings().starListBuyAndUserNobot, color: theme.colors.text, font: .normal(.text))
            case .ton:
                headerAttr.append(string: strings().starListTon, color: theme.colors.text, font: .medium(.header))
                headerInfo.append(string: strings().starListTonInfo, color: theme.colors.text, font: .normal(.text))
            }
        case let .reactions(_, requested):
            let need = Int(requested - myBalance.value)
            headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starListBuyAndUserNobot, color: theme.colors.text, font: .normal(.text))
        case let .prolongSubscription(peer, requested):
            let need = Int(requested - myBalance.value)
            headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starBuyScreenProlongSubs(peer._asPeer().displayTitle), color: theme.colors.text, font: .normal(.text))
        case let .purchaseSubscribe(peer, requested):
            let need = Int(requested - myBalance.value)
            headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starBuyScreenPurschaseSub(peer._asPeer().displayTitle), color: theme.colors.text, font: .normal(.text))

        case let .gift(peer):
            headerAttr.append(string: strings().starsGiftTitle, color: theme.colors.text, font: .medium(.header))
            
            let text = strings().starBuyScreenGift(peer._asPeer().displayTitle)
            
            headerInfo = parseMarkdownIntoAttributedString(text, attributes: .init(body: .init(font: .normal(.text), textColor: theme.colors.text), link: .init(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { value in
                    openRecommendedApps()
                }))
            })).mutableCopy() as! NSMutableAttributedString
            
        }
        headerAttr.detectBoldColorInString(with: .medium(.header))
        headerInfo.detectBoldColorInString(with: .medium(.text))

        self.header = .init(headerAttr, alignment: .center)
        self.headerText = .init(headerInfo, alignment: .center)
        
        self.headerText.interactions = globalLinkExecutor
        
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        header.measure(width: width - 40)
        headerText.measure(width: width - 40)
        return true
    }
    
    override var height: CGFloat {
        return 150 + header.layoutSize.height + 10 + headerText.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
}

private final class HeaderView : GeneralContainableRowView {
    private var sceneView: (NSView & PremiumSceneView)!
    private let dismiss = ImageButton()
    private let balance = InteractiveTextView()
    private let header = TextView()
    private let headerInfo = TextView()
    
    private var avatarView: AvatarControl?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(balance)
        addSubview(header)
        addSubview(headerInfo)
        

        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        headerInfo.isSelectable = false
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.dismiss()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        switch item.arguments.currency {
        case .ton:
            if self.sceneView == nil {
                self.sceneView = PremiumDiamondSceneView(frame: NSMakeRect(0, 0, frame.width, 150))
                addSubview(sceneView)
                self.sceneView.sceneBackground = theme.colors.listBackground
            }
            (sceneView as? PremiumDiamondSceneView)?.initFallbackView(context: item.context)

        case .stars:
            if sceneView == nil {
                self.sceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, frame.width, 150))
                addSubview(sceneView)
                self.sceneView.sceneBackground = theme.colors.listBackground
            }

        }
        

        
        switch item.source {
        case let .gift(peer):
            (sceneView as? GoldenStarSceneView)?.hideStar()
            balance.isHidden = true
            let current: AvatarControl
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(20))
                current.setFrameSize(NSMakeSize(80, 80))
                self.avatarView = current
                addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: peer._asPeer())
            
        default:
            (sceneView as? GoldenStarSceneView)?.showStar()
            balance.isHidden = false
            if let avatarView {
                performSubviewRemoval(avatarView, animated: animated)
                self.avatarView = nil
            }
            balance.isHidden = item.source == .account
        }
        
        
        
        balance.set(text: item.balance, context: item.context)

        header.update(item.header)
        headerInfo.update(item.headerText)
        
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        sceneView.centerX(y: 0)
        header.centerX(y: sceneView.frame.maxY - 20)
        headerInfo.centerX(y: header.frame.maxY + 10)
        
        avatarView?.centerX(y: 30)
        
        balance.setFrameOrigin(NSMakePoint(frame.width - balance.frame.width - 13, floorToScreenPixels((50 - balance.frame.height) / 2)))
        dismiss.setFrameOrigin(NSMakePoint(13, floorToScreenPixels((50 - dismiss.frame.height) / 2)))
    }
}


private final class Star_Item : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let option: State.Option
    
    fileprivate let price: TextViewLayout
    fileprivate let textLayout: TextViewLayout
    
    fileprivate let starsCount: Int64
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, option: State.Option, viewType: GeneralViewType, action:@escaping()->Void) {
        self.context = context
        self.option = option
        self.price = .init(.initialize(string: option.formattedPrice, color: theme.colors.grayText, font: .normal(.text)))
        self.textLayout = .init(.initialize(string: strings().starListItemCountCountable(Int(option.amount)).replacingOccurrences(of: "\(option.amount)", with: option.amount.formattedWithSeparator), color: theme.colors.text, font: .medium(.text)))
        
        self.starsCount = min(5, (Int64(option.id) ?? 0) + 1)
        
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action)
        
        price.measure(width: .greatestFiniteMagnitude)
        textLayout.measure(width: .greatestFiniteMagnitude)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return Star_ItemView.self
    }
}

private final class Star_ItemView : GeneralContainableRowView {
    private let stars = View()
    private let textView = TextView()
    private let price = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(stars)
        addSubview(textView)
        addSubview(price)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        price.userInteractionEnabled = false
        price.isSelectable = false
        
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
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)

        stars.layer?.masksToBounds = false
        
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
        
        guard let item = item as? Star_Item else {
            return
        }
        
        textView.update(item.textLayout)
        price.update(item.price)
        
        while stars.subviews.count > item.starsCount {
            stars.subviews.last?.removeFromSuperview()
        }
        
        for i in Int64(stars.subviews.count) ..< item.starsCount {
            if i == 0 {
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(20, 20))
                stars.addSubview(view)
            } else {
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_part_new.file, size: NSMakeSize(20, 20))
                stars.addSubview(view)
            }
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        price.centerY(x: containerView.frame.width - price.frame.width - 10)
        stars.frame = NSMakeRect(10, 0, 20, containerView.frame.height)
        
        for (i, star) in stars.subviews.enumerated() {
            if i == 0 {
                star.centerY(x: 0)
            } else {
                star.centerY(x: CGFloat(i) * 3)
            }
        }
        
        textView.centerY(x: 10 + 20 + CGFloat(stars.subviews.count * 3) + 5)
    }
}

private final class TransactionTypesItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let items: [ScrollableSegmentItem]
    fileprivate let callback:(State.TransactionMode)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transactionMode: State.TransactionMode, viewType: GeneralViewType, callback:@escaping(State.TransactionMode)->Void) {
        self.context = context
        self.callback = callback
        
        let theme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.text, textFont: .normal(.text))
        
        var items: [ScrollableSegmentItem] = []
        items.append(.init(title: strings().starListTransactionsAll, index: 0, uniqueId: 0, selected: transactionMode == .all, insets: NSEdgeInsets(left: 10, right: 10), icon: nil, theme: theme, equatable: UIEquatable(transactionMode)))
        items.append(.init(title: strings().starListTransactionsIncoming, index: 1, uniqueId: 1, selected: transactionMode == .incoming, insets: NSEdgeInsets(left: 10, right: 10), icon: nil, theme: theme, equatable: UIEquatable(transactionMode)))
        items.append(.init(title: strings().starListTransactionsOutgoing, index: 2, uniqueId: 2, selected: transactionMode == .outgoing, insets: NSEdgeInsets(left: 10, right: 10), icon: nil, theme: theme, equatable: UIEquatable(transactionMode)))

        self.items = items
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return TransactionTypesView.self
    }
}

private final class TransactionTypesView: GeneralContainableRowView {
    fileprivate let segmentControl: ScrollableSegmentView
    required init(frame frameRect: NSRect) {
        self.segmentControl = ScrollableSegmentView(frame: NSMakeRect(0, 0, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(segmentControl)
        
        segmentControl.didChangeSelectedItem = { [weak self] selected in
            if let item = self?.item as? TransactionTypesItem {
                if selected.uniqueId == 0 {
                    item.callback(.all)
                } else if selected.uniqueId == 1 {
                    item.callback(.incoming)
                } else if selected.uniqueId == 2 {
                   item.callback(.outgoing)
                }
            }
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? TransactionTypesItem else {
            return
        }
        
        
        segmentControl.updateItems(item.items, animated: animated)
        needsLayout = true
    }
    
    override func layout() {
        segmentControl.frame = containerView.bounds
    }
}

private final class Arguments {
    let context: AccountContext
    let currency: CurrencyAmount.Currency
    let source: Star_ListScreenSource
    let reveal: ()->Void
    let openLink:(String)->Void
    let dismiss:()->Void
    let buyMore:()->Void
    let giftStars:()->Void
    let toggleFilterMode:(State.TransactionMode)->Void
    let buy:(State.Option)->Void
    let loadMoreTransactions:()->Void
    let loadMoreSubscriptions:()->Void
    let openTransaction:(Star_Transaction)->Void
    let openSubscription:(Star_Subscription)->Void
    let openRecommendedApps:()->Void
    let openAffiliate:()->Void
    let stats:()->Void
    init(context: AccountContext, currency: CurrencyAmount.Currency, source: Star_ListScreenSource, reveal: @escaping()->Void, openLink:@escaping(String)->Void, dismiss:@escaping()->Void, buyMore:@escaping()->Void, giftStars:@escaping()->Void, toggleFilterMode:@escaping(State.TransactionMode)->Void, buy:@escaping(State.Option)->Void, loadMoreTransactions:@escaping()->Void, loadMoreSubscriptions:@escaping()->Void, openTransaction:@escaping(Star_Transaction)->Void, openSubscription:@escaping(Star_Subscription)->Void, openRecommendedApps:@escaping()->Void, openAffiliate:@escaping()->Void, stats:@escaping()->Void) {
        self.context = context
        self.currency = currency
        self.source = source
        self.reveal = reveal
        self.openLink = openLink
        self.dismiss = dismiss
        self.buyMore = buyMore
        self.giftStars = giftStars
        self.toggleFilterMode = toggleFilterMode
        self.buy = buy
        self.loadMoreTransactions = loadMoreTransactions
        self.loadMoreSubscriptions = loadMoreSubscriptions
        self.openTransaction = openTransaction
        self.openSubscription = openSubscription
        self.openRecommendedApps = openRecommendedApps
        self.openAffiliate = openAffiliate
        self.stats = stats
    }
}

private struct State : Equatable {
        
    enum TransactionMode : Equatable {
        case all
        case incoming
        case outgoing
    }
    struct Option : Equatable {
        let amount: Int64
        let price: Int64
        let currency: String
        let id: String
        
        let storeProduct: InAppPurchaseManager.Product?
        
        var native: StarsTopUpOption {
            return .init(count: amount, storeProductId: storeProduct?.id, currency: currency, amount: price, isExtended: false)
        }
        
        
        var formattedPrice: String {
            if let storeProduct {
                return formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
            } else {
                return formatCurrencyAmount(price, currency: currency)
            }
        }
    }
    
    var myBalance: StarsAmount? = nil
    var options: [Option]? = nil
    var transactions: [Star_Transaction]? = nil
    var revealed: Bool = false
    var transactionMode: TransactionMode = .all
    
    var premiumProducts: [InAppPurchaseManager.Product] = []
    var canMakePayment: Bool
    
    var starsState: StarsContext.State?
    
    var subscriptions: [Star_Subscription] = []
    var revenueStats: StarsRevenueStats?

}

private let _id_header = InputDataIdentifier("_id_header")
private func _id_option(_ option: State.Option) -> InputDataIdentifier {
    return .init("_id_\(option.id)")
}
private func _id_transaction(_ transaction: Star_Transaction) -> InputDataIdentifier {
    return .init("_id_\(transaction.id)_\(transaction.type)")
}
private func _id_subscription(_ subscription: Star_Subscription) -> InputDataIdentifier {
    return .init("_id_\(subscription.peer.id.toInt64())_\(subscription.id)")
}


private let _id_show_more = InputDataIdentifier("_id_show_more")
private let _id_balance = InputDataIdentifier("_id_balance")

private let _id_transaction_mode = InputDataIdentifier("_id_transaction_mode")
private let _id_empty_transactions = InputDataIdentifier("_id_empty_transactions")

private let _id_load_more = InputDataIdentifier("_id_load_more")
private let _id_loading = InputDataIdentifier("_id_loading")

private let _id_loading_subs = InputDataIdentifier("_id_loading_subs")
private let _id_load_more_subs = InputDataIdentifier("_id_load_more_subs")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let balance = state.myBalance {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, context: arguments.context, currency: arguments.currency, myBalance: balance, source: arguments.source, viewType: .legacy, dismiss: arguments.dismiss, openRecommendedApps: arguments.openRecommendedApps, arguments: arguments)
        }))
        
        switch arguments.source {
        case .buy, .purchase, .prolongSubscription, .gift, .reactions, .purchaseSubscribe:
            
            struct Tuple : Equatable {
                let option: State.Option
                let viewType: GeneralViewType
            }
            
            var tuples: [Tuple] = []
            
            let alwaysShow: [Int64] = [15, 75, 250, 500, 1000, 2500]
            
            
            if var options = state.options {
                
                switch arguments.source {
                case let .purchase(_, amount):
                    let minumum = max(0, amount - (state.myBalance?.value ?? 0))
                    options.removeAll(where: {
                        $0.amount < minumum
                    })
                default:
                    break
                }
                
                let revealed = options.count < alwaysShow.count || state.revealed

                
                for option in options {
                    if revealed || alwaysShow.contains(option.amount) {
                        tuples.append(.init(option: option, viewType: .singleItem))
                    }
                }
                
                for tuple in tuples {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(tuple.option), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                        return Star_Item(initialSize, stableId: stableId, context: arguments.context, option: tuple.option, viewType: tuple.viewType, action: {
                            arguments.buy(tuple.option)
                        })
                    }))
                    if tuple != tuples.last {
                        entries.append(.sectionId(sectionId, type: .normal))
                        sectionId += 1
                    }
                }
              
                if !revealed {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                    
                    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_show_more, data: .init(name: strings().starListItemShowMore, color: theme.colors.accent, type: .image(NSImage(resource: .iconHorizontalChevron).precomposed(theme.colors.accent)), viewType: .singleItem, action: arguments.reveal)))
                }
            } else {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                    return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
                }))
            }
            
            
            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
            
            let text = strings().starListTos
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { link in
                arguments.openLink(link)
            }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem, centerViewAlignment: true, alignment: .center)))
            index += 1
        case .account:
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return BalanceItem(initialSize, stableId: stableId, context: arguments.context, currency: arguments.currency, myBalance: state.myBalance ?? .init(value: 0, nanos: 0), viewType: .singleItem, canWithdraw: state.revenueStats?.balances.withdrawEnabled == true && arguments.currency != .ton, buyMore: arguments.buyMore, giftStars: arguments.giftStars, stats: arguments.stats)
            }))
            
            let affiliateEnabled = arguments.context.appConfiguration.getBoolValue("starref_connect_allowed", orElse: false)
            
            if affiliateEnabled, arguments.currency == .stars {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("affiliate"), data: .init(name: strings().affilateProgramEarn, color: theme.colors.text, icon: NSImage(resource: .iconAffiliateEarnStars).precomposed(flipVertical: true), type: .next, viewType: .singleItem, description: strings().affilateProgramEarnInfo, descTextColor: theme.colors.grayText, action: arguments.openAffiliate, afterNameImage: generateTextIcon_NewBadge_Flipped(bgColor: theme.colors.accent, textColor: theme.colors.underSelectedColor))))
            }
            
            
            if !state.subscriptions.isEmpty, arguments.currency == .stars {
                
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                
                struct Tuple : Equatable {
                    let subscription: Star_Subscription
                    let viewType: GeneralViewType
                }
                var tuples: [Tuple] = []
                for (i, subscription) in state.subscriptions.enumerated() {
                    var viewType: GeneralViewType = bestGeneralViewType(state.subscriptions, for: i)
                    if i == state.subscriptions.count - 1, state.starsState?.canLoadMoreSubscriptions == true || state.starsState?.isLoading == true {
                        viewType = .innerItem
                    }
                    tuples.append(.init(subscription: subscription, viewType: viewType))
                }
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().starBuyScreenMySubs), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                index += 1

                
                for tuple in tuples {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_subscription(tuple.subscription), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                        return Star_SubscriptionRowItem(initialSize, stableId: stableId, context: arguments.context, viewType: tuple.viewType, subscription: tuple.subscription, callback: arguments.openSubscription)
                    }))
                }
                
                if state.starsState?.isLoading == true {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading_subs, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                        return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
                    }))
                } else if state.starsState?.canLoadMoreSubscriptions == true {
                    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more_subs, data: .init(name: strings().starListTransactionsShowMore, color: theme.colors.accent, icon: theme.icons.chatSearchUp, viewType: .lastItem, action: arguments.loadMoreSubscriptions, iconTextInset: 42)))
                }
            }
            
            if let transactions = state.transactions, !transactions.isEmpty {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                
                struct Tuple : Equatable {
                    let transaction: Star_Transaction
                    let viewType: GeneralViewType
                }
                
                let transactions = transactions.filter { transaction in
                    switch state.transactionMode {
                    case .all:
                        return true
                    case .incoming:
                        if case .incoming = transaction.type {
                            return true
                        } else {
                            return false
                        }
                    case .outgoing:
                        if case .outgoing = transaction.type {
                            return true
                        } else {
                            return false
                        }
                    }
                }
                
                var tuples: [Tuple] = []
                for (i, transaction) in transactions.enumerated() {
                    var viewType = bestGeneralViewTypeAfterFirst(transactions, for: i)
                    if i == transactions.count - 1, state.starsState?.canLoadMoreTransactions == true || state.starsState?.isLoading == true {
                        viewType = .innerItem
                    }
                    tuples.append(.init(transaction: transaction, viewType: viewType))
                }
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().starListTransactionsHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                index += 1
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction_mode, equatable: .init(state.transactionMode), comparable: nil, item: { initialSize, stableId in
                    return TransactionTypesItem(initialSize, stableId: stableId, context: arguments.context, transactionMode: state.transactionMode, viewType: .firstItem, callback: arguments.toggleFilterMode)
                }))
                
                if !transactions.isEmpty {
                    for tuple in tuples {
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(tuple.transaction), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                            return Star_TransactionItem(initialSize, stableId: stableId, context: arguments.context, viewType: tuple.viewType, transaction: tuple.transaction, callback: arguments.openTransaction)
                        }))
                    }
                    if state.starsState?.isLoading == true {
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
                        }))
                    } else if state.starsState?.canLoadMoreTransactions == true {
                        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: strings().starListTransactionsShowMore, color: theme.colors.accent, icon: theme.icons.chatSearchUp, viewType: .lastItem, action: arguments.loadMoreTransactions, iconTextInset: 42)))
                    }
                } else {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_empty_transactions, equatable: .init(state.transactionMode), comparable: nil, item: { initialSize, stableId in
                        let text: String
                        switch state.transactionMode {
                        case .all:
                            text = strings().starListTransactionsEmptyAll
                        case .incoming:
                            text = strings().starListTransactionsEmptyIncoming
                        case .outgoing:
                            text = strings().starListTransactionsEmptyOutgoing
                        }
                        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .lastItem, text: text, font: .normal(.text))
                    }))
                }
            }
        }
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return LoadingTableItem(initialSize, height: 200, stableId: stableId, backgroundColor: theme.colors.listBackground)
        }))
    }
    
    
    return entries
}

enum Star_ListScreenSource : Equatable {
    case buy(suffix: String?, amount: Int64?)
    case purchase(EnginePeer, Int64)
    case purchaseSubscribe(EnginePeer, Int64)
    case account
    case prolongSubscription(EnginePeer, Int64)
    case gift(EnginePeer)
    case reactions(EnginePeer, Int64)
}

func Star_ListScreen(context: AccountContext, currency: CurrencyAmount.Currency = .stars, source: Star_ListScreenSource) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    let paymentDisposable = MetaDisposable()
    actionsDisposable.add(paymentDisposable)
    let inAppPurchaseManager = context.inAppPurchaseManager
    
    let starsContext: StarsContext = context.currencyContext(currency)
    
    let starsSubscriptionsContext = context.starsSubscriptionsContext
    
    
    let transactions = context.engine.payments.peerStarsTransactionsContext(subject: .starsContext(starsContext), mode: .all)

    starsContext.load(force: true)
    starsSubscriptionsContext.load(force: true)
    
    var canMakePayment: Bool = true
    #if APP_STORE || DEBUG
    canMakePayment = inAppPurchaseManager.canMakePayments
    #endif
    
    
    
    let initialState = State(options: nil, transactions: nil, canMakePayment: canMakePayment, subscriptions: [])
    
    
    
    let products: Signal<[InAppPurchaseManager.Product], NoError>
    #if APP_STORE || DEBUG
    products = inAppPurchaseManager.availableProducts |> map {
        $0.filter { !$0.isSubscription }
    }
    #else
        products = .single([])
    #endif
    
    var close:(()->Void)? = nil
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    switch source {
    case let .gift(peer):
        actionsDisposable.add(combineLatest(context.engine.payments.starsGiftOptions(peerId: peer.id), products).startStrict(next: { value, products in
            let options:[State.Option] = value.compactMap { value in
                let product = products.first(where: { $0.id == value.storeProductId })
                return .init(amount: value.count, price: value.amount, currency: value.currency, id: "\(value.count)", storeProduct: product)
            }
            updateState { current in
                var current = current
                current.premiumProducts = products
                current.options = options
                return current
            }
        }))
    default:
        actionsDisposable.add(combineLatest(context.engine.payments.starsTopUpOptions(), products).startStrict(next: { value, products in
            
            let options:[State.Option] = value.compactMap { value in
                let product = products.first(where: { $0.id == value.storeProductId })
                return .init(amount: value.count, price: value.amount, currency: value.currency, id: "\(value.count)", storeProduct: product)
            }
            updateState { current in
                var current = current
                current.premiumProducts = products
                current.options = options
                return current
            }
        }))
    }
    
    
    let starsRevenue = context.engine.payments.peerStarsRevenueContext(peerId: context.peerId, ton: currency == .ton)
    
    actionsDisposable.add(combineLatest(starsContext.state, starsSubscriptionsContext.state, transactions.state, starsRevenue.state).startStrict(next: { state, subscriptionState, transactions, starsRevenue in
        updateState { current in
            var current = current
            current.myBalance = state?.balance
            current.revenueStats = starsRevenue.stats
            current.subscriptions = subscriptionState.subscriptions.map { value in
                let state: Star_Subscription.State
                if value.untilDate < context.timestamp, !value.flags.contains(.isCancelled) {
                    state = .expired
                } else {
                    if value.flags.contains(.isCancelled) {
                        state = .cancelled(refulfil: value.flags.contains(.canRefulfill))
                    } else {
                        state = .active(refulfil: value.flags.contains(.canRefulfill))
                    }
                }
                return .init(id: value.id, peer: value.peer, amount: value.pricing.amount, date: value.untilDate - value.pricing.period, renewDate: value.untilDate, state: state, native: value)
            }
            current.transactions = transactions.transactions.map { value in
                let type: Star_TransactionType
                var botPeer: EnginePeer?
                let incoming: Bool = value.count.amount.value > 0
                let source: Star_TransactionType.Source
                switch value.peer {
                case let .peer(peer):
                    source = .peer
                    botPeer = peer
                case .appStore:
                    source = .appstore
                case .fragment:
                    source = .fragment
                case .playMarket:
                    source = .playmarket
                case .premiumBot:
                    source = .premiumbot
                case .ads:
                    source = .ads
                case .unsupported:
                    source = .unknown
                case .apiLimitExtension:
                    source = .apiLimitExtension
                }
                if incoming {
                    type = .incoming(source)
                } else {
                    type = .outgoing(source)
                }
                return Star_Transaction(id: value.id, currency: value.count.currency, amount: value.count.amount, date: value.date, name: "", peer: botPeer, type: type, native: value)
            }
            current.starsState = state
            return current
        }
    }))
    
    
    let buyNonStore:(State.Option)->Void = { option in
        
        let invoiceSource: BotPaymentInvoiceSource
        switch source {
        case let .gift(peer):
            invoiceSource = .starsGift(peerId: peer.id, count: option.native.count, currency: option.native.currency, amount: option.native.amount)
        default:
            invoiceSource = .stars(option: option.native)
        }
        
        let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: invoiceSource), for: window)

        _ = signal.start(next: { invoice in
            showModal(with: PaymentsCheckoutController(context: context, source: invoiceSource, invoice: invoice, completion: { status in
                switch status {
                case .paid:
                    PlayConfetti(for: window, stars: true)
                    showModalText(for: window, text: strings().starListBuySuccessCountable(Int(option.amount)).replacingOccurrences(of: "\(option.amount)", with: option.amount.formattedWithSeparator))
                    close?()
                case .cancelled:
                    break
                case .failed:
                    break
                }
            }), for: window)
        }, error: { error in
            showModalText(for: window, text: strings().paymentsInvoiceNotExists)
        })
    }
    
    let buyAppStore:(State.Option)->Void = { option in
        
        let storeProduct = option.storeProduct

        guard let storeProduct = storeProduct else {
            buyNonStore(option)
            return
        }
        
        let lockModal = PremiumLockModalController()
        
        var needToShow = true
        delay(0.2, closure: {
            if needToShow {
                showModal(with: lockModal, for: window)
            }
        })
        
        let purpose: AppStoreTransactionPurpose
        switch source {
        case let .gift(peer):
            purpose = .starsGift(peerId: peer.id, count: option.native.count, currency: storeProduct.priceCurrencyAndAmount.currency, amount: storeProduct.priceCurrencyAndAmount.amount)
        default:
            purpose = .stars(count: option.amount, currency: storeProduct.priceCurrencyAndAmount.currency, amount: storeProduct.priceCurrencyAndAmount.amount)
        }
        
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
                 |> deliverOnMainQueue).start(next: { [weak lockModal] available in
            if available {
                paymentDisposable.set((inAppPurchaseManager.buyProduct(storeProduct, purpose: purpose)
                |> deliverOnMainQueue).start(next: { [weak lockModal] status in

                    lockModal?.close()
                    needToShow = false
                    close?()
                    inAppPurchaseManager.finishAllTransactions()
                    
                    
                    delay(0.2, closure: {
                        PlayConfetti(for: window, stars: true)
                        showModalText(for: window, text: strings().starListBuySuccessCountable(Int(option.amount)).replacingOccurrences(of: "\(option.amount)", with: option.amount.formattedWithSeparator))
                    })
                    
                }, error: { [weak lockModal] error in
                    let errorText: String
                    switch error {
                        case .generic:
                            errorText = strings().premiumPurchaseErrorUnknown
                        case .network:
                            errorText =  strings().premiumPurchaseErrorNetwork
                        case .notAllowed:
                            errorText =  strings().premiumPurchaseErrorNotAllowed
                        case .cantMakePayments:
                            errorText =  strings().premiumPurchaseErrorCantMakePayments
                        case .assignFailed:
                            errorText =  strings().premiumPurchaseErrorUnknown
                        case .cancelled:
                            errorText = strings().premiumBoardingAppStoreCancelled
                    }
                    lockModal?.close()
                    showModalText(for: window, text: errorText)
                    inAppPurchaseManager.finishAllTransactions()
                }))
            } else {
                lockModal?.close()
                needToShow = false
            }
        })
        
    }


    let arguments = Arguments(context: context, currency: currency, source: source, reveal: {
        updateState { current in
            var current = current
            current.revealed = !current.revealed
            return current
        }
    }, openLink: { link in
        execute(inapp: .external(link: link, false))
    }, dismiss: {
        close?()
    }, buyMore: {
        switch currency {
        case .stars:
            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: nil)), for: window)
        case .ton:
            execute(inapp: .external(link: strings().fragmentTonAddFundsLink, false))
        //    tonWithdrawal()
        }
    }, giftStars: {
        multigift(context: context, type: .stars)
    }, toggleFilterMode: { mode in
        updateState { current in
            var current = current
            current.transactionMode = mode
            return current
        }
    }, buy: { option in
        #if APP_STORE
        buyAppStore(option)
        #else
        buyNonStore(option)
        #endif
    }, loadMoreTransactions: {
        transactions.loadMore()
    }, loadMoreSubscriptions: {
        starsSubscriptionsContext.loadMore()
    }, openTransaction: { transaction in
        showModal(with: Star_TransactionScreen(context: context, fromPeerId: context.peerId, peer: transaction.peer, transaction: transaction.native, currency: transaction.currency), for: window)
    }, openSubscription: { subscription in
        showModal(with: Star_SubscriptionScreen(context: context, subscription: subscription), for: window)
    }, openRecommendedApps: {
        showModal(with: Star_AppExamples(context: context), for: window)
    }, openAffiliate: {
        close?()
        context.bindings.rootNavigation().push(Affiliate_PeerController(context: context, peerId: context.peerId))
    }, stats: { [weak starsRevenue] in
        context.bindings.rootNavigation().push(FragmentStarMonetizationController(context: context, peerId: context.peerId, revenueContext: starsRevenue))
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    controller.contextObject_second = (starsContext, starsRevenue)

    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(360, 300))
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.afterTransaction = { controller in
        let view = controller.contextObject as? FloatingHeaderView
        let myBalance = stateValue.with { $0.myBalance }
        if let myBalance {
            view?.update(myBalance: myBalance, context: context)
        }
    }
    
    
    controller.didLoad = { controller, _ in
        let myBalance = stateValue.with { $0.myBalance ?? .init(value: 0, nanos: 0) }
        let view = FloatingHeaderView(frame: NSMakeRect(0, 0, controller.frame.width, 50), currency: currency, source: source, myBalance: myBalance)
        view.layer?.opacity = 0
        controller.genericView.addSubview(view)
        controller.contextObject = view
        view.dismiss.set(handler: { _ in
            close?()
        }, for: .Click)
        
        view.update(myBalance: myBalance, context: context)
        
        controller.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak view] position in
            let height = view?.superview?.frame.height ?? 0
            view?.change(opacity: position.rect.minY > height ? 1 : 0, animated: true)
        }))
        
    }
    
    return modalController
}



