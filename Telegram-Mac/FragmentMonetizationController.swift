//
//  FragmentMonetizationController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit
import CurrencyFormat
import InputView


private func insertSymbolIntoMiddle(of string: String, with symbol: Character) -> String {
    var modifiedString = string
    let middleIndex = modifiedString.index(modifiedString.startIndex, offsetBy: modifiedString.count / 2)
    modifiedString.insert(contentsOf: [symbol], at: middleIndex)
    return modifiedString
}


private extension String {
    var pretty: String {
        let range = self.nsstring.range(of: ".")
        if range.location != NSNotFound {
            return self.nsstring.substring(to: min(range.location + 3, self.length))
        }
        return self
    }
}

private extension NSAttributedString {
    var smallDecemial: NSAttributedString {
        let range = self.string.nsstring.range(of: ".")
        if range.location != NSNotFound {
            let attr = self.mutableCopy() as! NSMutableAttributedString
            
            let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            if let font = font, let updated = NSFont(name: font.fontName, size: font.pointSize / 1.5) {
                attr.addAttribute(.font, value: updated, range: NSMakeRange(range.location, attr.range.length - range.lowerBound))
            }
            return attr

        } else {
            return self
        }
        
    }
}

private final class TransactionRowItem : GeneralRowItem {
    let context: AccountContext
    let transaction: State.Transaction
    let title: TextViewLayout
    let address: TextViewLayout?
    let date: TextViewLayout
    let amount: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: State.Transaction, viewType: GeneralViewType) {
        self.context = context
        self.transaction = transaction
        
        let titleText: String
        switch transaction.source {
        case .incoming:
            titleText = "Proceeds from Ads"
        case .withdraw:
            titleText = "Balance Withdrawal to"
        }
        
        self.title = .init(.initialize(string: titleText, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        
        switch transaction.source {
        case .incoming:
            address = nil
        case var .withdraw(wallet):
            wallet = insertSymbolIntoMiddle(of: wallet, with: "\n")
            address = .init(.initialize(string: wallet, color: theme.colors.text, font: .code(.text)))
        }
        self.date = .init(.initialize(string: stringForFullDate(timestamp: transaction.date), color: theme.colors.grayText, font: .normal(.text)))
        
        let amountAttr = NSMutableAttributedString()
        let justAmount = NSAttributedString.initialize(string: formatCurrencyAmount(transaction.amount, currency: "TON").pretty, color: theme.colors.text, font: .medium(.header)).smallDecemial
        amountAttr.append(justAmount)
        amountAttr.append(string: " TON", color: theme.colors.text, font: .medium(.header))
        switch transaction.source {
        case .incoming:
            amountAttr.insert(.initialize(string: "+", font: .medium(.header)), at: 0)
            amountAttr.addAttribute(.foregroundColor, value: theme.colors.greenUI, range: amountAttr.range)
        case .withdraw:
            amountAttr.insert(.initialize(string: "-", font: .medium(.header)), at: 0)
            amountAttr.addAttribute(.foregroundColor, value: theme.colors.redUI, range: amountAttr.range)
        }
        
        self.amount = .init(amountAttr)
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.amount.measure(width: blockWidth)
        self.title.measure(width: blockWidth - self.amount.layoutSize.width - viewType.innerInset.left - viewType.innerInset.right)
        self.date.measure(width: blockWidth - self.amount.layoutSize.width - viewType.innerInset.left - viewType.innerInset.right)
        self.address?.measure(width: blockWidth - self.amount.layoutSize.width - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return TransactioRowView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        
        height += viewType.innerInset.top
        height += title.layoutSize.height
        height += 3
        if let address {
            height += address.layoutSize.height
            height += 3
        }
        height += date.layoutSize.height
        
        height += viewType.innerInset.bottom
        return height
    }
}

private final class TransactioRowView : GeneralContainableRowView {
    private let titleView = TextView()
    private let dateView = TextView()
    private let amountView = TextView()
    private var addressView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(dateView)
        addSubview(amountView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        
        amountView.userInteractionEnabled = false
        amountView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? TransactionRowItem else {
            return
        }
        
        titleView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        
        var dateY: CGFloat = titleView.frame.maxY + 3
        if let addressView {
            addressView.setFrameOrigin(NSMakePoint(titleView.frame.minX, titleView.frame.maxY + 3))
            dateY = addressView.frame.maxY + 3
        }
        dateView.setFrameOrigin(NSMakePoint(titleView.frame.minX, dateY))
        
        amountView.centerY(x: containerView.frame.width - amountView.frame.width - item.viewType.innerInset.right)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? TransactionRowItem else {
            return
        }
        
        titleView.update(item.title)
        amountView.update(item.amount)
        dateView.update(item.date)
        
        if let address = item.address {
            let current: TextView
            if let view = self.addressView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                addSubview(current)
                self.addressView = current
            }
            current.update(address)
        } else if let view = self.addressView {
            performSubviewRemoval(view, animated: animated)
            self.addressView = nil
        }
        
        needsLayout = true
    }
}

private final class OverviewRowItem : GeneralRowItem {
    
    struct Overview: Equatable {
        let tonAmount: Int64
        let usdAmount: Int64
        let info: String
    }
    
    let context: AccountContext
    
    let overview: Overview
    
    let amount: TextViewLayout
    let info: TextViewLayout
    
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, overview: Overview, viewType: GeneralViewType) {
        self.context = context
        self.overview = overview
        
                
        let amountAttr = NSMutableAttributedString()
        let justAmount = NSAttributedString.initialize(string: formatCurrencyAmount(overview.tonAmount, currency: "TON").pretty, color: theme.colors.text, font: .medium(.header)).smallDecemial
        amountAttr.append(justAmount)
        amountAttr.append(string: " ~", color: theme.colors.grayText, font: .normal(.text))
        
        let justAmount2 = NSAttributedString.initialize(string: formatCurrencyAmount(overview.usdAmount, currency: "USD").pretty, color: theme.colors.grayText, font: .normal(.text)).smallDecemial
        amountAttr.append(justAmount2)

        self.amount = .init(amountAttr)
        
        self.info = .init(.initialize(string: overview.info, color: theme.colors.grayText, font: .normal(.text)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        amount.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 22)
        info.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return OverviewRowView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += viewType.innerInset.top
        height += amount.layoutSize.height
        height += 2
        height += info.layoutSize.height
        
        height += viewType.innerInset.bottom
        return height
    }
}

private final class OverviewRowView : GeneralContainableRowView {
    private let amountView = TextView()
    private let infoView = TextView()
    private let icon = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 20, 20))

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(amountView)
        addSubview(infoView)
        addSubview(icon)
        
        amountView.userInteractionEnabled = false
        amountView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        guard let item = item as? OverviewRowItem else {
            return
        }
        icon.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top - 3))
        amountView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left + 22, item.viewType.innerInset.top))
        infoView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, amountView.frame.maxY + 2))
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? OverviewRowItem else {
            return
        }
        
        icon.update(with: LocalAnimatedSticker.brilliant_static.file, size: icon.frame.size, context: item.context, table: item.table, parameters: LocalAnimatedSticker.brilliant_static.parameters, animated: animated)
        
        amountView.update(item.amount)
        infoView.update(item.info)
    }
}

private final class BalanceRowItem : GeneralRowItem {
    let context: AccountContext
    let tonBalance: TextViewLayout
    let usdBalance: TextViewLayout
    let balance: State.Balance
    
    fileprivate let interactions: TextView_Interactions
    fileprivate let updateState:(Updated_ChatTextInputState)->Void

    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, balance: State.Balance, viewType: GeneralViewType, interactions: TextView_Interactions, updateState:@escaping(Updated_ChatTextInputState)->Void, transfer:@escaping()->Void) {
        self.context = context
        self.balance = balance
        self.interactions = interactions
        self.updateState = updateState
        
        let tonBalance = NSAttributedString.initialize(string: formatCurrencyAmount(balance.ton, currency: "TON").pretty, color: theme.colors.text, font: .medium(40)).smallDecemial
        let usdBalance = NSAttributedString.initialize(string: "~" + formatCurrencyAmount(balance.usd, currency: "USD").pretty, color: theme.colors.grayText, font: .normal(.text)).smallDecemial

        self.tonBalance = .init(tonBalance)
        self.usdBalance = .init(usdBalance)

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var withdrawText: String {
        return "Transfer \(formatCurrencyAmount(balance.ton, currency: "TON").pretty) TON"
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.tonBalance.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        self.usdBalance.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return BalanceRowView.self
    }
    
    var inputHeight: CGFloat {
        let attr = NSMutableAttributedString()
        attr.append(self.interactions.presentation.inputText)
        let str: NSMutableAttributedString = .init()
        attr.addAttribute(.font, value: NSFont.normal(.text), range: attr.range)
        let size = attr.sizeFittingWidth(blockWidth - viewType.innerInset.left - viewType.innerInset.right - 20)
        return max(40, size.height + 24)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += viewType.innerInset.top
        
        height += 46
        height -= 3
        height += usdBalance.layoutSize.height
        
        
        if balance.ton > 0 {
            height += viewType.innerInset.top
            height += 40
            
            height += viewType.innerInset.top * 2
            height += inputHeight
        }
        
        height += viewType.innerInset.left
        return height
    }
}

private final class BalanceRowView : GeneralContainableRowView {
    
    
    private final class WithdrawInput : View {
        
        private weak var item: BalanceRowItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(inputView)
                        
            inputView.placeholder = "Enter your TON address"

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: BalanceRowItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.grayForeground.withAlphaComponent(0.6)
            
            
            inputView.context = item.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            

            
            
            item.interactions.filterEvent = { event in
                return true
            }

            self.inputView.set(item.interactions.presentation.textInputState())

            self.inputView.interactions = item.interactions
            
            item.interactions.inputDidUpdate = { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.set(state)
                self.inputDidUpdateLayout(animated: true)
            }
            
        }
        
        
        var textWidth: CGFloat {
            return frame.width - 20
        }
        
        func textViewSize() -> (NSSize, CGFloat) {
            let w = textWidth
            let height = inputView.height(for: w)
            return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
        }
        
        private func inputDidUpdateLayout(animated: Bool) {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            guard let item else {
                return
            }
            
            let (textSize, textHeight) = textViewSize()
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: 10, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.updateState(state)
            
            item.redraw(animated: true)
        }
        

    }
    
    private let tonBalanceView = TextView()
    private let tonBalanceContainer = View()
    private let tonView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 46, 46))
    private let usdBalanceView = TextView()
    
    private var withdrawAction: TextButton?
    private var withdrawInput: WithdrawInput?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tonBalanceContainer.addSubview(tonView)
        tonBalanceContainer.addSubview(tonBalanceView)
        addSubview(tonBalanceContainer)
        addSubview(usdBalanceView)
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? BalanceRowItem else {
            return
        }
        
        transition.updateFrame(view: tonBalanceContainer, frame: tonBalanceContainer.centerFrameX(y: item.viewType.innerInset.top))
        transition.updateFrame(view: tonView, frame: tonView.centerFrameY(x: 0, addition: -3))
        transition.updateFrame(view: tonBalanceView, frame: tonBalanceView.centerFrameY(x: tonView.frame.maxX))

        
        transition.updateFrame(view: usdBalanceView, frame: usdBalanceView.centerFrameX(y: tonBalanceContainer.frame.maxY - 4))
        
        var withdrawY: CGFloat = containerView.frame.height - item.viewType.innerInset.left
        
        if let withdrawAction {
            withdrawY -= withdrawAction.frame.height
            transition.updateFrame(view: withdrawAction, frame: CGRect(origin: NSMakePoint(item.viewType.innerInset.left, withdrawY), size: withdrawAction.frame.size))
            withdrawY -= item.viewType.innerInset.left
        }
        if let withdrawInput {
            withdrawY -= withdrawInput.frame.height
            transition.updateFrame(view: withdrawInput, frame: CGRect(origin: NSMakePoint(item.viewType.innerInset.left, withdrawY), size: NSMakeSize(containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, item.inputHeight)))
            withdrawInput.updateLayout(size: withdrawInput.frame.size, transition: transition)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BalanceRowItem else {
            return
        }
        
        usdBalanceView.update(item.usdBalance)
        tonBalanceView.update(item.tonBalance)
        tonView.update(with: LocalAnimatedSticker.brilliant_static.file, size: tonView.frame.size, context: item.context, table: item.table, parameters: LocalAnimatedSticker.brilliant_static.parameters, animated: animated)
        
        tonBalanceContainer.setFrameSize(tonBalanceContainer.subviewsWidthSize)

        if item.balance.ton > 0 {
            let currentAction: TextButton
            if let withdrawAction {
                currentAction = withdrawAction
            } else {
                currentAction = TextButton()
                currentAction.scaleOnClick = true
                currentAction.autohighlight = false
                currentAction.set(font: .medium(.text), for: .Normal)
                addSubview(currentAction)
                self.withdrawAction = currentAction
            }
            
            let blockWidth = item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right
            
            currentAction.set(color: theme.colors.underSelectedColor, for: .Normal)
            currentAction.set(background: theme.colors.accent, for: .Normal)
            currentAction.layer?.cornerRadius = 10
            currentAction.set(text: item.withdrawText, for: .Normal)
            currentAction.sizeToFit(.zero, NSMakeSize(blockWidth, 40), thatFit: true)
            
            
            let currentInput: WithdrawInput
            if let withdrawInput {
                currentInput = withdrawInput
            } else {
                currentInput = WithdrawInput(frame: NSMakeRect(0, 0, blockWidth, item.inputHeight))
                addSubview(currentInput)
                self.withdrawInput = currentInput
            }
            currentInput.update(item: item, animated: animated)
            
        } else {
            if let withdrawInput {
                performSubviewRemoval(withdrawInput, animated: animated)
                self.withdrawInput = nil
            }
            if let withdrawAction {
                performSubviewRemoval(withdrawAction, animated: animated)
                self.withdrawAction = nil
            }
        }
        
        updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override var firstResponder: NSResponder? {
        return withdrawInput?.inputView.inputView
    }
}

private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState:(Updated_ChatTextInputState)->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState:@escaping(Updated_ChatTextInputState)->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
    }
}

private struct State : Equatable {

    struct Transaction : Equatable {
        enum Source : Equatable {
            case incoming
            case withdraw(String)
        }
        let date: Int32
        let source: Source
        let amount: Int64
        let uniqueId: Int64
    }
    struct Balance : Equatable {
        var ton: Int64
        var usd: Int64
    }
    struct Overview : Equatable {
        let balance: Balance
        let last: Balance
        let all: Balance
    }
    
    
    var overview: Overview
    var balance: Balance
    var transactions: [Transaction]
    
}

private let _id_overview = InputDataIdentifier("_id_overview")
private let _id_balance = InputDataIdentifier("_id_balance")
private let _id_transaction = InputDataIdentifier("_id_transaction")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
        
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        struct Tuple : Equatable {
            let overview: OverviewRowItem.Overview
            let viewType: GeneralViewType
        }
        
        let tuples: [Tuple] = [.init(overview: .init(tonAmount: state.overview.balance.ton, usdAmount: state.overview.balance.usd, info: "Balance Available to Withdraw"), viewType: .firstItem),
                               .init(overview: .init(tonAmount: state.overview.last.ton, usdAmount: state.overview.last.usd, info: "Proceeds Since Last Withdrawal"), viewType: .innerItem),
                               .init(overview: .init(tonAmount: state.overview.all.ton, usdAmount: state.overview.all.usd, info: "Total Lifetime Proceeds"), viewType: .lastItem)]
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("PROCEEDS OVERVIEW"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_overview, equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return OverviewRowItem(initialSize, stableId: stableId, context: arguments.context, overview: tuple.overview, viewType: tuple.viewType)
            }))
        }
        
    }
    
    
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("AVAILABLE BALANCE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return BalanceRowItem(initialSize, stableId: stableId, context: arguments.context, balance: state.balance, viewType: .singleItem, interactions: arguments.interactions, updateState: arguments.updateState, transfer: {
                
            })
        }))
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("We will transfer your balance to the TON wallet address you specify. [Learn More >]()", linkHandler: { _ in
            
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }

    
       
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("TRANSACTION HISTORY"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        struct Tuple : Equatable {
            let transaction: State.Transaction
            let viewType: GeneralViewType
        }
        var tuples: [Tuple] = []
        for (i, transaction) in state.transactions.enumerated() {
            tuples.append(.init(transaction: transaction, viewType: bestGeneralViewType(state.transactions, for: i)))
        }
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction, equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return  TransactionRowItem(initialSize, stableId: stableId, context: arguments.context, transaction: tuple.transaction, viewType: tuple.viewType)
            }))
        }
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FragmentMonetizationController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(overview: .init(balance: .init(ton: 10000000000, usd: 1000), last: .init(ton: 10000000000, usd: 100), all: .init(ton: 10000000000, usd: 10000)), balance: .init(ton: 10000000000, usd: 10000), transactions: [.init(date: Int32(Date().timeIntervalSince1970), source: .incoming, amount: 10000000000, uniqueId: arc4random64()), .init(date: Int32(Date().timeIntervalSince1970), source: .withdraw("UQCMOXxD-f8LSWWbXQowKxqTr3zMY-X1wMTyWp3B-LR6syif"), amount: 10000000000, uniqueId: arc4random64())])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let textInteractions = TextView_Interactions()

    
    textInteractions.processEnter = { event in
        return false
    }
    textInteractions.processAttriburedCopy = { attributedString in
        return globalLinkExecutor.copyAttributedString(attributedString)
    }
    textInteractions.processPaste = { pasteboard in
        if let data = pasteboard.data(forType: .kInApp) {
            let decoder = AdaptedPostboxDecoder()
            if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                let state = decoded.unique(isPremium: true)
                textInteractions.update { _ in
                    return textInteractions.insertText(state.attributedString())
                }
                return true
            }
        }
        return false
    }

    let arguments = Arguments(context: context, interactions: textInteractions, updateState: { state in
        textInteractions.update { _ in
            return state
        }
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Monetization", hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
