//
//  SearchSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit

private func searchSettingsEntries(context: AccountContext, items:[SettingsSearchableItem], recent: Bool) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    let sectionId: Int32 = 0
    var index: Int32 = 0
    
    var previousIcon: SettingsSearchableItemIcon?

    if recent, !items.isEmpty {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("separator"), equatable: InputDataEquatable(true), item: { initialSize, stableId in
            return SeparatorRowItem(initialSize, stableId, string: L10n.settingsSearchRecent, right: L10n.settingsSearchRecentClear, state: .clear, height: 20, action: {
                clearRecentSettingsSearchItems(postbox: context.account.postbox)
            })
        }))
        index += 1
    }
    
    for item in items {
        var image: CGImage? = nil
        var leftInset: CGFloat = 21
        if previousIcon != item.icon {
            image = item.icon.thumb
        } else {
            leftInset += 33
        }
        previousIcon = item.icon
        
        let desc = item.breadcrumbs.joined(separator: " ")
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("search_\(item.id.index)"), equatable: InputDataEquatable(item.id), item: { initialSize, stableId in
            
            let icon:GeneralThumbAdditional?
            if let image = image {
                icon = GeneralThumbAdditional(thumb: image, textInset: 33, thumbInset: 0)
            } else {
                icon = nil
            }
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.title, description: desc.isEmpty ? nil : desc, type: .context("  "), action: {
                
                addRecentSettingsSearchItem(postbox: context.account.postbox, item: item.id)
                
                item.present(context, context.sharedContext.bindings.rootNavigation(), { presentation, controller in
                    switch presentation {
                    case .push:
                        if let controller = controller {
                            context.sharedContext.bindings.rootNavigation().push(controller)
                        }
                    default:
                        break
                    }
                })
            }, thumb: icon, border:[BorderType.Right], inset:NSEdgeInsets(left: leftInset))
        }))
        index += 1
        
//        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("search_\(item.id.index)"), data: InputDataGeneralData(name: item.title, color: theme.colors.text, icon: nil, type: .none, description: item.breadcrumbs.joined(separator: " "), action: {
//
//        })))
//        index += 1
    }
    
    /*
     return
 */
    
    return entries
}

func SearchSettingsController(context: AccountContext, searchQuery: Signal<SearchState, NoError>, archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError>, privacySettings: Signal<AccountPrivacySettings?, NoError>) -> InputDataController {
    
    let searchableItems = Promise<[SettingsSearchableItem]>()
    searchableItems.set(settingsSearchableItems(context: context, archivedStickerPacks: archivedStickerPacks, privacySettings: privacySettings))
    
    
    let previousRecentlySearchedItemOrder = Atomic<[SettingsSearchableItemId]>(value: [])
    let fixedRecentlySearchedItems = settingsSearchRecentItems(postbox: context.account.postbox)
        |> map { recentIds -> [SettingsSearchableItemId] in
            var result: [SettingsSearchableItemId] = []
            let _ = previousRecentlySearchedItemOrder.modify { current in
                var updated: [SettingsSearchableItemId] = []
                for id in current {
                    inner: for recentId in recentIds {
                        if recentId == id {
                            updated.append(id)
                            result.append(recentId)
                            break inner
                        }
                    }
                }
                for recentId in recentIds.reversed() {
                    if !updated.contains(recentId) {
                        updated.insert(recentId, at: 0)
                        result.insert(recentId, at: 0)
                    }
                }
                return updated
            }
            return result
    }
    
    
    let items:Signal<([SettingsSearchableItem], Bool), NoError> = searchQuery |> mapToSignal { state in
        switch state.state {
        case .Focus:
            if !state.request.isEmpty {
                return combineLatest(searchableItems.get(), faqSearchableItems(context: context))
                    |> mapToSignal { searchableItems, faqSearchableItems -> Signal<([SettingsSearchableItem], Bool), NoError> in
                        let results = searchSettingsItems(items: searchableItems, query: state.request)
                        let faqResults = searchSettingsItems(items: faqSearchableItems, query: state.request)
                        let finalResults: [SettingsSearchableItem]
                        if faqResults.first?.id == .faq(1) {
                            finalResults = faqResults + results
                        } else {
                            finalResults = results + faqResults
                        }
                        return .single((finalResults, false))
                    }
            } else {
                return combineLatest(searchableItems.get(), fixedRecentlySearchedItems)
                    |> map { searchableItems, recentItems -> ([SettingsSearchableItem], Bool) in
                        let searchableItemsMap = searchableItems.reduce([SettingsSearchableItemId : SettingsSearchableItem]()) { (map, item) -> [SettingsSearchableItemId: SettingsSearchableItem] in
                            var map = map
                            map[item.id] = item
                            return map
                        }
                        var result: [SettingsSearchableItem] = []
                        for itemId in recentItems {
                            if let searchItem = searchableItemsMap[itemId] {
                                if case let .language(id) = searchItem.id, id > 0 {
                                } else {
                                    result.append(searchItem)
                                }
                            }
                        }
                        return (result, true)
                }
            }
        case .None:
            return .complete()
        }
    }
    
    let entries:Signal<InputDataSignalValue, NoError> = items |> map { items, recent in
        return searchSettingsEntries(context: context, items: items, recent: recent)
    } |> map {
        return InputDataSignalValue(entries: $0, animated: false)
    }
    
    let controller = InputDataController(dataSignal: entries, title: "")
    
    controller.getBackgroundColor = {
        return theme.colors.background
    }
    
    return controller
}
