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
    return InputDataIdentifier("_id_preset_\(filter.id)")
}
private let _id_add_new = InputDataIdentifier("_id_add_new")
private let _id_add_tabs = InputDataIdentifier("_id_add_tabs")
private let _id_badge_tabs = InputDataIdentifier("_id_badge_tabs")

private func chatListPresetEntries(state: ChatListFiltersState, arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    

  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("FILTERS"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    for filter in state.filters {
        var viewType = bestGeneralViewType(state.filters, for: filter)
        if state.filters.count == 1 {
            viewType = .firstItem
        } else if filter == state.filters.last, state.filters.count < 10 {
            viewType = .innerItem
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(filter), data: .init(name: filter.title, color: theme.colors.text, type: .nextContext(filter.desc), viewType: viewType, enabled: true, description: nil, justUpdate: arc4random64(), action: {
            arguments.openPreset(filter)
        }, menuItems: {
            return [ContextMenuItem("Remove", handler: {
                arguments.removePreset(filter)
            })]
        })))
        index += 1
    }
    
    if state.filters.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, type: .next, viewType: state.filters.isEmpty ? .singleItem : .lastItem, action: {
           // arguments.openPreset(ChatListFilter.new)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("You can add \(10 - state.filters.count) more filters. Drag and drop filter to sort it."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Drag and drop filter to sort it. Right click to remove."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ChatListFiltersListController(context: AccountContext) -> InputDataController {
    
    let arguments = ChatListPresetArguments(context: context, openPreset: { filter in
        context.sharedContext.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
    }, removePreset: { filter in
        _ = updateChatListFilterSettingsInteractively(postbox: context.account.postbox, {
            $0.withRemovedFilter(filter)
        }).start()
    })
    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, chatListFilterPreferences(postbox: context.account.postbox)) |> map { _, state in
        return chatListPresetEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterListTitle, removeAfterDisappear: false, hasDone: false)
    
    controller._abolishWhenNavigationSame = true
    
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
                _ = updateChatListFilterSettingsInteractively(postbox: context.account.postbox, {
                    $0.withMoveFilter(from - range.location, to - range.location)
                }).start()
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
