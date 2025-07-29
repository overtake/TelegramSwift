//
//  SelectGiftsModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let toggle:(ProfileGiftsContext.State.StarGift)->Void
    init(context: AccountContext, toggle:@escaping(ProfileGiftsContext.State.StarGift)->Void) {
        self.context = context
        self.toggle = toggle
    }
}

private struct State : Equatable {
    
    var collectionId: Int32
    
    var gifts: [ProfileGiftsContext.State.StarGift] = []
    var perRowCount: Int = 3
    var selected: [ProfileGiftsContext.State.StarGift] = []
    var unselected: [ProfileGiftsContext.State.StarGift] = []
    var state: ProfileGiftsContext.State?
    
    func selected(_ gift: ProfileGiftsContext.State.StarGift) -> Bool {
        if let collectionIds = gift.collectionIds, collectionIds.contains(collectionId) {
            return !unselected.contains {
                $0.reference == gift.reference
            }
        } else {
            return selected.contains(where: {
                $0.reference == gift.reference
            })
        }
    }
}

private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    let chunks = state.gifts.chunks(state.perRowCount)
    
    struct Tuple : Equatable {
        var chunk: [ProfileGiftsContext.State.StarGift]
        var selected: [ProfileGiftsContext.State.StarGift]
    }
    

    
    for (i, chunk) in chunks.enumerated() {
        let tuple = Tuple(chunk: chunk, selected: chunk.filter { state.selected($0) })
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0, selected: tuple.selected.map(\.reference!).contains($0.reference!)) }, perRowCount: state.perRowCount, fitToSize: false, insets: NSEdgeInsets(left: 10, right: 10), callback: { option in
                if let gift = option.nativeProfileGift {
                    arguments.toggle(gift)
                }
            }, contextMenu: { option in
                return []
            })
        }))
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func SelectGiftsModalController(context: AccountContext, collectionId: Int32, peerId: PeerId, callback: @escaping([ProfileGiftsContext.State.StarGift], [ProfileGiftsContext.State.StarGift])->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(collectionId: collectionId)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let gifts: ProfileGiftsContext = ProfileGiftsContext(account: context.account, peerId: peerId, filter: [.unique, .limited, .unlimited, .displayed, .hidden])
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    actionsDisposable.add(gifts.state.startStrict(next: { state in
        updateState { current in
            var current = current
            current.gifts = state.filteredGifts
            current.state = state
            return current
        }
    }))
    
    let collectionGiftsLimit = context.appConfiguration.getGeneralValue("stargifts_collection_gifts_limit", orElse: 500)


    let arguments = Arguments(context: context, toggle: { gift in
        var failedToAdd: Bool = false
        updateState { current in
            var current = current
            
            if let collectionIds = gift.collectionIds, collectionIds.contains(collectionId) {
                if let index = current.unselected.map(\.reference!).firstIndex(of: gift.reference!) {
                    current.unselected.remove(at: index)
                } else {
                    current.unselected.append(gift)
                }
            } else {
                if let index = current.selected.map(\.reference!).firstIndex(of: gift.reference!) {
                    current.selected.remove(at: index)
                } else {
                    if current.selected.count < collectionGiftsLimit {
                        current.selected.append(gift)
                    } else {
                        failedToAdd = true
                    }
                }
            }
            
            return current
        }
        if failedToAdd {
            showModalText(for: window, text: strings().selectGiftsLimitReached)
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    let controller = InputDataController(
        dataSignal: signal,
        title: strings().selectGiftsTitle
    )

    getController = { [weak controller] in
        return controller
    }
    
    controller.validateData = { _ in
        callback(stateValue.with { $0.selected }, stateValue.with { $0.unselected })
        close?()
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    let modalInteractions = ModalInteractions(
        acceptTitle: strings().selectGiftsAccept,
        accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        },
        inset: 10,
        singleButton: true
    )
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 0))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.rightModalHeader = ModalHeaderData(image: theme.icons.chatActionsActive, handler: {
       
    }, contextMenu: { [weak gifts] in
        
        let giftsState = stateValue.with { $0.state }
        guard let giftsState else {
            return []
        }
        
        let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak gifts] value in
            var updatedFilter = giftsState.filter
            if updatedFilter.contains(value) {
                updatedFilter.remove(value)
            } else {
                updatedFilter.insert(value)
            }
            if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limited) && !updatedFilter.contains(.unique) {
                updatedFilter.insert(.unlimited)
            }
            if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                if value == .displayed {
                    updatedFilter.insert(.hidden)
                } else {
                    updatedFilter.insert(.displayed)
                }
            }
            gifts?.updateFilter(updatedFilter)
        }

        var items: [ContextMenuItem] = []
        
        items.append(ContextMenuItem(giftsState.sorting == .value ? strings().peerInfoGiftsSortByDate : strings().peerInfoGiftsSortByValue, handler: {
            gifts?.updateSorting(giftsState.sorting == .value ? .date : .value)
        }))
        
        items.append(ContextSeparatorItem())
        
        items.append(ContextMenuItem(strings().peerInfoGiftsUnlimited, handler: {
            toggleFilter(.unlimited)
        }, state: giftsState.filter.contains(.unlimited) ? .on : nil))
        
        items.append(ContextMenuItem(strings().peerInfoGiftsLimited, handler: {
            toggleFilter(.limited)
        }, state: giftsState.filter.contains(.limited) ? .on : nil))
        
        items.append(ContextMenuItem(strings().peerInfoGiftsUnique, handler: {
            toggleFilter(.unique)
        }, state: giftsState.filter.contains(.unique) ? .on : nil))
        
        items.append(ContextSeparatorItem())
        
        items.append(ContextMenuItem(strings().peerInfoGiftsDisplayed, handler: {
            toggleFilter(.displayed)
        }, state: giftsState.filter.contains(.displayed) ? .on : nil))
        
        items.append(ContextMenuItem(strings().peerInfoGiftsHidden, handler: {
            toggleFilter(.hidden)
        }, state: giftsState.filter.contains(.hidden) ? .on : nil))
               
        return items
    })
    
    controller.contextObject = gifts
    
    
    controller.didLoad = { [weak gifts] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                gifts?.loadMore()
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



