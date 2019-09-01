//
//  ChatListTouchBar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let chatListSearch = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chatListSearch")
    static let chatListNewChat = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chatListNewChat")
    
    static let composeNewGroup = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewGroup")
    static let composeNewChannel = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewChannel")
    static let composeNewSecretChat = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewSecretChat")

}

@available(OSX 10.12.2, *)
final class ComposePopoverTouchBar : NSTouchBar, NSTouchBarDelegate {
    
    private let newGroup:()->Void
    private let newSecretChat:()->Void
    private let newChannel:()->Void
    init(newGroup:@escaping()->Void, newSecretChat:@escaping()->Void, newChannel:@escaping()->Void) {
        self.newGroup = newGroup
        self.newSecretChat = newSecretChat
        self.newChannel = newChannel
        super.init()
        
        delegate = self
        defaultItemIdentifiers = [.flexibleSpace, .composeNewGroup, .composeNewSecretChat, .composeNewChannel, .flexibleSpace]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func newGroupAction() {
        newGroup()
    }
    @objc private func newSecretChatAction() {
        newSecretChat()
    }
    @objc private func newChannelAction() {
        newChannel()
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .composeNewGroup:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeGroup"))!
            let button = NSButton(title: L10n.composePopoverNewGroup, image: image, target: self, action: #selector(newGroupAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewGroup
            return item
        case .composeNewChannel:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeChannel"))!
            let button = NSButton(title: L10n.composePopoverNewChannel, image: image, target: self, action: #selector(newChannelAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewChannel
            return item
        case .composeNewSecretChat:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeSecretChat"))!
            let button = NSButton(title: L10n.composePopoverNewSecretChat, image: image, target: self, action: #selector(newSecretChatAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewSecretChat
            return item
        default:
            break
        }
        return nil
    }
}

@available(OSX 10.12.2, *)
class ChatListTouchBar: NSTouchBar, NSTouchBarDelegate {

    private let search:()->Void
    private let newGroup:()->Void
    private let newSecretChat:()->Void
    private let newChannel:()->Void
    init(search:@escaping()->Void, newGroup:@escaping()->Void, newSecretChat:@escaping()->Void, newChannel:@escaping()->Void) {
        self.search = search
        self.newGroup = newGroup
        self.newSecretChat = newSecretChat
        self.newChannel = newChannel
        super.init()
        delegate = self
        customizationIdentifier = .windowBar
        defaultItemIdentifiers = [.chatListNewChat, .flexibleSpace, .chatListSearch, .flexibleSpace]
        customizationAllowedItemIdentifiers = defaultItemIdentifiers
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .chatListNewChat:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: NSImage.Name("Icon_TouchBar_Compose"))!, target: item, action: #selector(NSPopoverTouchBarItem.showPopover(_:)))
            
            item.popoverTouchBar = ComposePopoverTouchBar(newGroup: self.newGroup, newSecretChat: self.newSecretChat, newChannel: self.newChannel)
            item.collapsedRepresentation = button
            item.customizationLabel = L10n.touchBarLabelNewChat
            return item
        case .chatListSearch:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_Search"))!
            let button = NSButton(title: L10n.touchBarSearchUsersOrMessages, image: image, target: self, action: #selector(searchAction))
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
            button.addWidthConstraint(relation: .equal, size: 350)
            item.view = button
            item.customizationLabel = button.title
            return item
        default:
            break
        }
        return nil
    }
    
    @objc private func composeAction() {
        
    }
    
    @objc private func searchAction() {
        self.search()
    }
}
