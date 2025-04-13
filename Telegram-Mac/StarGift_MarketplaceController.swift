
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private extension StarGift.UniqueGift.Attribute {
    var name: String {
        switch self {
        case let .model(name, _, _):
            return name
        case let .backdrop(name, _, _, _, _, _, _):
            return name
        case let .pattern(name, _, _):
            return name
        default:
            return ""
        }
    }
}

private class AttributeMenuItem : ContextMenuItem {
    fileprivate let attribute: StarGift.UniqueGift.Attribute
    fileprivate let arguments: Arguments
    init(attribute: StarGift.UniqueGift.Attribute, arguments: Arguments) {
        self.attribute = attribute
        self.arguments = arguments
        super.init(attribute.name, handler: {
            
        })
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return AttributeMenuRowItem(self, presentation: presentation, interaction: interaction)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AttributeMenuRowItem : AppMenuRowItem {
    init(_ item: AttributeMenuItem, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) {
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
    }
    
    var genericItem: AttributeMenuItem {
        return self.item as! AttributeMenuItem
    }
    
    override func viewClass() -> AnyClass {
        return AttributeMenuRowView.self
    }
}

private final class AttributeMenuRowView : AppMenuRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class HeaderItem : GeneralRowItem {
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let balanceLayout: TextViewLayout
    
    fileprivate let context: AccountContext
    fileprivate let arguments: Arguments
    
    struct AttributeItem {
        let text: TextViewLayout
        let attribute: State.Attribute
        init(attribute: State.Attribute) {
            self.attribute = attribute
            self.text = .init(.initialize(string: attribute.string, color: theme.colors.darkGrayText, font: .medium(.text)))
            self.text.measure(width: .greatestFiniteMagnitude)
        }
    }
    
    let items: [AttributeItem]
    
    init(_ initialSize: NSSize, stableId: AnyHashable, state: State, context: AccountContext, arguments: Arguments) {
        
        self.context = context
        self.arguments = arguments
        
        let balanceAttr = NSMutableAttributedString()
        balanceAttr.append(string: strings().starPurchaseBalance("\(clown_space)\(state.myBalance)"), color: theme.colors.text, font: .normal(.text))
        balanceAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        
        self.balanceLayout = .init(balanceAttr, alignment: .right)

        
        self.headerLayout = .init(.initialize(string: "Plush Pepe", color: theme.colors.text, font: .normal(.title)))
        self.infoLayout = .init(.initialize(string: "455 for resale", color: theme.colors.grayText, font: .normal(.small)))
        
        self.items = State.Attribute.all.map { .init(attribute: $0) }

        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.balanceLayout.measure(width: .greatestFiniteMagnitude)
        
        self.headerLayout.measure(width: width - 40 - balanceLayout.layoutSize.width)
        self.infoLayout.measure(width: width - 40 - balanceLayout.layoutSize.width)
        
        return true
    }
    
    
    override var height: CGFloat {
        return 110
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private class HeaderItemView: GeneralRowView {
    private let top_Container = View()
    private let bottom_Container = HorizontalScrollView(frame: .zero)
    private let headerView = TextView()
    private let statusView = TextView()
    private let balanceView = InteractiveTextView()
    private let dismiss = ImageButton()
    
    private let documentView = View()
    
    private class AttributeItemView : Control {
        private let textView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            
            imageView.image = NSImage(resource: .iconAffiliateExpand).precomposed(theme.colors.darkGrayText)
            imageView.sizeToFit()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(item: HeaderItem.AttributeItem, arguments: Arguments, animated: Bool) {
            self.textView.update(item.text)
            
            self.setFrameSize(NSMakeSize(item.text.layoutSize.width + imageView.frame.width + 23, 30))
            
            self.backgroundColor = theme.colors.grayForeground

            
            self.layer?.cornerRadius = 15
            
            self.contextMenu = {
                var menu = ContextMenu()
                menu.items = arguments.getMenuItems(item.attribute)
                return menu
            }
        }
        
        override func layout() {
            super.layout()
            
            self.textView.centerY(x: 10)
            self.imageView.centerY(x: self.textView.frame.maxX + 3)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(top_Container)
        addSubview(bottom_Container)
        
        
        top_Container.addSubview(dismiss)
        
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
        top_Container.addSubview(headerView)
        top_Container.addSubview(statusView)
        top_Container.addSubview(balanceView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        while documentView.subviews.count > item.items.count {
            documentView.subviews.last?.removeFromSuperview()
        }
        
        while documentView.subviews.count < item.items.count {
            documentView.addSubview(AttributeItemView(frame: .zero))
        }
        
        var x: CGFloat = 10
        for (i, attr) in item.items.enumerated() {
            let view = documentView.subviews[i] as! AttributeItemView
            view.set(item: attr, arguments: item.arguments, animated: animated)
            view.centerY(x: x)
            x += view.frame.width + 5
        }
        
        documentView.frame = NSMakeRect(0, 0, x + 5, 30)
        bottom_Container.documentView = documentView

        headerView.update(item.headerLayout)
        statusView.update(item.infoLayout)
        balanceView.set(text: item.balanceLayout, context: item.context)
        
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.dismiss()
        }, for: .Click)
        
        needsLayout = true
        
    }
    
    
    override func layout() {
        super.layout()
        
        top_Container.frame = NSMakeRect(0, 0, frame.width, 50)
        bottom_Container.frame = NSMakeRect(0, frame.height - 50, frame.width, 30)
        
        headerView.centerX(y: 9)
        statusView.centerX(y: top_Container.frame.height - 9 - statusView.frame.height)
        
        balanceView.centerY(x: top_Container.frame.width - balanceView.frame.width - 10)
        
        dismiss.setFrameOrigin(NSMakePoint(10, 10))
        
        var x: CGFloat = 10
        for view in documentView.subviews {
            view.centerY(x: x)
            x += view.frame.width + 5
        }
        
    }
}

private final class Arguments {
    
    
    
    let context: AccountContext
    let dismiss:()->Void
    let getMenuItems:(State.Attribute)->[ContextMenuItem]
    init(context: AccountContext, dismiss:@escaping()->Void, getMenuItems:@escaping(State.Attribute)->[ContextMenuItem]) {
        self.context = context
        self.dismiss = dismiss
        self.getMenuItems = getMenuItems
    }
}

private struct State : Equatable {
    
    enum Attribute {
        case price
        case model
        case backdrop
        case symbol
        
        var string: String {
            switch self {
            case .price:
                return "Price"
            case .model:
                return "Model"
            case .backdrop:
                return "Backdrop"
            case .symbol:
                return "Symbol"
            }
        }
        
        static var all: [Attribute] {
            return [.price, .model, .backdrop, .symbol]
        }
    }
    
    
    var starsState: StarsContext.State?
    var myBalance: Int64 {
        return starsState?.balance.value ?? 0
    }
    
    var attributes: [StarGift.UniqueGift.Attribute] = []

}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, state: state, context: arguments.context, arguments: arguments)
    }))
    sectionId += 1
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func StarGift_MarketplaceController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
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
    
    let starsContext = context.starsContext
    
    starsContext.load(force: true)
    
    actionsDisposable.add(starsContext.state.startStrict(next: { starsState in
        updateState { current in
            var current = current
            current.starsState = starsState
            return current
        }
    }))
        
    actionsDisposable.add(context.engine.payments.starGiftUpgradePreview(giftId: 5897593557492957738).startStrict(next: { attributes in
        updateState { current in
            var current = current
            current.attributes = attributes
            return current
        }
    }))
    
    var getMenuItems:((State.Attribute)->[ContextMenuItem])? = nil

    let arguments = Arguments(context: context, dismiss: {
        close?()
    }, getMenuItems: { attribute in
        return getMenuItems?(attribute) ?? []
    })
    
    getMenuItems = { [weak arguments] attribute in
        
        guard let arguments else {
            return []
        }
        let state = stateValue.with { $0 }
        
        var items: [ContextMenuItem] = []
        switch attribute {
        case .price:
            items.append(ContextMenuItem("Sort by Price", handler: {
                
            }, itemImage: MenuAnimation.menu_sort_up.value))
            
            items.append(ContextMenuItem("Sort by Date", handler: {
                
            }, itemImage: MenuAnimation.menu_sort_up.value))
            
            items.append(ContextMenuItem("Sort by Number", handler: {
                
            }, itemImage: MenuAnimation.menu_sort_up.value))
        default:
            let attrs = state.attributes.filter({ attr in
                switch attr {
                case .model:
                    return attribute == .model
                case .backdrop:
                    return attribute == .backdrop
                case .pattern:
                    return attribute == .symbol
                default:
                    return false
                }
            })
            
            for attr in attrs {
                items.append(AttributeMenuItem(attribute: attr, arguments: arguments))
            }
        }
        return items
    }
    
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

    let modalInteractions = ModalInteractions(acceptTitle: "PAY", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(368, 0))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*

 */



