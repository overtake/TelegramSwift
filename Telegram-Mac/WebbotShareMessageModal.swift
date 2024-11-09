
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
}

private final class HeaderItem : GeneralRowItem {
    let context: AccountContext
    fileprivate let message: Message
    fileprivate let messageItem: TableRowItem
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        messageItem = ChatRowItem.item(initialSize, from: .MessageEntry(message, .init(message), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, .init()), interaction: ChatInteraction.init(chatLocation: .peer(context.peerId), context: context), theme: theme)
        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        _ = messageItem.makeSize(width)
        
        return true
    }
    
    override var height: CGFloat {
        return 100 + messageItem.height
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MESSAGE PREVIEW"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_custom, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, message: state.message._asMessage())
    }))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Bums mini app suggests you to send this message to a chat you select."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))

    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func WebbotShareMessageModal(context: AccountContext, preparedMessage: PreparedInlineMessage) -> InputDataModalController {

    var close:(()->Void)? = nil
    
    let actionsDisposable = DisposableSet()
    
    
    
    let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil)
    
    let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil)
    
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 18 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: fromUser1, text: strings().appearanceSettingsChatPreview1, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])


    let initialState = State(message: .init(firstMessage))
    
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

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Share Message")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
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



