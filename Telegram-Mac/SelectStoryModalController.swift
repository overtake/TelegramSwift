//
//  SelectStoryModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox


private final class Arguments {
    let context: AccountContext
    let toggleSelected:(StoryId)->Void
    init(context: AccountContext, toggleSelected:@escaping(StoryId)->Void) {
        self.context = context
        self.toggleSelected = toggleSelected
    }
}


private struct State : Equatable {
    var listState: PeerStoryListContext.State?
    var folderState: PeerStoryListContext.State?
    var perRowCount: Int = 3
    var selected: Set<StoryId> = []
    
}

private func _id_row(_ i: Int) -> InputDataIdentifier {
    return .init("_id_row_\(i)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
  
    if let listState = state.listState, let peerReference = listState.peerReference {
        let chunks = listState.items.chunks(state.perRowCount)
        struct Tuple : Equatable {
            var chunk: [PeerStoryListContext.State.Item]
            var viewType: GeneralViewType
            var perRowCount: Int
            var selected: Set<StoryId>
        }
        var tuples: [Tuple] = []
        
        for (i, chunk) in chunks.enumerated() {
            let viewType: GeneralViewType = .modern(position: bestGeneralViewType(chunks, for: i).position, insets: NSEdgeInsetsMake(0, 0, 0, 0))

            tuples.append(.init(chunk: chunk, viewType: viewType, perRowCount: state.perRowCount, selected: state.selected.filter({ chunk.map(\.id).contains($0) })))
        }
        for (i, tuple) in tuples.enumerated() {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_row(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, standalone: true, peerId: peerReference.id, peerReference: peerReference, items: tuple.chunk, selected: tuple.selected, pinnedIds: [], rowCount: tuple.perRowCount, viewType: tuple.viewType, openStory: { _ in }, toggleSelected: arguments.toggleSelected, menuItems: { story in
                    return []
                })
            }))
        }
        
    }
    
    // entries
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
    
   
}

func SelectStoryModalController(context: AccountContext, peerId: PeerId, listContext: PeerStoryListContext?, folderContext: PeerStoryListContext, callback: @escaping([EngineStoryItem])->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let listContext = listContext ?? PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false, folderId: nil)
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    actionsDisposable.add(combineLatest(listContext.state, folderContext.state).startStrict(next: { listState, folderState in
        updateState { current in
            var current = current
            current.listState = listState
            current.folderState = folderState
            
            if current.selected.isEmpty {
                current.selected = Set(folderState.items.map(\.id))
            }
            return current
        }
    }))
    
    let collectionGiftsLimit = context.appConfiguration.getGeneralValue("collection_stories_limit", orElse: 1000)


    let arguments = Arguments(context: context, toggleSelected: { id in
        var failedToAdd: Bool = false
        updateState { current in
            var current = current
            if !current.selected.contains(id) {
                current.selected.insert(id)
            } else {
                current.selected.remove(id)
            }
            return current
        }
        if failedToAdd {
            //TODOLANG
            showModalText(for: window, text: "Limit Reached")
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: "Add Stories")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.validateData = { _ in
        
        let state = stateValue.with { $0 }
        let selected = state.selected
        
        let stories = state.listState?.items.filter({ value in
            return selected.contains(value.id)
        }).map(\.storyItem) ?? []
        
        callback(stories)
        close?()
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    //TODOLANG
    let modalInteractions = ModalInteractions(acceptTitle: "Add Stories", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, inset: 10, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 0))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.contextObject = (listContext, folderContext)
    
    
    controller.didLoad = { [weak listContext, weak folderContext] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                listContext?.loadMore()
                folderContext?.loadMore()
            default:
                break
            }
        }
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}



