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


struct AppearanceAccentColor : Equatable {
    let accent: PaletteAccentColor
    let cloudTheme: TelegramTheme?
    let cachedTheme: InstallCloudThemeCachedData?
    init(accent: PaletteAccentColor, cloudTheme: TelegramTheme?, cachedTheme: InstallCloudThemeCachedData? = nil) {
        self.accent = accent
        self.cloudTheme = cloudTheme
        self.cachedTheme = cachedTheme
    }
    func withUpdatedCachedTheme(_ cachedTheme: InstallCloudThemeCachedData?) -> AppearanceAccentColor {
        return .init(accent: self.accent, cloudTheme: self.cloudTheme, cachedTheme: cachedTheme)
    }
}

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


struct InstallCloudThemeCachedData : Equatable {
    let palette: ColorPalette
    let wallpaper: Wallpaper
    let cloudWallpaper: TelegramWallpaper?
}
enum InstallThemeSource : Equatable {
    case local(ColorPalette)
    case cloud(TelegramTheme, InstallCloudThemeCachedData?)
}

private final class AppAppearanceViewArguments {
    let context: AccountContext
    let togglePalette:(InstallThemeSource)->Void
    let toggleBubbles:(Bool)->Void
    let toggleFontSize:(CGFloat)->Void
    let selectAccentColor:(AppearanceAccentColor?)->Void
    let selectChatBackground:()->Void
    let openAutoNightSettings:()->Void
    let removeTheme:(TelegramTheme)->Void
    let editTheme:(TelegramTheme)->Void
    let shareTheme:(TelegramTheme)->Void
    let shareLocal:(ColorPalette)->Void
    init(context: AccountContext, togglePalette: @escaping(InstallThemeSource)->Void, toggleBubbles: @escaping(Bool)->Void, toggleFontSize: @escaping(CGFloat)->Void, selectAccentColor: @escaping(AppearanceAccentColor?)->Void, selectChatBackground:@escaping()->Void, openAutoNightSettings:@escaping()->Void, removeTheme:@escaping(TelegramTheme)->Void, editTheme: @escaping(TelegramTheme)->Void, shareTheme:@escaping(TelegramTheme)->Void, shareLocal:@escaping(ColorPalette)->Void) {
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
        self.shareLocal = shareLocal
    }
}


private let _id_theme_preview = InputDataIdentifier("_id_theme_preview")
private let _id_theme_list = InputDataIdentifier("_id_theme_list")
private let _id_theme_accent_list = InputDataIdentifier("_id_theme_accent_list")
private let _id_theme_chat_mode = InputDataIdentifier("_id_theme_chat_mode")
private let _id_theme_wallpaper1 = InputDataIdentifier("_id_theme_wallpaper")
private let _id_theme_wallpaper2 = InputDataIdentifier("_id_theme_wallpaper")
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
    
    var accentList = appearance.presentation.cloudTheme == nil || appearance.presentation.cloudTheme?.settings != nil ? appearance.presentation.colors.accentList.map { AppearanceAccentColor(accent: $0, cloudTheme: nil) } : []
    
    var cloudThemes = cloudThemes
    if let cloud = appearance.presentation.cloudTheme {
        if !cloudThemes.contains(where: {$0.id == cloud.id}) {
            cloudThemes.append(cloud)
        }
    }
    if appearance.presentation.cloudTheme == nil || appearance.presentation.cloudTheme?.settings != nil {
        let copy = cloudThemes
        var cloudAccents:[AppearanceAccentColor] = []
        for cloudTheme in copy {
            if let settings = cloudTheme.settings, settings.palette.parent == appearance.presentation.colors.parent {
                cloudAccents.append(AppearanceAccentColor(accent: settings.accent, cloudTheme: cloudTheme))
            }
        }
        accentList.insert(contentsOf: cloudAccents, at: 0)
    }
    
    cloudThemes.removeAll(where:{ $0.settings != nil })
    
    struct ListEquatable : Equatable {
        let theme: TelegramPresentationTheme
        let cloudThemes:[TelegramTheme]
    }
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_list, equatable: InputDataEquatable(ListEquatable(theme: appearance.presentation, cloudThemes: cloudThemes)), item: { initialSize, stableId in
        
        let selected: ThemeSource
        if let cloud = appearance.presentation.cloudTheme {
            if let _ = cloud.settings {
               selected = .local(appearance.presentation.colors, cloud)
            } else {
                selected = .cloud(cloud)
            }
        } else {
            selected = .local(appearance.presentation.colors, nil)
        }
                
        let dayClassicCloud = settings.associated.first(where: { $0.local == dayClassicPalette.parent })?.cloud?.cloud
        let dayCloud = settings.associated.first(where: { $0.local == whitePalette.parent })?.cloud?.cloud
        let nightAccentCloud = settings.associated.first(where: { $0.local == nightAccentPalette.parent })?.cloud?.cloud
        
        var locals: [LocalPaletteWithReference] = [LocalPaletteWithReference(palette: dayClassicPalette, cloud: dayClassicCloud),
                                                   LocalPaletteWithReference(palette: whitePalette, cloud: dayCloud),
                                                   LocalPaletteWithReference(palette: nightAccentPalette, cloud: nightAccentCloud),
                                                   LocalPaletteWithReference(palette: systemPalette, cloud: nil)]
        
        for (i, local) in locals.enumerated() {
            if let accent = settings.accents.first(where: { $0.name == local.palette.parent }), accent.color.accent != local.palette.basicAccent {
                locals[i] = local.withAccentColor(accent.color)
            }
        }
        
        return ThemeListRowItem(initialSize, stableId: stableId, context: arguments.context, theme: appearance.presentation, selected: selected, local: locals, cloudThemes: cloudThemes, viewType: accentList.isEmpty ? .lastItem : .innerItem, togglePalette: arguments.togglePalette, menuItems: { source in
            var items:[ContextMenuItem] = []
            var cloud: TelegramTheme?
            
            switch source {
            case let .cloud(c):
                cloud = c
            case let .local(_, c):
                cloud = c
            }
            
            if let cloud = cloud {
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
            }
            
            return items
        })
    }))
    
    
    if !accentList.isEmpty {
        
        struct ALEquatable : Equatable {
            let accentList: [AppearanceAccentColor]
            let theme: TelegramPresentationTheme
        }
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_theme_accent_list, equatable: InputDataEquatable(ALEquatable(accentList: accentList, theme: appearance.presentation)), item: { initialSize, stableId in
            return AccentColorRowItem(initialSize, stableId: stableId, context: arguments.context, list: accentList, isNative: true, theme: appearance.presentation, viewType: .lastItem, selectAccentColor: arguments.selectAccentColor, menuItems: { accent in
                var items:[ContextMenuItem] = []
                if let cloud = accent.cloudTheme {
                    items.append(ContextMenuItem(L10n.appearanceThemeShare, handler: {
                        arguments.shareTheme(cloud)
                    }))
                    items.append(ContextMenuItem(L10n.appearanceThemeRemove, handler: {
                        arguments.removeTheme(cloud)
                    }))
                }
                return items
            })
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
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: appearance.presentation.bubbled ? _id_theme_wallpaper2 : _id_theme_wallpaper1, data: InputDataGeneralData(name: L10n.generalSettingsChatBackground, color: appearance.presentation.colors.text, type: .next, viewType: .lastItem, action: arguments.selectChatBackground)))
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
    
    
    let applyTheme:(InstallThemeSource)->Void = { source in
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
                return settings.installDefaultWallpaper().installDefaultAccent().withUpdatedDefaultIsDark(palette.isDark).withSavedAssociatedTheme()
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
                    let defaultTheme = DefaultTheme(local: settings.palette.parent, cloud: DefaultCloudTheme(cloud: cloud, palette: cached.palette, wallpaper: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper)))
                    if cached.palette.isDark {
                        settings = settings.withUpdatedDefaultDark(defaultTheme)
                    } else {
                        settings = settings.withUpdatedDefaultDay(defaultTheme)
                    }
                    return settings.saveDefaultWallpaper().withUpdatedDefaultIsDark(cached.palette.isDark).withSavedAssociatedTheme()
                }).start())
                
                applyCloudThemeDisposable.set(downloadAndApplyCloudTheme(context: context, theme: cloud, install: true).start())
            } else if cloud.file != nil || cloud.settings != nil {
                applyCloudThemeDisposable.set(showModalProgress(signal: downloadAndApplyCloudTheme(context: context, theme: cloud, install: true), for: context.window).start())
            } else {
                showEditThemeModalController(context: context, theme: cloud)
            }
        }
    }
    
    
    let arguments = AppAppearanceViewArguments(context: context, togglePalette: { source in
        
        let nightSettings = autoNightSettings(accountManager: context.sharedContext.accountManager) |> take(1) |> deliverOnMainQueue
        
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
                        applyTheme(source)
                    })
                })
            } else {
                applyTheme(source)
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
        let updateColor:(AppearanceAccentColor)->Void = { color in
            if let cloudTheme = color.cloudTheme {
                applyTheme(.cloud(cloudTheme, color.cachedTheme))
            } else {
                updateDisposable.set(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    let clearPalette = settings.palette.withoutAccentColor()
                    var settings = settings
                    if color.accent.accent == settings.palette.basicAccent {
                        settings = settings.withUpdatedPalette(clearPalette)
                    } else {
                        settings = settings.withUpdatedPalette(clearPalette.withAccentColor(color.accent))
                    }
                    
                    let defaultTheme = DefaultTheme(local: settings.palette.parent, cloud: nil)
                    if settings.palette.isDark {
                        settings = settings.withUpdatedDefaultDark(defaultTheme)
                    } else {
                        settings = settings.withUpdatedDefaultDay(defaultTheme)
                    }
                    
                    return settings.withUpdatedCloudTheme(nil).saveDefaultAccent(color: color.accent).installDefaultWallpaper().withSavedAssociatedTheme()
                }).start())
            }
        }
        if let color = value {
           updateColor(color)
        } else {
            showModal(with: CustomAccentColorModalController(context: context, updateColor: { accent in
                updateColor(AppearanceAccentColor(accent: accent, cloudTheme: nil))
            }), for: context.window)
        }
    }, selectChatBackground: {
        showModal(with: ChatWallpaperModalController(context), for: context.window)
    }, openAutoNightSettings: {
        context.sharedContext.bindings.rootNavigation().push(AutoNightSettingsController(context: context))
    }, removeTheme: { cloudTheme in
        confirm(for: context.window, header: L10n.appearanceConfirmRemoveTitle, information: L10n.appearanceConfirmRemoveText, okTitle: L10n.appearanceConfirmRemoveOK, successHandler: { _ in
            var signals:[Signal<Void, NoError>] = []
            if theme.cloudTheme?.id == cloudTheme.id {
                signals.append(updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    var settings = settings.withUpdatedCloudTheme(nil)
                        .withUpdatedToDefault(dark: settings.defaultIsDark, onlyLocal: true)
                    let defaultTheme = DefaultTheme(local: settings.palette.parent, cloud: nil)
                    if settings.defaultIsDark {
                        settings = settings.withUpdatedDefaultDark(defaultTheme)
                    } else {
                        settings = settings.withUpdatedDefaultDay(defaultTheme)
                    }
                    return settings.withSavedAssociatedTheme()
                    
                }))
            }
            signals.append(deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: cloudTheme))
            updateDisposable.set(combineLatest(signals).start())
        })
    }, editTheme: { value in
        showEditThemeModalController(context: context, theme: value)
    }, shareTheme: { value in
        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/addtheme/\(value.slug)")), for: context.window)
    }, shareLocal: { palette in
        
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
                
                if theme.cloudTheme != nil || theme.colors.accent != theme.colors.basicAccent {
                    items.append(SPopoverItem(L10n.appearanceReset, {
                         _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                            var settings = settings
                            if settings.defaultIsDark {
                                settings = settings.withUpdatedDefaultDark(DefaultTheme(local: TelegramBuiltinTheme.nightAccent, cloud: nil)).saveDefaultAccent(color: PaletteAccentColor(nightAccentPalette.accent))
                            } else {
                                settings = settings.withUpdatedDefaultDay(DefaultTheme(local: TelegramBuiltinTheme.dayClassic, cloud: nil)).saveDefaultAccent(color: PaletteAccentColor(dayClassicPalette.accent))
                            }
                            
                            return settings.installDefaultAccent().withUpdatedCloudTheme(nil).updateWallpaper({ _ -> ThemeWallpaper in
                                return ThemeWallpaper(wallpaper: settings.palette.wallpaper.wallpaper, associated: nil)
                            }).installDefaultWallpaper()
                         }).start()
                    }))
                }
                
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .minX, inset: NSMakePoint(0,-50))
            }
        }, for: .Click)
        view.button.set(image: theme.icons.chatActions, for: .Normal)
        view.button.set(image: theme.icons.chatActionsActive, for: .Highlight)
        return view
        
    })
    
    controller.didLoaded = { controller, _ in
        if let focusOnItemTag = focusOnItemTag {
            controller.genericView.tableView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
        }
    }
    
    return controller
}
