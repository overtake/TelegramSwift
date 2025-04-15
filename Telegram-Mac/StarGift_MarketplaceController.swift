
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private extension StarGift.UniqueGift.Attribute {
    var resaleAttr: ResaleGiftsContext.Attribute {
        switch self {
        case let .model(_, file, _):
            return .model(file.fileId.id)
        case let .backdrop(_, id, _, _, _, _, _):
            return .backdrop(id)
        case let .pattern(_, file, _):
            return .pattern(file.fileId.id)
        default:
            fatalError()
        }
    }
}

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
    init(attribute: StarGift.UniqueGift.Attribute, count: Int32, selected: Bool, arguments: Arguments) {
        self.attribute = attribute
        self.arguments = arguments
        super.init(attribute.name + " (\(count))", handler: {
            arguments.toggleAttribute(attribute.resaleAttr)
        }, state: selected ? .on : nil)
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return AttributeMenuRowItem(self, presentation: presentation, interaction: interaction)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AttributeMenuRowItem : AppMenuRowItem {
    private let disposable = MetaDisposable()
    init(_ item: AttributeMenuItem, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) {
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        let image = generateImage(NSMakeSize(imageSize, imageSize), rotatedContext: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(NSColor.clear.cgColor)
            ctx.fillEllipse(in: size.bounds)
        })!
        item.image = NSImage(cgImage: image, size: NSMakeSize(imageSize, imageSize))
        
        switch item.attribute {
        case let .backdrop(_, _, innerColor, outerColor, _, _, _):
            let image = generateImage(NSMakeSize(imageSize, imageSize), rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.round(size, size.height / 2)

                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colors = [NSColor(UInt32(innerColor)).cgColor, NSColor(UInt32(outerColor)).cgColor] as CFArray
                let locations: [CGFloat] = [0.0, 1.0]

                if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2

                    ctx.drawRadialGradient(
                        gradient,
                        startCenter: center, startRadius: 0,
                        endCenter: center, endRadius: radius,
                        options: [.drawsAfterEndLocation]
                    )
                }
            })!
            item.image = NSImage(cgImage: image, size: NSMakeSize(imageSize, imageSize))
        case let .model(_, file, _), let .pattern(_, file, _):
            
            let isPattern: Bool
            switch item.attribute {
            case .pattern:
                isPattern = true
            default:
                isPattern = false
            }
            
            let size = NSMakeSize(imageSize, imageSize)
            
            let aspectSize = file.dimensions?.size.aspectFitted(size) ?? size
            
            let signal = chatMessageAnimatedSticker(postbox: item.arguments.context.account.postbox, file: .standalone(media: file), small: false, scale: System.backingScale, size: aspectSize, fetched: true, thumbAtFrame: 0, isVideo: file.fileName == "webm-preview" || file.isVideoSticker)

            let arguments = TransformImageArguments(corners: .init(), imageSize: size, boundingSize: aspectSize, intrinsicInsets: .init(), emptyColor: isPattern ? .fill(theme.colors.text) : nil)
            
            let result = signal |> map { data -> TransformImageResult in
                let context = data.execute(arguments, data.data)
                let image = context?.generateImage()
                return TransformImageResult(image, context?.isHighQuality ?? false)
            } |> deliverOnMainQueue
            
            disposable.set(result.start(next: { [weak item] result in
                item?.image = result.image.flatMap({
                    NSImage(cgImage: $0, size: size)
                })
            }))
        default:
            break
            
        }
    }
    
    deinit {
        disposable.dispose()
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
    let toggleAttribute:(ResaleGiftsContext.Attribute)->Void
    let selectAll:(ResaleGiftsContext.Attribute)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, getMenuItems:@escaping(State.Attribute)->[ContextMenuItem], toggleAttribute:@escaping(ResaleGiftsContext.Attribute)->Void,
         selectAll:@escaping(ResaleGiftsContext.Attribute)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.getMenuItems = getMenuItems
        self.toggleAttribute = toggleAttribute
        self.selectAll = selectAll
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
    
    var resaleState: ResaleGiftsContext.State?

}

private let _id_header = InputDataIdentifier("_id_header")
private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, state: state, context: arguments.context, arguments: arguments)
    }))
    sectionId += 1
  
    if let resaleState = state.resaleState {
        
        let chunks = resaleState.gifts.chunks(3)
        
        for (i, chunk) in chunks.enumerated() {
            if !chunk.isEmpty {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                    return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0.unique!) }, insets: .init(left: 10, right: 10), callback: { option in
                        
                    })
                }))
                
                entries.append(.sectionId(sectionId, type: .customModern(10)))
                sectionId += 1
            }
        }
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    return entries
}

func StarGift_MarketplaceController(context: AccountContext, giftId: Int64) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let resaleContext = ResaleGiftsContext(account: context.account, giftId: giftId)
    
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
        
    actionsDisposable.add(resaleContext.state.startStrict(next: { state in
        updateState { current in
            var current = current
            current.resaleState = state
            return current
        }
    }))
    
    var getMenuItems:((State.Attribute)->[ContextMenuItem])? = nil

    let arguments = Arguments(context: context, dismiss: {
        close?()
    }, getMenuItems: { attribute in
        return getMenuItems?(attribute) ?? []
    }, toggleAttribute: { [weak resaleContext] value in
        
        let state = stateValue.with { $0 }
        
        var currentFilterAttributes: [ResaleGiftsContext.Attribute] = []
        
        if let filterAttributes = state.resaleState?.filterAttributes {
            currentFilterAttributes = filterAttributes
        }

        if currentFilterAttributes.contains(where: { $0 == value }) {
            currentFilterAttributes.removeAll(where: { $0 == value })
        } else {
            currentFilterAttributes.insert(value, at: 0)
        }
        
        resaleContext?.updateFilterAttributes(currentFilterAttributes)
        
    }, selectAll: { [weak resaleContext] attr in
        let state = stateValue.with { $0 }
        
        var currentFilterAttributes: [ResaleGiftsContext.Attribute] = []
        
        if let filterAttributes = state.resaleState?.filterAttributes {
            currentFilterAttributes = filterAttributes
        }

        currentFilterAttributes.removeAll(where: { value in
            switch value {
            case .backdrop:
                if case .backdrop = attr {
                    return true
                }
            case .model:
                if case .model = attr {
                    return true
                }
            case .pattern:
                if case .pattern = attr {
                    return true
                }
            }
            return false
        })
        
        resaleContext?.updateFilterAttributes(currentFilterAttributes)
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
            if let resaleState = state.resaleState {
                
               
                
                let attrs = resaleState.attributes.filter({ attr in
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
                
                let filteredAttrs = resaleState.filterAttributes.filter({ attr in
                    switch attr {
                    case .model:
                        return attribute == .model
                    case .backdrop:
                        return attribute == .backdrop
                    case .pattern:
                        return attribute == .symbol
                    }
                })
                
                let allSelected: Bool = filteredAttrs.isEmpty
    
                //TODOLANG
                items.append(ContextMenuItem("Select All", handler: {
                    if let first = attrs.first?.resaleAttr {
                        arguments.selectAll(first)
                    }
                }, state: allSelected ? .on : nil))
                
                items.append(ContextSeparatorItem())
                
                for attr in attrs {
                    let count = resaleState.attributeCount[attr.resaleAttr] ?? 0
                    items.append(AttributeMenuItem(attribute: attr, count: count, selected: resaleState.filterAttributes.contains(where: { $0 == attr.resaleAttr }) || allSelected, arguments: arguments))
                }
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
    
    controller.contextObject = resaleContext
    
    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "PAY", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(368, 0))
    
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



