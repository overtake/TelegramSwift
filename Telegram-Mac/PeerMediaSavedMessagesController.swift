//
//  ChatSavedMessagesMediaController.swift
//  Telegram
//
//  Created by Mike Renoir on 28.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private class LoadingItem: TableRowItem {
    
    override var height: CGFloat {
        if let table = table {
            var tableHeight: CGFloat = 0
            table.enumerateItems { item -> Bool in
                if item.index < self.index {
                    tableHeight += item.height
                }
                return true
            }
            let height = table.frame.height == 0 ? initialSize.height : table.frame.height
            return height - tableHeight
        }
        return initialSize.height
    }
    
    override func viewClass() -> AnyClass {
        return LoadingView.self
    }
}


private class LoadingView : TableRowView {
    private let indicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    private let view = VisualEffect(frame: NSMakeRect(0, 0, 40, 40))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        view.addSubview(indicator)
        addSubview(view)
        view.layer?.cornerRadius = view.frame.height / 2
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    deinit {
    }
    
    
    override func layout() {
        super.layout()
        view.center()
        indicator.center()
    }
    
}



private final class Arguments {
    let context: AccountContext
    let chatInteraction: ChatInteraction
    let findGroupStableId:(AnyHashable)->AnyHashable?
    init(context: AccountContext, chatInteraction: ChatInteraction, findGroupStableId:@escaping(AnyHashable)->AnyHashable?) {
        self.context = context
        self.chatInteraction = chatInteraction
        self.findGroupStableId = findGroupStableId
    }
}

private struct SearchMessagesTuple : Equatable {
    let resultState: SearchMessagesResultState
    let state: SearchMessagesState?
    let loading: Bool
    let searchState: SearchState
}

private struct State : Equatable {
    var searchMessages: SearchMessagesTuple?
    var pollAnswers: [MessageId : ChatPollStateData] = [:]
    var mediaRevealed: Set<MessageId> = Set()
    var appearance: Appearance = appAppearance
}


private final class HistoryView {
    let view: MessageHistoryView?
    let entries: [ChatWrappedEntry]
    let state: State
    let isLoading: Bool
    init(view:MessageHistoryView?, entries: [ChatWrappedEntry], state: State, isLoading: Bool) {
        self.view = view
        self.entries = entries
        self.state = state
        self.isLoading = isLoading
    }
    
    deinit {
        
    }
}

private class MessageIdenfitifer : InputDataIdentifier {
    private let entryId: ChatHistoryEntryId
    init(_ entryId: ChatHistoryEntryId) {
        self.entryId = entryId
        super.init("id")
    }
    override func isEqual(to: InputDataIdentifier) -> Bool {
        if let to = to as? MessageIdenfitifer {
            return to.entryId == self.entryId
        } else {
            return false
        }
    }
}


private let _id_loading = InputDataIdentifier("_id_loading")
private func _id_entry(_ entry: ChatWrappedEntry) -> InputDataIdentifier {
    return MessageIdenfitifer(entry.entry.stableId)
}

private func entries(_ view: HistoryView, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    func makeItem(_ entry: ChatWrappedEntry, initialSize: NSSize) -> TableRowItem {
        let presentation: TelegramPresentationTheme = entry.entry.additionalData.chatTheme ?? theme
        let item:TableRowItem = ChatRowItem.item(initialSize, from: entry.appearance.entry, interaction: arguments.chatInteraction, theme: presentation)
        _ = item.makeSize(initialSize.width)
        return item;
    }
  
    if view.isLoading {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(view.state), comparable: nil, item: { initialSize, stableId in
            return LoadingItem(initialSize, stableId: stableId)
        }))
    } else if let searchMessages = view.state.searchMessages, searchMessages.loading {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(view.state), comparable: nil, item: { initialSize, stableId in
            return LoadingItem(initialSize, stableId: stableId)
        }))
    } else if !view.entries.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        for entry in view.entries {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_entry(entry), equatable: .init(entry), comparable: nil, item: { initialSize, _ in
                return makeItem(entry, initialSize: initialSize)
            }))
        }
            
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    
    return entries
}

private final class TableDelegate : TableViewDelegate {
    
    private let arguments: Arguments
    init(_ arguments: Arguments) {
        self.arguments = arguments
    }
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
       
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return false
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return false
    }
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return arguments.findGroupStableId(stableId)
    }
}



private var nextId: Int32 = 0
private func getNextId() -> Int32 {
    return OSAtomicIncrement32(&nextId)
}

func PeerMediaSavedMessagesController(context: AccountContext, peerId: PeerId) -> InputDataController {
    
    let actionsDisposable = DisposableSet()
    let pollOptionDisposable = DisposableDict<MessageId>()
    
    actionsDisposable.add(pollOptionDisposable)
    
    let initialState = State()
    let search = InputDataMediaSearchContext()
    
    var getController:(()->InputDataController?)? = nil
    var getScreenEffect:(()->EmojiScreenEffect?)?
    var afterNextTransaction:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let location: ChatLocation = .makeSaved(context.peerId, peerId: peerId)
    let mode: ChatMode = .thread(mode: .saved(origin: .init(peerId: peerId, namespace: 0, id: 0)))
    
    let chatInteraction = ChatInteraction(chatLocation: location, context: context, mode: mode, isPeerSavedMessages: true)
    
    var selectText: ChatSelectText? = nil
    
    
    actionsDisposable.add(context.engine.stickers.refreshSavedMessageTags(subPeerId: peerId).startStrict())

    
    
    chatInteraction.openInfo = { peerId, toChat, postId, action in
        let navigation = context.bindings.rootNavigation()
        if toChat {
            navigateToChat(navigation: navigation, context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: postId), initialAction: action)
        } else {
            PeerInfoController.push(navigation: navigation, context: context, peerId: peerId)
        }
    }
    chatInteraction.focusMessageId = { fromId, focusTarget, state in
        let navigation = context.bindings.rootNavigation()
        navigation.push(ChatAdditionController(context: context, chatLocation: .peer(focusTarget.messageId.peerId), focusTarget: focusTarget))
    }
    chatInteraction.runReactionEffect = { value, messageId in
        getScreenEffect?()?.addReactionAnimation(value, index: nil, messageId: messageId, animationSize: NSMakeSize(80, 80), viewFrame: context.window.bounds, for: context.window.contentView!)
    }
    chatInteraction.vote = { messageId, opaqueIdentifiers, submit in
        
        updateState { state in
            var state = state
            var data = state.pollAnswers
            data[messageId] = ChatPollStateData(identifiers: opaqueIdentifiers, isLoading: submit && !opaqueIdentifiers.isEmpty)
            state.pollAnswers = data
            return state
        }
        
        let signal:Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError>
        
        if submit {
            if opaqueIdentifiers.isEmpty {
                signal = showModalProgress(signal: (context.engine.messages.requestMessageSelectPollOption(messageId: messageId, opaqueIdentifiers: []) |> deliverOnMainQueue), for: context.window)
            } else {
                signal = (context.engine.messages.requestMessageSelectPollOption(messageId: messageId, opaqueIdentifiers: opaqueIdentifiers) |> deliverOnMainQueue)
            }
            
            pollOptionDisposable.set(signal.start(next: { poll in
                if let poll = poll {
                    updateState { state in
                        var state = state
                        var data = state.pollAnswers
                        data.removeValue(forKey: messageId)
                        state.pollAnswers = data
                        return state
                    }
                    var once: Bool = true
                    afterNextTransaction = {
                        if let controller = getController?(), once {
                            let tableView = controller.genericView.tableView
                            tableView.enumerateItems(with: { item -> Bool in
                                if let item = item as? ChatRowItem, let message = item.message, message.id == messageId {
                                    
                                    let entry = item.entry.withUpdatedMessageMedia(poll)
                                    let size = controller.atomicSize.with { $0 }
                                    let updatedItem = ChatRowItem.item(size, from: entry, interaction: chatInteraction, theme: theme)
                                    
                                    _ = updatedItem.makeSize(size.width, oldWidth: 0)
                                    
                                    tableView.merge(with: .init(deleted: [], inserted: [], updated: [(item.index, updatedItem)], animated: true))
                                    
                                    let view = item.view as? ChatPollItemView
                                    if let view = view, view.window != nil, view.visibleRect != .zero {
                                        view.doAfterAnswer()
                                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
                                    }
                                    return false
                                }
                                return true
                            })
                            once = false
                        }
                    }
                    
                    if opaqueIdentifiers.isEmpty {
                        afterNextTransaction?()
                    }
                }
                
            }, error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: strings().unknownError)
                }
                updateState { state in
                    var state = state
                    var data = state.pollAnswers
                    data.removeValue(forKey: messageId)
                    state.pollAnswers = data
                    return state
                }
                
            }), forKey: messageId)
        }
        
    }
    chatInteraction.closePoll = { messageId in
        pollOptionDisposable.set(context.engine.messages.requestClosePoll(messageId: messageId).start(), forKey: messageId)
    }
    
    chatInteraction.revealMedia = { message in
        updateState { current in
            var current = current
            current.mediaRevealed.insert(message.id)
            return current
        }
    }
    
    let historyLocation:Promise<ChatHistoryLocationInput> = Promise()
    let _locationValue:Atomic<ChatHistoryLocationInput?> = Atomic(value: nil)
    var locationValue:ChatHistoryLocationInput? {
        return _locationValue.with { $0 }
    }
    func setLocation(_ lc: ChatHistoryLocationInput) {
        _ = _locationValue.swap(lc)
        historyLocation.set(.single(lc))
    }
    
    func setInitialLocation() {
        setLocation(.init(content: .Navigation(index: .upperBound, anchorIndex: .upperBound, count: 100, side: .upper), chatLocation: location, tag: nil, id: getNextId()))
    }
    
    let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
    
    let history = historyLocation.get() |> mapToSignal { historyLocation in
        return chatHistoryViewForLocation(historyLocation.content, context: context, chatLocation: location, fixedCombinedReadStates: { nil }, tag: nil, mode: mode, additionalData: [], chatLocationContextHolder: chatLocationContextHolder)
    }
    
    let wallpaper: Signal<TelegramWallpaper?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
    |> map { cachedData in
        if let cachedData = cachedData as? CachedChannelData {
            return cachedData.wallpaper
        } else if let cachedData = cachedData as? CachedUserData {
            return cachedData.wallpaper
        } else {
            return nil
        }
    }
    
    let appearance: Signal<Appearance, NoError> = combineLatest(appearanceSignal, wallpaper, context.chatThemes) |> map { appearance, wallpaper, chatThemes in
        
        var theme = appearance.presentation.withUpdatedEmoticonThemes(chatThemes)
        if let wallpaper = wallpaper {
            theme = theme.withUpdatedWallpaper(.init(wallpaper: .init(wallpaper), associated: nil))
        }
        return .init(language: appearance.language, presentation: theme)
    }
    
    
    
    
    let messagesLocation: SearchMessagesLocation = .peer(peerId: context.peerId, fromId: nil, tags: nil, reactions: nil, threadId: peerId.toInt64(), minDate: nil, maxDate: nil)
    
    
    let searchResult:Signal<SearchMessagesTuple?, NoError> = search.searchState.get() |> mapToSignal { searchState in
        
        let empty: Signal<SearchMessagesTuple?, NoError> = .single(nil)
        let loading: Signal<SearchMessagesTuple?, NoError> = .single(.init(resultState: .init(searchState.request, []), state: nil, loading: true, searchState: searchState))
        
        if searchState.request.isEmpty {
            return empty
        } else {
            return loading |> then(context.engine.messages.searchMessages(location: messagesLocation, query: searchState.request, state: nil) |> map { state in
                return .init(resultState: .init(searchState.request, state.0.messages), state: state.1, loading: false, searchState: searchState)
            } |> delay(0.2, queue: .concurrentBackgroundQueue()))
        }
    } |> deliverOnMainQueue
    
    actionsDisposable.add(searchResult.startStrict(next: { searchResult in
        let current = stateValue.with { $0.searchMessages }
        
        updateState { current in
            var current = current
            current.searchMessages = searchResult
            return current
        }
        
        if searchResult?.searchState.request != current?.searchState.request {
            setInitialLocation()
        }
    }))
    
    let historyView: Signal<HistoryView, NoError> = combineLatest(history, statePromise.get()) |> map { update, state -> HistoryView in
        let isLoading: Bool
        let view: MessageHistoryView?
        let initialData: ChatHistoryCombinedInitialData
        switch update {
        case let .Loading(data, _):
            view = nil
            initialData = data
            isLoading = true
        case let .HistoryView(_view, _, _, _initialData):
            initialData = _initialData
            view = _view
            isLoading = false
        }
        if let view = view {
            
            let effectiveEntries: [MessageHistoryEntry]
            if let search = state.searchMessages {
                effectiveEntries = search.resultState.messages.map {
                    MessageHistoryEntry(message: $0, isRead: true, location: nil, monthLocation: nil, attributes: .init(authorIsContact: false))
                }
            } else {
                effectiveEntries = view.entries
            }
            
            let messages: [ChatHistoryEntry] = messageEntries(effectiveEntries, renderType: theme.bubbled ? .bubble : .list, pollAnswersLoading: state.pollAnswers, groupingPhotos: true, searchState: state.searchMessages?.resultState, chatTheme: state.appearance.presentation, mediaRevealed: state.mediaRevealed, automaticDownload: initialData.autodownloadSettings, contentConfig: context.contentConfig).reversed()
            
            
            let entries = messages.map {
                ChatWrappedEntry(appearance: AppearanceWrapperEntry(entry: $0, appearance: state.appearance), tag: nil)
            }
            return HistoryView(view: view, entries: entries, state: state, isLoading: isLoading)
        } else {
            return HistoryView(view: nil, entries: [], state: state, isLoading: isLoading)
        }
    }
    
    actionsDisposable.add(appearance.start(next: { appearance in
        updateState { current in
            var current = current
            current.appearance = appearance
            return current
        }
    }))
    
    
    let peerSignal = getPeerView(peerId: peerId, postbox: context.account.postbox) |> deliverOnMainQueue
    
    actionsDisposable.add(peerSignal.startStrict(next: { peer in
        chatInteraction.update {
            $0.updatedMainPeer(peer)
        }
    }))
    
    var view: HistoryView? = nil
    let historySignal:Promise<HistoryView> = Promise()
    actionsDisposable.add((historyView |> deliverOnMainQueue).start(next: { value in
        view = value
        historySignal.set(.single(value))
    }))

    
    let arguments = Arguments(context: context, chatInteraction: chatInteraction, findGroupStableId: { stableId in
        if let entries = view?.entries, let stableId = stableId.base as? ChatHistoryEntryId {
            switch stableId {
            case let .message(message):
                for entry in entries {
                    s: switch entry.entry {
                    case let .groupedPhotos(entries, _):
                        for groupedEntry in entries {
                            if message.id == groupedEntry.message?.id {
                                return entry.stableId
                            }
                        }
                    default:
                        break s
                    }
                }
            default:
                break
            }
        }
        return nil
    })
    
    
    let signal = historySignal.get() |> deliverOnPrepareQueue |> map { view in
        return InputDataSignalValue(entries: entries(view, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    
    
    let delegate = TableDelegate(arguments)
    
    let emojiEffects = EmojiScreenEffect(context: context, takeTableItem: { [weak controller] msgId in
        if controller?.isLoaded() == false {
            return nil
        }
        var found: ChatRowItem? = nil
        controller?.tableView.enumerateVisibleItems(with: { item in
            if let item = item as? ChatRowItem, item.message?.id == msgId {
                found = item
                return false
            } else {
                return true
            }
        })
        return found
    })
    
    
    controller.didLoad = { controller, _ in
        selectText = ChatSelectText(controller.tableView)
        selectText?.initializeHandlers(for: context.window, chatInteraction: chatInteraction)
        
        controller.tableView.delegate = delegate
        controller.tableView.emptyItem = ChatEmptyPeerItem(controller.frame.size, chatInteraction: chatInteraction, theme: stateValue.with { $0.appearance.presentation })

        controller.tableView.addScroll(listener: emojiEffects.scrollUpdater)
        
        controller.tableView.setScrollHandler { scroll in
            if let view = view?.view, let controller = getController?() {
                var messageIndex:MessageIndex?

                let visible = controller.tableView.visibleRows()
                
                switch scroll.direction {
                case .top:
                    if view.laterId != nil {
                        for i in visible.min ..< visible.max {
                            if let item = controller.tableView.item(at: i) as? ChatRowItem, !item.ignoreAtInitialization {
                                messageIndex = item.entry.index
                                break
                            }
                        }
                    } else if view.laterId == nil, !view.holeLater, let locationValue = locationValue, !locationValue.content.isAtUpperBound, view.anchorIndex != .upperBound {
                        messageIndex = .upperBound(peerId: peerId)
                    }
                case .bottom:
                    if view.earlierId != nil {
                        for i in stride(from: visible.max - 1, to: -1, by: -1) {
                            if let item = controller.tableView.item(at: i) as? ChatRowItem, !item.ignoreAtInitialization {
                                messageIndex = item.entry.index
                                break
                            }
                        }
                    }
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    let lc: ChatHistoryLocation = .Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 100, side: .lower)
                    guard lc != locationValue?.content else {
                        return
                    }
                    setLocation(.init(content: lc, chatLocation: location, tag: nil, id: getNextId()))
                }
            }
        }
    }
    
    
    
    
    controller.afterTransaction = { controller in
        let bubbled = stateValue.with { $0.appearance.presentation.bubbled }
        if bubbled {
            controller.genericView.backgroundMode = stateValue.with { $0.appearance.presentation.backgroundMode }
        } else {
            controller.genericView.backgroundMode = .plain
        }
        if let afterNextTransaction = afterNextTransaction {
            delay(0.1, closure: afterNextTransaction)
        }
        afterNextTransaction = nil
    }
    
    getController = { [weak controller] in
        return controller
    }
    getScreenEffect = { [weak emojiEffects] in
        return emojiEffects
    }
    controller.getBackgroundColor = {
        .clear
    }
    
    controller.contextObject = search
    
    actionsDisposable.add(search.searchState.get().startStrict(next: { searchState in
        search.mediaSearchState.set(.init(state: searchState, animated: true, isLoading: false))
        search.inSearch = searchState.state == .Focus
    }))
    
    setInitialLocation()
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        _ = selectText
        _ = emojiEffects
    }
    
    return controller
    
}
