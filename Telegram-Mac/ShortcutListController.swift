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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.shortcutsControllerChat), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("chat_open_info"), data: InputDataGeneralData(name: L10n.shortcutsControllerChatOpenInfo, color: theme.colors.text, icon: nil, type: .context("→"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("reply_to_message"), data: InputDataGeneralData(name: L10n.shortcutsControllerChatSelectMessageToReply, color: theme.colors.text, icon: nil, type: .context("⌘↑ / ⌘↓"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_message"), data: InputDataGeneralData(name: L10n.shortcutsControllerChatEditLastMessage, color: theme.colors.text, icon: nil, type: .context("↑"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("edit_media"), data: InputDataGeneralData(name: L10n.shortcutsControllerChatRecordVoiceMessage, color: theme.colors.text, icon: nil, type: .context("⌘R"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("search_in_chat"), data: InputDataGeneralData(name: L10n.shortcutsControllerChatSearchMessages, color: theme.colors.text, icon: nil, type: .context("⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // messages
    
    
    
    //search
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.shortcutsControllerSearch), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("quick_search"), data: InputDataGeneralData(name: L10n.shortcutsControllerSearchQuickSearch, color: theme.colors.text, icon: nil, type: .context("⌘K"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("global_search"), data: InputDataGeneralData(name: L10n.shortcutsControllerSearchGlobalSearch, color: theme.colors.text, icon: nil, type: .context("⇧⌘F"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    //MARKDOWN
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.shortcutsControllerMarkdown), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_bold"), data: InputDataGeneralData(name: L10n.shortcutsControllerMarkdownBold, color: theme.colors.text, icon: nil, type: .context("⌘B / **"), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_italic"), data: InputDataGeneralData(name: L10n.shortcutsControllerMarkdownItalic, color: theme.colors.text, icon: nil, type: .context("⌘I / __"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_monospace"), data: InputDataGeneralData(name: L10n.shortcutsControllerMarkdownMonospace, color: theme.colors.text, icon: nil, type: .context("⇧⌘K / `"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_url"), data: InputDataGeneralData(name: L10n.shortcutsControllerMarkdownHyperlink, color: theme.colors.text, icon: nil, type: .context("⌘U"), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("markdown_strikethrough"), data: InputDataGeneralData(name: L10n.shortcutsControllerMarkdownStrikethrough, color: theme.colors.text, icon: nil, type: .context("~~"), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    // MOUSE
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.shortcutsControllerMouse), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("fast_reply"), data: InputDataGeneralData(name: L10n.shortcutsControllerMouseFastReply, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerMouseFastReplyValue), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("schedule"), data: InputDataGeneralData(name: L10n.shortcutsControllerMouseScheduleMessage, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerMouseScheduleMessageValue), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    

    //Trackpad Gesture

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.shortcutsControllerGestures), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_reply"), data: InputDataGeneralData(name: L10n.shortcutsControllerGesturesReply, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerGesturesReplyValue), viewType: .firstItem, enabled: true, description: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_actions"), data: InputDataGeneralData(name: L10n.shortcutsControllerGesturesChatAction, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerGesturesChatActionValue), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_navigation"), data: InputDataGeneralData(name: L10n.shortcutsControllerGesturesNavigation, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerGesturesNavigationsValue), viewType: .innerItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: InputDataIdentifier("swipe_stickers"), data: InputDataGeneralData(name: L10n.shortcutsControllerGesturesStickers, color: theme.colors.text, icon: nil, type: .context(L10n.shortcutsControllerGesturesStickersValue), viewType: .lastItem, enabled: true, description: nil)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ShortcutListController(context: AccountContext) -> ViewController {
    
    let controller = InputDataController(dataSignal: .single(InputDataSignalValue(entries: shortcutEntires())), title: L10n.shortcutsControllerTitle, validateData: { data in
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "shortcuts")
    
    controller._abolishWhenNavigationSame = true
    
    return controller
}
