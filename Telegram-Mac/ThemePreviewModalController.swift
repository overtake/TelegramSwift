//
//  ThemePreviewModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class ThemePreviewView : View {
    private let tableView: TableView = TableView.init(frame: NSZeroRect, isFlipped: false)
    weak var controller: ModalViewController?
    private let context: AccountContext
    required init(frame frameRect: NSRect, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(tableView)
        
        layout()
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate func addTableItems(_ context: AccountContext, theme: TelegramPresentationTheme) {
        
        self.tableView.getBackgroundColor = {
            return theme.colors.chatBackground
        }
        
        tableView.removeAll()
        tableView.updateLocalizationAndTheme(theme: theme)
        tableView.backgroundColor = theme.colors.background
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
        
        _ = tableView.addItem(item: item2)
        _ = tableView.addItem(item: item1)
        
    }
    
}

enum ThemePreviewSource {
    case localTheme(TelegramPresentationTheme)
    case cloudTheme(TelegramTheme)
}


class ThemePreviewModalController: ModalViewController {
    
    private let context: AccountContext
    private let source:ThemePreviewSource
    private let disposable = MetaDisposable()
    private var currentTheme: TelegramPresentationTheme = theme
    private var fetchDisposable = MetaDisposable()
    init(context: AccountContext, source: ThemePreviewSource) {
        self.context = context
        self.source = source
        super.init(frame: NSMakeRect(0, 0, 350, 350))
        self.bar = .init(height: 0)
    }
    
    deinit {
        disposable.dispose()
        fetchDisposable.dispose()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.controller = self
        let context = self.context
        
        switch self.source {
        case let .localTheme(theme):
            self.currentTheme = theme
            genericView.addTableItems(self.context, theme: theme)
            modal?.updateLocalizationAndTheme(theme: theme)
            self.readyOnce()
        case let .cloudTheme(theme):
            if let file = theme.file {
                disposable.set(showModalProgress(signal: context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1), for: context.window).start(next: { [weak self] data in
                    guard let `self` = self else {
                        return
                    }
                    if let palette = importPalette(data.path) {
                        let newTheme = self.currentTheme.withUpdatedColors(palette)
                        self.currentTheme = newTheme
                        self.genericView.addTableItems(context, theme: newTheme)
                        self.modal?.updateLocalizationAndTheme(theme: newTheme)
                        self.readyOnce()
                    } else {
                        self.close()
                        alert(for: context.window, info: L10n.unknownError)
                    }
                    
                }))
                fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.media(media: AnyMediaReference.standalone(media: file), resource: file.resource)).start())
            }
        }
        
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        switch self.source {
        case let .cloudTheme(theme):
            
            let count:Int32 = theme.installCount
            
            var countTitle = L10n.themePreviewUsesCountCountable(Int(count))
            countTitle = countTitle.replacingOccurrences(of: "\(count)", with: count.formattedWithSeparator)

            return (left: nil, center: ModalHeaderData(title: theme.title, subtitle: count > 0 ? countTitle : nil), right: ModalHeaderData(image: currentTheme.icons.modalShare, handler: { [weak self] in
                self?.share()
            }))
        case let .localTheme(theme):
            return (left: nil, center: ModalHeaderData(title: theme.colors.name), right: nil)
        }
        
    }
    
    private func share() {
        switch self.source {
        case let .cloudTheme(theme):
            showModal(with: ShareModalController(ShareLinkObject(self.context, link: "https://t.me/addtheme/\(theme.slug)")), for: self.context.window)
        default:
            break
        }
    }
    
    private func saveAccent() {
        
        let context = self.context
        let colors = currentTheme.colors
        
        let cloudTheme: TelegramTheme?
        switch self.source {
        case let .cloudTheme(t):
            cloudTheme = t
            if t.id == theme.cloudTheme?.id {
                self.close()
                return
            }
        default:
            cloudTheme = nil
        }
        
        
        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
           return settings.withUpdatedPalette(colors).withUpdatedCloudTheme(cloudTheme)
        }).start()
        
        delay(0.1, closure: { [weak self] in
            self?.close()
        })
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalSet, accept: { [weak self] in
            self?.saveAccent()
        }, cancelTitle: L10n.modalCancel, cancel: { [weak self] in
            self?.close()
        }, drawBorder: true)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func initializer() -> NSView {
        return ThemePreviewView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), context: self.context)
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: NSMakeSize(350, 350), animated: false)
    }
    
    private var genericView:ThemePreviewView {
        return self.view as! ThemePreviewView
    }
    override func viewClass() -> AnyClass {
        return ThemePreviewView.self
    }
}


func paletteFromFile(context: AccountContext, file: TelegramMediaFile) -> ColorPalette? {
    let path = context.account.postbox.mediaBox.resourcePath(file.resource)
    
    return importPalette(path)
}

