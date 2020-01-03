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
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

private final class ThemePreviewView : BackgroundView {
    fileprivate let segmentControl = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 290, 30))
    private let segmentContainer = View()
    private let tableView: TableView = TableView(frame: NSZeroRect, isFlipped: false)
    weak var controller: ModalViewController?
    private let context: AccountContext
    required init(frame frameRect: NSRect, context: AccountContext) {
        self.context = context
        super.init(frame: frameRect)
        self.addSubview(tableView)
        segmentContainer.addSubview(segmentControl.view)
        self.addSubview(segmentContainer)
        
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            self.tableView.enumerateVisibleViews(with: { view in
                if let view = view as? ChatRowView {
                    view.updateBackground(within: self.tableView.frame.size, inset: position.rect.origin, animated: false)
                }
            })
        }))
        
        layout()
    }
    
    override func layout() {
        super.layout()
        segmentContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        self.segmentControl.view.center()
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
        
        
        self.tableView.enumerateVisibleViews(with: { view in
            if let view = view as? ChatRowView {
                view.updateBackground(within: self.tableView.frame.size, inset: self.tableView.scrollPosition().current.rect.origin, animated: false)
            }
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate func addTableItems(_ context: AccountContext, theme: TelegramPresentationTheme) {
        
        self.tableView.getBackgroundColor = {
            if theme.bubbled {
                return .clear
            } else {
                return theme.chatBackground
            }
        }
        
        tableView.afterSetupItem = { [weak self] view, item in
            guard let `self` = self else {
                return
            }
            if let view = view as? ChatRowView {
                let offset = self.tableView.scrollPosition().current.rect.origin
                view.updateBackground(within: self.tableView.frame.size, inset: offset, animated: false)
            }
        }
        
        
        
        segmentContainer.backgroundColor = theme.colors.background
        segmentContainer.borderColor = theme.colors.border
        segmentContainer.border = [.Bottom]
        segmentControl.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)
        
        tableView.removeAll()
        tableView.updateLocalizationAndTheme(theme: theme)
        tableView.backgroundColor = theme.colors.background
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: 0, backgroundColor: .clear))
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context, disableSelectAbility: true)
        
        let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        
        let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        
        let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
        
        let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, ChatHistoryEntryData(nil, nil, AutoplayMediaPreferences.defaultSettings))
        
        let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil), nil, ChatHistoryEntryData(nil, nil, AutoplayMediaPreferences.defaultSettings))
        
        
        let item1 = ChatRowItem.item(frame.size, from: firstEntry, interaction: chatInteraction, theme: theme)
        let item2 = ChatRowItem.item(frame.size, from: secondEntry, interaction: chatInteraction, theme: theme)
        
        
        _ = item1.makeSize(frame.width, oldWidth: 0)
        _ = item2.makeSize(frame.width, oldWidth: 0)
        
        _ = tableView.addItem(item: item2)
        _ = tableView.addItem(item: item1)
        
        

        
    }
    
}

enum ThemePreviewSource {
    case localTheme(TelegramPresentationTheme, name: String?)
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
        
        let updateChatMode:(Bool)->Void = { [weak self] bubbled in
            guard let `self` = self else {
                return
            }
            let newTheme = self.currentTheme.withUpdatedChatMode(bubbled).withUpdatedBackgroundSize(NSMakeSize(350, 350))
            self.currentTheme = newTheme
            self.genericView.addTableItems(self.context, theme: newTheme)
            self.genericView.backgroundMode = newTheme.controllerBackgroundMode
        }
        
        self.genericView.segmentControl.add(segment: CatalinaSegmentedItem(title: L10n.appearanceSettingsChatViewBubbles, handler: {
            updateChatMode(true)
        }))
        
        self.genericView.segmentControl.add(segment: CatalinaSegmentedItem(title: L10n.appearanceSettingsChatViewClassic, handler: {
            updateChatMode(false)
        }))
        
        switch self.source {
        case let .localTheme(theme, _):
            self.currentTheme = theme.withUpdatedChatMode(true)
            genericView.addTableItems(self.context, theme: theme)
            modal?.updateLocalizationAndTheme(theme: theme)
            genericView.backgroundMode = theme.controllerBackgroundMode
            self.readyOnce()
        case let .cloudTheme(theme):
            if let settings = theme.settings {
                let palette = settings.palette
                let wallpaper: Wallpaper
                let cloud = settings.wallpaper
                if let cloud = cloud {
                    wallpaper = Wallpaper(cloud)
                } else {
                    if settings.baseTheme == .classic {
                        wallpaper = .builtin
                    } else {
                        wallpaper = .none
                    }
                }
                self.disposable.set(showModalProgress(signal: moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wallpaper), for: context.window).start(next: { [weak self] wallpaper in
                    guard let `self` = self else {
                        return
                    }
                    let newTheme = self.currentTheme
                        .withUpdatedColors(palette)
                        .withUpdatedWallpaper(ThemeWallpaper(wallpaper: wallpaper, associated: AssociatedWallpaper(cloud: cloud, wallpaper: wallpaper)))
                        .withUpdatedChatMode(true)
                        .withUpdatedBackgroundSize(WallpaperDimensions.aspectFilled(NSMakeSize(600, 600)))
                    self.currentTheme = newTheme
                    self.genericView.addTableItems(context, theme: newTheme)
                    self.modal?.updateLocalizationAndTheme(theme: newTheme)
                    self.genericView.backgroundMode = newTheme.controllerBackgroundMode
                    self.readyOnce()
                    
                }))

            } else if let file = theme.file {
                let signal = loadCloudPaletteAndWallpaper(context: context, file: file)
                disposable.set(showModalProgress(signal: signal |> deliverOnMainQueue, for: context.window).start(next: { [weak self] data in
                    guard let `self` = self else {
                        return
                    }
                    if let (palette, wallpaper, cloud) = data {
                        let newTheme = self.currentTheme
                            .withUpdatedColors(palette)
                            .withUpdatedWallpaper(ThemeWallpaper(wallpaper: wallpaper, associated: AssociatedWallpaper(cloud: cloud, wallpaper: wallpaper)))
                            .withUpdatedChatMode(true)
                        self.currentTheme = newTheme
                        self.genericView.addTableItems(context, theme: newTheme)
                        self.modal?.updateLocalizationAndTheme(theme: newTheme)
                        self.genericView.backgroundMode = newTheme.controllerBackgroundMode
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
            
            return (left: ModalHeaderData(image: currentTheme.icons.modalClose, handler: { [weak self] in
                self?.close()
            }), center: ModalHeaderData(title: theme.title, subtitle: count > 0 ? countTitle : nil), right: ModalHeaderData(image: currentTheme.icons.modalShare, handler: { [weak self] in
                self?.share()
            }))
        case let .localTheme(theme, name):
            return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
                self?.close()
            }), center: ModalHeaderData(title: name ?? localizedString("AppearanceSettings.ColorTheme.\(theme.colors.name)")), right: nil)
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
        let currentTheme = self.currentTheme
        let colors = currentTheme.colors
        
        let cloudTheme: TelegramTheme?
        switch self.source {
        case let .cloudTheme(t):
            cloudTheme = t
        default:
            cloudTheme = nil
        }
        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
           var settings = settings
            .withUpdatedPalette(colors)
            .updateWallpaper { _ in
                return currentTheme.wallpaper
            }
            .withUpdatedCloudTheme(cloudTheme)
            .withUpdatedBubbled(currentTheme.bubbled)
            
            
            let defaultTheme: DefaultTheme
            
            if let cloudTheme = cloudTheme {
                defaultTheme = DefaultTheme(local: colors.parent, cloud: DefaultCloudTheme(cloud: cloudTheme, palette: colors, wallpaper: currentTheme.wallpaper.associated ?? AssociatedWallpaper(cloud: currentTheme.wallpaper.associated?.cloud, wallpaper: currentTheme.wallpaper.wallpaper)))
            } else {
                defaultTheme = DefaultTheme(local: colors.parent, cloud: nil)
            }
            
            if colors.isDark {
                settings = settings.withUpdatedDefaultDark(defaultTheme)
            } else {
                settings = settings.withUpdatedDefaultDay(defaultTheme)
            }
            settings = settings.withUpdatedDefaultIsDark(colors.isDark).saveDefaultAccent(color: PaletteAccentColor(colors.accent, (top: colors.bubbleBackgroundTop_outgoing, colors.bubbleBackgroundBottom_outgoing))).saveDefaultWallpaper().withSavedAssociatedTheme()
            return settings
        }).start()
        
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

func loadCloudPaletteAndWallpaper(context: AccountContext, file: TelegramMediaFile) -> Signal<(ColorPalette, Wallpaper, TelegramWallpaper?)?, NoError> {
    return context.account.postbox.mediaBox.resourceData(file.resource)
        |> filter { $0.complete }
        |> take(1)
        |> map { importPalette($0.path) }
        |> mapToSignal { palette -> Signal<(ColorPalette, Wallpaper, TelegramWallpaper?)?, NoError> in
            if let palette = palette {
                switch palette.wallpaper {
                case .builtin:
                    return .single((palette, Wallpaper.builtin, nil))
                case .none:
                    return .single((palette, Wallpaper.none, nil))
                case let .color(color):
                    return .single((palette, Wallpaper.color(color.argb), nil))
                case let .url(url):
                    let link = inApp(for: url as NSString, context: context)
                    switch link {
                    case let .wallpaper(values):
                        switch values.preview {
                        case let .slug(slug, settings):
                            return getWallpaper(network: context.account.network, slug: slug)
                                |> mapToSignal { cloud in
                                    return moveWallpaperToCache(postbox: context.account.postbox, wallpaper: Wallpaper(cloud).withUpdatedSettings(settings)) |> map { wallpaper in
                                        return (palette, wallpaper, cloud)
                                    } |> castError(GetWallpaperError.self)
                                }
                                |> `catch` { _ in
                                    return .single((palette, .none, nil))
                            }
                        default:
                            break
                        }
                    default:
                        break
                    }
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
    }
}
