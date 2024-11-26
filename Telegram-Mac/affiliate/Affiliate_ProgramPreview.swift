

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class HeaderItem : GeneralRowItem {
    fileprivate let program: AffiliateProgram
    fileprivate let peer: EnginePeer
    fileprivate let arguments: Arguments
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, program: AffiliateProgram, peer: EnginePeer, arguments: Arguments) {
        self.program = program
        self.peer = peer
        self.arguments = arguments
        
        let localizedDuration = program.duration < 12 ? strings().timerMonthsCountable(Int(program.duration)) : program.duration == .max ? "Lifetime" : strings().timerYearsCountable(Int(program.duration / 12))

        
        self.headerLayout = .init(.initialize(string: "Affiliate Program", color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1)
        self.infoLayout = .init(.initialize(string: "**\(program.peer._asPeer().displayTitle)** will share **\(program.commission)%** of the revenue from each user you refer to it for **\(localizedDuration)**.", color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        infoLayout.measure(width: width - 40)
        headerLayout.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 20 + 80 + 20 + headerLayout.layoutSize.height + 10 + infoLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class HeaderItemView : GeneralRowView {
    private let fromPeer = AvatarControl(font: .avatar(20))
    private let toPeer = AvatarControl(font: .avatar(20))
    private let next = ImageView()
    private let container = View()
    private let badge: ImageView = ImageView()
    
    private let header = TextView()
    private let dismiss = ImageButton()
    private let info = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.addSubview(fromPeer)
        container.addSubview(toPeer)
        container.addSubview(next)
        container.addSubview(badge)
        addSubview(container)
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        info.userInteractionEnabled = false
        info.isSelectable = false
        
        addSubview(header)
        addSubview(info)
        addSubview(dismiss)
        
        fromPeer.setFrameSize(NSMakeSize(80, 80))
        toPeer.setFrameSize(NSMakeSize(80, 80))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        container.layer?.masksToBounds = false
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.close()
        }, for: .Click)
        
        next.image = NSImage(resource: .iconAffiliateChevron).precomposed(theme.colors.grayIcon)
        next.sizeToFit()
        
        badge.image = generateImage(NSMakeSize(34, 34), contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(theme.colors.background.cgColor)
            ctx.round(size, size.width / 2)
            ctx.fill(size.bounds)
            
            let image = NSImage(resource: .iconAffiliateBadge).precomposed()
            
            ctx.draw(image, in: size.bounds.focus(image.systemSize))
        })
        badge.sizeToFit()
        
        fromPeer.setPeer(account: item.arguments.context.account, peer: item.program.peer._asPeer())
        toPeer.setPeer(account: item.arguments.context.account, peer: item.peer._asPeer())
        container.setFrameSize(NSMakeSize(fromPeer.frame.width + toPeer.frame.width + 40, 80))
        
        info.update(item.infoLayout)
        header.update(item.headerLayout)

    }
    
    override func layout() {
        super.layout()
        container.centerX(y: 20)
        fromPeer.centerY(x: 0)
        next.center()
        toPeer.centerY(x: container.frame.width - toPeer.frame.width)
        
        dismiss.setFrameOrigin(NSMakePoint(10, 10))
        
        header.centerX(y: container.frame.maxY + 20)
        info.centerX(y: header.frame.maxY + 10)
        
        badge.setFrameOrigin(NSMakePoint(toPeer.frame.maxX - badge.frame.width, toPeer.frame.height - badge.frame.height))
    }
}


struct AffiliateProgram : Equatable {
    var peer: EnginePeer
    var commission: Int32
    var commission2: Int32
    var duration: Int32
    var date: Int32
    var revenue: Int32
}

private final class Arguments {
    let context: AccountContext
    let close:()->Void
    init(context: AccountContext, close:@escaping()->Void) {
        self.close = close
        self.context = context
    }
}

private struct State : Equatable {
    var program: AffiliateProgram
    var peer: EnginePeer?
}


private let _id_button = InputDataIdentifier("_id_button")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0

    // entries
    
    if let peer = state.peer {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, program: state.program, peer: peer, arguments: arguments)
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return GeneralActionButtonRowItem(initialSize, stableId: stableId, text: "Join Program", viewType: .legacy, action: {
            
        }, inset: .init(left: 10, right: 10))
    }))
    
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("By joining this program, you agree to the [Terms and Services](https://telegram.org) of Affiliate Programs.", linkHandler: { link in
        execute(inapp: .external(link: link, false))
    }), data: .init(color: theme.colors.listGrayText, viewType: .legacy, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}



func Affiliate_ProgramPreview(context: AccountContext, peerId: PeerId, program: AffiliateProgram) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(program: program)
    
    var close:(()->Void)? = nil
    
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

    actionsDisposable.add(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)).startStrict(next: { peer in
        updateState { current in
            var current = current
            current.peer = peer
            return current
        }
    }))
    
    let arguments = Arguments(context: context, close: {
        close?()
    })
    
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

    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
    }
    
    let modalController = InputDataModalController(controller)
    
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



