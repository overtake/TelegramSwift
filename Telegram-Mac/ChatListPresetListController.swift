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
    let openPreset:(ChatListFilterPreset)->Void
    let removePreset: (ChatListFilterPreset)->Void
    let toggleTabsIsEnabled:(Bool)->Void
    init(context: AccountContext, openPreset: @escaping(ChatListFilterPreset)->Void, removePreset: @escaping(ChatListFilterPreset)->Void, toggleTabsIsEnabled: @escaping(Bool)->Void) {
        self.context = context
        self.openPreset = openPreset
        self.removePreset = removePreset
        self.toggleTabsIsEnabled = toggleTabsIsEnabled
    }
}
private func _id_preset(_ preset: ChatListFilterPreset) -> InputDataIdentifier {
    return InputDataIdentifier("_id_preset_\(preset.uniqueId)")
}
private let _id_add_new = InputDataIdentifier("_id_add_new")
private let _id_add_tabs = InputDataIdentifier("_id_add_tabs")

private func chatListPresetEntries(state: ChatListFilterPreferences, arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if !state.presets.isEmpty {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_tabs, data: InputDataGeneralData(name: "Show Tabs", color: theme.colors.text, type: .switchable(state.tabsIsEnabled), viewType: .singleItem, action: {
            arguments.toggleTabsIsEnabled(!state.tabsIsEnabled)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Display filter tabs on main screen for quick switching."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("FILTERS"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    for preset in state.presets {
        var viewType = bestGeneralViewType(state.presets, for: preset)
        if state.presets.count == 1 {
            viewType = .firstItem
        } else if preset == state.presets.last, state.presets.count < 10 {
            viewType = .innerItem
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(preset), data: .init(name: preset.title, color: theme.colors.text, type: .nextContext(preset.desc), viewType: viewType, enabled: true, description: nil, justUpdate: arc4random64(), action: {
            arguments.openPreset(preset)
        }, menuItems: {
            return [ContextMenuItem("Remove", handler: {
                arguments.removePreset(preset)
            })]
        })))
        index += 1
    }
    
    if state.presets.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, icon: theme.icons.peerInfoAddMember, type: .next, viewType: state.presets.isEmpty ? .singleItem : .lastItem, action: {
            arguments.openPreset(ChatListFilterPreset.new)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("You can add more \(10 - state.presets.count) filters. Drag and drop filter to sort it."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Drag and drop filter to sort it. Right click to remove."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ChatListPresetListController(context: AccountContext) -> InputDataController {
    
    let arguments = ChatListPresetArguments(context: context, openPreset: { preset in
        context.sharedContext.bindings.rootNavigation().push(ChatListPresetController(context: context, preset: preset))
    }, removePreset: { preset in
        _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
            $0.withRemovedPreset(preset)
        }).start()
    }, toggleTabsIsEnabled: { value in
        _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
            $0.withUpdatedTabEnable(value)
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
                _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
                    $0.withMovePreset(from - range.location, to - range.location)
                }).start()
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
