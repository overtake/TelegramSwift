//
//  CustomAccentColorModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

private final class CustomAccentColorView : View {
    private let tableView: TableView = TableView(frame: NSZeroRect)
    weak var controller: ModalViewController?
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    private let context: AccountContext
    private let backgroundView = BackgroundView(frame: .zero)
    required init(frame frameRect: NSRect, theme: TelegramPresentationTheme, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(backgroundView)
        self.addSubview(tableView)
        self.addSubview(colorPicker)
        colorPicker.colorPicker.color = theme.colors.accent
        
        self.colorPicker.updateMode(.single(theme.colors.accent), animated: false)
        
        colorPicker.modeDidUpdate = { [weak self] mode in
            guard let `self` = self else {return}
            switch mode {
            case let .single(color):
                self.colorPicker.colorPicker.color = color
                self.colorPicker.colorPicker.needsLayout = true
                let colors = theme.colors.withoutAccentColor().withAccentColor(PaletteAccentColor(color), disableTint: false)
                let newTheme = theme.withUpdatedColors(colors)
                self.addTableItems(self.context, theme: newTheme)
                self.tableView.updateLocalizationAndTheme(theme: newTheme)
                self.controller?.updateLocalizationAndTheme(theme: newTheme)
                self.colorPicker.updateLocalizationAndTheme(theme: newTheme)
                self.updateLocalizationAndTheme(theme: newTheme)
                self.colorPicker.updateMode(.single(color), animated: true)
            default:
                break
            }
        }
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            self.tableView.enumerateVisibleViews(with: { view in
                if let view = view as? ChatRowView {
                    view.updateBackground(animated: false, item: view.item)
                }
            })
        }))
        
        if theme.bubbled {
            backgroundView.backgroundMode = theme.backgroundMode
        } else {
            backgroundView.backgroundMode = .color(color: theme.colors.chatBackground)
        }
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: backgroundView, frame: NSMakeRect(0, 0, frame.width, frame.height - 160))
        backgroundView.updateLayout(size: NSMakeSize(frame.width, frame.height - 160), transition: transition)
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 0, frame.width, frame.height - 160))
        
        transition.updateFrame(view: colorPicker, frame: NSMakeRect(0, frame.height - 160, frame.width, 160))
        colorPicker.updateLayout(size: NSMakeSize(frame.width, 160), transition: transition)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate func addTableItems(_ context: AccountContext, theme: TelegramPresentationTheme) {
        
        tableView.removeAll()
        
        self.tableView.getBackgroundColor = {
            .clear
        }
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: arc4random(), backgroundColor: .clear))

        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, disableSelectAbility: true)
        
        chatInteraction.getGradientOffsetRect = { [weak self] in
            guard let `self` = self else {
                return .zero
            }
            let offset = self.tableView.scrollPosition().current.rect.origin
            return CGRect(origin: offset, size: self.tableView.frame.size)
        }
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        
        let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        
        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id, threadMessageId: nil)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        
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
    private let updateColor: (PaletteAccentColor)->Void
    init(context: AccountContext, updateColor: @escaping(PaletteAccentColor)->Void) {
        self.context = context
        self.updateColor = updateColor
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
        return (left: ModalHeaderData(image: currentTheme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: L10n.generalSettingsAccentColor), right: nil)
    }
    
    private func saveAccent() {
        let color = genericView.colorPicker.colorPicker.color
        self.updateColor(PaletteAccentColor(color))
        
        delay(0.1, closure: { [weak self] in
           self?.close()
        })
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalSet, accept: { [weak self] in
            self?.saveAccent()
        }, drawBorder: true, singleButton: true)
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
        return genericView.colorPicker.colorEditor.textView.inputView
    }
}
