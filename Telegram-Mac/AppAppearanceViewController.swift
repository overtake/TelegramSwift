//
//  AppAppearanceViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit
import SyncCore

enum ThemeSettingsEntryTag: ItemListItemTag {
    case fontSize
    case theme
    case autoNight
    case chatMode
    case accentColor
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ThemeSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
    
    var stableId: InputDataEntryId {
        switch self {
        case .fontSize:
            return .custom(_id_theme_text_size)
        case .theme:
            return .custom(_id_theme_list)
        case .autoNight:
            return .general(_id_theme_auto_night)
        case .chatMode:
            return .general(_id_theme_chat_mode)
        case .accentColor:
            return .custom(_id_theme_accent_list)
        }
    }
}


struct InstallCloudThemeCachedData {
    let palette: ColorPalette
    let wallpaper: Wallpaper
    let cloudWallpaper: TelegramWallpaper?
}
enum InstallThemeSource {
    case local(ColorPalette)
    case cloud(TelegramTheme, InstallCloudThemeCachedData?)
}

private final class AppAppearanceViewArguments {
    let context: AccountContext
    let togglePalette:(InstallThemeSource)->Void
    let toggleBubbles:(Bool)->Void
    let toggleFontSize:(CGFloat)->Void
    let selectAccentColor:(NSColor?)->Void
    let selectChatBackground:()->Void
    let openAutoNightSettings:()->Void
    let removeTheme:(TelegramTheme)->Void
    let editTheme:(TelegramTheme)->Void
    let shareTheme:(TelegramTheme)->Void
    init(context: AccountContext, togglePalette: @escaping(InstallThemeSource)->Void, toggleBubbles: @escaping(Bool)->Void, toggleFontSize: @escaping(CGFloat)->Void, selectAccentColor: @escaping(NSColor?)->Void, selectChatBackground:@escaping()->Void, openAutoNightSettings:@escaping()->Void, removeTheme:@escaping(TelegramTheme)->Void, editTheme: @escaping(TelegramTheme)->Void, shareTheme:@escaping(TelegramTheme)->Void) {
        self.context = context
        self.togglePalette = togglePalette
        self.toggleBubbles = toggleBubbles
        self.toggleFontSize = toggleFontSize
        self.selectAccentColor = selectAccentColor
        self.selectChatBackground = selectChatBackground
        self.openAutoNightSettings = openAutoNightSettings
        self.removeTheme = removeTheme
        self.editTheme = editTheme
        self.shareTheme = shareTheme
    }
}


private let _id_theme_preview = InputDataIdentifier("_id_theme_preview")
private let _id_theme_list = InputDataIdentifier("_id_theme_list")
private let _id_theme_accent_list = InputDataIdentifier("_id_theme_accent_list")
private let _id_theme_chat_mode = InputDataIdentifier("_id_theme_chat_mode")
private let _id_theme_wallpaper = InputDataIdentifier("_id_theme_wallpaper")
private let _id_theme_text_size = InputDataIdentifier("_id_theme_text_size")
private let _id_theme_auto_night = InputDataIdentifier("_id_theme_auto_night")

private func appAppearanceEntries(appearance: Appearance, settings: ThemePaletteSettings, cloudThemes: [TelegramTheme], autoNightSettings: AutoNightThemePreferences, arguments: AppAppearanceViewArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appearanceSettingsColorThemeHeader), data: .init(viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_preview, equatable: InputDataEquatable(appearance), item: { initialSize, stableId in
        return ThemePreviewRowItem(initialSize, stableId: stableId, context: arguments.context, theme: appearance.presentation, viewType: .firstItem)
    }))
    
    let accentList = appearance.presentation.cloudTheme == nil ? appearance.presentation.colors.accentList : []
    
    var cloudThemes = cloudThemes
    if let cloud = appearance.presentation.cloudTheme {
        if !cloudThemes.contains(where: {$0.id == cloud.id}) {
            cloudThemes.append(cloud)
        }
    }
    
    struct ListEquatable : Equatable {
        let theme: TelegramPresentationTheme
        let cloudThemes:[TelegramTheme]
    }
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_list, equatable: InputDataEquatable(ListEquatable(theme: appearance.presentation, cloudThemes: cloudThemes)), item: { initialSize, stableId in
        
        let selected: ThemeSource
        if let cloud = appearance.presentation.cloudTheme {
            selected = .cloud(cloud)
        } else {
            selected = .local(appearance.presentation.colors)
        }
        
        var locals = [dayClassicPalette, whitePalette, tintedNightPalette, systemPalette]
        
        for (i, local) in locals.enumerated() {
            if let accent = settings.accents.first(where: { $0.name == local.parent }) {
                locals[i] = local.withAccentColor(accent.color)
            }
        }
        
        return ThemeListRowItem(initialSize, stableId: stableId, context: arguments.context, theme: appearance.presentation, selected: selected, local:  locals, cloudThemes: cloudThemes, viewType: accentList.isEmpty ? .lastItem : .innerItem, togglePalette: arguments.togglePalette, menuItems: { source in
            switch source {
            case let .cloud(cloud):
                var items:[ContextMenuItem] = []
                
                if cloud.isCreator {
                    items.append(ContextMenuItem(L10n.appearanceThemeEdit, handler: {
                        arguments.editTheme(cloud)
                    }))
                }
                items.append(ContextMenuItem(L10n.appearanceThemeShare, handler: {
                    arguments.shareTheme(cloud)
                }))
                items.append(ContextMenuItem(L10n.appearanceThemeRemove, handler: {
                    arguments.removeTheme(cloud)
                }))
                
                return items
            default:
                return []
            }
        })
    }))
    
    
    if !accentList.isEmpty {
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_accent_list, equatable: InputDataEquatable(appearance), item: { initialSize, stableId in
            return AccentColorRowItem(initialSize, stableId: stableId, list: accentList, isNative: true, theme: appearance.presentation, viewType: .lastItem, selectAccentColor: arguments.selectAccentColor)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_theme_chat_mode, data: InputDataGeneralData(name: L10n.appearanceSettingsBubblesMode, color: appearance.presentation.colors.text, type: .switchable(appearance.presentation.bubbled), viewType: appearance.presentation.bubbled ? .firstItem : .singleItem, action: {
        arguments.toggleBubbles(!appearance.presentation.bubbled)
    })))
    index += 1
    
    if appearance.presentation.bubbled {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_theme_wallpaper, data: InputDataGeneralData(name: L10n.generalSettingsChatBackground, color: appearance.presentation.colors.text, type: .next, viewType: .lastItem, action: arguments.selectChatBackground)))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appearanceSettingsTextSizeHeader), data: .init(viewType: .textTopItem)))
    index += 1

    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_text_size, equatable: InputDataEquatable(appearance), item: { initialSize, stableId in
        let sizes:[Int32] = [11, 12, 13, 14, 15, 16, 17, 18]
        return SelectSizeRowItem(initialSize, stableId: stableId, current: Int32(appearance.presentation.fontSize), sizes: sizes, hasMarkers: true, viewType: .singleItem, selectAction: { index in
            arguments.toggleFontSize(CGFloat(sizes[index]))
        })
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appearanceSettingsAutoNightHeader), data: .init(viewType: .textTopItem)))
    index += 1
    
    let autoNightText: String
    if autoNightSettings.systemBased {
        autoNightText = L10n.autoNightSettingsSystemBased
    } else if let _ = autoNightSettings.schedule {
        autoNightText = L10n.autoNightSettingsScheduled
    } else {
        autoNightText = L10n.autoNightSettingsDisabled
    }
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_theme_auto_night, data: InputDataGeneralData(name: L10n.appearanceSettingsAutoNight, color: appearance.presentation.colors.text, type: .nextContext(autoNightText), viewType: .singleItem, action: arguments.openAutoNightSettings)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func AppAppearanceViewController(context: AccountContext, focusOnItemTag: ThemeSettingsEntryTag? = nil) -> InputDataController {
    
    let applyCloudThemeDisposable = MetaDisposable()
    let updateDisposable = MetaDisposable()
    
    let arguments = AppAppearanceViewArguments(context: context, togglePalette: { source in
        
        let nightSettings = autoNightSettings(accountManager: context.sharedContext.accountManager) |> take(1) |> deliverOnMainQueue
        
        let applyTheme:()->Void = {
            switch source {
            case let .local(palette):
                updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    var settings = settings
                    settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(nil)
                    
                    let defaultTheme = DefaultTheme(local: palette.parent, cloud: nil)
                    if palette.isDark {
                        settings = settings.withUpdatedDefaultDark(defaultTheme)
                    } else {
                        settings = settings.withUpdatedDefaultDay(defaultTheme)
                    }
                    
                    return settings.installDefaultWallpaper().installDefaultAccent().withUpdatedDefaultIsDark(palette.isDark)
                }).start())
            case let .cloud(cloud, cached):
                if let cached = cached {
                    updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                        var settings = settings
                        settings = settings.withUpdatedPalette(cached.palette)
                        settings = settings.withUpdatedCloudTheme(cloud)
                        settings = settings.updateWallpaper { _ in
                            return ThemeWallpaper(wallpaper: cached.wallpaper, associated: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper))
                        }
                        let defaultTheme = DefaultTheme(local: settings.defaultDark.local, cloud: DefaultCloudTheme(cloud: cloud, palette: cached.palette, wallpaper: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper)))
                        if cached.palette.isDark {
                            settings = settings.withUpdatedDefaultDark(defaultTheme)
                        } else {
                            settings = settings.withUpdatedDefaultDay(defaultTheme)
                        }
                        return settings.saveDefaultWallpaper().withUpdatedDefaultIsDark(cached.palette.isDark)
                    }).start())
                    
                    applyCloudThemeDisposable.set(downloadAndApplyCloudTheme(context: context, theme: cloud, install: true).start())
                } else if let _ = cloud.file {
                    applyCloudThemeDisposable.set(showModalProgress(signal: downloadAndApplyCloudTheme(context: context, theme: cloud, install: true), for: context.window).start())
                } else {
                    showEditThemeModalController(context: context, theme: cloud)
                }
            }
        }
        
        _ = nightSettings.start(next: { settings in
            if settings.systemBased || settings.schedule != nil {
                confirm(for: context.window, header: L10n.darkModeConfirmNightModeHeader, information: L10n.darkModeConfirmNightModeText, okTitle: L10n.darkModeConfirmNightModeOK, successHandler: { _ in
                    let disableNightMode = context.sharedContext.accountManager.transaction { transaction -> Void in
                        transaction.updateSharedData(ApplicationSharedPreferencesKeys.autoNight, { entry in
                            let settings: AutoNightThemePreferences = entry as? AutoNightThemePreferences ?? AutoNightThemePreferences.defaultSettings
                            return settings.withUpdatedSystemBased(false).withUpdatedSchedule(nil)
                        })
                    } |> deliverOnMainQueue
                    _ = disableNightMode.start(next: {
                        applyTheme()
                    })
                })
            } else {
                applyTheme()
            }
        })
        
       
    }, toggleBubbles: { value in
        updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
            return settings.withUpdatedBubbled(value)
        }).start())
    }, toggleFontSize: { value in
        updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
            return settings.withUpdatedFontSize(value)
        }).start())
    }, selectAccentColor: { value in
        let updateColor:(NSColor)->Void = { color in
            updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                let clearPalette = settings.palette.withoutAccentColor()
                var settings = settings
                if color == settings.palette.basicAccent {
                    settings = settings.withUpdatedPalette(clearPalette)
                } else {
                    settings = settings.withUpdatedPalette(clearPalette.withAccentColor(color))
                }
                return settings.saveDefaultAccent(color: color)
            }).start())
        }
        if let color = value {
           updateColor(color)
        } else {
            showModal(with: CustomAccentColorModalController(context: context, updateColor: updateColor), for: context.window)
        }
    }, selectChatBackground: {
        showModal(with: ChatWallpaperModalController(context), for: context.window)
    }, openAutoNightSettings: {
        context.sharedContext.bindings.rootNavigation().push(AutoNightSettingsController(context: context))
    }, removeTheme: { cloudTheme in
        confirm(for: context.window, header: L10n.appearanceConfirmRemoveTitle, information: L10n.appearanceConfirmRemoveText, successHandler: { _ in
            var signals:[Signal<Void, NoError>] = []
            if theme.cloudTheme?.id == cloudTheme.id {
                signals.append(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: {
                    return $0.withUpdatedCloudTheme(nil).withUpdatedToDefault(dark: $0.defaultIsDark, onlyLocal: true).installDefaultWallpaper()
                }))
            }
            signals.append(deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: cloudTheme))
            updateDisposable.set(combineLatest(signals).start())
        })
    }, editTheme: { value in
        showEditThemeModalController(context: context, theme: value)
    }, shareTheme: { value in
        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/addtheme/\(value.slug)")), for: context.window)
    })
    
    let cloudThemes = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
    let nightSettings = autoNightSettings(accountManager: context.sharedContext.accountManager)
    
    let signal:Signal<InputDataSignalValue, NoError> = combineLatest(queue: prepareQueue, appearanceSignal, themeUnmodifiedSettings(accountManager: context.sharedContext.accountManager), cloudThemes, nightSettings) |> map { appearance, themeSettings, cloudThemes, autoNightSettings in
        return appAppearanceEntries(appearance: appearance, settings: themeSettings, cloudThemes: cloudThemes.reversed(), autoNightSettings: autoNightSettings, arguments: arguments)
    }
    |> map { entries in
         return InputDataSignalValue(entries: entries, animated: false)
    } |> deliverOnMainQueue
    
    
    let controller = InputDataController(dataSignal: signal, title: L10n.telegramAppearanceViewController, removeAfterDisappear:false, identifier: "app_appearance", customRightButton: { controller in
        
        let view = ImageBarView(controller: controller, theme.icons.chatActions)
        
        view.button.set(handler: { control in
            var items:[SPopoverItem] = []
            if theme.colors.parent != .system {
                items.append(SPopoverItem(L10n.appearanceNewTheme, {
                    showModal(with: NewThemeController(context: context, palette: theme.colors.withUpdatedWallpaper(theme.wallpaper.paletteWallpaper)), for: context.window)
                }))
                items.append(SPopoverItem(L10n.appearanceExportTheme, {
                    exportPalette(palette: theme.colors.withUpdatedName(theme.cloudTheme?.title ?? theme.colors.name).withUpdatedWallpaper(theme.wallpaper.paletteWallpaper))
                }))
                if let cloudTheme = theme.cloudTheme {
                    items.append(SPopoverItem(L10n.appearanceThemeShare, {
                        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/addtheme/\(cloudTheme.slug)")), for: context.window)
                    }))
                }
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .minX, inset: NSMakePoint(0,-50))
            }
        }, for: .Click)
        view.set(image: theme.icons.chatActions, highlightImage: nil)
        return view
        
    })
    
    controller.didLoaded = { controller, _ in
        if let focusOnItemTag = focusOnItemTag {
            controller.genericView.tableView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
        }
    }
    
    return controller
}
