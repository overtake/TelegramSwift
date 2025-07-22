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
    var folderId: Int64
    var listState: PeerStoryListContext.State?
    var folderState: PeerStoryListContext.State?
    var perRowCount: Int = 3
    var selected: [EngineStoryItem] = []
    var unselected: [EngineStoryItem] = []
    
    
    func selected(_ story: EngineStoryItem) -> Bool {
        if let folderIds = story.folderIds, folderIds.contains(folderId) {
            return !unselected.contains {
                $0.id == story.id
            }
        } else {
            return selected.contains(where: {
                $0.id == story.id
            })
        }
    }
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

            tuples.append(.init(chunk: chunk, viewType: viewType, perRowCount: state.perRowCount, selected: Set(chunk.compactMap { value in
                if state.selected(value.storyItem) {
                    return value.id
                } else {
                    return nil
                }
            })))
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

func SelectStoryModalController(context: AccountContext, folderId: Int64, peerId: PeerId, listContext: PeerStoryListContext?, callback: @escaping([EngineStoryItem], [EngineStoryItem])->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(folderId: folderId)
    
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
    
    actionsDisposable.add(listContext.state.startStrict(next: { listState in
        updateState { current in
            var current = current
            current.listState = listState
            return current
        }
    }))
    
    let limit = context.appConfiguration.getGeneralValue("stories_album_stories_limit", orElse: 1000)


    let arguments = Arguments(context: context, toggleSelected: { storyId in
        let state = stateValue.with { $0 }
        
        guard let story = state.listState?.items.first(where: { $0.id == storyId })?.storyItem else {
            return
        }
        
        var failedToAdd: Bool = false
        updateState { current in
            var current = current
            
            if let folderIds = story.folderIds, folderIds.contains(folderId) {
                if let index = current.unselected.map(\.id).firstIndex(of: story.id) {
                    current.unselected.remove(at: index)
                } else {
                    current.unselected.append(story)
                }
            } else {
                if current.selected.map(\.id).contains(story.id) {
                    current.selected.removeAll(where: { $0.id == story.id })
                } else {
                    if limit > current.selected.count {
                        failedToAdd = true
                    } else {
                        current.selected.append(story)
                    }
                }
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
                
        callback(state.selected, state.unselected)
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
    
    controller.contextObject = listContext
    
    
    controller.didLoad = { [weak listContext] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                listContext?.loadMore()
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



