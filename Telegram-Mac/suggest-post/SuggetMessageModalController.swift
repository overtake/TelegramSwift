
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class HeaderItem : GeneralRowItem {
    fileprivate let state: State
    fileprivate let arguments: Arguments
    fileprivate let maxValue: Int64
    
    fileprivate let infoLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, state: State, arguments: Arguments) {
        self.state = state
        self.arguments = arguments
        self.maxValue = 10000
        self.infoLayout = .init(.initialize(string: "Choose how many Stars you want to offer **AutoScope** to publish this message.", color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        infoLayout.measure(width: width - 40)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    
    override var height: CGFloat {
        return 110 + 15 + infoLayout.layoutSize.height + 15 + 30 + 10
    }
}

private final class HeaderView: GeneralRowView {
    let badgeView = Star_BadgeView(frame: NSMakeRect(0, 0, 100, 48))
    let sliderView = Star_SliderView(frame: NSMakeRect(0, 0, 100, 30))
    let infoView = TextView()
    private let timeView = TimeView(frame: .zero)
    
    private class TimeView : Control {
        private let textView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            
            imageView.image = NSImage(resource: .iconAffiliateExpand).precomposed(theme.colors.grayIcon)
            imageView.sizeToFit()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(state: State, arguments: Arguments, animated: Bool) {
            
            let layout = TextViewLayout(.initialize(string: state.timeText, color: theme.colors.darkGrayText, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.textView.update(layout)
            
            self.setFrameSize(NSMakeSize(self.textView.frame.width + imageView.frame.width + 21, 30))
            self.backgroundColor = theme.colors.grayForeground
            self.layer?.cornerRadius = 15

        }
        
        override func layout() {
            super.layout()
            
            self.textView.centerY(x: 10)
            self.imageView.centerY(x: self.textView.frame.maxX + 3)
        }
    }

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(badgeView)
        addSubview(sliderView)
        
        addSubview(infoView)
        addSubview(timeView)
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        sliderView.updateProgress = { [weak self] progress, maybeToBalance in
            if let item = self?.item as? HeaderItem {
                
                var value = progress * CGFloat(item.maxValue)
                let myBalance = CGFloat(item.state.myBalance)
                if maybeToBalance, item.state.amount.realValue < item.state.myBalance, value > myBalance {
                    value = Double(item.state.amount.withRealValue(Int(myBalance + 1)).sliderValue)
                }
                item.arguments.updateValue(Int64(ceil(value)))
            }
        }

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition = .immediate
        
        
        let size = badgeView.update(sliderValue: Int64(item.state.amount.sliderValue), realValue: Int64(item.state.amount.realValue), max: item.maxValue, context: item.arguments.context)
        
        transition.updateFrame(view: self.badgeView, frame: self.focus(size))
        badgeView.updateLayout(size: size, transition: transition)

        sliderView.update(count: Int64(item.state.amount.sliderValue), minValue: 1, maxValue: item.maxValue)

        infoView.update(item.infoLayout)
        
        
        timeView.set(state: item.state, arguments: item.arguments, animated: animated)
        
        timeView.setSingle(handler: { [weak item] _ in
            item?.arguments.selectTime()
        }, for: .Click)
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        sliderView.frame = NSMakeRect(20, badgeView.frame.height + 20, frame.width - 40, 30)
        sliderView.layout()
        
        badgeView.centerX(y: 50)
        
        badgeView.setFrameOrigin(NSMakePoint(10 + sliderView.dotLayer.frame.midX - badgeView.frame.width * badgeView.tailPosition, 10))
        
        infoView.centerX(y: sliderView.frame.maxY + 15)
        
        timeView.centerX(y: infoView.frame.maxY + 15)
    }
}

private final class Arguments {
    let context: AccountContext
    let updateValue:(Int64)->Void
    let selectTime:()->Void
    init(context: AccountContext, updateValue:@escaping(Int64)->Void, selectTime:@escaping()->Void) {
        self.context = context
        self.updateValue = updateValue
        self.selectTime = selectTime
    }
}

private struct State : Equatable {
    var amount: Star_SliderAmount = Star_SliderAmount(realValue: 1, maxRealValue: 10000, maxSliderValue: 10000, isLogarithmic: true)
    var myBalance: Int64 = 1000
    
    var date: Int32?
    
    var timeText: String {
        if let date {
            return stringForFullDate(timestamp: date)
        } else {
            //TODOLANG
            return "Anytime"
        }
    }
    
    var offerText: String {
        //TODOLANG
        return "Offer \(self.amount.realValue) Stars"
    }
}


private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, state: state, arguments: arguments)
    }))
  
    // entries
    
    
    return entries
}

func SuggetMessageModalController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)?
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, updateValue: { value in
        updateState { current in
            var current = current
            current.amount = current.amount.withSliderValue(Int(value))
            return current
        }
        let current = stateValue.with { $0.amount.realValue }
        let myBalance = stateValue.with { $0.myBalance }
        if current == myBalance {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }, selectTime: {
        //TODOLANG
        let date = stateValue.with { $0.date }
        let defaultDate: Date
        
        let mode: DateSelectorModalController.Mode
        if let date {
            mode = .dateAction(title: "Time", done: { _ in "OK" }, action: .init(string: "Send Anytime", callback: {
                updateState { current in
                    var current = current
                    current.date = nil
                    return current
                }
            }))
            defaultDate = Date(timeIntervalSince1970: TimeInterval(date))
        } else {
            mode = .date(title: "Time", doneTitle: "OK")
            defaultDate = Date()
        }
        
        let infoLayout = TextViewLayout(.initialize(string: "Select the date and time you want your message to be published.", color: theme.colors.text, font: .normal(.text)), alignment: .center)
        
        infoLayout.measure(width: 290)
        
        showModal(with: DateSelectorModalController(context: context, defaultDate: defaultDate, mode: mode, selectedAt: { date in
            updateState { current in
                var current = current
                current.date = Int32(date.timeIntervalSince1970)
                return current
            }
        }, infoText: infoLayout), for: window)
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: "Suggest a Message")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "PAY", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, listBackground: theme.colors.background)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    modalController.getModalTheme = {
        .init(background: theme.colors.background, border: .clear, activeBorder: .clear, listBackground: theme.colors.background)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone({
            $0.set(text: stateValue.with { $0.offerText }, for: .Normal)
        })
    }
    
    
    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            theme.colors.background
        }
        
    }
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}


/*
 
 */



