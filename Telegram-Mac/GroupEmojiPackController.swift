//
//  GroupEmojiPackController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let select:(State.Item)->Void
    init(context: AccountContext, select:@escaping(State.Item)->Void) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    
    struct SearchResult : Equatable {
        var isLoading: Bool
        var result: [Item]
    }
    
    struct Item : Equatable {
        let info: StickerPackCollectionInfo
        let id: ItemCollectionId
        let item: StickerPackItem
        let count: Int32
    }
    var items: [Item] = []
    var searchState: SearchState?
    var searchResult: SearchResult?
    var selected: Item?
}

private func _id_pack(_ id: ItemCollectionId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_pack_\(id.id)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let _ = state.searchState {
        entries.append(.sectionId(sectionId, type: .customModern(70)))
        sectionId += 1
    } else {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
  
   
    
    struct Tuple : Equatable {
        let item: State.Item
        let selected: Bool
        let viewType: GeneralViewType
    }
    
    var tuples: [Tuple] = []
    
    if let searchResult = state.searchResult {
        
        if searchResult.isLoading {
            entries.append(.loading)
        } else {
            if !searchResult.result.isEmpty {
                for (i, item) in searchResult.result.enumerated() {
                    tuples.append(.init(item: item, selected: state.selected?.id == item.id, viewType: bestGeneralViewType(state.items, for: i)))
                }
            } else {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_not_found"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return SearchEmptyRowItem(initialSize, stableId: stableId)
                }))
            }
            
        }
        
    } else {
        var items = state.items

        if let selected = state.selected, !items.contains(where: { $0.id == selected.id }) {
            items.insert(selected, at: 0)
        }
        
        for (i, item) in items.enumerated() {
            tuples.append(.init(item: item, selected: state.selected?.id == item.id, viewType: bestGeneralViewType(state.items, for: i)))
        }
    }
    
    if !tuples.isEmpty {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().groupEmojiPackHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pack(tuple.item.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: tuple.item.info, topItem: tuple.item.item, itemCount: tuple.item.count, unread: false, editing: .init(editable: false, editing: false), enabled: true, control: tuple.selected ? .selected : .empty, viewType: tuple.viewType, action: {
                    arguments.select(tuple.item)
                })
            }))
        }
    }
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func GroupEmojiPackController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()
    let searchDisposable = MetaDisposable()
    
    actionsDisposable.add(searchDisposable)
    
    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let searchStatePromise = ValuePromise<SearchState?>(nil, ignoreRepeated: true)
    let searchStateValue = Atomic<SearchState?>(value: nil)
    let updateSearchState: ((SearchState?) -> SearchState?) -> Void = { f in
        searchStatePromise.set(searchStateValue.modify (f))
    }
    
    actionsDisposable.add(context.diceCache.emojies.start(next: { view in
        updateState { current in
            var current = current
            for infos in view.collectionInfos {
                if let info = infos.1 as? StickerPackCollectionInfo, let item = infos.2 as? StickerPackItem {
                    current.items.append(.init(info: info, id: infos.0, item: item, count: info.count))
                }
            }
            return current
        }
    }))
    
    actionsDisposable.add(searchStatePromise.get().start(next: { state in
        
        let result: State.SearchResult?
        if let state = state, !state.request.isEmpty {
            result = .init(isLoading: true, result: [])
        } else {
            result = nil
        }
        updateState { current in
            var current = current
            current.searchState = state
            current.searchResult = result
            return current
        }
        
        if let result = result, let state = state {
            let emojies = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, engine: context.engine, sharedContext: context.sharedContext, query: state.request, completeMatch: false, checkPrediction: false) |> map(Optional.init) |> delay(0.2, queue: .concurrentDefaultQueue())
            
            let signal = context.engine.stickers.searchEmojiSetsRemotely(query: state.request)
            
            searchDisposable.set(signal.start(next: { value in
                var items:[State.Item] = []
                for infos in value.infos {
                    if let info = infos.1 as? StickerPackCollectionInfo, let item = infos.2 as? StickerPackItem {
                        items.append(.init(info: info, id: infos.0, item: item, count: info.count))
                    }
                }
                updateState { current in
                    var current = current
                    current.searchResult = .init(isLoading: false, result: items)
                    return current
                }
            }))
        } else {
            searchDisposable.set(nil)
        }
    }))

    let arguments = Arguments(context: context, select: { item in
        showModal(with: StickerPackPreviewModalController(context, peerId: nil, references: [.emoji(.id(id: item.info.id.id, accessHash: item.info.accessHash))], onAdd: {
            updateState { current in
                var current = current
                if current.selected?.id == item.id {
                    current.selected = nil
                } else {
                    current.selected = item
                }
                return current
            }
        }, source: stateValue.with { $0.selected?.id == item.id } ? .removeGroupEmojiPack : .installGroupEmojiPack), for: context.window)
        
    })
    
    let searchValue:Atomic<TableSearchViewState> = Atomic(value: .none({ searchState in
        updateSearchState { _ in
            return searchState
        }
    }))
    let searchPromise: ValuePromise<TableSearchViewState> = ValuePromise(.none({ searchState in
        updateSearchState { _ in
            return searchState
        }
    }), ignoreRepeated: true)
    
    let updateSearchValue:((TableSearchViewState)->TableSearchViewState)->Void = { f in
        searchPromise.set(searchValue.modify(f))
    }
    
    
    let searchData = TableSearchVisibleData(cancelImage: theme.icons.chatSearchCancel, cancel: {
        updateSearchValue { _ in
            return .none({ searchState in
                updateSearchState { _ in
                    return nil
                }
            })
        }
    }, updateState: { searchState in
        updateSearchState { _ in
            return searchState
        }
    })
    
    let signal = combineLatest(statePromise.get(), searchPromise.get()) |> deliverOnPrepareQueue |> map { state, searchData in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), searchState: searchData)
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().groupEmojiPackTitle, customRightButton: { controller in
        let bar = ImageBarView(controller: controller, theme.icons.chatSearch)
        bar.button.set(handler: { _ in
            updateSearchValue { current in
                switch current {
                case .none:
                    return .visible(searchData)
                case .visible:
                    return .none({ searchState in
                        updateState { current in
                            var current = current
                            current.searchState = nil
                            return current
                        }
                    })
                }
            }
        }, for: .Click)
        bar.button.autohighlight = false
        bar.button.scaleOnClick = true
        return bar
    })
    
    controller.searchKeyInvocation = {
        updateSearchValue { current in
            switch current {
            case .none:
                return .visible(searchData)
            case .visible:
                return .none({ searchState in
                    updateState { current in
                        var current = current
                        current.searchState = nil
                        return current
                    }
                })
            }
        }
        
        return .invoked
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}



