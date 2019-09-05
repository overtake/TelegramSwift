//
//  AppearanceViewController.swift
//  Telegram
//
//  Created by keepcoder on 07/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class AppearanceViewArguments {
    let context: AccountContext
    let togglePalette:(ColorPalette, Wallpaper?)->Void
    let toggleBubbles:(Bool)->Void
    let toggleFontSize:(Int32)->Void
    let selectAccentColor:(NSColor?)->Void
    let selectChatBackground:()->Void
    let openAutoNightSettings:()->Void
    let toggleFollowSystemAppearance:(Bool)->Void
    let removeTheme:(TelegramTheme)->Void
    let editTheme:(TelegramTheme)->Void
    let shareTheme:(TelegramTheme)->Void
    let installCloudTheme: (TelegramTheme)->Void
    init(context: AccountContext, togglePalette: @escaping(ColorPalette, Wallpaper?)->Void, toggleBubbles: @escaping(Bool)->Void, toggleFontSize: @escaping(Int32)->Void, selectAccentColor: @escaping(NSColor?)->Void, selectChatBackground:@escaping()->Void, openAutoNightSettings:@escaping()->Void, toggleFollowSystemAppearance: @escaping(Bool)->Void, removeTheme:@escaping(TelegramTheme)->Void, editTheme: @escaping(TelegramTheme)->Void, shareTheme:@escaping(TelegramTheme)->Void, installCloudTheme:@escaping(TelegramTheme)->Void) {
        self.context = context
        self.togglePalette = togglePalette
        self.toggleBubbles = toggleBubbles
        self.toggleFontSize = toggleFontSize
        self.selectAccentColor = selectAccentColor
        self.selectChatBackground = selectChatBackground
        self.openAutoNightSettings = openAutoNightSettings
        self.toggleFollowSystemAppearance = toggleFollowSystemAppearance
        self.removeTheme = removeTheme
        self.editTheme = editTheme
        self.shareTheme = shareTheme
        self.installCloudTheme = installCloudTheme
    }
}

private enum AppearanceViewEntry : TableItemListNodeEntry {
    case colorPalette(Int32, Int32, Bool, ColorPalette, Wallpaper?)
    case telegramTheme(Int32, Int32, Bool, TelegramTheme)
    case chatView(Int32, Int32, Bool, Bool)
    case accentColor(Int32, Int32, [NSColor], Bool)
    case chatBackground(Int32, Int32)
    case autoNight(Int32, Int32)
    case followSystemAppearance(Int32, Int32, Bool)
    case section(Int32)
    case preview(Int32, Int32, ChatHistoryEntry)
    case font(Int32, Int32, Int32, [Int32])
    case description(Int32, Int32, String, Bool)
    
    var stableId: Int32 {
        switch self {
        case .colorPalette(_, let index, _, _, _):
            return index
        case .telegramTheme(_, let index, _, _):
            return index
        case .chatView(_, let index, _, _):
            return index
        case .accentColor(_, let index, _, _):
            return index
        case .chatBackground(_, let index):
            return index
        case .autoNight(_, let index):
            return index
        case .followSystemAppearance(_, let index, _):
            return index
        case .section(let section):
            return section + 1000
        case .font(_, let index, _, _):
            return index
        case let .preview(_, index, _):
            return index
        case let .description(section, index, _, _):
            return (section * 1000) + (index + 1) * 1000
        }
    }
    
    var index:Int32 {
        switch self {
        case let .colorPalette(section, index, _, _, _):
            return (section * 1000) + index
        case let .telegramTheme(section, index, _, _):
             return (section * 1000) + index
        case let .chatView(section, index, _, _):
            return (section * 1000) + index
        case let .accentColor(section, index, _, _):
            return (section * 1000) + index
        case let .chatBackground(section, index):
            return (section * 1000) + index
        case let .autoNight(section, index):
            return (section * 1000) + index
        case let .followSystemAppearance(section, index, _):
            return (section * 1000) + index
        case .section(let section):
            return (section + 1) * 1000 - section
        case let .font(section, index, _, _):
            return (section * 1000) + index
        case let .preview(section, id, _):
            return (section * 1000) + id
        case let .description(section, index, _, _):
            return (section * 1000) + index + 2
        }
    }
    
    func item(_ arguments: AppearanceViewArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .colorPalette(_, _, selected, palette, wallpaper):
            let localizationKey = "AppearanceSettings.ColorTheme." + palette.name.lowercased().replacingOccurrences(of: " ", with: "_")
            let localized = _NSLocalizedString(localizationKey)
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: localized != localizationKey ? localized : palette.name, type: .selectable(selected), action: {
                arguments.togglePalette(palette, wallpaper)
            })
        case let .telegramTheme(_, _, selected, theme):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: theme.title, description: theme.file == nil ? L10n.appearanceCloudThemeUnsupported : nil, type: .selectable(selected), action: {
               if theme.file == nil {
                    arguments.editTheme(theme)
                } else {
                    arguments.installCloudTheme(theme)
                }
            }, menuItems: {
                var items:[ContextMenuItem] = []
                
                if theme.isCreator {
                    items.append(ContextMenuItem(L10n.appearanceThemeEdit, handler: {
                        arguments.editTheme(theme)
                    }))
                }
                items.append(ContextMenuItem(L10n.appearanceThemeShare, handler: {
                    arguments.shareTheme(theme)
                }))
                items.append(ContextMenuItem(L10n.appearanceThemeRemove, handler: {
                    arguments.removeTheme(theme)
                }))
                
                
                
                return items
            })
        case let .chatView(_, _, selected, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: !value ? tr(L10n.appearanceSettingsChatViewClassic) : tr(L10n.appearanceSettingsChatViewBubbles), type: .selectable(selected), action: {
                arguments.toggleBubbles(value)
            })
        case .chatBackground:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsChatBackground, type: .next, action: {
                arguments.selectChatBackground()
            })
        case .autoNight:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.appearanceSettingsAutoNight, type: .next, action: {
                arguments.openAutoNightSettings()
            })
        case let .followSystemAppearance(_, _, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.appearanceSettingsFollowSystemAppearance, type: .switchable(value), action: {
                arguments.toggleFollowSystemAppearance(!value)
            })
        case let .accentColor(_, _, list, isNative):
            return AccentColorRowItem(initialSize, stableId: stableId, list: list, isNative: isNative, selectAccentColor: { color in
                arguments.selectAccentColor(color)
            })
        case .description(_, _, let text, let haveSeparator):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: haveSeparator, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, backgroundColor: theme.colors.background)
        case let .font(_, _, current, sizes):
            return SelectSizeRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, hasMarkers: true, selectAction: { index in
                arguments.toggleFontSize(sizes[index])
            })
        case let .preview(_, _, entry):
            let item = ChatRowItem.item(initialSize, from: entry, interaction: ChatInteraction(chatLocation: .peer(PeerId(0)), context: arguments.context, disableSelectAbility: true), theme: theme)
            _ = item.makeSize(initialSize.width, oldWidth: 0)
            return item
        }
    }
}

private func <(lhs: AppearanceViewEntry, rhs: AppearanceViewEntry) -> Bool {
    return lhs.index < rhs.index
}

private func AppearanceViewEntries(settings: TelegramPresentationTheme, themeSettings: ThemePaletteSettings, telegramThemes: [TelegramTheme]) -> [AppearanceViewEntry] {
    var entries:[AppearanceViewEntry] = []
    
    var sectionId:Int32 = 1
    var descIndex:Int32 = 1
   
    var index: Int32 = 0
    
    
    let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
    
    let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])

    
    let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])

    
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
    
    let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, themeSettings.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    
    entries.append(.preview(sectionId, index, firstEntry))
    index += 1
    
    let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    
    let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, themeSettings.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    
    entries.append(.preview(sectionId, index, secondEntry))
    index += 1
    
    entries.append(.chatBackground(sectionId, index))
    index += 1
    
    if !themeSettings.palette.accentList.isEmpty {
        entries.append(.accentColor(sectionId, index, settings.colors.accentList, themeSettings.palette.isNative))
        index += 1
    }
    

    if !themeSettings.followSystemAppearance {
       
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsColorThemeHeader, true))
        descIndex += 1
        
        
        var installed:[String: ColorPalette] = [:]
        
        installed[whitePalette.name] = whitePalette
        installed[nightBluePalette.name] = nightBluePalette
        installed[dayClassicPalette.name] = dayClassicPalette
        installed[darkPalette.name] = darkPalette
        installed[mojavePalette.name] = darkPalette
        
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == dayClassicPalette.name && themeSettings.cloudTheme == nil, dayClassicPalette, settings.bubbled ? .builtin : nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == whitePalette.name && themeSettings.cloudTheme == nil, whitePalette, nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == nightBluePalette.name && themeSettings.cloudTheme == nil, nightBluePalette, nil))
        index += 1
        
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == mojavePalette.name && themeSettings.cloudTheme == nil, mojavePalette, nil))
        index += 1
        
        
        if installed[settings.colors.name] == nil && settings.cloudTheme == nil {
            installed[settings.colors.name] = settings.colors
            entries.append(.colorPalette(sectionId, index, true, settings.colors, settings.wallpaper.wallpaper))
            index += 1
        }
        
       
       
        if !telegramThemes.isEmpty {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            entries.append(.description(sectionId, descIndex, L10n.appearanceCloudThemes, true))
            descIndex += 1
            
            for theme in telegramThemes {
                entries.append(.telegramTheme(sectionId, index, themeSettings.cloudTheme?.id == theme.id, theme))
                index += 1
            }
        }
        
        
       
        let foundCloud: Bool = telegramThemes.contains {
            themeSettings.cloudTheme?.id == $0.id
        }
        if !foundCloud, let theme = themeSettings.cloudTheme {
            if telegramThemes.isEmpty {
                entries.append(.section(sectionId))
                sectionId += 1
                
                entries.append(.description(sectionId, descIndex, L10n.appearanceCloudThemes, true))
                descIndex += 1
            }
            entries.append(.telegramTheme(sectionId, index, true, theme))
            index += 1
        }
        
    } else {
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsFollowSystemAppearanceDefaultHeader, false))
        descIndex += 1

        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultNightName == nightBluePalette.name, nightBluePalette, nil))
        index += 1
        
        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultNightName == mojavePalette.name, mojavePalette, nil))
        index += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsFollowSystemAppearanceDefaultDark, false))
        descIndex += 1
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultDayName == dayClassicPalette.name, dayClassicPalette, nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultDayName == whitePalette.name, whitePalette, nil))
        index += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsFollowSystemAppearanceDefaultDay, false))
        descIndex += 1
        
    }
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsTextSizeHeader, true))
    descIndex += 1
    
    let sizes:[Int32] = [11, 12, 13, 14, 15, 16, 17, 18]
    
    entries.append(.font(sectionId, index, Int32(settings.fontSize), sizes))
    index += 1
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsChatViewHeader, true))
    descIndex += 1
    
    entries.append(.chatView(sectionId, index, !settings.bubbled, false))
    index += 1
    entries.append(.chatView(sectionId, index, settings.bubbled, true))
    index += 1
    

    entries.append(.section(sectionId))
    sectionId += 1

    
    if #available(OSX 10.14, *) {
        entries.append(.followSystemAppearance(sectionId, index, settings.followSystemAppearance))
        index += 1
    }
    
   // #if BETA
    if !settings.followSystemAppearance {
        entries.append(.autoNight(sectionId, index))
        index += 1
    }
   

    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
  //  #endif
   
  
//
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<AppearanceViewEntry>], right: [AppearanceWrapperEntry<AppearanceViewEntry>], initialSize:NSSize, arguments:AppearanceViewArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: false, grouping: false)
}

final class AppeaanceView : View {
    fileprivate let tableView: TableView = TableView()
    private let bottomHolder: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.verticalScrollElasticity = .none
        tableView.layer?.backgroundColor = .clear
        addSubview(bottomHolder)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
      //  super.updateLocalizationAndTheme(theme: theme)
        tableView.updateLocalizationAndTheme(theme: theme)
        bottomHolder.backgroundColor = theme.colors.background
    }
    
    func merge(with transition: TableUpdateTransition) {
        self.tableView.merge(with: transition)
        self.needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        tableView.frame = bounds
        let height = frame.height - tableView.listHeight
        bottomHolder.frame = NSMakeRect(0, frame.height - height, frame.width, height)
    }
}

class AppearanceViewController: TelegramGenericViewController<AppeaanceView> {
    private let disposable = MetaDisposable()
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        _ = telegramWallpapers(postbox: context.account.postbox, network: context.account.network).start()
        
        let arguments = AppearanceViewArguments(context: context, togglePalette: { palette, _ in
            _ = combineLatest(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                var settings = settings.withUpdatedPalette(palette)
                settings = settings.withUpdatedDefaultDayName(!palette.isDark ? palette.name : settings.defaultDayName)
                settings = settings.withUpdatedDefaultNightName(palette.isDark ? palette.name : settings.defaultNightName)
                settings = settings.withUpdatedCloudTheme(nil)
                settings = settings.withStandartWallpaper()
                return settings
            }), updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedSchedule(nil)})).start()
        }, toggleBubbles: { enabled in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedBubbled(enabled)
            }).start()
        }, toggleFontSize: { size in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedFontSize(CGFloat(size))
            }).start()
        }, selectAccentColor: { color in
            if let color = color {
                _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    if color == theme.colors.basicAccent {
                        return settings.withUpdatedPalette(theme.colors.withoutAccentColor())
                    } else {
                        return settings.withUpdatedPalette(theme.colors.withoutAccentColor().withAccentColor(color))
                    }
                }).start()
            } else {
                showModal(with: CustomAccentColorModalController(context: context), for: context.window)
            }
        }, selectChatBackground: {
            showModal(with: ChatWallpaperModalController(context), for: mainWindow)
        }, openAutoNightSettings: { [weak self] in
            self?.navigationController?.push(autoNightSettingsController(context.sharedContext))
        }, toggleFollowSystemAppearance: { value in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedFollowSystemAppearance(value).withUpdatedCloudTheme(nil)
            }).start()
        }, removeTheme: { cloudTheme in
            confirm(for: context.window, header: L10n.appearanceConfirmRemoveTitle, information: L10n.appearanceConfirmRemoveText, successHandler: { _ in
                if theme.cloudTheme?.id == cloudTheme.id {
                    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: {
                        return $0.withUpdatedCloudTheme(nil).withUpdatedPaletteToDefault()
                    }).start()
                    if theme.colors.isDark {
                       
                    }
                }
                _ = deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: cloudTheme).start()
            })
        }, editTheme: { theme in
            showEditThemeModalController(context: context, theme: theme)
        }, shareTheme: { theme in
            showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/addtheme/\(theme.slug)")), for: context.window)
        }, installCloudTheme: { theme in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: {
                return $0.withUpdatedCloudTheme(theme).updateWallpaper { value in
                    return value.withUpdatedWallpaper(.none).withUpdatedAssociated(AssociatedWallpaper(cloud: nil, wallpaper: .none))
                }
            }).start()
        })
        
        let initialSize = self.atomicSize

        
        let previous: Atomic<[AppearanceWrapperEntry<AppearanceViewEntry>]> = Atomic(value: [])
        
        let telegramThemesSignal = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
        
        let signal:Signal<(TableUpdateTransition, Wallpaper), NoError> = combineLatest(queue: prepareQueue, appearanceSignal, themeUnmodifiedSettings(accountManager: context.sharedContext.accountManager), telegramThemesSignal) |> map { appearance, themeSettings, telegramThemes in
            let entries = AppearanceViewEntries(settings: appearance.presentation, themeSettings: themeSettings, telegramThemes: telegramThemes).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), appearance.presentation.wallpaper.wallpaper)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition, wallpaper in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
    
    override func getRightBarViewOnce() -> BarView {
        let view = ImageBarView(controller: self, theme.icons.chatActions)
        
        let context = self.context
        
        view.button.set(handler: { control in
            
            var items:[SPopoverItem] = []
            
            items.append(SPopoverItem(L10n.appearanceNewTheme, {
                showModal(with: NewThemeController(context: context, palette: theme.colors.withUpdatedWallpaper(theme.wallpaper.paletteWallpaper)), for: context.window)
            }))
            items.append(SPopoverItem(L10n.appearanceExportTheme, {
                exportPalette(palette: theme.colors.withUpdatedWallpaper(theme.wallpaper.paletteWallpaper))
            }))
            
            if let cloudTheme = theme.cloudTheme {
                items.append(SPopoverItem(L10n.appearanceThemeShare, {
                    showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/addtheme/\(cloudTheme.slug)")), for: context.window)
                }))
            }
            showPopover(for: control, with: SPopoverViewController(items: items), edge: .minX, inset: NSMakePoint(0,-50))
        }, for: .Click)
        view.set(image: theme.icons.chatActions, highlightImage: theme.icons.chatActionsActive)
        return view
    }
    
    override public var isOpaque: Bool {
        return false
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        genericView.backgroundColor = .clear
        let theme = (theme as! TelegramPresentationTheme)
        self.navigationController?.backgroundMode = theme.backgroundMode
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        (self.rightBarView as? ImageBarView)?.set(image: theme.icons.chatActions, highlightImage: theme.icons.chatActionsActive)
    }
   
    deinit {
        disposable.dispose()
    }
    
    override var supportSwipes: Bool {
        var accentView: AccentColorRowView?
        genericView.tableView.enumerateViews { view -> Bool in
            if let view = view as? AccentColorRowView {
                accentView = view
                return false
            }
            return true
        }
        if let accentView = accentView {
            return !accentView.mouseInside()
        }
        return true
    }
    
    override func firstResponder() -> NSResponder? {
       return genericView.tableView.item(stableId: Int32(1))?.view?.firstResponder
    }
    
}
