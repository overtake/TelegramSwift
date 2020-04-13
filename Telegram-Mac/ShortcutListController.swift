//
//  ShortcutListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private func shortcutEntires() -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    // chat
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CHAT"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("chat_open_info"), data: InputDataGeneralData(name: "Open Info", color: theme.colors.text, icon: nil, type: .context("→"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("reply_to_message"), data: InputDataGeneralData(name: "Select Message to Reply", color: theme.colors.text, icon: nil, type: .context("⌘↑ / ⌘↓"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_message"), data: InputDataGeneralData(name: "Edit Last Message", color: theme.colors.text, icon: nil, type: .context("↑"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_media"), data: InputDataGeneralData(name: "Record Voice/Video Message", color: theme.colors.text, icon: nil, type: .context("⌘R"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("search_in_chat"), data: InputDataGeneralData(name: "Search Messages", color: theme.colors.text, icon: nil, type: .context("⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // messages
    
    
    
    //search
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("SEARCH"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("quick_search"), data: InputDataGeneralData(name: "Quick Search", color: theme.colors.text, icon: nil, type: .context("⌘K"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("global_search"), data: InputDataGeneralData(name: "Global Search", color: theme.colors.text, icon: nil, type: .context("⇧⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    //MARKDOWN
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MARKDOWN"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_bold"), data: InputDataGeneralData(name: "Bold", color: theme.colors.text, icon: nil, type: .context("⌘B / **"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_italic"), data: InputDataGeneralData(name: "Italic", color: theme.colors.text, icon: nil, type: .context("⌘I / __"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_monospace"), data: InputDataGeneralData(name: "Monospace", color: theme.colors.text, icon: nil, type: .context("⇧⌘K / `"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_url"), data: InputDataGeneralData(name: "Hyperlink", color: theme.colors.text, icon: nil, type: .context("⌘U"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_strikethrough"), data: InputDataGeneralData(name: "Strikethrough", color: theme.colors.text, icon: nil, type: .context("~~"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // MOUSE
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MOUSE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("fast_reply"), data: InputDataGeneralData(name: "Fast Reply", color: theme.colors.text, icon: nil, type: .context("Double Click"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("schedule"), data: InputDataGeneralData(name: "Schedule a Message", color: theme.colors.text, icon: nil, type: .context("Option Click on Airplane"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    

    //Trackpad Gesture

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("GESTURES"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_reply"), data: InputDataGeneralData(name: "Reply", color: theme.colors.text, icon: nil, type: .context("Swipe Right To Left a Message"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_actions"), data: InputDataGeneralData(name: "Chat Actions", color: theme.colors.text, icon: nil, type: .context("Swipe on a Chat Both sides"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_navigation"), data: InputDataGeneralData(name: "Navigation Back", color: theme.colors.text, icon: nil, type: .context("Swipe Left To Right"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_stickers"), data: InputDataGeneralData(name: "Stickers/Emoji/GIFs Panel", color: theme.colors.text, icon: nil, type: .context("Swipe Both Sides in Panel"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ShortcutListController(context: AccountContext) -> ViewController {
    
    let controller = InputDataController(dataSignal: .single(InputDataSignalValue(entries: shortcutEntires())), title: "Shortcuts", validateData: { data in
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "shortcuts")
    
    controller._abolishWhenNavigationSame = true
    
    return controller
}
