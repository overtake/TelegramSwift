
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

private final class HeaderItem : GeneralRowItem {
    fileprivate let peer: EnginePeer
    fileprivate let context: AccountContext
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, context: AccountContext) {
        self.peer = peer
        self.context = context
        self.textLayout = .init(.initialize(string: "**\(peer._asPeer().displayTitle)** is requesting permission to import data from a previous Telegram account used on this device.", color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 70 + 15 + textLayout.layoutSize.height
    }
    
}

private final class HeaderItemView : GeneralRowView {
    private let textView = TextView()
    private let avatarView = AvatarControl(font: .avatar(20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(avatarView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        avatarView.setFrameSize(NSMakeSize(70, 70))
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        avatarView.centerX(y: 0)
        textView.centerX(y: avatarView.frame.maxY + 15)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        self.textView.update(item.textLayout)
        self.avatarView.setPeer(account: item.context.account, peer: item.peer._asPeer())
        
        needsLayout = true
    }
}

private final class Arguments {
    let context: AccountContext
    let select:(String)->Void
    init(context: AccountContext, select:@escaping(String)->Void) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    var list: [WebAppSecureStorage.ExistingKey] = []
    var selected: String?
    var peer: EnginePeer
}

private func _id_uuid(_ id: String) -> InputDataIdentifier {
    return .init("_id_uuid_\(id)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_id_header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, peer: state.peer, context: arguments.context)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    struct Tuple : Equatable {
        var peer: WebAppSecureStorage.ExistingKey
        var viewType: GeneralViewType
        var selected: Bool
    }
    
    var tuples: [Tuple] = []
    for (i, peer) in state.list.enumerated() {
        tuples.append(.init(peer: peer, viewType: bestGeneralViewType(state.list, for: i), selected: peer.uuid == state.selected))
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ACCOUNT TO IMPORT DATA FROM"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    for tuple in tuples {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_uuid(tuple.peer.uuid), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tuple.peer.accountName, description: "Created at \(stringForFullDate(timestamp: tuple.peer.timestamp))", type: .selectableLeft(tuple.selected), viewType: tuple.viewType, action: {
                arguments.select(tuple.peer.uuid)
            })
        }))
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func WebappTransferDataController(context: AccountContext, peer: EnginePeer, storedKeys: [WebAppSecureStorage.ExistingKey], completion:@escaping(String?)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(list: storedKeys, peer: peer)
    
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

    let arguments = Arguments(context: context, select: { value in
        updateState { current in
            var current = current
            if current.selected == value {
                current.selected = nil
            } else {
                current.selected = value
            }
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    
    controller.centerModalHeader = .init(title: strings().webAppTransferDataImportData)
    
    getController = { [weak controller] in
        return controller
    }
    
    var success = false
    
    controller.validateData = { _ in
        let selected = stateValue.with { $0.selected }
        let list = stateValue.with { $0.list }
        if selected == nil {
            var fields:[InputDataIdentifier: InputDataValidationFailAction] = [:]
            for item in list {
                fields[_id_uuid(item.uuid)] = .shake
            }
            return .fail(.fields(fields))
        } else {
            success = true
            completion(selected ?? "")
            close?()
        }
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        if !success {
            completion(nil)
        }
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().webAppTransferDataImport, accept: { [weak controller] in
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
    
}





