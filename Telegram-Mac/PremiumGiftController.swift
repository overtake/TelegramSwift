//
//  PremiumGifController.swift
//  Telegram
//
//  Created by Mike Renoir on 27.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit

struct PremiumGiftOption : Equatable {
    
    let option: CachedPremiumGiftOption
    let options: [CachedPremiumGiftOption]
    let configuration: PremiumPromoConfiguration
    
    var titleString: String {
        return strings().timerMonthsCountable(Int(option.months))
    }
    var discountString: Int {
        
        let optionMonthly:Int64 = Int64((CGFloat(option.amount) / CGFloat(option.months)))
        
        let highestOptionMonthly:Int64 = options.map { option in
            return Int64((CGFloat(option.amount) / CGFloat(option.months)))
        }.max()!
        
        
        let discountPercent = Int(ceil((Float(highestOptionMonthly) - Float(optionMonthly)) / Float(highestOptionMonthly) * 100))
        return discountPercent
    }
    
    var priceString: String {
        return formatCurrencyAmount(option.amount, currency: option.currency)
    }
    var priceDiscountString: String {
        let optionMonthly = Int64((CGFloat(option.amount) / CGFloat(option.months)))
        return strings().premiumGiftMonth(formatCurrencyAmount(optionMonthly, currency: option.currency))
        
    }
}




private struct State : Equatable {
    var peer: PeerEquatable?
    var options: [CachedPremiumGiftOption]
    var option: CachedPremiumGiftOption
    var premiumConfiguration: PremiumPromoConfiguration
    
    
    var values: [PremiumGiftOption] {
        return self.options.map({
            .init(option: $0, options: self.options, configuration: self.premiumConfiguration)
        })
    }
    var value: PremiumGiftOption {
        return .init(option: self.option, options: self.options, configuration: self.premiumConfiguration)
    }
}


private final class Arguments {
    let context: AccountContext
    let select:(PremiumGiftOption)->Void
    let openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void
    let buy:(String)->Void
    init(context: AccountContext, select:@escaping(PremiumGiftOption)->Void, openInfo:@escaping(PeerId, Bool, MessageId?, ChatInitialAction?)->Void, buy:@escaping(String)->Void) {
        self.select = select
        self.context = context
        self.openInfo = openInfo
        self.buy = buy
    }
}

private let _id_message = InputDataIdentifier("_id_message")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(35)))
    sectionId += 1
   
    if let peer = state.peer {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(peer), comparable: nil, item: { initialSize, stableId in
            return PremiumGiftHeaderItem(initialSize, stableId: stableId, context: arguments.context, peer: peer.peer)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("discount"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return PremiumGiftRowItem(initialSize, stableId: stableId, viewType: .singleItem, context: arguments.context, selectedOption: state.value, options: state.values, select: arguments.select)
    }))
    index += 1
    
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//  
//    entries.append(.input(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_message, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: "Message", filter: { $0 }, limit: 140))
//    index += 1
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("You can include a message with your gift."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
//    index += 1
//    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private final class PremiumBoardingView : View {
    
    private final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let shimmer = ShimmerEffectView()
        private let textView = TextView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            addSubview(shimmer)
            shimmer.isStatic = true
            container.addSubview(textView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            
            
            gradient.frame = bounds
            shimmer.frame = bounds
            
            shimmer.updateAbsoluteRect(bounds, within: frame.size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: bounds, cornerRadius: frame.height / 2)], horizontal: true, size: frame.size)
            
            container.center()
            textView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(animated: Bool, state: State) -> NSSize {
            
            let layout = TextViewLayout(.initialize(string: strings().premiumGiftButtonText(state.value.priceString), color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
                        
            container.setFrameSize(layout.layoutSize)
            
            layer?.cornerRadius = 10
            
            let size = NSMakeSize(container.frame.width + 100, 40)

            needsLayout = true
                        
            return size
        }
    }

    
    final class HeaderView: View {
        let dismiss = ImageButton()
        private let container = View()
        private let titleView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            addSubview(dismiss)
            
            dismiss.scaleOnClick = true
            dismiss.autohighlight = false
            
            dismiss.set(image: theme.icons.modalClose, for: .Normal)
            dismiss.sizeToFit()
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = theme.colors.background
            container.border = [.Bottom]

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingTitle, color: theme.colors.text, font: .medium(.header)))
            layout.measure(width: 300)
            
            titleView.update(layout)
            container.addSubview(titleView)
        }
        
        func update(isHidden: Bool, animated: Bool) {
            container.change(opacity: isHidden ? 0 : 1, animated: animated)
        }
        
        override func layout() {
            super.layout()
            dismiss.centerY(x: 10)
            container.frame = bounds
            titleView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    
    private let headerView: HeaderView = HeaderView(frame: .zero)
    
    let tableView = TableView()
    private let bottomView: View = View()
    private let acceptView = AcceptView(frame: .zero)
    private let bottomBorder = View()
    
    private let containerView = View()
    private var fadeView: View?
    
    var dismiss:(()->Void)?
    var accept:(()->Void)?
    
    private var state: State?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(tableView)
        containerView.addSubview(headerView)
        containerView.addSubview(bottomView)
        bottomView.addSubview(acceptView)
        bottomView.addSubview(bottomBorder)
        addSubview(containerView)
        
        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
                
        bottomBorder.backgroundColor = theme.colors.border
        
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateScroll(position, animated: true)
        }))
        
        headerView.dismiss.set(handler: { [weak self] _ in
            self?.dismiss?()
        }, for: .Click)
        
        acceptView.set(handler: { [weak self] _ in
            self?.accept?()
        }, for: .Click)
    }
    
    private func updateScroll(_ scroll: ScrollPosition, animated: Bool) {
        let offset = scroll.rect.minY - tableView.frame.height
                
        if scroll.rect.minY >= tableView.listHeight || scroll.rect.minY == 0 {
            bottomBorder.change(opacity: 0, animated: animated)
            bottomView.backgroundColor = theme.colors.listBackground
            if animated {
                bottomView.layer?.animateBackground()
            }
        } else {
            bottomBorder.change(opacity: 1, animated: animated)
            bottomView.backgroundColor = theme.colors.background
            if animated {
                bottomView.layer?.animateBackground()
            }
        }
        
        headerView.update(isHidden: offset <= 127, animated: animated)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: self.frame.size, transition: .immediate)
        self.updateScroll(tableView.scrollPosition().current, animated: false)
    }
    
    var bottomHeight: CGFloat {
        return 60
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: NSMakeRect(0, 0, size.width, 50))
        transition.updateFrame(view: containerView, frame: bounds)
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 0, size.width, size.height - bottomHeight))
        transition.updateFrame(view: bottomView, frame: NSMakeRect(0, tableView.frame.maxY, size.width, bottomHeight))
                    
        transition.updateFrame(view: acceptView, frame: acceptView.centerFrame())
        transition.updateFrame(view: bottomBorder, frame: NSMakeRect(0, 0, bottomView.frame.width, .borderSize))

        
    }
    
    func contentSize(maxSize size: NSSize) -> NSSize {
        return NSMakeSize(size.width, min(tableView.listHeight + bottomHeight, size.height))
    }
    
    func update(animated: Bool, arguments: Arguments, state: State) {
        self.state = state
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        let size = acceptView.update(animated: animated, state: state)
        acceptView.setFrameSize(NSMakeSize(frame.width - 60, size.height))
        
        updateLayout(size: frame.size, transition: transition)
        
        self.updateScroll(tableView.scrollPosition().current, animated: false)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumGiftController : ModalViewController {

    private let context: AccountContext
    private let peerId: PeerId
    private let options: [CachedPremiumGiftOption]
    init(context: AccountContext, peerId: PeerId, options: [CachedPremiumGiftOption]) {
        self.context = context
        self.peerId = peerId
        self.options = options
        super.init(frame: NSMakeRect(0, 0, 380, 300))
    }
    
    override func measure(size: NSSize) {
        updateSize(false)
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(380, contentSize.height - 80)), animated: animated)
        }
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    private var genericView: PremiumBoardingView {
        return self.view as! PremiumBoardingView
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingView.self
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.tableView.item(stableId: InputDataEntryId.input(_id_message))?.view?.firstResponder
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        let actionsDisposable = DisposableSet()
        
        
        let context = self.context
        let peerId = self.peerId
                
        let close: ()->Void = {
            closeAllModals()
        }

        let initialState = State(peer: nil, options: options, option: options[0], premiumConfiguration: PremiumPromoConfiguration.defaultValue)
        
        let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let arguments = Arguments(context: context, select: { option in
            updateState { current in
                var current = current
                current.option = option.option
                return current
            }
        }, openInfo: { peerId, _, _, initialAction in
            var updated: ChatInitialAction? = initialAction
            switch initialAction {
            case let .start(parameter, _):
                updated = .start(parameter: parameter, behavior: .automatic)
            default:
                break
            }
            let controller = ChatController(context: context, chatLocation: .peer(peerId), initialAction: updated)
            context.bindings.rootNavigation().push(controller)
            
            close()
        }, buy: { slug in
            let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug)), for: context.window)

            _ = signal.start(next: { invoice in
                showModal(with: PaymentsCheckoutController(context: context, source: .slug(slug), invoice: invoice, completion: { status in
                    switch status {
                    case .paid:
                        PlayConfetti(for: context.window)
                        context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
                        close()
                    case .cancelled:
                        break
                    case .failed:
                        break
                    }
                }), for: context.window)
            }, error: { error in
                showModalText(for: context.window, text: strings().paymentsInvoiceNotExists)
            })
        })
        
        let stateSignal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return (InputDataSignalValue(entries: entries(state, arguments: arguments)), state)
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {
            
        })
        
        
        
        
        let signal: Signal<(TableUpdateTransition, State), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, stateSignal) |> mapToQueue { appearance, state in
            let entries = state.0.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.0.animated, searchState: state.0.searchState, initialSize: initialSize.modify{ $0 }, arguments: inputArguments, onMainQueue: true)
            |> map {
                ($0, state.1)
            }
        } |> deliverOnMainQueue |> afterDisposed {
            previous.swap([])
        }
               
        let peer = context.account.postbox.loadedPeerWithId(peerId)
        
        let premiumPromo = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.PremiumPromo())
        |> deliverOnMainQueue
        

        
        actionsDisposable.add(combineLatest(peer, premiumPromo).start(next: { peer, configuration in
            updateState { current in
                var current = current
                current.peer = .init(peer)
                current.premiumConfiguration = configuration
                return current
            }
        }))
        
        actionsDisposable.add(signal.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition.0)
            self?.genericView.update(animated: transition.0.animated, arguments: arguments, state: transition.1)
            self?.updateSize(transition.0.animated)
            self?.readyOnce()
        }))
        
        let buyAppStore: ()->Void = {
            
        }
        let buyNonAppStore: ()->Void = {
            
            let url = inApp(for: stateValue.with { $0.option.botUrl.nsstring }, context: context, openInfo: arguments.openInfo)
            switch url {
            case let .invoice(_, context, slug):
                arguments.buy(slug)
            case .followResolvedName:
                execute(inapp: url)
            default:
                break
            }
            
        }
        
        genericView.accept = {
            
            #if APP_STORE
            buyAppStore()
            #else
            buyNonAppStore()
            #endif
            
//            close()
//            PlayConfetti(for: context.window)
//
//
//            delay(0.2, closure: {
//                showModalText(for: context.window, text: "You successfully gifted Telegram Premium")
//            })
        }
    }
    
}





