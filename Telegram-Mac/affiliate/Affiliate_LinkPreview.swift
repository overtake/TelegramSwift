
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class HeaderItem : GeneralRowItem {
    fileprivate let peer: EnginePeer
    fileprivate let program: AffiliateProgram
    fileprivate let sendas: [SendAsPeer]
    fileprivate let arguments: Arguments
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, program: AffiliateProgram, peer: EnginePeer, sendas: [SendAsPeer], arguments: Arguments) {
        self.peer = peer
        self.program = program
        self.sendas = sendas
        self.arguments = arguments
        
        let localizedDuration = program.duration < 12 ? strings().timerMonthsCountable(Int(program.duration)) : program.duration == .max ? strings().affiliateProgramDurationLifetime : strings().timerYearsCountable(Int(program.duration / 12))
        
        self.headerLayout = .init(.initialize(string: strings().affiliateProgramLinkTitle, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1)
        
        
        
        self.infoLayout = .init(.initialize(string: strings().affiliateProgramLinkSubtitle(Int(program.commission), program.peer._asPeer().displayTitle, localizedDuration), color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        infoLayout.measure(width: blockWidth - 40)
        headerLayout.measure(width: blockWidth - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 20 + 80 + 20 + headerLayout.layoutSize.height + 10 + infoLayout.layoutSize.height + 26 + 10
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class HeaderItemView : GeneralRowView {
    
    
    class JoinedBadge : View {
        private let imageView = ImageView()
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(count: Int32) {
            self.backgroundColor = theme.colors.greenUI
            self.layer?.borderWidth = 2
            self.layer?.borderColor = theme.colors.background.cgColor
            imageView.image = NSImage(resource: .iconAffiliatePersonSmall).precomposed(theme.colors.underSelectedColor)
            imageView.sizeToFit()
            
            let layout = TextViewLayout(.initialize(string: "\(count)", color: theme.colors.underSelectedColor, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.textView.update(layout)
            
            setFrameSize(NSMakeSize(6 + imageView.frame.width + 4 + layout.layoutSize.width + 6, 20))
            
            self.layer?.cornerRadius = frame.height / 2
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            
            imageView.centerY(x: 6)
            textView.centerY(x: imageView.frame.maxX + 4)
        }
    }
    
    private let thumb = View(frame: NSMakeRect(0, 0, 80, 80))
    private let animatedSticker = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 80, 80))
    private let header = TextView()
    private let dismiss = ImageButton()
    private let info = TextView()
    private let peerView = PeerView(frame: .zero)
    
    private var joined: JoinedBadge?
    
    
    private final class PeerView: Control {
        private let avatarView = AvatarControl(font: .avatar(13))
        private let nameView: TextView = TextView()
        
        private var select: ImageView?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatarView)
            addSubview(nameView)
            
            avatarView.userInteractionEnabled = false
            
            nameView.userInteractionEnabled = false
            self.avatarView.setFrameSize(NSMakeSize(26, 26))
            
            layer?.cornerRadius = 12.5
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(_ peer: EnginePeer, sendas: [SendAsPeer], _ context: AccountContext, maxWidth: CGFloat, arguments: Arguments) {
            self.avatarView.setPeer(account: context.account, peer: peer._asPeer())
            
            let nameLayout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: sendas.isEmpty ? theme.colors.text : theme.colors.accent, font: .normal(.title)), maximumNumberOfLines: 1)
            nameLayout.measure(width: maxWidth)
            
            nameView.update(nameLayout)
            
            self.userInteractionEnabled = !sendas.isEmpty
            self.scaleOnClick = true
            
            if !sendas.isEmpty {
                let current: ImageView
                if let view = self.select {
                    current = view
                } else {
                    current = ImageView()
                    self.select = current
                    addSubview(current)
                }
                current.image = NSImage(resource: .iconAffiliateExpand).precomposed(theme.colors.accent)
                current.sizeToFit()
            } else if let select {
                performSubviewRemoval(select, animated: false)
                self.select = nil
            }
            
            if !sendas.isEmpty {
                self.contextMenu = {
                    let menu = ContextMenu()
                    for senda in sendas {
                        menu.addItem(ContextSendAsMenuItem(peer: senda, context: context, isSelected: true, handler: {
                            arguments.setGetAs(senda)
                        }))
                    }
                    return menu
                }
            } else {
                self.contextMenu = nil
            }

            setFrameSize(NSMakeSize(avatarView.frame.width + 10 + nameLayout.layoutSize.width + 10 + (sendas.isEmpty ? 0 : 16), 26))
            
            self.background = sendas.isEmpty ? theme.colors.grayForeground : theme.colors.accent.withAlphaComponent(0.2)
        }
        
        override func layout() {
            super.layout()
            nameView.centerY(x: self.avatarView.frame.maxX + 10, addition: -1)
            
            if let select {
                select.centerY(x: nameView.frame.maxX + 4)
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(thumb)
        
        thumb.addSubview(animatedSticker)
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        info.userInteractionEnabled = false
        info.isSelectable = false
        
        addSubview(header)
        addSubview(info)
        addSubview(dismiss)
        
        addSubview(peerView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        peerView.set(item.peer, sendas: item.sendas, item.arguments.context, maxWidth: frame.width - 40, arguments: item.arguments)
        
        animatedSticker.update(with: LocalAnimatedSticker.affiliate_link.file, size: NSMakeSize(80, 80), context: item.arguments.context, table: item.table, parameters: LocalAnimatedSticker.affiliate_link.parameters, animated: false)
        
        thumb.layer?.cornerRadius = thumb.frame.height / 2
        thumb.backgroundColor = theme.colors.accent
        
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.arguments.dismiss()
        }, for: .Click)
        
        info.update(item.infoLayout)
        header.update(item.headerLayout)

        
        if item.program.connected!.participants > 0 {
            let current: JoinedBadge
            if let view = self.joined {
                current = view
            } else {
                current = JoinedBadge(frame: .zero)
                self.joined = current
                addSubview(current)
            }
            current.set(count: Int32(item.program.connected!.participants))
        } else if let view = self.joined {
            performSubviewRemoval(view, animated: animated)
            self.joined = nil
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        thumb.centerX(y: 20)

        dismiss.setFrameOrigin(NSMakePoint(10, 10))
        
        header.centerX(y: thumb.frame.maxY + 20)
        info.centerX(y: header.frame.maxY + 10)
        peerView.centerX(y: info.frame.maxY + 10)
        
        if let joined {
            joined.centerX(y: thumb.frame.maxY - joined.frame.height / 2)
        }
        
    }
}



private final class Arguments {
    let context: AccountContext
    let dismiss: ()->Void
    let copyToClipboard:()->Void
    let setGetAs:(SendAsPeer)->Void
    init(context: AccountContext, dismiss: @escaping()->Void, copyToClipboard: @escaping()->Void, setGetAs:@escaping(SendAsPeer)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.copyToClipboard = copyToClipboard
        self.setGetAs = setGetAs
    }
}

private struct State : Equatable {
    var program: AffiliateProgram
    var peer: EnginePeer?
    
    var sendAs: [SendAsPeer] = []
    
    var getAs: SendAsPeer?
}

private let _id_button = InputDataIdentifier("_id_button")
private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let peer = state.getAs?.peer {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, program: state.program, peer: .init(peer), sendas: state.sendAs, arguments: arguments)
        }))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("link"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: state.program.connected!.url, font: .normal(.text), centerViewAlignment: true, hasBorder: nil, customTheme: .init(backgroundColor: theme.colors.grayForeground))
        }))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return GeneralActionButtonRowItem(initialSize, stableId: stableId, text: strings().affiliateProgramActionCopyLink, viewType: .legacy, action: arguments.copyToClipboard, inset: .init(left: 10, right: 10))
        }))
        
        
        let openedCount: String
        if let connected = state.program.connected, connected.participants > 0 {
            openedCount = strings().affiliateProgramUserCountFooterCountable(Int(connected.participants), state.program.peer._asPeer().displayTitle)
        } else {
            openedCount = strings().affiliateProgramUserCountFooterZeroValueHolder(state.program.peer._asPeer().displayTitle)
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(openedCount, linkHandler: { link in
            execute(inapp: .external(link: link, false))
        }), data: .init(color: theme.colors.listGrayText, viewType: .legacy, centerViewAlignment: true, alignment: .center)))
        index += 1
        
    }
  
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    
    
    return entries
}

func Affiliate_LinkPreview(context: AccountContext, program: AffiliateProgram, peerId: PeerId) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(program: program)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let sendas: Signal<[SendAsPeer], NoError> = context.engine.peers.getPossibleStarRefBotTargets() |> map {
        return $0.map { .init(peer: $0._asPeer(), subscribers: nil, isPremiumRequired: false) }
    }
    
    
    actionsDisposable.add(combineLatest(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)), sendas).startStrict(next: { peer, sendAs in
        updateState { current in
            var current = current
            current.peer = peer
            if let peer {
                current.getAs = .init(peer: peer._asPeer(), subscribers: nil, isPremiumRequired: false)
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

    let arguments = Arguments(context: context, dismiss: {
        close?()
    }, copyToClipboard: {
        let program = stateValue.with { $0.program }
        copyToClipboard(program.connected!.url)
        
        showModalText(for: window, text: strings().affiliateProgramToastLinkCopiedText("\(program.commission.decemial)%", program.peer._asPeer().displayTitle), title: strings().affiliateProgramToastLinkCopiedTitle)
        close?()
    }, setGetAs: { value in
        updateState { current in
            var current = current
            current.getAs = value
            return current
        }
        _ = context.engine.peers.connectStarRefBot(id: value.peer.id, botId: peerId).start()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
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



