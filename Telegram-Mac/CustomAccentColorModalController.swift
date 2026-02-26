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
import ColorPalette
import Postbox
import SwiftSignalKit
import InAppSettings

private final class CustomAccentColorView : View {
    private let tableView: TableView = TableView(frame: NSZeroRect, isFlipped: false)
    weak var controller: ModalViewController?
    let colorPicker = WallpaperColorPickerContainerView(frame: NSZeroRect)
    private let context: AccountContext
    private let backgroundView = BackgroundView(frame: .zero)
    fileprivate let segmentControl = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 290, 30))
    private let segmentContainer = View()

    required init(frame frameRect: NSRect, theme: TelegramPresentationTheme, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(backgroundView)
        self.addSubview(tableView)
        self.addSubview(colorPicker)
        colorPicker.colorPicker.color = theme.colors.accent
        
       
        
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
        
        segmentContainer.backgroundColor = theme.colors.background
        
        segmentContainer.addSubview(segmentControl.view)
        self.addSubview(segmentContainer)
        
        

    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: backgroundView, frame: NSMakeRect(0, 50, frame.width, frame.height - 160))
        backgroundView.updateLayout(size: NSMakeSize(frame.width, frame.height - 160), transition: transition)
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 50, frame.width, frame.height - 160 - 50))
        
        transition.updateFrame(view: colorPicker, frame: NSMakeRect(0, frame.height - 160, frame.width, 160))
        colorPicker.updateLayout(size: NSMakeSize(frame.width, 160), transition: transition)
        
        transition.updateFrame(view: segmentContainer, frame: NSMakeRect(0, 0, frame.width, 50))
        transition.updateFrame(view: segmentControl.view, frame: segmentControl.view.centerFrame())

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate func addTableItems(_ context: AccountContext, theme: TelegramPresentationTheme) {
        
        segmentContainer.backgroundColor = theme.colors.background
        segmentContainer.borderColor = theme.colors.border
        segmentContainer.border = [.Bottom]
        segmentControl.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)

        
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
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: strings().appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
        
        
        
        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 18 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: fromUser1, text: strings().appearanceSettingsChatPreview1, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        
        let timestamp1: Int32 = 60 * 20 + 60 * 60 * 18

        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: timestamp1, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: fromUser2, text: strings().appearanceSettingsChatPreview2, attributes: [ReplyMessageAttribute(messageId: firstMessage.id, threadMessageId: nil, quote: nil, isQuote: false, todoItemId: nil)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([firstMessage.id : firstMessage]), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        let timestamp2: Int32 = 60 * 22 + 60 * 60 * 18
        
        let thridMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: timestamp2, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: fromUser1, text: strings().appearanceSettingsChatPreview3, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let thridEntry: ChatHistoryEntry = .MessageEntry(thridMessage, MessageIndex(thridMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, interaction: chatInteraction, theme: theme)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, interaction: chatInteraction, theme: theme)
        let item3 = ChatRowItem.item(frame.size, from: thridEntry, interaction: chatInteraction, theme: theme)
        
        let items = [item1, item2, item3]
        for item in items {
            _ = item.makeSize(frame.width, oldWidth: 0)
            _ = self.tableView.addItem(item: item)
        }

    }
    
    func updateMode(_ mode: WallpaperColorSelectMode, newTheme: TelegramPresentationTheme) {
        self.colorPicker.colorPicker.needsLayout = true
        self.addTableItems(self.context, theme: newTheme)
        self.tableView.updateLocalizationAndTheme(theme: newTheme)
        self.controller?.updateLocalizationAndTheme(theme: newTheme)
        self.colorPicker.updateLocalizationAndTheme(theme: newTheme)
        self.updateLocalizationAndTheme(theme: newTheme)
        self.colorPicker.updateMode(mode, animated: true)

    }
    
}


class CustomAccentColorModalController: ModalViewController {

    enum SelectMode {
        case accent
        case messages
    }
    
    private var selectMode: SelectMode = .accent
    
    private let context: AccountContext
    private let updateColor: (PaletteAccentColor)->Void
    init(context: AccountContext, updateColor: @escaping(PaletteAccentColor)->Void) {
        self.context = context
        self.updateColor = updateColor
        super.init(frame: NSMakeRect(0, 0, 350, 380))
        self.bar = .init(height: 0)
    }
    private var currentTheme: TelegramPresentationTheme = theme
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        currentTheme = theme as! TelegramPresentationTheme
        self.modal?.updateLocalizationAndTheme(theme: theme)
    }
    private func updateSelectMode(_ selectMode: SelectMode, animated: Bool) {
        self.selectMode = selectMode
        switch selectMode {
        case .accent:
            self.genericView.colorPicker.updateMode(.single(currentTheme.colors.accent), animated: animated)
        case .messages:
            self.genericView.colorPicker.updateMode(.gradient(currentTheme.colors.bubbleBackground_outgoing, 0, nil), animated: animated)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.controller = self
        
        genericView.addTableItems(self.context, theme: theme)
        
        self.genericView.segmentControl.add(segment: CatalinaSegmentedItem(title: strings().appearanceThemeAccent, handler: { [weak self] in
            self?.updateSelectMode(.accent, animated: true)
        }))
        if theme.bubbled && System.supportsTransparentFontDrawing {
            self.genericView.segmentControl.add(segment: CatalinaSegmentedItem(title: strings().appearanceThemeAccentMessages, handler: { [weak self] in
                self?.updateSelectMode(.messages, animated: true)
            }))
        }

        
        genericView.colorPicker.updateMode(.single(theme.colors.accent), animated: false)
        
        genericView.colorPicker.modeDidUpdate = { [weak self] mode in
            guard let `self` = self else {return}
            var newTheme = self.currentTheme
            switch mode {
            case let .single(color):
                let accent = PaletteAccentColor(color, newTheme.colors.bubbleBackground_outgoing)
                let colors = newTheme.colors.withoutAccentColor().withAccentColor(accent, disableTint: false)
                newTheme = newTheme.withUpdatedColors(colors)

            case let .gradient(colors, _, _):
                let accent = PaletteAccentColor(newTheme.colors.accent, colors)
                let colors = newTheme.colors.withoutAccentColor().withAccentColor(accent, disableTint: false)
                newTheme = newTheme.withUpdatedColors(colors)
            }
            self.currentTheme = newTheme
            self.genericView.updateMode(mode, newTheme: newTheme)
        }
        
        readyOnce()
    }
    
    
//    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
//        return (left: ModalHeaderData(image: currentTheme.icons.modalClose, handler: { [weak self] in
//            self?.close()
//        }), center: ModalHeaderData(title: strings().generalSettingsAccentColor), right: nil)
//    }
    
    private func saveAccent() {
        self.updateColor(PaletteAccentColor(currentTheme.colors.accent, currentTheme.colors.bubbleBackground_outgoing))
        
        delay(0.1, closure: { [weak self] in
           self?.close()
        })
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: strings().modalSet, accept: { [weak self] in
            self?.saveAccent()
        }, height: 50, customTheme: { [weak self] in
            return self?.modalTheme ?? .init()
        })
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(text: currentTheme.colors.text, grayText: currentTheme.colors.grayText, background: currentTheme.colors.background, border: currentTheme.colors.border, accent: currentTheme.colors.accent, grayForeground: currentTheme.colors.grayForeground)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func initializer() -> NSView {
        return CustomAccentColorView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), theme: currentTheme, context: self.context)
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: NSMakeSize(350, 380), animated: false)
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
