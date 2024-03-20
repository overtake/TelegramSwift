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
    let openStickerBot:(String)->Void
    let deselect:()->Void
    init(context: AccountContext, select:@escaping(State.Item)->Void, openStickerBot:@escaping(String)->Void, deselect:@escaping()->Void) {
        self.context = context
        self.select = select
        self.openStickerBot = openStickerBot
        self.deselect = deselect
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
    var loading: Bool = false
    var string: String?
}

private func _id_pack(_ id: ItemCollectionId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_pack_\(id.id)")
}
private func _id_pack_selected(_ id: ItemCollectionId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_pack_\(id.id)_selected")
}
private let _id_input = InputDataIdentifier("_id_input")
private let _id_loading = InputDataIdentifier("_id_loading")

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
   
    if state.searchResult == nil {
        entries.append(.input(sectionId: sectionId, index: index, value: .string(state.string), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: state.selected != nil || state.loading ? .firstItem : .singleItem, defaultText: "https://t.me/addstickers/", pasteFilter: { value in
            if let index = value.range(of: "t.me/addstickers/") {
                return (true, String(value[index.upperBound...]))
            }
            return (false, value)
        }), placeholder: nil, inputPlaceholder: "https://t.me/addstickers/", filter: { text in
            var filter = NSCharacterSet.alphanumerics
            filter.insert(charactersIn: "_/")
            return text.trimmingCharacters(in: filter.inverted)
        }, limit: 25 + 30))

        if state.loading {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return LoadingTableItem(initialSize, height: 50, stableId: stableId, viewType: .lastItem)
            }))
        } else {
            if let item = state.selected {
                let tuple = Tuple(item: item, selected: false, viewType: .lastItem)
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pack_selected(tuple.item.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                    return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: tuple.item.info, topItem: tuple.item.item, itemCount: tuple.item.count, unread: false, editing: .init(editable: false, editing: false), enabled: true, control: tuple.selected ? .selected : .remove, viewType: tuple.viewType, action: {
                        arguments.select(tuple.item)
                    }, removePack: arguments.deselect)
                }))
            } else if let string = state.string, !string.isEmpty {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                    return EmptyGroupstickerSearchRowItem(initialSize, height: 50, stableId: stableId, viewType: .lastItem, type: .emojies)
                }))
            }
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().groupEmojiPackCreateInfo, linkHandler: arguments.openStickerBot), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    }
    
    
    
    
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
 
    
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

func GroupEmojiPackController(context: AccountContext, peerId: PeerId, selected: StickerPackCollectionInfo?, updated: @escaping(StickerPackCollectionInfo?)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()
    let searchDisposable = MetaDisposable()
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(searchDisposable)
    actionsDisposable.add(resolveDisposable)
    let initialState = State()
    
    var closeSearch:(()->Void)? = nil
    
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
    if let info = selected {
        let signal: Signal<(StickerPackCollectionInfo, StickerPackItem)?, NoError> = context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false) |> map { value in
            switch value {
            case let .result(info, items, _):
                if let item = items.first {
                    return (info, item)
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        actionsDisposable.add(signal.start(next: { selected in
            updateState { current in
                var current = current
                if let selected = selected {
                    current.selected = .init(info: selected.0, id: selected.0.id, item: selected.1, count: selected.0.count)
                    current.string = selected.0.shortName
                }
                return current
            }
        }))
        
    }
    
    
    
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
        
        if let _ = result, let state = state {
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
                    current.string = nil
                } else {
                    current.selected = item
                    current.string = item.info.shortName
                }
                return current
            }
            updated(stateValue.with { $0.selected?.info })
            closeSearch?()
        }, source: stateValue.with { $0.selected?.id == item.id } ? .removeGroupEmojiPack : .installGroupEmojiPack), for: context.window)
        
    }, openStickerBot: { name in
        _ = (resolveUsername(username: name, context: context) |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peer.id)))
            }
        })
    }, deselect: {
        updateState { current in
            var current = current
            current.selected = nil
            current.string = nil
            return current
        }
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
    
    let controller = InputDataController(dataSignal: signal, title: strings().groupEmojiPackTitle, removeAfterDisappear: false, customRightButton: { controller in
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
    
    controller.afterDisappear = {
    }
    
    
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
    
    controller.updateDatas = { data in
        
        let text = data[_id_input]?.stringValue ?? ""
        
        updateState { current in
            var current = current
            current.string = text
            return current
        }
        
        if text.isEmpty {
            resolveDisposable.set(nil)
        } else {
            resolveDisposable.set((context.engine.stickers.loadedStickerPack(reference: .name(text), forceActualized: false) |> deliverOnMainQueue).start(next: { result in
                switch result {
                case .fetching:
                    updateState { current in
                        var current = current
                        current.loading = true
                        return current
                    }
                case .none:
                    updateState { current in
                        var current = current
                        current.loading = false
                        current.selected = nil
                        return current
                    }
                case let .result(info, items, _):
                    updateState { current in
                        var current = current
                        current.loading = false
                        if let first = items.first {
                            current.selected = .init(info: info, id: info.id, item: first, count: info.count)
                        } else {
                            current.selected = nil
                        }
                        return current
                    }
                }
            }))
        }
        return .none
    }
    
    closeSearch = {
        updateSearchValue { _ in
            return .none({ searchState in
                updateSearchState { _ in
                    return nil
                }
            })
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}



