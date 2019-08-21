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
    let selectAccentColor:()->Void
    let selectChatBackground:()->Void
    let openAutoNightSettings:()->Void
    let toggleFollowSystemAppearance:(Bool)->Void
    init(context: AccountContext, togglePalette: @escaping(ColorPalette, Wallpaper?)->Void, toggleBubbles: @escaping(Bool)->Void, toggleFontSize: @escaping(Int32)->Void, selectAccentColor: @escaping()->Void, selectChatBackground:@escaping()->Void, openAutoNightSettings:@escaping()->Void, toggleFollowSystemAppearance: @escaping(Bool)->Void) {
        self.context = context
        self.togglePalette = togglePalette
        self.toggleBubbles = toggleBubbles
        self.toggleFontSize = toggleFontSize
        self.selectAccentColor = selectAccentColor
        self.selectChatBackground = selectChatBackground
        self.openAutoNightSettings = openAutoNightSettings
        self.toggleFollowSystemAppearance = toggleFollowSystemAppearance
    }
}

private enum AppearanceViewEntry : TableItemListNodeEntry {
    case colorPalette(Int32, Int32, Bool, ColorPalette, Wallpaper?)
    case chatView(Int32, Int32, Bool, Bool)
    case accentColor(Int32, Int32, NSColor)
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
        case .chatView(_, let index, _, _):
            return index
        case .accentColor(_, let index, _):
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
        case let .chatView(section, index, _, _):
            return (section * 1000) + index
        case let .accentColor(section, index, _):
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
        case let .chatView(_, _, selected, value):
            //, description: tr(L10n.generalSettingsDarkModeDescription)
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
        case let .accentColor(_, _, color):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.generalSettingsAccentColor), type: .colorSelector(color), action: {
                arguments.selectAccentColor()
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

private func AppearanceViewEntries(settings: TelegramPresentationTheme, themeSettings: ThemePaletteSettings) -> [AppearanceViewEntry] {
    var entries:[AppearanceViewEntry] = []
    
    var sectionId:Int32 = 1
    var descIndex:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    
    var index: Int32 = 0
    
    entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsTextSizeHeader, true))
    descIndex += 1
    
    let sizes:[Int32] = [11, 12, 13, 14, 15, 16, 17, 18]
            
    entries.append(.font(sectionId, index, Int32(settings.fontSize), sizes))
    index += 1
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsChatPreviewHeader, true))
    descIndex += 1
    
    let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName1, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
    
    let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: L10n.appearanceSettingsChatPreviewUserName2, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])

    
    entries.append(.section(sectionId))
    sectionId += 1
    
    let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewZeroText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])

    
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
    
    let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, MessageIndex(firstMessage), true, settings.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    
    entries.append(.preview(sectionId, index, firstEntry))
    index += 1
    
    let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: fromUser1, text: L10n.appearanceSettingsChatPreviewSecondText, attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    
    let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, settings.bubbled ? .bubble : .list, .Full(rank: nil), nil, nil, nil, AutoplayMediaPreferences.defaultSettings)
    
    entries.append(.preview(sectionId, index, secondEntry))
    index += 1
    
    entries.append(.chatBackground(sectionId, index))
    index += 1
    

    
    if !settings.followSystemAppearance {
        if settings.colors.name != dayClassic.name {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            entries.append(.accentColor(sectionId, index, theme.colors.accent))
            index += 1
        }
        
        
        
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsColorThemeHeader, true))
        descIndex += 1
        
        
        var installed:[String: ColorPalette] = [:]
        
        installed[whitePalette.name] = whitePalette
        installed[nightBluePalette.name] = nightBluePalette
        installed[dayClassic.name] = dayClassic
        installed[darkPalette.name] = darkPalette
        installed[mojavePalette.name] = darkPalette
        
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == dayClassic.name, dayClassic, settings.bubbled ? .builtin : nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == whitePalette.name, whitePalette, nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == nightBluePalette.name, nightBluePalette, nil))
        index += 1
        
        
        entries.append(.colorPalette(sectionId, index, settings.colors.name == mojavePalette.name, mojavePalette, nil))
        index += 1
        
        
        var paths = Bundle.main.paths(forResourcesOfType: "palette", inDirectory: "palettes")
        let globalPalettes = "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/Palettes/".nsstring.expandingTildeInPath + "/"
        paths += ((try? FileManager.default.contentsOfDirectory(atPath: globalPalettes)) ?? []).map({globalPalettes + $0})
        
        let palettes = paths.map{importPalette($0)}.filter{$0 != nil}.map{$0!}
        
        for palette in palettes {
            if palette != whitePalette && palette != darkPalette && palette != settings.colors, installed[palette.name] == nil {
                installed[palette.name] = palette
                entries.append(.colorPalette(sectionId, index, palette.name == settings.colors.name, palette, nil))
                index += 1
            }
        }
        
        if installed[settings.colors.name] == nil {
            installed[settings.colors.name] = settings.colors
            entries.append(.colorPalette(sectionId, index, true, settings.colors, settings.wallpaper))
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
        
        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultDayName == dayClassic.name, dayClassic, nil))
        index += 1
        
        entries.append(.colorPalette(sectionId, index, themeSettings.defaultDayName == whitePalette.name, whitePalette, nil))
        index += 1
        
        entries.append(.description(sectionId, descIndex, L10n.appearanceSettingsFollowSystemAppearanceDefaultDay, false))
        descIndex += 1
        
    }
    
    
    
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
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: false)
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
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
      //  super.updateLocalizationAndTheme()
        tableView.updateLocalizationAndTheme()
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
                return settings.withUpdatedPalette(palette).withUpdatedWallpaper(settings.bubbled ? settings.wallpaper : .none).withUpdatedDefaultDayName(!palette.isDark ? palette.name : settings.defaultDayName).withUpdatedDefaultNightName(palette.isDark ? palette.name : settings.defaultNightName)
                
            }), updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedSchedule(nil)})).start()
        }, toggleBubbles: { enabled in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedBubbled(enabled)//.withUpdatedWallpaper(enabled ? settings.wallpaper : .none)
            }).start()
        }, toggleFontSize: { size in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedFontSize(CGFloat(size))
            }).start()
        }, selectAccentColor: {
            showModal(with: AccentColorModalController(context, current: theme.colors.accent), for: context.window)
        }, selectChatBackground: {
            showModal(with: ChatWallpaperModalController(context), for: mainWindow)
        }, openAutoNightSettings: { [weak self] in
            self?.navigationController?.push(autoNightSettingsController(context.sharedContext))
        }, toggleFollowSystemAppearance: { value in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedFollowSystemAppearance(value).withUpdatedWallpaper(settings.bubbled ? settings.wallpaper : .none)
            }).start()
        })
        
        let initialSize = self.atomicSize

        
        let previous: Atomic<[AppearanceWrapperEntry<AppearanceViewEntry>]> = Atomic(value: [])
        
        let signal:Signal<(TableUpdateTransition, Wallpaper), NoError> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, themeUnmodifiedSettings(accountManager: context.sharedContext.accountManager)) |> map { appearance, themeSettings in
            let entries = AppearanceViewEntries(settings: appearance.presentation, themeSettings: themeSettings).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), appearance.presentation.wallpaper)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition, wallpaper in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
    
    override public var isOpaque: Bool {
        return false
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        genericView.backgroundColor = .clear
        self.navigationController?.backgroundMode = theme.backgroundMode
    }
   
    deinit {
        disposable.dispose()
    }
    
    override func firstResponder() -> NSResponder? {
       return genericView.tableView.item(stableId: Int32(1))?.view?.firstResponder
    }
    
}
