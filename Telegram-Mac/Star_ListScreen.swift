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

enum Star_TransactionType : Equatable {
    enum Source : Equatable {
        case peer
        case appstore
        case fragment
        case playmarket
        case premiumbot
        case unknown
        case ads
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
    let amount: Int64
    let date: Int32
    let name: String
    let peer: EnginePeer?
    let type: Star_TransactionType
    let native: StarsContext.State.Transaction
}


private final class FloatingHeaderView : Control {
    private let textView = TextView()
    private let balanceView = InteractiveTextView()
    fileprivate let dismiss = ImageButton()
    required init(frame frameRect: NSRect, source: Star_ListScreenSource, myBalance: Int64) {
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
        case .buy:
            text = strings().starListGetStars
        case let .purchase(_, requested):
            let need = Int(requested - myBalance)
            text = strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator)
        case .account:
            text = strings().starListTelegramStars
        }
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
    }
    
    func update(myBalance: Int64, context: AccountContext) {
        
        let balance = NSMutableAttributedString()
        balance.append(string: strings().starListMyBalance(clown, myBalance.formattedWithSeparator), color: theme.colors.text, font: .normal(.text))
        balance.detectBoldColorInString(with: .medium(.text))
        balance.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file, playPolicy: .onceEnd), for: clown)
        
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
    fileprivate let myBalance: Int64
    fileprivate let myBalanceLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let infoLayout: TextViewLayout
    fileprivate let buyMore: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, myBalance: Int64, viewType: GeneralViewType, buyMore: @escaping()->Void) {
        self.myBalance = myBalance
        self.context = context
        self.buyMore = buyMore
        
        let attr = NSMutableAttributedString()
        attr.append(string: myBalance.formattedWithSeparator, color: theme.colors.text, font: .medium(40))
        self.myBalanceLayout = .init(attr)
        self.myBalanceLayout.measure(width: .greatestFiniteMagnitude)
        
        self.infoLayout = .init(.initialize(string: strings().starListYourBalance, color: theme.colors.grayText, font: .normal(.header)))
        self.infoLayout.measure(width: .greatestFiniteMagnitude)
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        return 10 + myBalanceLayout.layoutSize.height + infoLayout.layoutSize.height + 10 + 40 + 20
    }
    
    override func viewClass() -> AnyClass {
        return BalanceView.self
    }
}

private final class BalanceView: GeneralContainableRowView {
    private let balance = InteractiveTextView()
    private let info = TextView()
    private let action = TextButton()
    private var star: InlineStickerView?
    private let container = View()
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
        
        if self.star == nil {
            let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency.file, size: NSMakeSize(item.myBalanceLayout.layoutSize.height - 4, item.myBalanceLayout.layoutSize.height - 4))
            self.star = view
            container.addSubview(view)
        }
        
        self.balance.set(text: item.myBalanceLayout, context: item.context)
        self.info.update(item.infoLayout)
        
        container.setFrameSize(container.subviewsWidthSize)
        
        action.set(font: .medium(.text), for: .Normal)
        action.set(color: theme.colors.underSelectedColor, for: .Normal)
        action.set(background: theme.colors.accent, for: .Normal)
        action.set(text: strings().starListBuyMoreStars, for: .Normal)
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
        
        action.frame = NSMakeRect(20, containerView.frame.height - 20 - 40, containerView.frame.width - 40, 40)
    }
}

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let balance: TextViewLayout
    fileprivate let header: TextViewLayout
    fileprivate let headerText: TextViewLayout
    fileprivate let dismiss: ()->Void
    fileprivate let source: Star_ListScreenSource
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, myBalance: Int64, source: Star_ListScreenSource, viewType: GeneralViewType, dismiss: @escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.source = source
        let balance = NSMutableAttributedString()
        balance.append(string: strings().starListMyBalance(clown, myBalance.formattedWithSeparator), color: theme.colors.text, font: .normal(.text))
        balance.detectBoldColorInString(with: .medium(.text))
        balance.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file, playPolicy: .onceEnd), for: clown)
        
        self.balance = .init(balance, alignment: .right)
        self.balance.measure(width: .greatestFiniteMagnitude)
        
        let headerAttr = NSMutableAttributedString()
        let headerInfo = NSMutableAttributedString()
        
        switch source {
        case .buy:
            headerAttr.append(string: strings().starListGetStars, color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starListHowMany, color: theme.colors.text, font: .normal(.text))
        case let .purchase(peer, requested):
            let need = Int(requested - myBalance)
            headerAttr.append(string: strings().starListStarsNeededCountable(need).replacingOccurrences(of: "\(need)", with: need.formattedWithSeparator), color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starListBuyAndUse(peer._asPeer().displayTitle), color: theme.colors.text, font: .normal(.text))
        case .account:
            headerAttr.append(string: strings().starListTelegramStars, color: theme.colors.text, font: .medium(.header))
            headerInfo.append(string: strings().starListBuyAndUserNobot, color: theme.colors.text, font: .normal(.text))
        }
        headerAttr.detectBoldColorInString(with: .medium(.header))
        headerInfo.detectBoldColorInString(with: .medium(.text))

        self.header = .init(headerAttr, alignment: .center)
        self.headerText = .init(headerInfo, alignment: .center)
        
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
    private let sceneView: GoldenStarSceneView
    private let dismiss = ImageButton()
    private let balance = InteractiveTextView()
    private let header = TextView()
    private let headerInfo = TextView()
    required init(frame frameRect: NSRect) {
        self.sceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, frameRect.width, 150))
        super.init(frame: frameRect)
        addSubview(sceneView)
        addSubview(dismiss)
        addSubview(balance)
        addSubview(header)
        addSubview(headerInfo)
        
        self.sceneView.sceneBackground = theme.colors.listBackground

        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        headerInfo.userInteractionEnabled = false
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
        
        balance.set(text: item.balance, context: item.context)
        balance.isHidden = item.source == .account

        header.update(item.header)
        headerInfo.update(item.headerText)
        
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        sceneView.centerX(y: 0)
        header.centerX(y: sceneView.frame.maxY - 20)
        headerInfo.centerX(y: header.frame.maxY + 10)
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
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency.file, size: NSMakeSize(20, 20))
                stars.addSubview(view)
            } else {
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_part.file, size: NSMakeSize(20, 20))
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
    let source: Star_ListScreenSource
    let reveal: ()->Void
    let openLink:(String)->Void
    let dismiss:()->Void
    let buyMore:()->Void
    let toggleFilterMode:(State.TransactionMode)->Void
    let buy:(State.Option)->Void
    let loadMore:()->Void
    let openTransaction:(Star_Transaction)->Void
    init(context: AccountContext, source: Star_ListScreenSource, reveal: @escaping()->Void, openLink:@escaping(String)->Void, dismiss:@escaping()->Void, buyMore:@escaping()->Void, toggleFilterMode:@escaping(State.TransactionMode)->Void, buy:@escaping(State.Option)->Void, loadMore:@escaping()->Void, openTransaction:@escaping(Star_Transaction)->Void) {
        self.context = context
        self.source = source
        self.reveal = reveal
        self.openLink = openLink
        self.dismiss = dismiss
        self.buyMore = buyMore
        self.toggleFilterMode = toggleFilterMode
        self.buy = buy
        self.loadMore = loadMore
        self.openTransaction = openTransaction
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
            return .init(count: amount, storeProductId: storeProduct?.id, currency: currency, amount: price)
        }
        
        
        var formattedPrice: String {
            if let storeProduct {
                return formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
            } else {
                return formatCurrencyAmount(price, currency: currency)
            }
        }
    }
    
    var myBalance: Int64? = nil
    var options: [Option]? = nil
    var transactions: [Star_Transaction]? = nil
    var revealed: Bool = false
    var transactionMode: TransactionMode = .all
    
    var premiumProducts: [InAppPurchaseManager.Product] = []
    var canMakePayment: Bool
    
    var starsState: StarsContext.State?

}

private let _id_header = InputDataIdentifier("_id_header")
private func _id_option(_ option: State.Option) -> InputDataIdentifier {
    return .init("_id_\(option.id)")
}
private func _id_transaction(_ transaction: Star_Transaction) -> InputDataIdentifier {
    return .init("_id_\(transaction.id)_\(transaction.type)")
}
private let _id_show_more = InputDataIdentifier("_id_show_more")
private let _id_balance = InputDataIdentifier("_id_balance")

private let _id_transaction_mode = InputDataIdentifier("_id_transaction_mode")
private let _id_empty_transactions = InputDataIdentifier("_id_empty_transactions")

private let _id_load_more = InputDataIdentifier("_id_load_more")
private let _id_loading = InputDataIdentifier("_id_loading")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let balance = state.myBalance {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, context: arguments.context, myBalance: balance, source: arguments.source, viewType: .legacy, dismiss: arguments.dismiss)
        }))
        
        switch arguments.source {
        case .buy, .purchase:
            
            struct Tuple : Equatable {
                let option: State.Option
                let viewType: GeneralViewType
            }
            
            var tuples: [Tuple] = []
            
            let alwaysShow: [Int64] = [15, 75, 250, 500, 1000, 2500]
            
            
            if var options = state.options {
                
                switch arguments.source {
                case let .purchase(_, amount):
                    let minumum = max(0, amount - (state.myBalance ?? 0))
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
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: .init(state.myBalance), comparable: nil, item: { initialSize, stableId in
                return BalanceItem(initialSize, stableId: stableId, context: arguments.context, myBalance: state.myBalance ?? 0, viewType: .singleItem, buyMore: arguments.buyMore)
            }))
            
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
                    if i == transactions.count - 1, state.starsState?.canLoadMore == true || state.starsState?.isLoading == true {
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
                    } else if state.starsState?.canLoadMore == true {
                        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: strings().starListTransactionsShowMore, color: theme.colors.accent, icon: theme.icons.chatSearchUp, viewType: .lastItem, action: arguments.loadMore, iconTextInset: 42)))
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
    case buy
    case purchase(EnginePeer, Int64)
    case account
}

func Star_ListScreen(context: AccountContext, source: Star_ListScreenSource) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    let paymentDisposable = MetaDisposable()
    actionsDisposable.add(paymentDisposable)
    let inAppPurchaseManager = context.inAppPurchaseManager
    
    let starsContext = context.starsContext
    
    starsContext.load(force: true)

    var canMakePayment: Bool = true
    #if APP_STORE || DEBUG
    canMakePayment = inAppPurchaseManager.canMakePayments
    #endif
    
    let initialState = State(options: nil, transactions: nil, canMakePayment: canMakePayment)
    
    
    
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
    
    actionsDisposable.add(starsContext.state.startStrict(next: { state in
        updateState { current in
            var current = current
            current.myBalance = state?.balance
            current.transactions = state?.transactions.map { value in
                let type: Star_TransactionType
                var botPeer: EnginePeer?
                let incoming: Bool = value.count > 0
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
                }
                if incoming {
                    type = .incoming(source)
                } else {
                    type = .outgoing(source)
                }
                return Star_Transaction(id: value.id, amount: value.count, date: value.date, name: "", peer: botPeer, type: type, native: value)
            }
            current.starsState = state
            return current
        }
    }))
    
    
    let buyNonStore:(State.Option)->Void = { option in
        
        let source: BotPaymentInvoiceSource = .stars(option: option.native)
        
        let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: source), for: window)

        _ = signal.start(next: { invoice in
            showModal(with: PaymentsCheckoutController(context: context, source: source, invoice: invoice, completion: { status in
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
        
        let purpose: AppStoreTransactionPurpose = .stars(count: option.amount, currency: storeProduct.priceCurrencyAndAmount.currency, amount: storeProduct.priceCurrencyAndAmount.amount)
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
                 |> deliverOnMainQueue).start(next: { [weak lockModal] available in
            if available {
                paymentDisposable.set((inAppPurchaseManager.buyProduct(storeProduct, purpose: purpose)
                |> deliverOnMainQueue).start(next: { [weak lockModal] status in

                    lockModal?.close()
                    needToShow = false
                    close?()
                    inAppPurchaseManager.finishAllTransactions()
                    
                    starsContext.add(balance: option.amount)
                    
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

    

    let arguments = Arguments(context: context, source: source, reveal: {
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
        showModal(with: Star_ListScreen(context: context, source: .buy), for: window)
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
    }, loadMore: {
        context.starsContext.loadMore()
    }, openTransaction: { transaction in
        showModal(with: Star_TransactionScreen(context: context, peer: transaction.peer, transaction: transaction.native), for: window)
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
    
    controller.contextObject = starsContext

    
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
        let myBalance = stateValue.with { $0.myBalance ?? 0 }
        let view = FloatingHeaderView(frame: NSMakeRect(0, 0, controller.frame.width, 50), source: source, myBalance: myBalance)
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



