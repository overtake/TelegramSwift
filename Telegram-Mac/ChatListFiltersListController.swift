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
    let openPreset:(ChatListFilter, Bool)->Void
    let removePreset: (ChatListFilter)->Void
    let addFeatured: (ChatListFeaturedFilter)->Void
    let toggleSidebar: (Bool)->Void
    init(context: AccountContext, openPreset: @escaping(ChatListFilter, Bool)->Void, removePreset: @escaping(ChatListFilter)->Void, addFeatured: @escaping(ChatListFeaturedFilter)->Void, toggleSidebar: @escaping(Bool)->Void) {
        self.context = context
        self.openPreset = openPreset
        self.removePreset = removePreset
        self.addFeatured = addFeatured
        self.toggleSidebar = toggleSidebar
    }
}
private func _id_preset(_ filter: ChatListFilter) -> InputDataIdentifier {
    return InputDataIdentifier("_id_filter_\(filter.id)")
}
private func _id_recommended(_ index: Int32) -> InputDataIdentifier {
    return InputDataIdentifier("_id_recommended\(index)")
}
private let _id_add_new = InputDataIdentifier("_id_add_new")
private let _id_add_tabs = InputDataIdentifier("_id_add_tabs")
private let _id_badge_tabs = InputDataIdentifier("_id_badge_tabs")

private let _id_header = InputDataIdentifier("_id_header")

private func chatListPresetEntries(filtersWithCounts: [(ChatListFilter, Int)], sidebar: Bool, suggested: ChatListFiltersFeaturedState?, arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, item: { initialSize, stableId in
        
        let attributedString = NSMutableAttributedString()
        
        _ = attributedString.append(string: L10n.chatListFilterHeader, color: theme.colors.listGrayText, font: .normal(.text))
        
        return ChatListFiltersHeaderItem(initialSize, context: arguments.context, stableId: stableId, sticker: LocalAnimatedSticker.folder, text: attributedString)
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
        
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(filter), data: .init(name: filter.title, color: theme.colors.text, icon: FolderIcon(filter).icon(for: .preview), type: .nextContext(count > 0 ? "\(count)" : ""), viewType: viewType, enabled: true, description: nil, justUpdate: arc4random64(), action: {
            arguments.openPreset(filter, false)
        }, menuItems: {
            return [ContextMenuItem(L10n.chatListFilterListRemove, handler: {
                arguments.removePreset(filter)
            })]
        })))
        index += 1
    }
    
    if filtersWithCounts.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, type: .next, viewType: filtersWithCounts.isEmpty ? .singleItem : .lastItem, action: {
            arguments.openPreset(ChatListFilter.new(excludeIds: filtersWithCounts.map { $0.0.id }), true)
        })))
        index += 1
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterListDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
   
    
    

    
    if let suggested = suggested, filtersWithCounts.count < 10 {
        
        let filtered = suggested.filters.filter { value -> Bool in
            return filtersWithCounts.first(where: { $0.0.data == value.data }) == nil
        }
        if !filtered.isEmpty {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterRecommendedHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
            index += 1
            
            var suggeted_index:Int32 = 0
            for filter in filtered {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recommended(suggeted_index), equatable: InputDataEquatable(filter), item: { initialSize, stableId in
                    return ChatListFilterRecommendedItem(initialSize, stableId: stableId, title: filter.title, description: filter.description, viewType: bestGeneralViewType(filtered, for: filter), add: {
                        arguments.addFeatured(filter)
                    })
                }))
                suggeted_index += 1
                index += 1
            }
        }
        
        
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if !filtersWithCounts.isEmpty {
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterTabBarHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("sidebar"), equatable: InputDataEquatable(sidebar), item: { initialSize, stableId in
            return ChatListFilterVisibilityItem(initialSize, stableId: stableId, sidebar: sidebar, viewType: .singleItem, toggle: { sidebar in
                arguments.toggleSidebar(sidebar)
            })
        }))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.chatListFilterTabBarDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    
    return entries
}

func ChatListFiltersListController(context: AccountContext) -> InputDataController {
    
    let arguments = ChatListPresetArguments(context: context, openPreset: { filter, isNew in
        context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter, isNew: isNew))
    }, removePreset: { filter in
        confirm(for: context.window, header: L10n.chatListFilterConfirmRemoveHeader, information: L10n.chatListFilterConfirmRemoveText, okTitle: L10n.chatListFilterConfirmRemoveOK, successHandler: { _ in
            _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
                var filters = filters
                filters.removeAll(where: { $0.id == filter.id })
                return filters
            }).start()
        })
        
    }, addFeatured: { featured in
        _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
            var filters = filters
            var new = ChatListFilter.new(excludeIds: filters.map { $0.id })
            new.data = featured.data
            new.title = featured.title
            filters.append(new)
            return filters
        }).start()
    }, toggleSidebar: { sidebar in
        _ = updateChatListFolderSettings(context.account.postbox, {
            $0.withUpdatedSidebar(sidebar)
        }).start()
    })
    
    
    let chatCountCache = Atomic<[ChatListFilterData: Int]>(value: [:])
    
    let filtersWithCounts = chatListFilterPreferences(postbox: context.account.postbox)
        |> distinctUntilChanged
        |> mapToSignal { filters -> Signal<([(ChatListFilter, Int)], Bool), NoError> in
            return context.account.postbox.transaction { transaction -> ([(ChatListFilter, Int)], Bool) in
                return (filters.list.map { filter -> (ChatListFilter, Int) in
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
                }, filters.sidebar)
            }
    }
    
    let suggested: Signal<ChatListFiltersFeaturedState?, NoError> = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFiltersFeaturedState]) |> map { view in
        return view.values[PreferencesKeys.chatListFiltersFeaturedState] as? ChatListFiltersFeaturedState
    }

    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, filtersWithCounts, suggested) |> map { _, filtersWithCounts, suggested in
        return chatListPresetEntries(filtersWithCounts: filtersWithCounts.0, sidebar: filtersWithCounts.1, suggested: suggested, arguments: arguments)
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
                    if identifier.identifier.hasPrefix("_id_filter") {
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
                _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { filters in
                    var filters = filters
                    filters.move(at: from - range.location, to: to - range.location)
                    return filters
                }).start()
                
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
