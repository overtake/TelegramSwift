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
    private let tableView: TableView = TableView(frame: NSZeroRect)
    weak var controller: ModalViewController?
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    let tintedCheckbox: ApplyblurCheckbox = ApplyblurCheckbox(frame: NSMakeRect(0, 0, 70, 24), title: L10n.accentColorsTinted)
    private let context: AccountContext
    fileprivate var disableTint: Bool = false {
        didSet {
            colorPicker.colorChanged?(colorPicker.colorPicker.color)
        }
    }
    required init(frame frameRect: NSRect, theme: TelegramPresentationTheme, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(tableView)
        self.addSubview(colorPicker)
        self.addSubview(tintedCheckbox)
        colorPicker.colorPicker.color = theme.colors.accent
        colorPicker.defaultColor = colorPicker.colorPicker.color
        tintedCheckbox.update(by: nil)
        tintedCheckbox.isSelected = theme.colors.tinted
        tintedCheckbox.isHidden = true//!theme.colors.tinted || !theme.bubbled
        colorPicker.colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            self.colorPicker.textView.setString(color.hexString)
        }
        
        tintedCheckbox.onChangedValue = { [weak self] value in
            self?.disableTint = !value
        }
        
        colorPicker.colorChanged = { [weak self] color in
            guard let `self` = self else {return}
            self.colorPicker.colorPicker.color = color
            self.colorPicker.colorPicker.needsLayout = true
            let colors = theme.colors.withoutAccentColor().withAccentColor(color, disableTint: self.disableTint)
            let newTheme = theme.withUpdatedColors(colors)
            self.addTableItems(self.context, theme: newTheme)
            self.tableView.updateLocalizationAndTheme(theme: newTheme)
            self.controller?.updateLocalizationAndTheme(theme: newTheme)
            self.colorPicker.updateLocalizationAndTheme(theme: newTheme)
            self.tintedCheckbox.update(by: nil)
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
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: arc4random(), backgroundColor: theme.chatBackground))
        
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
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: max(10, 160 - tableView.listHeight), stableId: arc4random(), backgroundColor: theme.chatBackground))

        
        
    }
    
}


class CustomAccentColorModalController: ModalViewController {

    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 350, 370))
        self.bar = .init(height: 0)
    }
    private var currentTheme: TelegramPresentationTheme = theme
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        currentTheme = theme as! TelegramPresentationTheme
        self.modal?.updateLocalizationAndTheme(theme: theme)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.controller = self
        
        genericView.addTableItems(self.context, theme: theme)
        
        readyOnce()
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: L10n.generalSettingsAccentColor), right: ModalHeaderData(image: currentTheme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }))
    }
    
    private func saveAccent() {
        
        
        let color = genericView.colorPicker.colorPicker.color
        let context = self.context
        let disableTint = self.genericView.disableTint
        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
            if color == theme.colors.basicAccent {
                return settings.withUpdatedPalette(theme.colors.withoutAccentColor())
            } else {
                return settings.withUpdatedPalette(theme.colors.withoutAccentColor().withAccentColor(color, disableTint: disableTint))
            }
        }).start()
        
        delay(0.1, closure: { [weak self] in
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
        return CustomAccentColorView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), theme: currentTheme, context: self.context)
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: NSMakeSize(350, 370), animated: false)
    }
    
    private var genericView:CustomAccentColorView {
        return self.view as! CustomAccentColorView
    }
    override func viewClass() -> AnyClass {
        return CustomAccentColorView.self
    }
    
    override var handleAllEvents: Bool {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.colorPicker.textView
    }
}
