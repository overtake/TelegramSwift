
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var message: EngineMessage
    var peer: EnginePeer
}

private final class HeaderItem : GeneralRowItem {
    let context: AccountContext
    fileprivate let message: Message
    fileprivate let messageItem: TableRowItem
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        let interactions = ChatInteraction(chatLocation: .peer(context.peerId), context: context, isLogInteraction: true)
        messageItem = ChatRowItem.item(initialSize, from: .MessageEntry(message, .init(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, .init()), interaction: interactions, theme: theme)
        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        _ = messageItem.makeSize(width)
        
        return true
    }
    
    override var height: CGFloat {
        return  messageItem.height + 20
    }
    
    override func viewClass() -> AnyClass {
        return HeaderRowView.self
    }
}


private final class HeaderRowView: GeneralContainableRowView {
    private let backgroundView = BackgroundView(frame: .zero)
    private let tableView: TableView
    required init(frame frameRect: NSRect) {
        tableView = TableView(frame: frameRect.size.bounds, isFlipped: false)
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            return .clear
        }
        
        
    }
    
     required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        self.layout()
        
        backgroundView.backgroundMode = theme.backgroundMode
        
        guard let item = item as? HeaderItem else {
            return
        }
        _ = tableView.addItem(item: GeneralRowItem(containerView.frame.size, height: 10, stableId: arc4random64(), backgroundColor: .clear))
        _ = tableView.addItem(item: item.messageItem)
        _ = tableView.addItem(item: GeneralRowItem(containerView.frame.size, height: 10, stableId: arc4random64(), backgroundColor: .clear))
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundView.frame = containerView.bounds
        self.tableView.frame = containerView.bounds

    }
}

private let _id_custom = InputDataIdentifier("_id_custom")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().webappShareMessagePreview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_custom, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, message: state.message._asMessage())
    }))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().webappShareMessageBotInfo(state.peer._asPeer().displayTitle)), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))

    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

enum WebbotShareMessageStatus {
    case success
    case failed
}

func WebbotShareMessageModal(context: AccountContext, bot: EnginePeer, preparedMessage: PreparedInlineMessage, window: Window, callback: @escaping(WebbotShareMessageStatus)->Void) -> InputDataModalController {

    var close:(()->Void)? = nil
    
    let actionsDisposable = DisposableSet()
    
    
    var text: String = ""
    var entities: TextEntitiesMessageAttribute?
    var media: [Media] = []
    
    switch preparedMessage.result {
    case let .internalReference(reference):
        switch reference.message {
        case let .auto(textValue, entitiesValue, _):
            text = textValue
            entities = entitiesValue
            if let file = reference.file {
                media = [file]
            } else if let image = reference.image {
                media = [image]
            }
        case let .text(textValue, entitiesValue, disableUrlPreview, previewParameters, _):
            text = textValue
            entities = entitiesValue
            let _ = disableUrlPreview
            let _ = previewParameters
        case let .contact(contact, _):
            media = [contact]
        case let .mapLocation(map, _):
            media = [map]
        case let .invoice(invoice, _):
            media = [invoice]
        default:
            break
        }
    case let .externalReference(reference):
        switch reference.message {
        case let .auto(textValue, entitiesValue, _):
            text = textValue
            entities = entitiesValue
            if let content = reference.content {
                media = [content]
            }
        case let .text(textValue, entitiesValue, disableUrlPreview, previewParameters, _):
            text = textValue
            entities = entitiesValue
            let _ = disableUrlPreview
            let _ = previewParameters
        case let .contact(contact, _):
            media = [contact]
        case let .mapLocation(map, _):
            media = [map]
        case let .invoice(invoice, _):
            media = [invoice]
        default:
            break
        }
    }

    var attributes: [MessageAttribute] = []
    
    attributes.append(InlineBotMessageAttribute.init(peerId: bot.id, title: bot._asPeer().displayTitle))
    if let entities {
        attributes.append(entities)
    }
    
    
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: bot.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: context.timestamp, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: bot._asPeer(), text: text, attributes: attributes, media: media, peers:SimpleDictionary([bot.id : bot._asPeer()]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])



    let initialState = State(message: .init(firstMessage), peer: bot)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    let controller = InputDataController(dataSignal: signal, title: strings().webappShareMessageShare)
    
    getController = { [weak controller] in
        return controller
    }
    
    
    var closedFromShare = false
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        if !closedFromShare {
            callback(.failed)
        }
    }
    
    controller.validateData = { [weak window] _ in
        if let window {
            showModal(with: ShareModalController(ShareChatContextResult(context, preparedMessage: preparedMessage), completion: { value in
                closedFromShare = true
                callback(value ? .success : .failed)
                closeAllModals(window: window)
            }), for: window)
        }
        
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Share With...", accept: { [weak controller] in
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


/*
 
 */



