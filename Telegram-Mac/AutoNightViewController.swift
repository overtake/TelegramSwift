//
//  AutoNightViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

fileprivate let _id_disabled = InputDataIdentifier("disabled")
fileprivate let _id_enabled = InputDataIdentifier("enabled")

fileprivate let _id_from = InputDataIdentifier("from")
fileprivate let _id_to = InputDataIdentifier("to")

fileprivate let _id_sunrise = InputDataIdentifier("sunrise")

fileprivate let _id_night_blue = InputDataIdentifier(nightBluePalette.name)
fileprivate let _id_dark = InputDataIdentifier(darkPalette.name)
fileprivate let _id_update = InputDataIdentifier("update")

private func autoNightEntries(_ settings: AutoNightThemePreferences) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
 
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_disabled, name: L10n.autoNightSettingsDisabled, color: theme.colors.text, icon: nil, type: .selectable(settings.schedule == nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, name: L10n.autoNightSettingsScheduled, color: theme.colors.text, icon: nil, type: .selectable(settings.schedule != nil)))
    index += 1
    

    if let schedule = settings.schedule {
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        let sunriseEnabled: Bool
        switch schedule {
        case .sunrise:
            sunriseEnabled = true
        default:
            sunriseEnabled = false
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sunrise, name: L10n.autoNightSettingsSunsetAndSunrise, color: theme.colors.text, icon: nil, type: .switchable(sunriseEnabled)))
        index += 1
        
        switch schedule {
        case let .sunrise(latitude, longitude):
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_update, name: L10n.autoNightSettingsUpdateLocation, color: theme.colors.blueUI, icon: nil, type: .none))
            index += 1
            
            let sunriseSet = EDSunriseSet(date: Date(), timezone: NSTimeZone.local, latitude: latitude, longitude: longitude)
            if let sunriseSet = sunriseSet {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.timeZone = NSTimeZone.local
                formatter.dateStyle = .none
                entries.append(.desc(sectionId: sectionId, index: index, text: L10n.autoNightSettingsSunriseDesc(latitude == 0 ? "N/A" : formatter.string(from: sunriseSet.sunset), longitude == 0 ? "N/A" : formatter.string(from: sunriseSet.sunrise)), color: theme.colors.grayText, detectBold: true))
                index += 1
            } else {
                entries.append(.desc(sectionId: sectionId, index: index, text: L10n.autoNightSettingsSunriseDescNA, color: theme.colors.grayText, detectBold: true))
                index += 1
            }
            
            
            
        case let .timeSensitive(from, to):
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_from, name: L10n.autoNightSettingsFrom, color: theme.colors.text, icon: nil, type: .nextContext(from < 10 ? "0\(from):00" : "\(from):00")))
            index += 1
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_to, name: L10n.autoNightSettingsTo, color: theme.colors.text, icon: nil, type: .nextContext(to < 10 ? "0\(to):00" : "\(to):00")))
            index += 1
        }
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        let nightBlueKey = "AppearanceSettings.ColorTheme." + nightBluePalette.name.lowercased().replacingOccurrences(of: " ", with: "_")
        let darkKey = "AppearanceSettings.ColorTheme." + darkPalette.name.lowercased().replacingOccurrences(of: " ", with: "_")

        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_night_blue, name: localizedString(nightBlueKey), color: theme.colors.text, icon: nil, type: .selectable(settings.themeName == _id_night_blue.identifier)))
        index += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_dark, name: localizedString(darkKey), color: theme.colors.text, icon: nil, type: .selectable(settings.themeName == _id_dark.identifier)))
        index += 1
        
    }
    
    
    
    return entries
}

func autoNightSettingsController(_ postbox: Postbox) -> InputDataController {
    
    let signal: Signal<[InputDataEntry], NoError> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, autoNightSettings(postbox: postbox) |> deliverOnPrepareQueue) |> mapToSignal { _, settings in
        if let schedule = settings.schedule {
            switch schedule {
            case let .sunrise(location):
                if location.latitude == 0 && location.longitude == 0 {
                    return requestUserLocation()
                        |> map {Optional($0)}
                        |> `catch` { error -> Signal<UserLocationResult?, NoError> in
                            return .single(nil)
                        } |> mapToSignal { value in
                            if let value = value {
                                return updateAutoNightSettingsInteractively(postbox: postbox, { pref -> AutoNightThemePreferences in
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
                
                return .single(autoNightEntries(settings))
            case .timeSensitive:
                break
            }
        }
        return .single(autoNightEntries(settings))
    }
    var controller: InputDataController!
    
    var getController:(()->InputDataController?)? = nil
    
    controller = InputDataController(dataSignal: signal, title: L10n.autoNightSettingsTitle, validateData: { data in
        
        if let _ = data[_id_disabled] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                return current.withUpdatedSchedule(nil)
            }).start()
        }
        
        if let _ = data[_id_enabled] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                return current.withUpdatedSchedule(.timeSensitive(from: 22, to: 9))
            }).start()
        }
        
        if let _ = data[_id_update] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                return current.withUpdatedSchedule(.sunrise(latitude: 0, longitude: 0))
            }).start()
        }
        
        if let _ = data[_id_sunrise] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                if let schedule = current.schedule {
                    switch schedule {
                    case .sunrise:
                        return current.withUpdatedSchedule(.timeSensitive(from: 22, to: 9))
                    case .timeSensitive:
                        return current.withUpdatedSchedule(.sunrise(latitude: 0, longitude: 0))
                    }
                }
                return current
            }).start()
        }
        
        
        if let _ = data[_id_night_blue] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                return current.withUpdatedName(nightBluePalette.name)
            }).start()
        }
        if let _ = data[_id_dark] {
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                return current.withUpdatedName(darkPalette.name)
            }).start()
        }
        
        
        let selectedFrom:(Int32)->Void = { selected in
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                if let schedule = current.schedule {
                    switch schedule {
                    case .sunrise:
                        return current
                    case let .timeSensitive(interval):
                        return current.withUpdatedSchedule(.timeSensitive(from: selected, to: interval.to))
                    }
                }
                return current
                
            }).start()
        }
        let selectedTo:(Int32)->Void = { selected in
            _ = updateAutoNightSettingsInteractively(postbox: postbox, { current in
                if let schedule = current.schedule {
                    switch schedule {
                    case .sunrise:
                        return current
                    case let .timeSensitive(interval):
                        return current.withUpdatedSchedule(.timeSensitive(from: interval.from, to: selected))
                    }
                }
                return current
            }).start()
        }
        
        func items(from:Int32, to:Int32, isTo: Bool) -> [SPopoverItem] {
            var items:[SPopoverItem] = []
            for i in from ..< to {
                items.append(SPopoverItem(i < 10 ? "0\(i):00" : "\(i):00", {
                    if isTo {
                        selectedTo(i)
                    } else {
                        selectedFrom(i)
                    }
                }))
            }
            return items
        }
        
       
        
        if let _ = data[_id_from], let controller = getController?(), let control = (controller.genericView.item(stableId: InputDataEntryId.general(_id_from))?.view as? GeneralInteractedRowView)?.textView {
            showPopover(for: control, with: SPopoverViewController(items: items(from: 0, to: 24, isTo: false), visibility: 10), edge: .minX, inset: NSMakePoint(0,-30))
        }
        if let _ = data[_id_to], let controller = getController?(), let control = (controller.genericView.item(stableId: InputDataEntryId.general(_id_to))?.view as? GeneralInteractedRowView)?.textView {
            showPopover(for: control, with: SPopoverViewController(items: items(from: 0, to: 24, isTo: true), visibility: 10), edge: .minX, inset: NSMakePoint(0,-30))
        }
        
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "auto-night")
    
    getController = { [weak controller] in
        return controller
    }
    
    return controller
}



