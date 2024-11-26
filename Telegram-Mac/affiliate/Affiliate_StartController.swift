//
//  Affiliate_StartController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.11.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class HeaderItem : GeneralRowItem {
    

    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    let peer: Peer?
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, presentation: TelegramPresentationTheme, peer: Peer?, viewType: GeneralViewType) {
        
        self.context = context
        self.peer = peer
        self.presentation = presentation
        
        let title: NSAttributedString
        let info = NSMutableAttributedString()
        
        //TODOLANG
        title = .initialize(string: "Affiliate Program", color: presentation.colors.text, font: .medium(.header))
        _ = info.append(string: "Reward those who help grow your user base.", color: presentation.colors.text, font: .normal(.text))

        self.titleLayout = .init(title, alignment: .center)

        self.titleLayout.interactions = globalLinkExecutor
        
        self.infoLayout = .init(info, alignment: .center)
        self.infoLayout.interactions = globalLinkExecutor
        super.init(initialSize, stableId: stableId)
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: width - 40)
        infoLayout.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        let height = 100 + 10 + titleLayout.layoutSize.height + 10 + infoLayout.layoutSize.height + 10
        return height
    }
    
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}


private final class HeaderItemView : TableRowView {
    private var premiumView: (PremiumSceneView & NSView)?
    private var statusView: InlineStickerView?
    private let titleView = TextView()
    private let infoView = TextView()
    private var packInlineView: InlineStickerItemLayer?
    private var timer: SwiftSignalKit.Timer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(infoView)
        
        
        titleView.isSelectable = false
        
        infoView.isSelectable = false
        
        self.layer?.masksToBounds = false
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? HeaderItem else {
            return theme.colors.listBackground
        }
        return item.presentation.colors.listBackground
    }
    
    
    override func layout() {
        super.layout()
        if let premiumView = premiumView {
            premiumView.centerX(y: -30)
            titleView.centerX(y: premiumView.frame.maxY - 30 + 10)
        }
        infoView.centerX(y: titleView.frame.maxY + 10)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        titleView.update(item.titleLayout)
        infoView.update(item.infoLayout)
        
                
        timer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
            self?.premiumView?.playAgain()
        }, queue: .mainQueue())
        
        timer?.start()
        
        var current: (PremiumSceneView & NSView)
        if let view = self.premiumView {
            current = view
        } else {
            current = PremiumCoinSceneView(frame: NSMakeRect(0, 0, frame.width, 150))
            addSubview(current)
            self.premiumView = current
        }
        current.sceneBackground = backdorColor
        current.updateLayout(size: current.frame.size, transition: .immediate)
        
        addSubview(titleView)

        needsLayout = true
        
    }
}


private final class PromoItem : GeneralRowItem {
    
    struct Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        let width: CGFloat
        init(image: CGImage, header: TextViewLayout, text: TextViewLayout, width: CGFloat) {
            self.image = image
            self.header = header
            self.text = text
            self.width = width
            self.header.measure(width: width - 80)
            self.text.measure(width: width - 80)
        }
        var size: NSSize {
            return NSMakeSize(width - 40, header.layoutSize.height + 5 + text.layoutSize.height)
        }
    }
    let context: AccountContext
    
    let options: [Option]

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext) {
        self.context = context
        
        var options:[Option] = []
        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateStar).precomposed(theme.colors.accent), header: .init(.initialize(string: "Share Revenue with Channels", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Define the commission for revenue from users referred to you.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateChannel).precomposed(theme.colors.accent), header: .init(.initialize(string: "Launch your affiliate program", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Telegram will feature your program in the admin panel for all channel owners.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateLink).precomposed(theme.colors.accent), header: .init(.initialize(string: "Let channels promote you", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Channel owners will share your referral link with their audience.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        self.options = options

        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += 20
        for option in options {
            height += option.size.height
            height += 20
        }
        return height
    }
    override func viewClass() -> AnyClass {
        return PromoItemView.self
    }
}

private final class PromoItemView: GeneralContainableRowView {
    
    final class OptionView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let infoView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(titleView)
            addSubview(infoView)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            infoView.userInteractionEnabled = false
            infoView.isSelectable = false
        }
        
        func update(option: PromoItem.Option) {
            self.titleView.update(option.header)
            self.infoView.update(option.text)
            self.imageView.image = option.image
            self.imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            titleView.setFrameOrigin(NSMakePoint(40, 0))
            infoView.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
        }
 
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
        
    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(optionsView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        optionsView.centerX(y: 20)
        
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 20
        }
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? PromoItem else {
            return
        }
        

        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: .zero))
        }
        
        var optionsSize = NSMakeSize(0, 0)
        for (i, option) in item.options.enumerated() {
            let view = optionsView.subviews[i] as! OptionView
            view.update(option: option)
            view.setFrameSize(option.size)
            optionsSize = NSMakeSize(max(option.width, optionsSize.width), option.size.height + optionsSize.height)
            if i != item.options.count - 1 {
                optionsSize.height += 20
            }
        }
        
        optionsView.setFrameSize(optionsSize)
        
        
        needsLayout = true
    }
}



private final class Arguments {
    let context: AccountContext
    let updateCommission:(Int32)->Void
    let updateCommission2:(Int32)->Void
    let updateDuration:(Int32)->Void
    let viewExisting:()->Void
    let end:()->Void
    init(context: AccountContext, updateCommission:@escaping(Int32)->Void, updateCommission2:@escaping(Int32)->Void, updateDuration: @escaping(Int32)->Void, viewExisting:@escaping()->Void, end:@escaping()->Void) {
        self.context = context
        self.updateCommission = updateCommission
        self.updateDuration = updateDuration
        self.viewExisting = viewExisting
        self.updateCommission2 = updateCommission2
        self.end = end
    }
}

private struct State : Equatable {
    var commission: Int32 = 10
    var commission2: Int32 = 0
    var duration: Int32 = 6
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_promo = InputDataIdentifier("_id_promo")
private let _id_commission = InputDataIdentifier("_id_commission")
private let _id_commission_2 = InputDataIdentifier("_id_commission_2")
private let _id_duration = InputDataIdentifier("_id_duration")

private let _id_view_existing = InputDataIdentifier("_id_view_existing")
private let _id_end = InputDataIdentifier("_id_end")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, presentation: theme, peer: arguments.context.myPeer, viewType: .legacy)
    }))
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_promo, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PromoItem(initialSize, stableId: stableId, context: arguments.context)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("COMMISSION"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_commission, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let values: [Int32] = [5, 10, 15, 20, 30, 50, 90]
        return SelectSizeRowItem(initialSize, stableId: stableId, current: state.commission, sizes: values, hasMarkers: false, titles:  values.map {"\($0)%"}, viewType: .singleItem, selectAction: { selected in
            arguments.updateCommission(values[selected])
        })
    }))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Define the percentage of star revenue your affiliates earn for referring users to your bot."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("COMMISSION FOR 2-LEVEL AFFILIATES"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_commission_2, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let values: [Int32] = [0, 5, 10, 15, 20, 30, 50, 90]
        return SelectSizeRowItem(initialSize, stableId: stableId, current: state.commission2, sizes: values, hasMarkers: false, titles:  values.map {"\($0)%"}, viewType: .singleItem, selectAction: { selected in
            arguments.updateCommission2(values[selected])
        })
    }))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Set the percentage of star revenue earned by affiliates who refer other affiliates that bring users to your bot."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
        
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DURATION"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: "1 YEAR", color: theme.colors.listGrayText, font: .normal(.small))))))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_duration, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let values: [Int32] = [1, 3, 6, 12, 24, 36, .max]
        
        let titles: [String] = values.map { value in
            if value < 12 {
                return "\(value)m"
            } else if value != .max {
                return "\(value / 12)y"
            } else {
                return "∞"
            }
        }
        
        return SelectSizeRowItem(initialSize, stableId: stableId, current: state.duration, sizes: values, hasMarkers: false, titles:  titles, viewType: .singleItem, selectAction: { selected in
            arguments.updateDuration(values[selected])
           // arguments.updateAwayPeriod(values[selected])
        })
    }))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Set the duration for which affiliates will earn commissions from referred users."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_view_existing, data: .init(name: "View Existing Programs", color: theme.colors.text, type: .next, viewType: .singleItem, action: arguments.viewExisting)))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Explore what other mini apps offer."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    // entries
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_end, data: .init(name: "End Affiliate Program", color: theme.colors.redUI, viewType: .singleItem, action: arguments.end)))

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func Affiliate_StartController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, updateCommission: { value in
        updateState { current in
            var current = current
            current.commission = value
            return current
        }
    }, updateCommission2: { value in
        updateState { current in
            var current = current
            current.commission2 = value
            return current
        }
    }, updateDuration: { value in
        updateState { current in
            var current = current
            current.duration = value
            return current
        }
    }, viewExisting: {
        context.bindings.rootNavigation().push(Affiliate_PeerController(context: context, peerId: peerId))
    }, end: {
        
        let text = "If you end your affiliate program:\n\n• Any referral links already shared will be disabled in 24 hours.\n\n• All participating affiliates will be notified.\n\n• You will be able to start a new affiliate program only in 24 hours."
        
        verifyAlert(for: window, header: "Warning", information: text, ok: "End Anyway", successHandler: { _ in
            
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Affiliate Program", removeAfterDisappear: false, doneString: { "Start" })
    
    controller.validateData = { _ in
        
        let info = "Once you start the affiliate program, you won't be able to decrease its commission or duration. You can only increase these parameters or end the program, which will disable all previously distributed referral links.";
        
        var rows: [InputDataTableBasedItem.Row] = []
        let comission = stateValue.with { $0.commission }
        let comission2 = stateValue.with { $0.commission2 }
        let duration = stateValue.with { $0.duration }
        
        rows.append(.init(left: .init(.initialize(string: "Commission", color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: "\(comission)%", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1))))
        
        if comission2 > 0 {
            rows.append(.init(left: .init(.initialize(string: "Commission for\n2-Level Affiliates", color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: "\(comission2)%", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1))))

        }
        
        let localizedDuration = duration < 12 ? strings().timerMonthsCountable(Int(duration)) : duration == .max ? "Lifetime" : strings().timerYearsCountable(Int(duration))
        
        rows.append(.init(left: .init(.initialize(string: "Duration", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1), right: .init(name: .init(.initialize(string: localizedDuration, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1))))

        
        let data = ModalAlertData(title: "Warning", info: info, description: nil, ok: "Start", options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: .init(value: { initialSize, stableId, presentation in
            return InputDataTableBasedItem(initialSize, stableId: stableId, viewType: .legacy, rows: rows, context: arguments.context)
        }))
        
        showModalAlert(for: window, data: data, completion: { result in
            
        })
        
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}

