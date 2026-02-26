//
//  EditPostSuggestionController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.06.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import InputView
import TelegramCore
import Postbox
import CurrencyFormat

private final class SegmentItem : GeneralRowItem {
    fileprivate let currency: CurrencyAmount.Currency
    fileprivate let callback:(CurrencyAmount.Currency)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, currency: CurrencyAmount.Currency, callback:@escaping(CurrencyAmount.Currency)->Void) {
        self.callback = callback
        self.currency = currency
        super.init(initialSize, stableId: stableId)
    }
    
    var selectedIndex: Int {
        return currency == .stars ? 0 : 1
    }
    
    override func viewClass() -> AnyClass {
        return SegmentItemView.self
    }
    
    override var height: CGFloat {
        return 30
    }
}

private final class SegmentItemView : GeneralRowView {
    fileprivate let segmentControl: CatalinaStyledSegmentController

    required init(frame frameRect: NSRect) {
        self.segmentControl = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(frame: frameRect)
      
        let items: [CatalinaSegmentedItem] = [.init(title: strings().editPostSuggestionCurrencyStars, handler: { [weak self] in
            if let item = self?.item as? SegmentItem  {
                item.callback(.stars)
            }
        }), .init(title: strings().editPostSuggestionCurrencyTon, handler: { [weak self] in
            if let item = self?.item as? SegmentItem  {
                item.callback(.ton)
            }
        })]
        
        segmentControl.set(items: items)
        
        addSubview(segmentControl.view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SegmentItem else {
            return
        }
        
        segmentControl.set(selected: item.selectedIndex, animated: animated)
        segmentControl.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.background, foregroundColor: theme.colors.listBackground, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)
    }
    
    override func layout() {
        super.layout()
        
        segmentControl.view.center()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
}


private final class HeaderItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let balance: TextViewLayout
    fileprivate let arguments: Arguments
    fileprivate let hasBalance: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, currency: CurrencyAmount.Currency, balance: Int64, title: String, hasBalance: Bool, arguments: Arguments) {
        self.arguments = arguments
        self.hasBalance = hasBalance
        self.titleLayout = .init(.initialize(string: title, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        let attr = NSMutableAttributedString()
        
        let formatted: String
        switch currency {
        case .stars:
            formatted = "\(balance)"
        case .ton:
            formatted = formatCurrencyAmount(balance, currency: TON).prettyCurrencyNumberUsd
        }
        
        attr.append(string: strings().starPurchaseBalance("\(clown + TINY_SPACE)\(formatted)"), color: theme.colors.text, font: .normal(.text))
        if currency == .ton {
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: theme.colors.accent), for: clown)
        } else {
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
        }
        
        self.balance = .init(attr)
        self.balance.measure(width: .greatestFiniteMagnitude)
        
        self.titleLayout.measure(width: initialSize.width - self.balance.layoutSize.width - 40)
        
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
}

private final class HeaderView : GeneralRowView {
    private let title = InteractiveTextView()
    private let balance = InteractiveTextView()
    private let dismiss = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(balance)
        addSubview(dismiss)
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
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
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        
        balance.isHidden = !item.hasBalance
        
        
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


private final class InputItem : GeneralRowItem {
    let inputState: Updated_ChatTextInputState
    let arguments: Arguments
    let interactions: TextView_Interactions
    let balance: StarsAmount
    let value: Int64
    let currency: CurrencyAmount.Currency
    let hasBalance: Bool
    let usdLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, value: Int64, currency: CurrencyAmount.Currency, balance: StarsAmount, inputState: Updated_ChatTextInputState, hasBalance: Bool, arguments: Arguments) {
        self.inputState = inputState
        self.arguments = arguments
        self.balance = balance
        self.currency = currency
        self.value = value
        self.hasBalance = hasBalance
        self.interactions = arguments.interactions
        
        let usd_rate: Double
        switch currency {
        case .ton:
            usd_rate = arguments.context.appConfiguration.getGeneralValueDouble("ton_usd_rate", orElse: 3)
        case .stars:
            usd_rate = arguments.context.appConfiguration.getGeneralValueDouble("star_usd_rate", orElse: 0.013)
        }
        
        self.usdLayout = .init(.initialize(string: "~\("\((Double(value) * usd_rate))".prettyCurrencyNumberUsd)", color: theme.colors.grayText, font: .normal(.short)))
        self.usdLayout.measure(width: .greatestFiniteMagnitude)
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return InputView.self
    }
}


private final class InputView : GeneralRowView {
    
    
    private final class Input : View {
        
        private weak var item: InputItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        private let starView = InteractiveTextView()
        private let usdView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(starView)
            addSubview(inputView)
            addSubview(usdView)

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: InputItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.background
            
            let attr = NSMutableAttributedString()
            attr.append(string: clown)
            if item.currency == .ton {
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: theme.colors.accent), for: clown)
            } else {
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            }
            
            let layout = TextViewLayout(attr)
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.starView.set(text: layout, context: item.arguments.context)
            self.usdView.update(item.usdLayout)

            
            inputView.placeholder = strings().fragmentStarAmountPlaceholder
            
            inputView.context = item.arguments.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            
            var value = Int64(item.inputState.string) ?? 0
            
            switch item.currency {
            case .stars:
                break
            case .ton:
                value = value * 1_000_000_000
            }
            let max = item.balance.value
            
            inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(value > max && item.hasBalance ? theme.colors.redUI : theme.colors.text)
            
            
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
            guard let item else {
                return frame.width - 20
            }
            return frame.width - 20 - item.usdLayout.layoutSize.width - 10
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
            
            ContainedViewLayoutTransition.immediate.updateFrame(view: usdView, frame: usdView.centerFrameY(x: size.width - usdView.frame.width - 10))
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.arguments.updateState(state)
            
            item.redraw(animated: true)
        }
    }
    
    private let inputView = Input(frame: NSMakeRect(0, 0, 40, 40))
    
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
        
        guard let item = item as? InputItem else {
            return
        }
        
        self.inputView.update(item: item, animated: animated)
               
        
        self.inputView.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func shakeView() {
        inputView.shake(beep: true)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(20, 0, size.width - 40,40))
        inputView.updateLayout(size: inputView.frame.size, transition: transition)
        
    }
    override var firstResponder: NSResponder? {
        return inputView.inputView.inputView
    }
}



private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState: (Updated_ChatTextInputState)->Void
    let close:()->Void
    let date:()->Void
    let currency:(CurrencyAmount.Currency)->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState: @escaping(Updated_ChatTextInputState)->Void, close:@escaping()->Void, date:@escaping()->Void, currency:@escaping(CurrencyAmount.Currency)->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        self.close = close
        self.date = date
        self.currency = currency
    }
}

private struct State : Equatable {
    var starAmount: Int64 = 0
    var tonAmount: Int64 = 0
    var currency: CurrencyAmount.Currency
    var inputState: Updated_ChatTextInputState = .init()
    var date: Int32?
    var mode: ChatInterfaceState.ChannelSuggestPost.Mode
    var starsState: StarsContext.State?
    var tonState: StarsContext.State?
    var peer: EnginePeer?
    
    var effectiveState: StarsContext.State? {
        switch currency {
        case .stars:
            return starsState
        case .ton:
            return tonState
        }
    }
    
    var amount: Int64 {
        get {
            switch currency {
            case .stars:
                return starAmount
            case .ton:
                return tonAmount
            }
        }
        set {
            switch currency {
            case .stars:
                starAmount = newValue
            case .ton:
                tonAmount = newValue
            }
        }
    }
    
    var starsAmount: StarsAmount {
        switch currency {
        case .stars:
            return .init(value: starAmount, nanos: 0)
        case .ton:
            return .init(value: tonAmount * 1_000_000_000, nanos: 0)
        }
    }
    
    var currencyAmount: CurrencyAmount {
        return .init(amount: starsAmount, currency: currency)
    }
    
    var result: ChatInterfaceState.ChannelSuggestPost {
        return .init(amount: currencyAmount, date: date, mode: mode)
    }
    
    var ok: String {
        switch mode {
        case .edit, .suggest:
            return strings().editPostSuggestionActionUpdate
        case .new:
            return strings().editPostSuggestionActionOffer(currencyAmount.fullyFormatted)
        }
    }
}

private let _id_input = InputDataIdentifier("_id_input")
private let _id_date = InputDataIdentifier("_id_date")
private let _id_currency = InputDataIdentifier("_id_currency")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    let title: String
    let hasBalance: Bool
    switch state.mode {
    case .new:
        title = strings().editPostSuggestionTitleNew
        hasBalance = true
    case .edit:
        title = strings().editPostSuggestionTitleEdit
        hasBalance = true
    case .suggest:
        title = strings().editPostSuggestionTitleSuggest
        hasBalance = false
    }
    
    if let starsState = state.effectiveState, let peer = state.peer {
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, currency: state.currency, balance: starsState.balance.value, title: title, hasBalance: hasBalance, arguments: arguments)
        }))
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
        
        if state.mode == .new {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_currency, equatable: .init(state.currency), comparable: nil, item: { initialSize, stableId in
                return SegmentItem(initialSize, stableId: stableId, currency: state.currency, callback: arguments.currency)
            }))
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
        
        let inputHeader: String
        let inputInfo: String
        switch state.currency {
        case .stars:
            inputHeader = strings().editPostSuggestionPriceLabel
            inputInfo = strings().editPostSuggestionPriceDescription(peer._asPeer().displayTitle)
        case .ton:
            inputHeader = strings().editPostSuggestionPriceTonLabel
            inputInfo = strings().editPostSuggestionPriceTonDescription(peer._asPeer().displayTitle)
        }
              
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(inputHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return InputItem(initialSize, stableId: stableId, value: state.amount, currency: state.currency, balance: starsState.balance, inputState: state.inputState, hasBalance: hasBalance, arguments: arguments)
        }))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(inputInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))

        index += 1
    }
    

    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_date, data: .init(name: strings().editPostSuggestionTimeLabel, color: theme.colors.text, type: .nextContext(state.date.flatMap({ stringForDate(timestamp: $0) }) ?? strings().editPostSuggestionTimeAnytime), viewType: .singleItem, action: arguments.date)))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editPostSuggestionTimeDescription), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func EditPostSuggestionController(chatInteraction: ChatInteraction, data: ChatInterfaceState.ChannelSuggestPost) -> InputDataModalController {
    
    let context = chatInteraction.context

    let actionsDisposable = DisposableSet()
    
    let min_stars = context.appConfiguration.getGeneralValue64("stars_suggested_post_amount_min", orElse: 5)
    let min_ton = max(1, context.appConfiguration.getGeneralValue64("ton_suggested_post_amount_min", orElse: 1_000_000_000) / 1_000_000_000)

    
    let amount = data.amount ?? .init(amount: .init(value: min_stars, nanos: 0), currency: .stars)

    let starAmount: Int64
    let tonAmount: Int64
    
    if let currency = data.amount {
        switch currency.currency {
        case .stars:
            starAmount = Int64(currency.formatted) ?? 0
            tonAmount = min_ton
        case .ton:
            tonAmount = Int64(currency.formatted) ?? 0
            starAmount = min_stars
        }
    } else {
        starAmount = min_stars
        tonAmount = min_ton
    }
    
    let initialState = State(starAmount: starAmount, tonAmount: tonAmount, currency: amount.currency, inputState: .init(inputText: .initialize(string: "\(amount.formatted)")), date: data.date, mode: data.mode)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: chatInteraction.peerId))
    
    actionsDisposable.add(combineLatest(context.starsContext.state, context.tonContext.state, peer).startStrict(next: { state, tonState, peer in
        updateState { current in
            var current = current
            current.starsState = state
            current.tonState = tonState
            current.peer = peer?.chatOrMonoforumMainPeer
            return current
        }
    }))
        
    let interactions = TextView_Interactions(presentation: initialState.inputState)
    
    let max_stars = context.appConfiguration.getGeneralValue64("stars_suggested_post_amount_max", orElse: 10000)
    let max_ton = context.appConfiguration.getGeneralValue64("ton_suggested_post_amount_max", orElse: 10000000000000) / 1_000_000_000
    

    let arguments = Arguments(context: context, interactions: interactions, updateState: { [weak interactions] value in
                
        let previous = value.string
        let currency = stateValue.with { $0.currency }
        let maximum: Int64
        let minimum: Int64
        switch currency {
        case .ton:
            maximum = max_ton
            minimum = min_ton
        case .stars:
            maximum = max_stars
            minimum = min_stars
        }
        
        let number = max(min(Int64(value.string) ?? 0, maximum), minimum)
                
        let value = Updated_ChatTextInputState(inputText: .initialize(string: "\(number)"))
        
        updateState { current in
            var current = current
            current.inputState = value
            current.amount = number
            return current
        }
        if value.string != previous {
            DispatchQueue.main.async {
                interactions?.update { _ in
                    return value
                }
            }
        }
        
    }, close: {
        close?()
    }, date: {
        
        let current = stateValue.with { $0.date }
        
        let mode: DateSelectorModalController.Mode
        if current != nil {
            mode = .dateAction(
                title: strings().editPostSuggestionDateTitle,
                done: { _ in strings().editPostSuggestionDateDone },
                action: .init(string: strings().editPostSuggestionDateReset, callback: {
                    updateState { current in
                        var current = current
                        current.date = nil
                        return current
                    }
                })
            )
        } else {
            mode = .date(
                title: strings().editPostSuggestionDateTitle,
                doneTitle: strings().editPostSuggestionDateDone
            )
        }
        
        showModal(with: DateSelectorModalController(context: context, mode: mode, selectedAt: { date in
            updateState { current in
                var current = current
                current.date = Int32(date.timeIntervalSince1970)
                return current
            }
        }), for: context.window)
    }, currency: { [weak interactions] value in
        updateState { current in
            var current = current
            current.currency = value
            return current
        }
        let amount = stateValue.with { $0.amount }
        let value = Updated_ChatTextInputState(inputText: .initialize(string: "\(amount)"))

        DispatchQueue.main.async {
            interactions?.update { _ in
                return value
            }
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    

    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.validateData = { [weak chatInteraction] _ in
        
        let state = stateValue.with { $0 }
        
        guard let starsState = state.effectiveState else {
            return .fail(.none)
        }
        
        switch data.mode {
        case .new, .edit:
            if starsState.balance.value < state.starsAmount.value {
                switch state.currency {
                case .stars:
                    showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: state.amount)), for: window)
                case .ton:
                    showModal(with: AddTonBalanceController(context: context, tonAmount: state.starsAmount.value - starsState.balance.value), for: window)
                }
                return .fail(.fields([_id_input : .shake]))
            }
        case .suggest:
            break
        }
       
    
        chatInteraction?.update {
            $0.updatedInterfaceState {
                $0.withUpdatedSuggestPost(stateValue.with { $0.result })
            }
        }
        close?()
        
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    

    
    let modalInteractions = ModalInteractions(acceptTitle: stateValue.with { $0.ok }, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone { value in
            value.set(text: stateValue.with { $0.ok }, for: .Normal)
        }
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}




