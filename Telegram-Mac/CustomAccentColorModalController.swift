//
//  CustomAccentColorModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class CustomAccentColorView : View {
    private let tableView: TableView = TableView.init(frame: NSZeroRect, isFlipped: true)
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    private let context: AccountContext
    required init(frame frameRect: NSRect, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(tableView)
        self.addSubview(colorPicker)
        
        colorPicker.colorPicker.color = theme.colors.accent
        colorPicker.defaultColor = colorPicker.colorPicker.color

        
        colorPicker.colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            self.colorPicker.textView.setString(color.hexString)
        }
        
        colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            if self.colorPicker.colorPicker.color != color {
                self.colorPicker.colorPicker.color = color
                self.colorPicker.colorPicker.needsLayout = true
                let colors = theme.colors.withoutAccentColor().withAccentColor(color)
                let newTheme = theme.withUpdatedColors(colors)
                self.addTableItems(self.context, theme: newTheme)
            }
        }
        layout()
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 0, frame.width, frame.height - 160)
        colorPicker.frame = NSMakeRect(0, frame.height - 160, frame.width, 160)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate func addTableItems(_ context: AccountContext, theme: TelegramPresentationTheme) {
        
        tableView.removeAll()
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: 0))
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, disableSelectAbility: true)
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        
        let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        
        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
        
        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, interaction: chatInteraction, theme: theme)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, interaction: chatInteraction, theme: theme)
        
        
        _ = item1.makeSize(frame.width, oldWidth: 0)
        _ = item2.makeSize(frame.width, oldWidth: 0)
        
        _ = tableView.addItem(item: item1)
        _ = tableView.addItem(item: item2)
        
    }
    
}


class CustomAccentColorModalController: ModalViewController {

    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 350, 350))
        self.bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.addTableItems(self.context, theme: theme)
        
        readyOnce()
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: L10n.generalSettingsAccentColor), right: ModalHeaderData(image: theme.icons.modalClose, handler: {
            
        }))
    }
    
    private func saveAccent() {
        
        
        let color = genericView.colorPicker.colorPicker.color
        let context = self.context
        
        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
            if color == theme.colors.basicAccent {
                return settings.withUpdatedPalette(theme.colors.withoutAccentColor())
            } else {
                return settings.withUpdatedPalette(theme.colors.withAccentColor(color))
            }
        }).start()
        
        delay(0.16, closure: { [weak self] in
           self?.close()
        })
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalSet, accept: { [weak self] in
            self?.saveAccent()
        })
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func initializer() -> NSView {
        return CustomAccentColorView.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), context: self.context)
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: NSMakeSize(350, 350), animated: false)
    }
    
    private var genericView:CustomAccentColorView {
        return self.view as! CustomAccentColorView
    }
    override func viewClass() -> AnyClass {
        return CustomAccentColorView.self
    }
}
