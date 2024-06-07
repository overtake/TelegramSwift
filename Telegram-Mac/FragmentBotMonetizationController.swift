//
//  FragmentBotMonetizationController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import CurrencyFormat
import InputView

private final class Arguments {
    let context: AccountContext
    let withdraw:()->Void
    let executeLink:(String)->Void
    let loadMore:()->Void
    let openTransaction:(Star_Transaction)->Void
    init(context: AccountContext, withdraw:@escaping()->Void, executeLink:@escaping(String)->Void, loadMore:@escaping()->Void, openTransaction:@escaping(Star_Transaction)->Void) {
        self.context = context
        self.withdraw = withdraw
        self.executeLink = executeLink
        self.loadMore = loadMore
        self.openTransaction = openTransaction
    }
}



private struct State : Equatable {

    enum TransactionType : Equatable {
        enum Source : Equatable {
            case bot
            case appstore
            case fragment
            case playmarket
            case premiumbot
            case unknown
        }
        case incoming(Source)
        case outgoing
    }
    struct Transaction : Equatable {
        let id: String
        let amount: Int64
        let date: Int32
        let name: String
        let peer: EnginePeer?
        let type: TransactionType
        let native: StarsContext.State.Transaction
    }
    
    struct Balance : Equatable {
        var stars: Int64
        var usdRate: Double
        
        var fractional: Double {
            return currencyToFractionalAmount(value: stars, currency: XTR) ?? 0
        }
        
        var usd: String {
            return "$" + "\(self.fractional * self.usdRate)".prettyCurrencyNumberUsd
        }
    }
    struct Overview : Equatable {
        var balance: Balance
        var last: Balance
        var all: Balance
    }
    
    var config_withdraw: Bool
    
    
    var overview: Overview = .init(balance: .init(stars: 0, usdRate: 0), last: .init(stars: 0, usdRate: 0), all: .init(stars: 0, usdRate: 0))
    var balance: Balance = .init(stars: 0, usdRate: 0)
    var transactions: [Star_Transaction] = []
    
    var starsState: StarsContext.State?
    
    var inputState: Updated_ChatTextInputState = .init()
    
    
    var withdrawError: RequestRevenueWithdrawalError? = nil
    
    var peer: EnginePeer? = nil
    
    var canWithdraw: Bool {
        return config_withdraw
    }
    
    var revenueGraph: StatsGraph?
    var topHoursGraph: StatsGraph?
    
}


private func _id_overview(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_overview_\(index)")
}
private func _id_transaction(_ id: String, type: Star_TransactionType) -> InputDataIdentifier {
    return InputDataIdentifier("_id_transaction\(id)_\(type)")
}

private let _id_balance = InputDataIdentifier("_id_balance")

private let _id_top_hours_graph = InputDataIdentifier("_id_top_hours_graph")
private let _id_revenue_graph = InputDataIdentifier("_id_revenue_graph")

private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_load_more = InputDataIdentifier("_id_load_more")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        struct Tuple : Equatable {
            let overview: Fragment_OverviewRowItem.Overview
            let viewType: GeneralViewType
        }
        
        let tuples: [Tuple] = [.init(overview: .init(amount: state.overview.balance.stars, usdAmount: state.overview.balance.usd, info: strings().monetizationOverviewAvailable), viewType: .firstItem),
                               .init(overview: .init(amount: state.overview.last.stars, usdAmount: state.overview.last.usd, info: strings().monetizationOverviewCurrent), viewType: .innerItem),
                               .init(overview: .init(amount: state.overview.all.stars, usdAmount: state.overview.all.usd, info: strings().monetizationOverviewTotal), viewType: .lastItem)]
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationOverviewTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for (i, tuple) in tuples.enumerated() {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_overview(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return Fragment_OverviewRowItem(initialSize, stableId: stableId, context: arguments.context, overview: tuple.overview, currency: .xtr, viewType: tuple.viewType)
            }))
        }
    }
    
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationBalanceTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return Fragment_BalanceRowItem(initialSize, stableId: stableId, context: arguments.context, balance: .init(amount: state.balance.stars, usd: state.balance.usd, currency: .xtr), canWithdraw: state.canWithdraw, viewType: .singleItem, transfer: arguments.withdraw)
        }))
        
        let text: String
        if state.config_withdraw {
            text = strings().monetizationBalanceInfo
        } else {
            text = strings().monetizationBalanceComingLaterInfo
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { link in
            arguments.executeLink(link)
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        
    }
    
    
    if !state.transactions.isEmpty, let starsState = state.starsState {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationTransactionsTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        struct Tuple : Equatable {
            let transaction: Star_Transaction
            let viewType: GeneralViewType
        }
        var tuples: [Tuple] = []
        for (i, transaction) in state.transactions.enumerated() {
            var viewType = bestGeneralViewType(state.transactions, for: i)
            if starsState.canLoadMore || starsState.isLoading {
                if i == state.transactions.count - 1 {
                    viewType = .innerItem
                }
            }
            tuples.append(.init(transaction: transaction, viewType: viewType))
        }
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(tuple.transaction.id, type: tuple.transaction.type), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return Star_TransactionItem(initialSize, stableId: stableId, context: arguments.context, viewType: tuple.viewType, transaction: tuple.transaction, callback: arguments.openTransaction)
            }))
        }
        
        if starsState.isLoading {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
                return LoadingTableItem(initialSize, height: 40, stableId: stableId, viewType: .lastItem)
            }))
        } else if starsState.canLoadMore {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: "Show More", color: theme.colors.accent, type: .none, viewType: .lastItem, action: arguments.loadMore)))
        }
    }
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FragmentBotMonetizationController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(config_withdraw: context.appConfiguration.getBoolValue("bot_revenue_withdrawal_enabled", orElse: true))

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    class ContextObject {
        let stars: StarsContext
        init(stars: StarsContext) {
            self.stars = stars
        }
    }
    
    let stars = context.engine.payments.peerStarsContext(peerId: peerId)

    let contextObject = ContextObject(stars: stars)
    
    
    actionsDisposable.add(contextObject.stars.state.startStrict(next: { state in
        if let state = state {
            updateState { current in
                var current = current
                current.balance = .init(stars: 120432, usdRate: 0.01)
                current.overview = .init(balance: .init(stars: 100, usdRate: 0.01), last: .init(stars: 150, usdRate: 0.01), all: .init(stars: 1234, usdRate: 0.01))
                current.starsState = state
                current.transactions = state.transactions.map { value in
                    let type: Star_TransactionType
                    var botPeer: EnginePeer?
                    let incoming: Bool = value.count > 0
                    switch value.peer {
                    case let .peer(peer):
                        if incoming {
                            type = .incoming(.bot)
                        } else {
                            type = .outgoing
                        }
                        botPeer = peer
                    case .appStore:
                        type = .incoming(.appstore)
                    case .fragment:
                        type = .incoming(.fragment)
                    case .playMarket:
                        type = .incoming(.playmarket)
                    case .premiumBot:
                        type = .incoming(.premiumbot)
                    case .unsupported:
                        type = .incoming(.unknown)
                    }
                    return Star_Transaction(id: value.id, amount: value.count, date: value.date, name: "", peer: botPeer, type: type, native: value)
                }
                return current
            }
        }
    }))

    let arguments = Arguments(context: context, withdraw: {
        showModal(with: withdraw(context: context, state: stateValue.with { $0 }, stateValue: statePromise.get(), updateState: updateState), for: context.window)
    }, executeLink: { link in
        execute(inapp: .external(link: link, false))
    }, loadMore: { [weak contextObject] in
        contextObject?.stars.loadMore()
    }, openTransaction: { transaction in
        showModal(with: Star_TransactionScreen(context: context, peer: transaction.peer, transaction: transaction.native), for: context.window)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Stars Balance", hasDone: false)
    
    controller.contextObject = contextObject
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}


private final class WithdrawHeaderItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let balance: TextViewLayout
    fileprivate let arguments: WithdrawArguments
    init(_ initialSize: NSSize, stableId: AnyHashable, balance: Int64, arguments: WithdrawArguments) {
        self.arguments = arguments
        self.titleLayout = .init(.initialize(string: "Withdraw", color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        let attr = NSMutableAttributedString()
        attr.append(string: "Balance:\n\(clown)\(balance)", color: theme.colors.text, font: .normal(.text))
        attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
        
        self.balance = .init(attr)
        self.balance.measure(width: .greatestFiniteMagnitude)
        
        self.titleLayout.measure(width: initialSize.width - self.balance.layoutSize.width - 40)
        
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return WithdrawHeaderView.self
    }
}

private final class WithdrawHeaderView : GeneralRowView {
    private let title = InteractiveTextView()
    private let balance = InteractiveTextView()
    private let dismiss = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(balance)
        addSubview(dismiss)
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? WithdrawHeaderItem {
                item.arguments.close()
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WithdrawHeaderItem else {
            return
        }
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        
        
        title.set(text: item.titleLayout, context: item.arguments.context)
        balance.set(text: item.balance, context: item.arguments.context)
        
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        
        title.center()
        balance.centerY(x: frame.width - balance.frame.width - 20)
        dismiss.centerY(x: 20)
    }
}

private final class WithdrawInputItem : GeneralRowItem {
    let inputState: Updated_ChatTextInputState
    let arguments: WithdrawArguments
    let interactions: TextView_Interactions
    let balance: Int64
    init(_ initialSize: NSSize, stableId: AnyHashable, balance: Int64, inputState: Updated_ChatTextInputState, arguments: WithdrawArguments) {
        self.inputState = inputState
        self.arguments = arguments
        self.balance = balance
        self.interactions = arguments.interactions
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 40 + 20 + 40
    }
    
    override func viewClass() -> AnyClass {
        return WithdrawInputView.self
    }
}


private final class WithdrawInputView : GeneralRowView {
    
    
    private final class AcceptView : Control {
        private let textView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            layer?.cornerRadius = 10
            scaleOnClick = true
            self.set(background: theme.colors.accent, for: .Normal)
            
            textView.userInteractionEnabled = false
        }
        
        func update(_ item: WithdrawInputItem, animated: Bool) {
            let attr = NSMutableAttributedString()
            
            attr.append(string: "Withdraw \("\(clown)\(item.inputState.inputText.string)")", color: theme.colors.underSelectedColor, font: .medium(.text))
            attr.insertEmbedded(.embedded(name: "Icon_Peer_Premium", color: theme.colors.underSelectedColor, resize: false), for: clown)
            
            let layout = TextViewLayout(attr)
            layout.measure(width: item.width - 60)
            
            textView.set(text: layout, context: item.arguments.context)
            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            textView.center()
        }
    }
    
    private final class LimitView : Control {
        private let iconView = InteractiveTextView()
        private let textView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(iconView)
            addSubview(textView)
            layer?.cornerRadius = 10
            scaleOnClick = true
            self.set(background: theme.colors.background, for: .Normal)
            
            textView.userInteractionEnabled = false
            iconView.userInteractionEnabled = false

        }
        
        func update(_ item: WithdrawInputItem, animated: Bool) {
            let attr = NSMutableAttributedString()
            
            attr.append(string: "You cannot withdraw less than 1000 Stars.", color: theme.colors.text, font: .medium(.text))
            let layout = TextViewLayout(attr)
            layout.measure(width: frame.width - 70)
            
            textView.set(text: layout, context: item.arguments.context)

            
            let iconAttr = NSMutableAttributedString()
            iconAttr.append(string: clown, color: theme.colors.text, font: .medium(.text))
            iconAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
            
            let iconLayout = TextViewLayout(iconAttr)
            iconLayout.measure(width: frame.width - 70)

            iconView.set(text: iconLayout, context: item.arguments.context)

            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            iconView.centerY(x: 10)
            textView.centerY(x: iconView.frame.maxX + 10)
        }
    }
    
    private final class WithdrawInput : View {
        
        private weak var item: WithdrawInputItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        private let starView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(starView)
            addSubview(inputView)
                        

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: WithdrawInputItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.background
            
            let attr = NSMutableAttributedString()
            attr.append(string: clown)
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
            
            let layout = TextViewLayout(attr)
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.starView.set(text: layout, context: item.arguments.context)

            
            inputView.placeholder = "Stars Amount"
            
            inputView.context = item.arguments.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            
            let value = Int64(item.inputState.string) ?? 0
            
            inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(value < 1000 ? theme.colors.redUI : theme.colors.text)
            
            
            item.interactions.filterEvent = { event in
                if let chars = event.characters {
                    return chars.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890\u{7f}")).isEmpty
                } else {
                    return false
                }
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
            let (textSize, textHeight) = textViewSize()
            
            transition.updateFrame(view: starView, frame: starView.centerFrameY(x: 10))
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: starView.frame.maxX + 10, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.arguments.updateState(state)
            
            item.redraw(animated: true)
        }
    }
    
    private let inputView = WithdrawInput(frame: NSMakeRect(0, 0, 40, 40))
    private var acceptView: AcceptView?
    private var limitView : LimitView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
    }
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WithdrawInputItem else {
            return
        }
        
        self.inputView.update(item: item, animated: animated)
        
        
        let value = Int64(item.inputState.string) ?? 0
        if value < 1000 {
            if let acceptView {
                performSubviewRemoval(acceptView, animated: animated)
                self.acceptView = nil
            }
            
            let current: LimitView
            if let view = self.limitView {
                current = view
            } else {
                current = LimitView(frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
                self.limitView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(item, animated: animated)
        } else {
            if let limitView {
                performSubviewRemoval(limitView, animated: animated)
                self.limitView = nil
            }
            let current: AcceptView
            if let view = self.acceptView {
                current = view
            } else {
                current = AcceptView(frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
                self.acceptView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? WithdrawInputItem {
                        item.arguments.withdraw()
                    }
                }, for: .Click)
            }
            current.update(item, animated: animated)
        }
        
        
        self.inputView.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func shakeView() {
        inputView.shake(beep: true)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(20, 0, size.width - 40,40))
        inputView.updateLayout(size: inputView.frame.size, transition: transition)
        
        if let acceptView {
            transition.updateFrame(view: acceptView, frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
        }
        if let limitView {
            transition.updateFrame(view: limitView, frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
        }
    }
    
}


private final class WithdrawArguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState: (Updated_ChatTextInputState)->Void
    let withdraw:()->Void
    let close:()->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState: @escaping(Updated_ChatTextInputState)->Void, withdraw:@escaping()->Void, close:@escaping()->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        self.withdraw = withdraw
        self.close = close
    }
}


private let _id_input = InputDataIdentifier("_id_input")

private func withdrawEntries(_ state: State, arguments: WithdrawArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WithdrawHeaderItem(initialSize, stableId: stableId, balance: state.balance.stars, arguments: arguments)
    }))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ENTER AMOUNT TO WITHDRAW"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WithdrawInputItem(initialSize, stableId: stableId, balance: state.balance.stars, inputState: state.inputState, arguments: arguments)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

private func withdraw(context: AccountContext, state: State, stateValue: Signal<State, NoError>, updateState:@escaping((State)->State)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
    
    let initialState: Updated_ChatTextInputState = .init(inputText: .initialize(string: "\(state.balance.stars)"))
    
    let interactions = TextView_Interactions(presentation: initialState)
    
    updateState { current in
        var current = current
        current.inputState = initialState
        return current
    }
        
    let arguments = WithdrawArguments(context: context, interactions: interactions, updateState: { [weak interactions] value in
        
        let number = Int64(value.string) ?? 0
        
        var value = value
        if number > state.balance.stars {
            let string = "\(state.balance.stars)"
            value = .init(inputText: .initialize(string: string), selectionRange: string.length..<string.length)
            getController?()?.proccessValidation(.fail(.fields([_id_input : .shake])))
        }
        
        interactions?.update { _ in
            return value
        }
        updateState { current in
            var current = current
            current.inputState = value
            return current
        }
    }, withdraw: {
        
    }, close: {
        close?()
    })
    
    let signal = stateValue |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: withdrawEntries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    
    return modalController
}

