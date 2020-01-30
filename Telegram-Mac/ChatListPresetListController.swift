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
    init(context: AccountContext, openPreset: @escaping(ChatListFilterPreset)->Void, removePreset: @escaping(ChatListFilterPreset)->Void) {
        self.context = context
        self.openPreset = openPreset
        self.removePreset = removePreset
    }
}
private func _id_preset(_ preset: ChatListFilterPreset) -> InputDataIdentifier {
    return InputDataIdentifier("_id_preset_\(preset.uniqueId)")
}
private let _id_add_new = InputDataIdentifier("_id_add_new")

private func chatListPresetEntries(state: ChatListFilterPreferences, arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    for (i, preset) in state.presets.enumerated() {
        var viewType = bestGeneralViewType(state.presets, for: preset)
        if state.presets.count == 1 {
            viewType = .firstItem
        } else if preset == state.presets.last, state.presets.count < 10 {
            viewType = .innerItem
        }
        var shortCut: String = "⌃⌘\(i + 2)"
        if i + 2 == 11 {
            shortCut = "⌃⌘-"
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(preset), data: .init(name: preset.title, color: theme.colors.text, type: .nextContext(shortCut), viewType: viewType, enabled: true, description: nil, justUpdate: arc4random64(), action: {
            arguments.openPreset(preset)
        }, menuItems: {
            return [ContextMenuItem("Remove", handler: {
                arguments.removePreset(preset)
            })]
        })))
        index += 1
    }
    
    if state.presets.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, icon: theme.icons.peerInfoAddMember, type: .next, viewType: .lastItem, action: {
            arguments.openPreset(ChatListFilterPreset.new)
        })))
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Use **⌃⌘1** to return to all chats."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
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
    })
    
    let dataSignal = chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnPrepareQueue |> map { state in
        return chatListPresetEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterListTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.updateDatas = { data in
        return .none
    }
    
    
    controller.validateData = { data in
        return .success(.custom {
            
        })
    }
    
    
    controller.afterTransaction = { controller in
        let count = controller.tableView.count - 3
        if count > 0 {
            controller.tableView.resortController = TableResortController(resortRange: NSMakeRange(1, controller.tableView.count - 3), start: { row in
                
            }, resort: { row in
                
            }, complete: { from, to in
                _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
                    $0.withMovePreset(from - 1, to - 1)
                }).start()
            })
        } else {
            controller.tableView.resortController = nil
        }
      
        
    }
    
    return controller
    
}
