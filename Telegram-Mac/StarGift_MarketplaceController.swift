
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class EmptyRowItem: GeneralRowItem {
    fileprivate let arguments: Arguments
    fileprivate let titleLayout: TextViewLayout
    fileprivate let clearLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, arguments: Arguments) {
        self.arguments = arguments
        self.titleLayout = .init(.initialize(string: strings().giftMarketplaceEmptyFilters, color: theme.colors.text, font: .normal(.title)), alignment: .center)
        self.titleLayout.measure(width: .greatestFiniteMagnitude)
        
        self.clearLayout = .init(.initialize(string: strings().giftMarketplaceEmptyFiltersClear, color: theme.colors.accent, font: .normal(.text)), alignment: .center)
        self.clearLayout.measure(width: .greatestFiniteMagnitude)

        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 270
    }
    
    override func viewClass() -> AnyClass {
        return EmptyRowView.self
    }
}

fileprivate class EmptyRowView : GeneralRowView {
    fileprivate let titleView = TextView()
    fileprivate let clearView = TextView()
    fileprivate let animationView = MediaAnimatedStickerView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(clearView)
        addSubview(animationView)
        
        titleView.isSelectable = false
        clearView.isSelectable = false
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmptyRowItem else {
            return
        }
        
        titleView.update(item.titleLayout)
        clearView.update(item.clearLayout)
        
        animationView.update(with: LocalAnimatedSticker.duck_empty.file, size: NSMakeSize(100, 100), context: item.arguments.context, table: item.table, animated: animated)
        
        clearView.setSingle(handler: { [weak item] _ in
            item?.arguments.clearFilters()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        animationView.centerX(y: 30)
        titleView.centerX(y: animationView.frame.maxY + 10)
        clearView.centerX(y: titleView.frame.maxY + 5)
    }
}


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
        let image: CGImage?
        let attribute: State.Attribute
        init(attribute: State.Attribute, resaleState: ResaleGiftsContext.State?) {
            self.attribute = attribute
            self.image = attribute.image(resaleState)
            self.text = .init(.initialize(string: attribute.string(resaleState), color: theme.colors.darkGrayText, font: .medium(.text)))
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

        
        self.headerLayout = .init(.initialize(string: state.gift.title ?? "-", color: theme.colors.text, font: .normal(.title)))
        self.infoLayout = .init(.initialize(string: "\(state.count) for resale", color: theme.colors.grayText, font: .normal(.small)))
        
        self.items = State.Attribute.all.map { .init(attribute: $0, resaleState: state.resaleState) }

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
        return 105
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
    
    private let separatorView = View()
    
    private class AttributeItemView : Control {
        private let textView = TextView()
        private let imageView = ImageView()
        private var leftIconView: ImageView?
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
            
            
            self.contextMenu = {
                let menu = ContextMenu()
                menu.items = arguments.getMenuItems(item.attribute)
                return menu
            }
            
            if let image = item.image {
                let current: ImageView
                if let view = self.leftIconView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current)
                    self.leftIconView = current
                }
                current.image = image
                current.sizeToFit()
            } else if let view = self.leftIconView {
                performSubviewRemoval(view, animated: animated)
                self.leftIconView = nil
            }
            
            self.setFrameSize(NSMakeSize((leftIconView != nil ? 14 : 0) + item.text.layoutSize.width + imageView.frame.width + 21, 30))
            self.backgroundColor = theme.colors.grayForeground
            self.layer?.cornerRadius = 15

        }
        
        override func layout() {
            super.layout()
            
            var offset: CGFloat = 10
            if let leftIconView {
                leftIconView.centerY(x: 5)
                offset = leftIconView.frame.maxX + 5
            }
            
            self.textView.centerY(x: offset)
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
        
        //addSubview(separatorView)
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
            x += view.frame.width + 10
        }
        
        documentView.frame = NSMakeRect(0, 0, x - 10, 30)
        bottom_Container.documentView = documentView

        headerView.update(item.headerLayout)
        statusView.update(item.infoLayout)
        balanceView.set(text: item.balanceLayout, context: item.context)
        
        separatorView.backgroundColor = theme.colors.border
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.dismiss()
        }, for: .Click)
        
        needsLayout = true
        
    }
    
    func updateBorder(visible: Bool) {
        separatorView.change(opacity: visible ? 1 : 0)
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
        
        separatorView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
}

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let getMenuItems:(State.Attribute)->[ContextMenuItem]
    let toggleAttribute:(ResaleGiftsContext.Attribute)->Void
    let selectAll:(ResaleGiftsContext.Attribute)->Void
    let open:(StarGift.UniqueGift)->Void
    let clearFilters:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void, getMenuItems:@escaping(State.Attribute)->[ContextMenuItem], toggleAttribute:@escaping(ResaleGiftsContext.Attribute)->Void,
         selectAll:@escaping(ResaleGiftsContext.Attribute)->Void,
         open:@escaping(StarGift.UniqueGift)->Void,
         clearFilters:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.getMenuItems = getMenuItems
        self.toggleAttribute = toggleAttribute
        self.selectAll = selectAll
        self.open = open
        self.clearFilters = clearFilters
    }
}

private struct State : Equatable {
    
    enum Attribute {
        case sort
        case model
        case backdrop
        case symbol
        
        func image(_ state: ResaleGiftsContext.State?) -> CGImage? {
            switch self {
            case .sort:
                switch state?.sorting {
                case .date:
                    return NSImage(resource: .menuCalendarUp).precomposed(theme.colors.darkGrayText)
                case .value:
                    return NSImage(resource: .menuCashUp).precomposed(theme.colors.darkGrayText)
                case .number:
                    return NSImage(resource: .menuHashtagUp).precomposed(theme.colors.darkGrayText)
                case .none:
                    return nil
                }
            default:
                return nil
            }
        }
        
        func string(_ state: ResaleGiftsContext.State?) -> String {
            switch self {
            case .sort:
                switch state?.sorting {
                case .date:
                    return strings().giftMarketplaceAttrDate
                case .value:
                    return strings().giftMarketplaceAttrPrice
                case .number:
                    return strings().giftMarketplaceAttrNumber
                case .none:
                    return strings().giftMarketplaceAttrDate
                }
            case .model:
                let attrs = state?.filterAttributes.filter({
                    switch $0 {
                    case .model:
                        return true
                    default:
                        return false
                    }
                }).count ?? 0
                return strings().giftMarketplaceAttrModelCountable(attrs)
               
            case .backdrop:
                let attrs = state?.filterAttributes.filter({
                    switch $0 {
                    case .backdrop:
                        return true
                    default:
                        return false
                    }
                }).count ?? 0
                return strings().giftMarketplaceAttrBackdropCountable(attrs)
            case .symbol:
                let attrs = state?.filterAttributes.filter({
                    switch $0 {
                    case .pattern:
                        return true
                    default:
                        return false
                    }
                }).count ?? 0
                return strings().giftMarketplaceAttrSymbolCountable(attrs)
            }
        }
        
        static var all: [Attribute] {
            return [.sort, .model, .backdrop, .symbol]
        }
    }
    
    var gift: StarGift.Gift
    
    var starsState: StarsContext.State?
    var myBalance: Int64 {
        return starsState?.balance.value ?? 0
    }
    
    var count: Int64 {
        return self.resaleState?.count.flatMap(Int64.init) ?? self.gift.availability?.resale ?? 0
    }
    
    var resaleState: ResaleGiftsContext.State?

}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_empty = InputDataIdentifier("_id_empty")
private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
//        return HeaderItem(initialSize, stableId: stableId, state: state, context: arguments.context, arguments: arguments)
//    }))
//    sectionId += 1
  
    if let resaleState = state.resaleState {
                
        let chunks = resaleState.gifts.filter { $0.unique?.resellStars != nil }.chunks(3)
        
        let isLoading: Bool
        switch resaleState.dataState {
        case .loading:
            isLoading = true
        case .ready:
            isLoading = false
        }
        
        if !chunks.isEmpty {
            for (i, chunk) in chunks.enumerated() {
                if !chunk.isEmpty {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                        return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0.unique!, showNumber: true) }, insets: .init(left: 5, right: 5), callback: { option in
                            if let gift = option.nativeStarUniqueGift {
                                arguments.open(gift)
                            }
                        })
                    }))
                    
                    entries.append(.sectionId(sectionId, type: .customModern(10)))
                    sectionId += 1
                }
            }
        } else if isLoading {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .legacy, height: 270)
            }))
        } else {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return EmptyRowItem(initialSize, stableId: stableId, arguments: arguments)
            }))
        }
        
        
    }
    
    // entries
    
//    entries.append(.sectionId(sectionId, type: .customModern(0)))
//    sectionId += 1
    
    return entries
}

func StarGift_MarketplaceController(context: AccountContext, peerId: PeerId, gift: StarGift.Gift) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(gift: gift)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let resaleContext = ResaleGiftsContext(account: context.account, giftId: gift.id)
    
    var getController:(()->InputDataController?)? = nil
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
    }, open: { [weak resaleContext] gift in
        showModal(with: StarGift_Nft_Controller(context: context, gift: .unique(gift), source: .quickLook(nil, gift), purpose: .starGift(gift: .unique(gift), convertStars: nil, text: nil, entities: nil, nameHidden: false, savedToProfile: false, converted: false, fromProfile: false, upgraded: true, transferStars: nil, canExportDate: nil, reference: nil, sender: nil, saverId: nil, canTransferDate: nil, canResaleDate: nil), resaleContext: resaleContext, toPeerId: peerId), for: window)
    }, clearFilters: { [weak resaleContext] in
        resaleContext?.updateFilterAttributes([])
    })
    
    getMenuItems = { [weak arguments, weak resaleContext] attribute in
        
        guard let arguments else {
            return []
        }
        let state = stateValue.with { $0 }
        
        var items: [ContextMenuItem] = []
        switch attribute {
        case .sort:
            
            items.append(ContextMenuItem(strings().giftMarketplaceSortPrice, handler: {
                resaleContext?.updateSorting(.value)
            }, state: state.resaleState?.sorting == .value ? .on : nil, itemImage: MenuAnimation.menu_cash_up.value))
            
            items.append(ContextMenuItem(strings().giftMarketplaceSortDate, handler: {
                resaleContext?.updateSorting(.date)
            }, state: state.resaleState?.sorting == .date ? .on : nil, itemImage: MenuAnimation.menu_calendar_up.value))
            
            items.append(ContextMenuItem(strings().giftMarketplaceSortNumber, handler: {
                resaleContext?.updateSorting(.number)
            }, state: state.resaleState?.sorting == .number ? .on : nil, itemImage: MenuAnimation.menu_hashtag_up.value))
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
    

                if !allSelected {
                    items.append(ContextMenuItem(strings().giftMarketplaceSelectAll, handler: {
                        if let first = attrs.first?.resaleAttr {
                            arguments.selectAll(first)
                        }
                    }, state: allSelected ? .on : nil))
                    
                    items.append(ContextSeparatorItem())
                }
                
                
                
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
    
    
    let view = HeaderItemView(frame: NSMakeRect(0, 0, 368, 105))

    
    controller.contextObject_second = view
    
    controller.afterTransaction = { controller in
        let view = controller.contextObject_second as? HeaderItemView
        let item = HeaderItem(controller.frame.size, stableId: InputDataEntryId.custom(_id_header), state: stateValue.with { $0 }, context: context, arguments: arguments)
        view?.set(item: item, animated: false)
    }
    
    
    controller.didLoad = { [weak resaleContext] controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
        
        
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                resaleContext?.loadMore()
            default:
                break
            }
        }
        
        controller.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak view, weak controller] scroll in
            guard let view, let controller else {
                return
            }
            let visible = scroll.rect.minY >= (controller.tableView.frame.height)
            view.updateBorder(visible: visible)
        }))
    }
    
    controller.afterViewDidLoad = { [weak resaleContext] in
        guard let controller = getController?() else {
            return
        }
        let view = controller.contextObject_second as? HeaderItemView
        controller.genericView.set(view)
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(368, 0))
    modalController.fullSizeList = true

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



