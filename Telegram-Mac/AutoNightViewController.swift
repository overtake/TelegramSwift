//
//  AutoNightViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

fileprivate let _id_disabled = InputDataIdentifier("disabled")
fileprivate let _id_scheduled = InputDataIdentifier("enabled")

fileprivate let _id_from = InputDataIdentifier("from")
fileprivate let _id_to = InputDataIdentifier("to")

fileprivate let _id_sunrise = InputDataIdentifier("sunrise")

fileprivate let _id_night_blue = InputDataIdentifier(nightAccentPalette.name)
fileprivate let _id_dark = InputDataIdentifier(darkPalette.name)
fileprivate let _id_update = InputDataIdentifier("update")

private let _id_system_based = InputDataIdentifier("_id_system_based")
private let _id_list = InputDataIdentifier("_id_list")

private final class AutoNightThemeArguments {
    let context: AccountContext
    let selectTheme:(InstallThemeSource)->Void
    let disable:()->Void
    let scheduled:()->Void
    let sunrise:(Bool)->Void
    let systemBased:()->Void
    let selectTimeFrom:(Int32)->Void
    let selectTimeTo:(Int32)->Void
    let updateLocation:()->Void
    init(context: AccountContext, selectTheme: @escaping(InstallThemeSource)->Void, disable:@escaping()->Void, scheduled: @escaping()->Void, sunrise:@escaping(Bool)->Void, systemBased: @escaping()->Void, selectTimeFrom: @escaping(Int32)->Void, selectTimeTo: @escaping(Int32)->Void, updateLocation:@escaping()->Void) {
        self.context = context
        self.disable = disable
        self.selectTheme = selectTheme
        self.scheduled = scheduled
        self.sunrise = sunrise
        self.selectTimeFrom = selectTimeFrom
        self.selectTimeTo = selectTimeTo
        self.systemBased = systemBased
        self.updateLocation = updateLocation
    }
}

private func autoNightEntries(appearance: Appearance, settings: AutoNightThemePreferences, cloudThemes: [TelegramTheme], arguments: AutoNightThemeArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
 
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_disabled, data: InputDataGeneralData(name: L10n.autoNightSettingsDisabled, color: theme.colors.text, icon: nil, type: .selectable(settings.schedule == nil && !settings.systemBased), viewType: .firstItem, action: arguments.disable)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_scheduled, data: InputDataGeneralData(name: L10n.autoNightSettingsScheduled, color: theme.colors.text, icon: nil, type: .selectable(settings.schedule != nil), viewType: .innerItem, action: arguments.scheduled)))
    index += 1
    
    if #available(OSX 10.14, *) {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_system_based, data: InputDataGeneralData(name: L10n.autoNightSettingsSystemBased, color: theme.colors.text, icon: nil, type: .selectable(settings.systemBased), viewType: .lastItem, action: arguments.systemBased)))
        index += 1
        if settings.systemBased {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoNightSettingsSystemBasedDesc), data: InputDataGeneralTextData(viewType: .textTopItem)))
            index += 1
        }
    }
    



    if let schedule = settings.schedule {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let sunriseEnabled: Bool
        switch schedule {
        case .sunrise:
            sunriseEnabled = true
        default:
            sunriseEnabled = false
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sunrise, data: InputDataGeneralData(name: L10n.autoNightSettingsSunsetAndSunrise, color: theme.colors.text, icon: nil, type: .switchable(sunriseEnabled), viewType: .firstItem, action: {
            arguments.sunrise(!sunriseEnabled)
        })))
        index += 1
        
        switch schedule {
        case let .sunrise(latitude, longitude, localizedGeo):
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_update, data: InputDataGeneralData(name: L10n.autoNightSettingsUpdateLocation, color: theme.colors.accent, icon: nil, type: .context(localizedGeo ?? ""), viewType: .lastItem, action: arguments.updateLocation)))
            index += 1
            
            let sunriseSet = EDSunriseSet(date: Date(), timezone: NSTimeZone.local, latitude: latitude, longitude: longitude)
            if let sunriseSet = sunriseSet {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.timeZone = NSTimeZone.local
                formatter.dateStyle = .none
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoNightSettingsSunriseDesc(latitude == 0 ? "N/A" : formatter.string(from: sunriseSet.sunset), longitude == 0 ? "N/A" : formatter.string(from: sunriseSet.sunrise))), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                index += 1
            } else {
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoNightSettingsSunriseDescNA), data: InputDataGeneralTextData(viewType: .textBottomItem)))
                index += 1
            }
            
        case let .timeSensitive(from, to):
            
            func items(from:Int32, to:Int32, isTo: Bool) -> [SPopoverItem] {
                var items:[SPopoverItem] = []
                for i in from ..< to {
                    items.append(SPopoverItem(i < 10 ? "0\(i):00" : "\(i):00", {
                        if isTo {
                            arguments.selectTimeTo(i)
                        } else {
                            arguments.selectTimeFrom(i)
                        }
                    }))
                }
                return items
            }
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_from, data: InputDataGeneralData(name: L10n.autoNightSettingsFrom, color: theme.colors.text, icon: nil, type: .contextSelector(from < 10 ? "0\(from):00" : "\(from):00", items(from: 0, to: 24, isTo: false)), viewType: .innerItem, action: nil)))
            index += 1
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_to, data: InputDataGeneralData(name: L10n.autoNightSettingsTo, color: theme.colors.text, icon: nil, type: .contextSelector(to < 10 ? "0\(to):00" : "\(to):00", items(from: 0, to: 24, isTo: true)), viewType: .lastItem, action: nil)))
            index += 1
        }
    }
    
    if settings.schedule != nil || settings.systemBased {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoNightSettingsPreferredTheme), data: InputDataGeneralTextData(viewType: .textTopItem)))
        index += 1
        
        var cloudThemes = Array(cloudThemes.filter { cloud in
            return cloud.file != nil
        }.reversed())
        
        let selected: ThemeSource
        if let theme = settings.theme.cloud {
            selected = .cloud(theme.cloud)
        } else {
            selected = .local(settings.theme.local.palette)
        }
        
        if let cloud = settings.theme.cloud?.cloud {
            if !cloudThemes.contains(where: {$0.id == cloud.id}) {
                cloudThemes.append(cloud)
            }
        }
        
         entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_list, equatable: InputDataEquatable(settings), item: { initialSize, stableId in
            return ThemeListRowItem(initialSize, stableId: stableId, context: arguments.context, theme: appearance.presentation, selected: selected, local:  [nightAccentPalette, systemPalette], cloudThemes: cloudThemes, viewType: .singleItem, togglePalette: arguments.selectTheme, menuItems: { source in
                return []
            })
        }))
        index += 1

    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    return entries
}


/*
 if location.latitude == 0 && location.longitude == 0 {
 return requestUserLocation()
 |> map {Optional($0)}
 |> `catch` { error -> Signal<UserLocationResult?, NoError> in
 return .single(nil)
 } |> mapToSignal { value in
 if let value = value {
 return updateAutoNightSettingsInteractively(accountManager: sharedContext.accountManager, { pref -> AutoNightThemePreferences in
 switch value {
 case let .success(location):
 return pref.withUpdatedSchedule(.sunrise(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
 }
 }) |> map { set in
 return autoNightEntries(set)
 }
 } else {
 return .single(autoNightEntries(settings))
 }
 }
 }
 */

func AutoNightSettingsController(context: AccountContext) -> InputDataController {
    
    let updateDisposable = MetaDisposable()
    let updateLocationDisposable = MetaDisposable()
    
    
    let updateLocation:(Bool)->Void = { inBackground in
        var signal: Signal<(Double, Double, String?), UserLocationError> = requestUserLocation() |> take(1) |> mapToSignal { value in
            switch value {
            case let .success(location):
                return reverseGeocodeLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    |> mapError { _ in return UserLocationError.denied } |> map { geocode in
                        return (location.coordinate.latitude, location.coordinate.longitude, geocode?.city)
                }
            }
        }
        if !inBackground {
            signal = showModalProgress(signal: signal, for: context.window)
        }
        updateLocationDisposable.set(signal.start(next: { location in
            updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedSchedule(.sunrise(latitude: location.0, longitude: location.1, localizedGeo: location.2))
            }).start())
        }, error: { error in
            if !inBackground {
                alert(for: context.window, info: L10n.autoNightSettingsUpdateLocationError)
            }
        }))
    }
    
    let arguments = AutoNightThemeArguments(context: context, selectTheme: { source in
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            switch source {
            case let .local(palette):
                settings = settings.withUpdatedTheme(DefaultTheme(local: palette.parent, cloud: nil))
            case let .cloud(theme, cachedData):
                if let cached = cachedData {
                    settings = settings.withUpdatedTheme(DefaultTheme(local: cached.palette.parent, cloud: DefaultCloudTheme(cloud: theme, palette: cached.palette, wallpaper: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper))))
                }
            }
            return settings
        }).start())
    }, disable: {
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedSchedule(nil).withUpdatedSystemBased(false)
        }).start())
    }, scheduled: {
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedSchedule(.timeSensitive(from: 22, to: 9)).withUpdatedSystemBased(false)
        }).start())
    }, sunrise: { enable in
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            if enable {
                return current.withUpdatedSchedule(.sunrise(latitude: 0, longitude: 0, localizedGeo: nil))
            } else {
                return current.withUpdatedSchedule(.timeSensitive(from: 22, to: 9))
            }
        }).start())
        
        if enable {
            updateLocation(true)
        }
    }, systemBased: {
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedSchedule(nil).withUpdatedSystemBased(true)
        }).start())
    }, selectTimeFrom: { value in
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            if let schedule = current.schedule {
                switch schedule {
                case .sunrise:
                    return current
                case let .timeSensitive(interval):
                    return current.withUpdatedSchedule(.timeSensitive(from: value, to: interval.to))
                }
            }
            return current
            
        }).start())
    }, selectTimeTo: { value in
        updateDisposable.set(updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            if let schedule = current.schedule {
                switch schedule {
                case .sunrise:
                    return current
                case let .timeSensitive(interval):
                    return current.withUpdatedSchedule(.timeSensitive(from: interval.from, to: value))
                }
            }
            return current
        }).start())
    }, updateLocation: {
        updateLocation(false)
    })
    
    
    
    

    
    let autoNight = autoNightSettings(accountManager: context.sharedContext.accountManager)
    let cloudThemes = telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)

    let signal: Signal<[InputDataEntry], NoError> = combineLatest(queue: prepareQueue, appearanceSignal, autoNight, cloudThemes) |> map {
        autoNightEntries(appearance: $0, settings: $1, cloudThemes: $2, arguments: arguments)
    }
    
    return InputDataController(dataSignal: signal |> map { InputDataSignalValue(entries: $0, animated: false) },
        title: L10n.autoNightSettingsTitle,
        afterDisappear: {
            updateDisposable.dispose()
            updateLocationDisposable.dispose()
        },
        removeAfterDisappear: true,
        hasDone: false,
        identifier: "auto-night")
}



