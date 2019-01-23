//
//  ChatTouchBar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let chatNextAndPrev = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.chatNextAndPrev")

    static let chatStickersAndEmojiPicker = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.StickerAndEmojiPicker")
    
    static let chatInfoAndAttach = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.chatInfoAndAttach")
    
    static func chatInputAction(_ key:String) -> NSTouchBarItem.Identifier {
        return NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.InputAction\(key)")
    }
    static let chatDeleteMessages = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.DeleteMessages")
    static let chatForwardMessages = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.ForwardMessages")
    
    static let chatEditMessageDone = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.EditMessageDone")
    static let chatEditMessageCancel = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.EditMessageCancel")
    static let chatEditMessageUpdateMedia = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.EditMessage.UpdateMedia")
    static let chatEditMessageUpdateFile = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.EditMessage.UpdateFile")
    
    static let chatSuggestStickers = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.SuggestStickers")

}
@available(OSX 10.12.2, *)
func inputChatTouchBarItems(presentation: ChatPresentationInterfaceState) -> [NSTouchBarItem.Identifier] {
    if let result = presentation.inputQueryResult {
        switch result {
        case .stickers:
            return []
        default:
            break
        }
    }
    
    if presentation.state == .editing {
        return []
    } else {
        switch presentation.state {
        case .normal:
            return [.candidateList]
        default:
            return []
        }
    }
}
@available(OSX 10.12.2, *)
func touchBarChatItems(presentation: ChatPresentationInterfaceState, layout: SplitViewState, isKeyWindow: Bool) -> (items: [NSTouchBarItem.Identifier], escapeReplacement: NSTouchBarItem.Identifier?) {
    
    if presentation.isSearchMode {
        return (items: [], escapeReplacement: nil)
    }
    if presentation.state == .editing {
        var items: [NSTouchBarItem.Identifier] = []
        items.append(.chatEditMessageDone)
 
        if let editState = presentation.interfaceState.editState, let media = editState.message.media.first, media is TelegramMediaFile || media is TelegramMediaImage {
            items.append(.flexibleSpace)
            items.append(.chatEditMessageUpdateMedia)
            if editState.message.groupingKey == nil {
                items.append(.chatEditMessageUpdateFile)
            }
            items.append(.flexibleSpace)
        }
        if isKeyWindow {
            items.append(.otherItemsProxy)
        }
        return (items: items, escapeReplacement: .chatEditMessageCancel)
    } else {
        //if presentation.effectiveInput.inputText.isEmpty {
        var items: [NSTouchBarItem.Identifier] = []
        if layout != .single {
          //  items.append(.chatNextAndPrev)
        }
       // items.append(.chatInfoAndSearch)
        //items.append(.fixedSpaceSmall)
        switch presentation.state {
        case .normal:
          //  items.append(.characterPicker)
            if let peer = presentation.peer, permissionText(from: peer, for: .banSendStickers) == nil {
                items.append(.chatStickersAndEmojiPicker)
               // items.append(.fixedSpaceSmall)
            }
           
            
            if let peer = presentation.peer, permissionText(from: peer, for: .banSendMedia) == nil {
               // items.append(.flexibleSpace)
                var appendAttachment: Bool = true
                if let result = presentation.inputQueryResult {
                    switch result {
                    case .stickers:
                        if permissionText(from: peer, for: .banSendStickers) == nil  {
                            items.append(.chatSuggestStickers)
                            appendAttachment = false
                        }
                    default:
                        break
                    }
                }
                if appendAttachment {
                    items.append(.chatInfoAndAttach)
                }
                items.append(.flexibleSpace)
            }
            if isKeyWindow {
                items.append(.otherItemsProxy)
            }

        case .selecting:
            items.append(.flexibleSpace)
            items.append(.chatDeleteMessages)
            items.append(.chatForwardMessages)
            items.append(.flexibleSpace)

        case let .action(text, _):
            if !(presentation.peer is TelegramSecretChat) {
                items.append(.flexibleSpace)
                items.append(.chatInputAction(text))
                items.append(.flexibleSpace)
            }
        default:
            break
        }
        return (items: items, escapeReplacement: nil)
    }
}




@available(OSX 10.12.2, *)
class ChatTouchBar: NSTouchBar, NSTouchBarDelegate, Notifable {
    
    private let loadStickersDisposable = MetaDisposable()
    private let loadRecentEmojiDisposable = MetaDisposable()

    private let chatInteraction: ChatInteraction
    private let textView: NSTextView
    private let candidateListItem = NSCandidateListTouchBarItem<AnyObject>(identifier: .candidateList)
    private let layoutStateDisposable = MetaDisposable()
    init(chatInteraction: ChatInteraction, textView: NSTextView) {
        self.chatInteraction = chatInteraction
        self.textView = textView
        super.init()
        self.delegate = self
        let result = touchBarChatItems(presentation: chatInteraction.presentation, layout: chatInteraction.account.context.layout, isKeyWindow: true)
        self.defaultItemIdentifiers = result.items
        self.escapeKeyReplacementItemIdentifier = result.escapeReplacement
        self.customizationAllowedItemIdentifiers = self.defaultItemIdentifiers
        self.textView.updateTouchBarItemIdentifiers()
        self.customizationIdentifier = .windowBar
        chatInteraction.add(observer: self)
        layoutStateDisposable.set(chatInteraction.account.context.layoutHandler.get().start(next: { [weak self] _ in
            guard let `self` = self else {return}
            self.notify(with: self.chatInteraction.presentation, oldValue: self.chatInteraction.presentation, animated: true)
        }))
    }
    
    func updateByKeyWindow() {
        self.notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: true)
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    deinit {
        chatInteraction.remove(observer: self)
        loadRecentEmojiDisposable.dispose()
        loadStickersDisposable.dispose()
        layoutStateDisposable.dispose()
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState {
            let result = touchBarChatItems(presentation: value, layout: chatInteraction.account.context.layout, isKeyWindow: textView.window?.isKeyWindow ?? false)
            self.defaultItemIdentifiers = result.items
            self.escapeKeyReplacementItemIdentifier = result.escapeReplacement
            self.customizationAllowedItemIdentifiers = self.defaultItemIdentifiers
            self.textView.updateTouchBarItemIdentifiers()
            updateUserInterface()
        }
    }
    
    
    @objc private func chatInfoAction() {
        guard let item = self.item(forIdentifier: .chatInfoAndAttach) as? NSPopoverTouchBarItem else {return}
        item.popoverTouchBar = ChatInfoTouchbar(chatInteraction: chatInteraction, dismiss: { [weak item] in
            item?.dismissPopover(nil)
        })
        item.showPopover(item)
    }
    @objc private func searchAction() {
        chatInteraction.update({$0.updatedSearchMode(!$0.isSearchMode)})
    }
    
    @objc private func attachPhotoOrVideo() {
        chatInteraction.attachPhotoOrVideo()
    }
    @objc private func attachPicture() {
        chatInteraction.attachPicture()
    }
    @objc private func attachFile() {
        chatInteraction.attachFile(false)
    }
    @objc private func attachLocation() {
        chatInteraction.attachLocation()
    }
    @objc private func invokeInputAction() {
        switch chatInteraction.presentation.state {
        case .action(_, let action):
            action(chatInteraction)
        default:
            break
        }
    }
    
    private func showEmojiPickerPopover(recent: [String], segments: [EmojiSegment : [String]]) {
        guard let item = self.item(forIdentifier: .chatStickersAndEmojiPicker) as? NSPopoverTouchBarItem else {return}
        
        item.popoverTouchBar = TouchBarEmojiPicker(recent: recent, segments: segments, selectedEmoji: { [weak self, weak item] emoji in
            guard let `self` = self else {return}
            if self.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                item?.dismissPopover(nil)
            }
            _ = self.chatInteraction.appendText(emoji)
        })
        item.showPopover(item)
    }
    
    private func showStickersPopover(_ itemCollectionView: ItemCollectionsView) {
        guard let item = self.item(forIdentifier: .chatStickersAndEmojiPicker) as? NSPopoverTouchBarItem else {return}
        var stickers: (favorite: [TelegramMediaFile], recent: [TelegramMediaFile], packs: [(StickerPackCollectionInfo, [TelegramMediaFile])]) = (favorite: [], recent: [], packs: [])

        stickers.favorite = itemCollectionView.orderedItemListsViews[0].items.compactMap {($0.contents  as? SavedStickerItem)?.file}
        stickers.recent = itemCollectionView.orderedItemListsViews[1].items.compactMap {($0.contents  as? RecentMediaItem)?.media as? TelegramMediaFile}

        var collections: [ItemCollectionId : [TelegramMediaFile]] = [:]

        for entry in itemCollectionView.entries {
            var collection = collections[entry.index.collectionId]
            if collection == nil {
                collection = []
                collections[entry.index.collectionId] = collection
            }
            if let item = entry.item as? StickerPackItem {
                collections[entry.index.collectionId]?.append(item.file)
            }
        }

        for (key, value) in collections {
            let info = itemCollectionView.collectionInfos.first(where: {$0.0 == key})
            if let info = info?.1 as? StickerPackCollectionInfo {
                stickers.packs.append((info, value))
            }
        }
        
        var entries: [TouchBarStickerEntry] = []
        if !stickers.favorite.isEmpty {
            let layout = TextViewLayout(.initialize(string: L10n.touchBarFavorite, color: .grayText, font: .normal(.header)))
            layout.measure(width: .greatestFiniteMagnitude)
            entries.append(.header(layout))
            entries.append(contentsOf: stickers.favorite.map {.sticker($0)})
        }
        if !stickers.recent.isEmpty {
            let layout = TextViewLayout(.initialize(string: L10n.touchBarRecent, color: .grayText, font: .normal(.header)))
            layout.measure(width: .greatestFiniteMagnitude)
            entries.append(.header(layout))
            entries.append(contentsOf: stickers.recent.map {.sticker($0)})
        }
        for pack in stickers.packs {
            let layout = TextViewLayout(.initialize(string: "\(pack.0.title)", color: .grayText, font: .normal(.header)))
            layout.measure(width: .greatestFiniteMagnitude)
            entries.append(.header(layout))
            entries.append(contentsOf: pack.1.map {.sticker($0)})
        }

        item.popoverTouchBar = ChatStickersTouchBarPopover(chatInteraction: chatInteraction, dismiss: { [weak item, weak self] file in
            if let file = file {
                self?.chatInteraction.sendAppFile(file)
            }
            item?.dismissPopover(nil)
        }, entries: entries)
        item.showPopover(item)
    }
    
    
    @objc private func openEmojiOrStickersPicker(_ sender: Any?) {
        if let segmentControl = sender as? NSSegmentedControl {
            switch segmentControl.selectedSegment {
            case 0:
                loadRecentEmojiDisposable.set((recentUsedEmoji(postbox: chatInteraction.account.postbox) |> deliverOnPrepareQueue |> map { ($0, emojiesInstance)} |> take(1) |> deliverOnMainQueue).start(next: { [weak self] recent, segments in
                    self?.showEmojiPickerPopover(recent: recent.emojies, segments: segments)
                }))
            case 1:
                loadStickersDisposable.set((chatInteraction.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 200) |> take(1) |> deliverOnMainQueue).start(next: { [weak self] itemCollectionView in
                    self?.showStickersPopover(itemCollectionView)
                }))
            default:
                break
            }
        }
        
    }
    
    @objc private func forwardMessages() {
        chatInteraction.forwardSelectedMessages()
    }
    @objc private func deleteMessages() {
        chatInteraction.deleteSelectedMessages()
    }
    
    @objc private func saveEditingMessage() {
        chatInteraction.sendMessage()
    }
    @objc private func replaceWithFile() {
        chatInteraction.updateEditingMessageMedia(nil, false)
    }
    @objc private func replaceWithMedia() {
        chatInteraction.updateEditingMessageMedia(mediaExts, true)
    }
    @objc private func cancelMessageEditing() {
        chatInteraction.update({$0.withoutEditMessage()})
    }
    @objc private func infoAndAttach(_ sender: Any?) {
        
        if let segmentControl = sender as? NSSegmentedControl {
            switch segmentControl.selectedSegment {
            case 1:
                chatInfoAction()
            case 0:
                attachFile()
            default:
                break
            }
        }
    }
    @objc private func upOrNext(_ sender: Any?) {
        if let segmentControl = sender as? NSSegmentedControl {
            switch segmentControl.selectedSegment {
            case 0:
                mainWindow.sendKeyEvent(KeyboardKey.Tab, modifierFlags: [.control, .shift])
            case 1:
                mainWindow.sendKeyEvent(KeyboardKey.Tab, modifierFlags: [.control])
            default:
                break
            }
        }
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        
        let actionKey: String
        switch chatInteraction.presentation.state {
        case let .action(title, _):
            actionKey = title
        default:
            actionKey = ""
        }
        
        switch identifier {
        case .chatNextAndPrev:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 2
            segment.setImage(NSImage(named: NSImage.touchBarGoUpTemplateName)!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.touchBarGoDownTemplateName)!, forSegment: 1)
            segment.setWidth(93, forSegment: 0)
            segment.setWidth(93, forSegment: 1)
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(upOrNext(_:))
            item.collapsedRepresentation = segment
            return item
//        case .chatInfoAndSearch:
//            let item = NSPopoverTouchBarItem(identifier: identifier)
//
//            let segment = NSSegmentedControl()
//            segment.segmentStyle = .separated
//            segment.segmentCount = 2
//            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_Info"))!, forSegment: 0)
//            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_Search"))!, forSegment: 1)
//            segment.setWidth(93, forSegment: 0)
//            segment.setWidth(93, forSegment: 1)
//            segment.trackingMode = .momentary
//            segment.target = self
//            segment.action = #selector(infoOrSearchAction(_:))
//            item.collapsedRepresentation = segment
//            return item
        case .chatStickersAndEmojiPicker:
            
            let item = NSPopoverTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 2
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_Emoji"))!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_Stickers"))!, forSegment: 1)
            segment.setWidth(92, forSegment: 0)
            segment.setWidth(92, forSegment: 1)
            segment.target = self
            segment.action = #selector(openEmojiOrStickersPicker(_:))
            segment.trackingMode = .momentary
            item.visibilityPriority = .high
            item.collapsedRepresentation = segment
            return item
            
//            let item = NSPopoverTouchBarItem(identifier: identifier)
//
//            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_Stickers"))!
//            let button = NSButton(image: icon, target: self, action: #selector(loadStickers))
//
//            item.collapsedRepresentation = button
//            item.customizationLabel = button.title
//            return item
            
        case .chatInfoAndAttach:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 2
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_ChatAttach"))!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_ChatMore"))!, forSegment: 1)
            segment.setWidth(98, forSegment: 0)
            segment.setWidth(98, forSegment: 1)
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(infoAndAttach(_:))
            item.collapsedRepresentation = segment
            return item

        case .chatEditMessageDone:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L10n.navigationDone, target: self, action: #selector(saveEditingMessage))
            button.bezelColor = theme.colors.blueUI
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatEditMessageUpdateMedia:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_AttachPhotoOrVideo"))!
            let button = NSButton(title: L10n.touchBarEditMessageReplaceWithMedia, image: icon, target: self, action: #selector(replaceWithMedia))
            button.imageHugsTitle = true
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatEditMessageUpdateFile:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_AttachFile"))!
            let button = NSButton(title: L10n.touchBarEditMessageReplaceWithFile, image: icon, target: self, action: #selector(replaceWithFile))
            button.imageHugsTitle = true
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatEditMessageDone:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L10n.navigationDone, target: self, action: #selector(attachFile))
            button.bezelColor = theme.colors.blueUI
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatEditMessageCancel:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L10n.navigationCancel, target: self, action: #selector(cancelMessageEditing))
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatInputAction(actionKey):
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: actionKey, target: self, action: #selector(invokeInputAction))
            button.addWidthConstraint(size: 200)
            button.bezelColor = actionKey == L10n.chatInputMute || actionKey == L10n.chatInputUnmute ? nil : theme.colors.blueUI
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatForwardMessages:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_MessagesForward"))!
            let button = NSButton(title: L10n.messageActionsPanelForward, image: icon, target: self, action: #selector(forwardMessages))
            button.addWidthConstraint(size: 160)
            button.bezelColor = theme.colors.blueUI
            button.imageHugsTitle = true
            button.isEnabled = chatInteraction.presentation.canInvokeBasicActions.forward
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatDeleteMessages:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_MessagesDelete"))!
            let button = NSButton(title: L10n.messageActionsPanelDelete, image: icon, target: self, action: #selector(deleteMessages))
            button.addWidthConstraint(size: 160)
            button.bezelColor = theme.colors.redUI
            button.imageHugsTitle = true
            button.isEnabled = chatInteraction.presentation.canInvokeBasicActions.delete
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatSuggestStickers:
            if let result = chatInteraction.presentation.inputQueryResult {
                switch result {
                case let .stickers(stickers):
                    return StickersScrubberBarItem(identifier: identifier, account: chatInteraction.account, sendSticker: { [weak self] file in
                        self?.chatInteraction.sendAppFile(file)
                        self?.chatInteraction.clearInput()
                    }, entries: stickers.map({.sticker($0.file)}))
                default:
                    break
                }
            }
            
        default:
            break
        }
        return nil
    }
    
    private func updateUserInterface() {
        for identifier in itemIdentifiers {
            switch identifier {
            case .chatForwardMessages:
                let button = (item(forIdentifier: identifier) as? NSCustomTouchBarItem)?.view as? NSButton
                button?.bezelColor = chatInteraction.presentation.canInvokeBasicActions.forward ? theme.colors.blueUI : nil
                button?.isEnabled = chatInteraction.presentation.canInvokeBasicActions.forward
                
            case .chatDeleteMessages:
                let button = (item(forIdentifier: identifier) as? NSCustomTouchBarItem)?.view as? NSButton
                button?.bezelColor = chatInteraction.presentation.canInvokeBasicActions.delete ? theme.colors.redUI : nil
                button?.isEnabled = chatInteraction.presentation.canInvokeBasicActions.delete
            default:
                break
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
