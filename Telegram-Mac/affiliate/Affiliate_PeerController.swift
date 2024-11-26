
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox




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
        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateShield).precomposed(theme.colors.accent), header: .init(.initialize(string: "Reliable", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Receive guaranteed commissions for spending by users you refer.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateEye).precomposed(theme.colors.accent), header: .init(.initialize(string: "Transparent", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Track your commissions from referred users in real time.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconBotAffiliateThumb).precomposed(theme.colors.accent), header: .init(.initialize(string: "Simple", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Choose a mini app below, get your referral link, and start earning Stars.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
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


private final class AffiliateRowItem: GeneralRowItem {
    fileprivate let arguments: Arguments
    fileprivate let item: AffiliateProgram
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let commissionLayout: TextViewLayout
    fileprivate let durationLayout: TextViewLayout
    
    fileprivate let commission2Layout: TextViewLayout?
    fileprivate let plusLayout: TextViewLayout?

    init(_ initialSize: NSSize, stableId: AnyHashable, item: AffiliateProgram, arguments: Arguments, viewType: GeneralViewType) {
        self.arguments = arguments
        self.item = item
        
        self.titleLayout = .init(.initialize(string: item.peer._asPeer().displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.commissionLayout = .init(.initialize(string: "\(item.commission)%", color: theme.colors.underSelectedColor, font: .menlo(.small)), alignment: .center)
        self.commissionLayout.measure(width: .greatestFiniteMagnitude)
        
        let localizedDuration = item.duration < 12 ? strings().timerMonthsCountable(Int(item.duration)) : strings().timerYearsCountable(Int(item.duration / 12))

        
        self.durationLayout = .init(.initialize(string: localizedDuration, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        
        if item.commission2 > 0 {
            self.commission2Layout = .init(.initialize(string: "\(item.commission2)%", color: theme.colors.underSelectedColor, font: .menlo(.small)), alignment: .center)
            self.commission2Layout?.measure(width: .greatestFiniteMagnitude)
            
            self.plusLayout = .init(.initialize(string: "+", color: theme.colors.grayText, font: .menlo(.small)), alignment: .center)
            self.plusLayout?.measure(width: .greatestFiniteMagnitude)

        } else {
            self.commission2Layout = nil
            self.plusLayout = nil
        }
        
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        
        items.append(.init("Open App", handler: {
            
        }, itemImage: MenuAnimation.menu_folder_bot.value))
        
        items.append(.init("Copy Link", handler: {
            
        }, itemImage: MenuAnimation.menu_copy_link.value))
        
        items.append(.init("Leave", handler: {
            
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value))
        
        return .single(items)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.titleLayout.measure(width: blockWidth - 60)
        self.durationLayout.measure(width: blockWidth - 60 - commissionLayout.layoutSize.width - 10)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return AffiliateRowView.self
    }
}

private final class AffiliateRowView : GeneralContainableRowView {
    private let avatar = AvatarControl(font: .avatar(15))
    private let title = TextView()
    private let commission = TextView()
    
    private var commission2: TextView?
    private var plus: TextView?

    
    private let duration = TextView()
    private let next = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        avatar.setFrameSize(NSMakeSize(36, 36))
        
        commission.userInteractionEnabled = false
        commission.isSelectable = false
        
        duration.userInteractionEnabled = false
        duration.isSelectable = false
        
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        addSubview(avatar)
        addSubview(commission)
        addSubview(duration)
        addSubview(next)
        addSubview(title)
        
        
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
            guard let item = self?.item as? AffiliateRowItem else {
                return
            }
            item.arguments.open(item.item)
        }, for: .Click)
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? AffiliateRowItem {
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
        
        guard let item = item as? AffiliateRowItem else {
            return
        }
        
        
        self.commission.update(item.commissionLayout)
        self.duration.update(item.durationLayout)
        self.title.update(item.titleLayout)
        
        
        commission.backgroundColor = theme.colors.accent
        commission.setFrameSize(NSMakeSize(commission.frame.width + 4, commission.frame.height + 2))
        commission.layer?.cornerRadius = 4
        
        avatar.setPeer(account: item.arguments.context.account, peer: item.item.peer._asPeer())
        
        next.image = theme.icons.generalNext
        next.sizeToFit()
        
        if let commission2Layout = item.commission2Layout {
            let current: TextView
            if let view = self.commission2 {
                current = view
            } else {
                current = TextView()
                self.addSubview(current)
                self.commission2 = current
                current.userInteractionEnabled = false
                current.isSelectable = false
            }
            current.update(commission2Layout)
            
            current.backgroundColor = theme.colors.greenUI
            current.setFrameSize(NSMakeSize(current.frame.width + 4, current.frame.height + 2))
            current.layer?.cornerRadius = 4

            
        } else if let view = self.commission2 {
            performSubviewRemoval(view, animated: animated)
            self.commission2 = nil
        }
        
        if let plusLayout = item.plusLayout {
            let current: TextView
            if let view = self.plus {
                current = view
            } else {
                current = TextView()
                self.addSubview(current)
                self.plus = current
                current.userInteractionEnabled = false
                current.isSelectable = false
            }
            current.update(plusLayout)
        } else if let view = self.plus {
            performSubviewRemoval(view, animated: animated)
            self.plus = nil
        }
        
        needsLayout = true
    }
    override var additionBorderInset: CGFloat {
        return 36 + 10
    }
    
    
    override func layout() {
        super.layout()
        avatar.centerY(x: 10)
        
        self.title.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, 5))
        self.commission.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, frame.height - 7 - self.commission.frame.height))
        
        if let commission2, let plus {
            
            plus.setFrameOrigin(NSMakePoint(commission.frame.maxX + 5, frame.height - 7 - plus.frame.height))
            commission2.setFrameOrigin(NSMakePoint(plus.frame.maxX + 5, frame.height - 7 - commission2.frame.height))

            self.duration.setFrameOrigin(NSMakePoint(commission2.frame.maxX + 5, frame.height - 7 - self.duration.frame.height))
        } else {
            self.duration.setFrameOrigin(NSMakePoint(self.commission.frame.maxX + 5, frame.height - 7 - self.duration.frame.height))
        }
        
        
        next.centerY(x: containerView.frame.width - 12 - next.frame.width)
    }
}


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
        title = .initialize(string: "Affiliate Programs", color: presentation.colors.text, font: .medium(.header))
        _ = info.append(string: "Earn a commission each time a user who first accessed a mini app through your referral link spends **Starts** within it.", color: presentation.colors.text, font: .normal(.text))

        info.detectBoldColorInString(with: .medium(.text))
        
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



private final class Arguments {
    let context: AccountContext
    let toggleSort:(State.Sort)->Void
    let open:(AffiliateProgram)->Void
    init(context: AccountContext, toggleSort:@escaping(State.Sort)->Void, open:@escaping(AffiliateProgram)->Void) {
        self.context = context
        self.toggleSort = toggleSort
        self.open = open
    }
}

private struct State : Equatable {
    
    enum Sort {
        case date
        case commission
        case revenue
        
        var string: String {
            switch self {
            case .date:
                return "Date"
            case .commission:
                return "Commission"
            case .revenue:
                return "Revenue"
            }
        }
    }
    var peers: [AffiliateProgram] = []
    
    var sort: Sort = .date
    
    
    var sorted: [AffiliateProgram] {
        switch sort {
        case .date:
            return self.peers.sorted(by: { $0.date > $1.date })
        case .commission:
            return self.peers.sorted(by: { $0.commission > $1.commission })
        case .revenue:
            return self.peers.sorted(by: { $0.revenue > $1.revenue })
        }
    }
}


private func _id_peer_id(_ peerId: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_id_\(peerId.toInt64())")
}

private let _id_promo = InputDataIdentifier("_id_promo")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, presentation: theme, peer: nil, viewType: .legacy)
    }))
   
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_promo, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PromoItem(initialSize, stableId: stableId, context: arguments.context)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let sortString = NSMutableAttributedString()
    sortString.append(string: "SORT BY", color: theme.colors.listGrayText, font: .normal(.text))
    sortString.append(string: " ", color: theme.colors.listGrayText, font: .normal(.text))
    sortString.append(string: state.sort.string.uppercased(), color: theme.colors.accent, font: .normal(.text))

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(" "), data: .init(viewType: .textTopItem, rightItem: .init(isLoading: false, text: sortString, contextMenu: {
        var items: [ContextMenuItem] = []
        
        let sortAll: [State.Sort] = [.date, .revenue, .commission]
        
        for sort in sortAll {
            items.append(ContextMenuItem(sort.string, handler: {
                arguments.toggleSort(sort)
            }))
        }
        return items
    }, afterImage: NSImage(resource: .iconAffiliateExpand).precomposed(theme.colors.accent)))))
    index += 1
    
    struct Tuple : Equatable {
        var peer: AffiliateProgram
        var viewType: GeneralViewType
    }
  
    var tuples: [Tuple] = []
    for (i, peer) in state.sorted.enumerated() {
        tuples.append(.init(peer: peer, viewType: bestGeneralViewType(state.peers, for: i)))
    }
    
    for tuple in tuples {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_id(tuple.peer.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return AffiliateRowItem(initialSize, stableId: stableId, item: tuple.peer, arguments: arguments, viewType: tuple.viewType)
        }))
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func Affiliate_PeerController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let bots: Signal<[EnginePeer], NoError> = context.account.viewTracker.tailChatListView(groupId: .root, count: 100) |> take(1) |> map { value in
        return value.0.entries.compactMap { value in
            switch value {
            case let .MessageEntry(data):
                if let message = data.messages.first {
                    if let peer = message.peers[message.id.peerId], peer.isBot {
                        return EnginePeer(peer)
                    }
                }
            default:
                return nil
            }
            return nil
        }
    }
    
    actionsDisposable.add(bots.startStrict(next: { peers in
        updateState { current in
            var current = current
            current.peers = peers.map {
                .init(peer: $0, commission: Int32.random(in: 1...90), commission2: Int32.random(in:0...50), duration: Int32.random(in: 3...36), date: context.timestamp - Int32.random(in: 0..<10000000), revenue: Int32.random(in: 0...100000000))
            }
            return current
        }
    }))
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, toggleSort: { sort in
        updateState { current in
            var current = current
            current.sort = sort
            return current
        }
    }, open: { program in
        if Int32.random(in: 0..<Int32.max) % 2 == 0 {
            showModal(with: Affiliate_ProgramPreview(context: context, peerId: peerId, program: program), for: window)
        } else {
            showModal(with: Affiliate_LinkPreview(context: context, link: .init(count: Int32.random(in: 0..<100)), program: program, peerId: peerId), for: window)
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Affiliate Programs", removeAfterDisappear: false)
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}


/*
 let modalInteractions = ModalInteractions(acceptTitle: "PAY", accept: { [weak controller] in
     _ = controller?.returnKeyAction()
 }, singleButton: true)
 
 let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
 
 controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
     modalController?.close()
 })
 
 close = { [weak modalController] in
     modalController?.modal?.close()
 }
 
 return modalController
 */



