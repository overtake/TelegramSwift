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
import InAppSettings
import TGUIKit


private final class ChatListPresetArguments {
    let context: AccountContext
    let openPreset:(ChatListFilter, Bool)->Void
    let removePreset: (ChatListFilter)->Void
    let addFeatured: (ChatListFeaturedFilter)->Void
    let toggleSidebar: (Bool)->Void
    let limitExceeded:()->Void
    init(context: AccountContext, openPreset: @escaping(ChatListFilter, Bool)->Void, removePreset: @escaping(ChatListFilter)->Void, addFeatured: @escaping(ChatListFeaturedFilter)->Void, toggleSidebar: @escaping(Bool)->Void, limitExceeded:@escaping()->Void) {
        self.context = context
        self.openPreset = openPreset
        self.removePreset = removePreset
        self.addFeatured = addFeatured
        self.toggleSidebar = toggleSidebar
        self.limitExceeded = limitExceeded
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
    
    
    let limit = arguments.context.isPremium ? arguments.context.premiumLimits.dialog_filters_limit_premium : arguments.context.premiumLimits.dialog_filters_limit_default
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        
        let attributedString = NSMutableAttributedString()
        
        _ = attributedString.append(string: strings().chatListFilterHeader, color: theme.colors.listGrayText, font: .normal(.text))
        
        return ChatListFiltersHeaderItem(initialSize, context: arguments.context, stableId: stableId, sticker: LocalAnimatedSticker.folder, text: attributedString)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterListHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    let filtersWithCounts = filtersWithCounts.filter { filter, _ in
        if !arguments.context.isPremium {
            return !filter.isAllChats
        } else {
            return true
        }
    }
    

    for (filter, count) in filtersWithCounts {
        var viewType = bestGeneralViewType(filtersWithCounts.map { $0.0 }, for: filter)
        
        if filtersWithCounts.count == 1 {
            viewType = .firstItem
        } else if filter == filtersWithCounts.last?.0, filtersWithCounts.count < arguments.context.premiumLimits.dialog_filters_limit_premium {
            viewType = .innerItem
        }
        
        switch filter {
        case .allChats:
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(filter), data: .init(name: filter.title, color: theme.colors.text, icon: FolderIcon(emoticon: .allChats).icon(for: .preview), type: .none, viewType: viewType)))
            index += 1
        case let .filter(_, title, _, _):
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(filter), data: .init(name: title, color: theme.colors.text, icon: FolderIcon(filter).icon(for: .preview), type: .nextContext(count > 0 ? "\(count)" : ""), viewType: viewType, enabled: true, description: nil, action: {
                arguments.openPreset(filter, false)
            }, menuItems: {
                return [ContextMenuItem(strings().chatListFilterListRemove, handler: {
                    arguments.removePreset(filter)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)]
            })))
            index += 1

        }
    }
    if filtersWithCounts.count < arguments.context.premiumLimits.dialog_filters_limit_premium {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: strings().chatListFilterListAddNew, color: theme.colors.accent, type: .next, viewType: filtersWithCounts.isEmpty ? .singleItem : .lastItem, action: {
            
            if filtersWithCounts.count < limit {
                arguments.openPreset(ChatListFilter.new(excludeIds: filtersWithCounts.map { $0.0.id }), true)
            } else {
                arguments.limitExceeded()
            }
            
        })))
        index += 1
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterListDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
       
    if let suggested = suggested, filtersWithCounts.count < 10 {
        
        let filtered = suggested.filters.filter { value -> Bool in
            return filtersWithCounts.first(where: { $0.0.data == value.data }) == nil
        }
        if !filtered.isEmpty {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterRecommendedHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
            index += 1
            
            var suggeted_index:Int32 = 0
            for filter in filtered {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recommended(suggeted_index), equatable: InputDataEquatable(filter), comparable: nil, item: { initialSize, stableId in
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
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterTabBarHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("sidebar"), equatable: InputDataEquatable(sidebar), comparable: nil, item: { initialSize, stableId in
            return ChatListFilterVisibilityItem(initialSize, stableId: stableId, sidebar: sidebar, viewType: .singleItem, toggle: { sidebar in
                arguments.toggleSidebar(sidebar)
            })
        }))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterTabBarDesc), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    
    return entries
}

func ChatListFiltersListController(context: AccountContext) -> InputDataController {
    
    let arguments = ChatListPresetArguments(context: context, openPreset: { filter, isNew in
        context.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter, isNew: isNew))
    }, removePreset: { filter in
        confirm(for: context.window, header: strings().chatListFilterConfirmRemoveHeader, information: strings().chatListFilterConfirmRemoveText, okTitle: strings().chatListFilterConfirmRemoveOK, successHandler: { _ in
            _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
                var filters = filters
                filters.removeAll(where: { $0.id == filter.id })
                return filters
            }).start()
        })
        
    }, addFeatured: { featured in
        _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
            var filters = filters
            var new = ChatListFilter.new(excludeIds: filters.map { $0.id })
            new = new.withUpdatedData(featured.data)
                .withUpdatedTitle(featured.title)
            
            filters.append(new)
            return filters
        }).start()
    }, toggleSidebar: { sidebar in
        _ = updateChatListFolderSettings(context.account.postbox, {
            $0.withUpdatedSidebar(sidebar)
        }).start()
    }, limitExceeded: {
        showModal(with: PremiumLimitController(context: context, type: .folders), for: context.window)
    })
    
    
    let chatCountCache = Atomic<[ChatListFilterData: Int]>(value: [:])
    
    let filtersWithCounts = chatListFilterPreferences(engine: context.engine)
        |> distinctUntilChanged
        |> mapToSignal { filters -> Signal<([(ChatListFilter, Int)], Bool), NoError> in
            return context.account.postbox.transaction { transaction -> ([(ChatListFilter, Int)], Bool) in
                return (filters.list.map { filter -> (ChatListFilter, Int) in
                    let count: Int
                    if let cachedValue = chatCountCache.with({ dict -> Int? in
                        switch filter {
                        case .allChats:
                            return nil
                        case let .filter(_, _, _, data):
                            return dict[data]
                        }
                    }) {
                        count = cachedValue
                    } else if let predicate = chatListFilterPredicate(for: filter) {
                        count = transaction.getChatCountMatchingPredicate(predicate)
                        let _ = chatCountCache.modify { dict in
                            var dict = dict
                            switch filter {
                            case .allChats:
                                break
                            case let .filter(_, _, _, data):
                                dict[data] = count
                            }
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
        return view.values[PreferencesKeys.chatListFiltersFeaturedState]?.get(ChatListFiltersFeaturedState.self)
    }

    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, filtersWithCounts, suggested) |> map { _, filtersWithCounts, suggested in
        return chatListPresetEntries(filtersWithCounts: filtersWithCounts.0, sidebar: filtersWithCounts.1, suggested: suggested, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: strings().chatListFilterListTitle, removeAfterDisappear: false, hasDone: false, identifier: "filters")
    
    
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
                _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
                    var filters = filters
                    
                    var offset: Int = 0
                    if !context.isPremium {
                        offset = 1
                    }
                    filters.move(at: from - range.location + offset, to: to - range.location + offset)
                    return filters
                }).start()
                
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
