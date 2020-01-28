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
    init(context: AccountContext) {
        self.context = context
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
    
    for preset in state.presets {
        var viewType = bestGeneralViewType(state.presets, for: preset)
        if state.presets.count == 1 {
            viewType = .firstItem
        } else if preset == state.presets.last, state.presets.count < 10 {
            viewType = .innerItem
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_preset(preset), data: .init(name: preset.title, color: theme.colors.text, type: .next, viewType: viewType, enabled: true, description: nil, action: {
            
        })))
        index += 1
    }
    
    if state.presets.count < 10 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_new, data: InputDataGeneralData(name: L10n.chatListFilterListAddNew, color: theme.colors.accent, type: .next, viewType: .lastItem, action: {
            
        })))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ChatListPresetController(context: AccountContext) -> InputDataModalController {
    

    let arguments = ChatListPresetArguments(context: context)
    
    let dataSignal = chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnPrepareQueue |> map { state in
        return chatListPresetEntries(state: state, arguments: arguments)
        } |> map { entries in
            return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterListTitle)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    controller.updateDatas = { data in
        return .none
    }
    
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, closeHandler: { f in
        f()
    }, size: NSMakeSize(350, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    controller.validateData = { data in
        return .success(.custom {
            
        })
    }
    
    
    return modalController
    
}
