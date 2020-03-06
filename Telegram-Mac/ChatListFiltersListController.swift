//
//  ChatListPresentController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit


private final class ChatListPresetArguments {
    let context: AccountContext
    let openPreset:(ChatListFilter)->Void
    let removePreset: (ChatListFilter)->Void
    init(context: AccountContext, openPreset: @escaping(ChatListFilter)->Void, removePreset: @escaping(ChatListFilter)->Void) {
        self.context = context
        self.openPreset = openPreset
        self.removePreset = removePreset
    }
}
private func _id_preset(_ filter: ChatListFilter) -> InputDataIdentifier {
    return InputDataIdentifier("_id_filter_\(filter.id)")
}
private func _id_recommended(_ filter: ChatListFilter) -> InputDataIdentifier {
    return InputDataIdentifier("_id_recommended\(filter.id)")
}
private let _id_add_new = InputDataIdentifier("_id_add_new")
private let _id_add_tabs = InputDataIdentifier("_id_add_tabs")
private let _id_badge_tabs = InputDataIdentifier("_id_badge_tabs")

private let _id_header = InputDataIdentifier("_id_header")

private func chatListPresetEntries(filtersWithCounts: [(ChatListFilter, Int)], arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, item: { initialSize, stableId in
        
        let attributedString = NSMutableAttributedString()
        
        _ = attributedString.append(string: L10n.chatListFilterHeader, color: theme.colors.listGrayText, font: .normal(.text))
        
        return ChatListFiltersHeaderItem(initialSize, context: arguments.context, stableId: stableId, text: attributedString)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterListHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    for (filter, count) in filtersWithCounts {
        var viewType = bestGeneralViewType(filtersWithCounts.map { $0.0 }, for: filter)
        if filtersWithCounts.count == 1 {
            viewType = .firstItem
        } else if filter == filtersWithCounts.last?.0, filtersWithCounts.count < 10 {
            viewType = .innerItem
        }
        
        
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(filter), data: .init(name: filter.title, color: theme.colors.text, type: .nextContext(count > 0 ? "\(count)" : ""), viewType: viewType, enabled: true, description: nil, justUpdate: arc4random64(), action: {
            arguments.openPreset(filter)
        }, menuItems: {
            return [ContextMenuItem(L10n.chatListFilterListRemove, handler: {
                arguments.removePreset(filter)
            })]
        })))
        index += 1
    }
    
    if filtersWithCounts.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, type: .next, viewType: filtersWithCounts.isEmpty ? .singleItem : .lastItem, action: {
            arguments.openPreset(ChatListFilter.new(excludeIds: filtersWithCounts.map { $0.0.id }))
        })))
        index += 1
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterListDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
   
    
    
//
//    if true {
//        entries.append(.sectionId(sectionId, type: .normal))
//        sectionId += 1
//
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterRecommendedHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
//        index += 1
//
//        var recommended:[ChatListFilter] = [ChatListFilter.new(excludeIds: [1]), ChatListFilter.new(excludeIds: [0])]
//
//        recommended[0].title = "Unread"
//        recommended[1].title = "Personal"
//        for filter in recommended {
//            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recommended(filter), equatable: nil, item: { initialSize, stableId in
//                return ChatListFilterRecommendedItem(initialSize, stableId: stableId, filter: filter, description: "All unread chats", viewType: bestGeneralViewType(recommended, for: filter), add: {
//
//                })
//            }))
//            index += 1
//        }
//
//
//    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChatListFiltersListController(context: AccountContext) -> InputDataController {
    
    let arguments = ChatListPresetArguments(context: context, openPreset: { filter in
        context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
    }, removePreset: { filter in
        _ = combineLatest(updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { state in
            var state = state
            state.withRemovedFilter(filter)
            return state
        }), replaceRemoteChatListFilters(account: context.account)).start()
    })
    
    
    let chatCountCache = Atomic<[ChatListFilterData: Int]>(value: [:])
    
    let filtersWithCounts = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
        |> map { preferences -> [ChatListFilter] in
            let filtersState = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
            return filtersState.filters
        }
        |> distinctUntilChanged
        |> mapToSignal { filters -> Signal<[(ChatListFilter, Int)], NoError> in
            return context.account.postbox.transaction { transaction -> [(ChatListFilter, Int)] in
                return filters.map { filter -> (ChatListFilter, Int) in
                    let count: Int
                    if let cachedValue = chatCountCache.with({ dict -> Int? in
                        return dict[filter.data]
                    }) {
                        count = cachedValue
                    } else if let predicate = chatListFilterPredicate(for: filter) {
                        count = transaction.getChatCountMatchingPredicate(predicate)
                        let _ = chatCountCache.modify { dict in
                            var dict = dict
                            dict[filter.data] = count
                            return dict
                        }
                    } else {
                        count = 0
                    }
                    return (filter, count)
                }
            }
    }

    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, filtersWithCounts) |> map { _, filtersWithCounts in
        return chatListPresetEntries(filtersWithCounts: filtersWithCounts, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterListTitle, removeAfterDisappear: false, hasDone: false, identifier: "filters")
    
    
    controller.updateDatas = { data in
        return .none
    }
    
    
    controller.validateData = { data in
        return .success(.custom {
            
        })
    }
    
    
    controller.afterTransaction = { controller in
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        
         controller.tableView.enumerateItems(with: { item in
            if let stableId = item.stableId.base as? InputDataEntryId {
                switch stableId {
                case let .general(identifier):
                    if identifier.identifier.hasPrefix("_id_preset") {
                        if range.location == NSNotFound {
                            range.location = item.index
                        }
                        range.length += 1
                    }
                default:
                    if range.location != NSNotFound {
                        return false
                    }
                }
            }
            return true
         })
        
        if range.location != NSNotFound {
            controller.tableView.resortController = TableResortController(resortRange: range, start: { row in
                
            }, resort: { row in
                
            }, complete: { from, to in
                _ = combineLatest(updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { state in
                    var state = state
                    state.withMoveFilter(from - range.location, to - range.location)
                    return state
                }), replaceRemoteChatListFilters(account: context.account)).start()
                
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
