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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerChat), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("chat_open_info"), data: InputDataGeneralData(name: strings().shortcutsControllerChatOpenInfo, color: theme.colors.text, icon: nil, type: .context("→"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("reply_to_message"), data: InputDataGeneralData(name: strings().shortcutsControllerChatSelectMessageToReply, color: theme.colors.text, icon: nil, type: .context("⌘↑ / ⌘↓"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_message"), data: InputDataGeneralData(name: strings().shortcutsControllerChatEditLastMessage, color: theme.colors.text, icon: nil, type: .context("↑"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_media"), data: InputDataGeneralData(name: strings().shortcutsControllerChatRecordVoiceMessage, color: theme.colors.text, icon: nil, type: .context("⌘R"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("search_in_chat"), data: InputDataGeneralData(name: strings().shortcutsControllerChatSearchMessages, color: theme.colors.text, icon: nil, type: .context("⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // video chat
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerVideoChat), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("toggle_camera"), data: InputDataGeneralData(name: strings().shortcutsControllerVideoChatToggleCamera, color: theme.colors.text, icon: nil, type: .context("⌘E"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("toggle_screen"), data: InputDataGeneralData(name: strings().shortcutsControllerVideoChatToggleScreencast, color: theme.colors.text, icon: nil, type: .context("⌘T"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1

    
    //search
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerSearch), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("quick_search"), data: InputDataGeneralData(name: strings().shortcutsControllerSearchQuickSearch, color: theme.colors.text, icon: nil, type: .context("⌘K"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("global_search"), data: InputDataGeneralData(name: strings().shortcutsControllerSearchGlobalSearch, color: theme.colors.text, icon: nil, type: .context("⇧⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    //MARKDOWN
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerMarkdown), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_bold"), data: InputDataGeneralData(name: strings().shortcutsControllerMarkdownBold, color: theme.colors.text, icon: nil, type: .context("⌘B / **"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_italic"), data: InputDataGeneralData(name: strings().shortcutsControllerMarkdownItalic, color: theme.colors.text, icon: nil, type: .context("⌘I / __"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_monospace"), data: InputDataGeneralData(name: strings().shortcutsControllerMarkdownMonospace, color: theme.colors.text, icon: nil, type: .context("⇧⌘K / `"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_url"), data: InputDataGeneralData(name: strings().shortcutsControllerMarkdownHyperlink, color: theme.colors.text, icon: nil, type: .context("⌘U"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_strikethrough"), data: InputDataGeneralData(name: strings().shortcutsControllerMarkdownStrikethrough, color: theme.colors.text, icon: nil, type: .context("~~"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // OTHERS
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerOthers), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("lock_passcode"), data: InputDataGeneralData(name: strings().shortcutsControllerOthersLockByPasscode, color: theme.colors.text, icon: nil, type: .context("⌘L"), viewType: .singleItem, enabled: true, description: nil)))
    index += 1
    
    
    // MOUSE
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerMouse), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("fast_reply"), data: InputDataGeneralData(name: strings().shortcutsControllerMouseFastReply, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerMouseFastReplyValue), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("schedule"), data: InputDataGeneralData(name: strings().shortcutsControllerMouseScheduleMessage, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerMouseScheduleMessageValue), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    

    //Trackpad Gesture

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().shortcutsControllerGestures), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_reply"), data: InputDataGeneralData(name: strings().shortcutsControllerGesturesReply, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerGesturesReplyValue), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_actions"), data: InputDataGeneralData(name: strings().shortcutsControllerGesturesChatAction, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerGesturesChatActionValue), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_navigation"), data: InputDataGeneralData(name: strings().shortcutsControllerGesturesNavigation, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerGesturesNavigationsValue), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_stickers"), data: InputDataGeneralData(name: strings().shortcutsControllerGesturesStickers, color: theme.colors.text, icon: nil, type: .context(strings().shortcutsControllerGesturesStickersValue), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ShortcutListController(context: AccountContext) -> ViewController {
    
    let controller = InputDataController(dataSignal: .single(InputDataSignalValue(entries: shortcutEntires())), title: strings().shortcutsControllerTitle, validateData: { data in
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "shortcuts")
    
    controller._abolishWhenNavigationSame = true
    
    return controller
}
