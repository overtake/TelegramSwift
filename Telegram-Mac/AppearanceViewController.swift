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
    let account:Account
    let toggleDarkMode:(Bool)->Void
    let toggleFontSize:(Int32)->Void
    init(account:Account, toggleDarkMode: @escaping(Bool)->Void, toggleFontSize: @escaping(Int32)->Void) {
        self.account = account
        self.toggleDarkMode = toggleDarkMode
        self.toggleFontSize = toggleFontSize
    }
}

private enum AppearanceViewEntry : TableItemListNodeEntry {
    case darkMode(Int32, Bool)
    case section(Int32)
    case font(Int32, Int32)
    case description(Int32, Int32, String)
    
    var stableId: Int32 {
        switch self {
        case .darkMode:
            return 0
        case .section(let section):
            return section + 1000
        case .font:
            return 1
        case let .description(section, index, _):
            return (section * 1000) + (index + 1) * 1000
        }
    }
    
    var index:Int32 {
        switch self {
        case .darkMode(let section, _):
            return (section * 1000) + 0
        case .section(let section):
            return (section + 1) * 1000 - section
        case .font(let section, _):
            return (section * 1000) + 1
        case let .description(section, index, _):
            return (section * 1000) + index + 2
        }
    }
    
    func item(_ arguments: AppearanceViewArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .darkMode(_, let enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(.generalSettingsDarkMode), type: .switchable(stateback: { () -> Bool in
                return enabled
            }), action: { 
                arguments.toggleDarkMode(!enabled)
            })
        case .description(_, _, let text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .font(_, let size):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(.generalSettingsLargeFonts), type: .switchable(stateback: { () -> Bool in
                return size == 15
            }), action: {
                arguments.toggleFontSize(size == 13 ? 15 : 13)
            })
        }
    }
}
private func ==(lhs: AppearanceViewEntry, rhs: AppearanceViewEntry) -> Bool {
    switch lhs {
    case let .darkMode(section, enabled):
        if case .darkMode(section, enabled) = rhs {
            return true
        } else {
            return false
        }
    case .section(let section):
        if case .section(section) = rhs {
            return true
        } else {
            return false
        }
    case let .font(section, size):
        if case .font(section, size) = rhs {
            return true
        } else {
            return false
        }
    case let .description(section, index, description):
        if case .description(section, index, description) = rhs {
            return true
        } else {
            return false
        }
    }
}
private func <(lhs: AppearanceViewEntry, rhs: AppearanceViewEntry) -> Bool {
    return lhs.index < rhs.index
}

private func AppearanceViewEntries(dark:Bool, settings: BaseApplicationSettings?) -> [AppearanceViewEntry] {
    var entries:[AppearanceViewEntry] = []
    
    var sectionId:Int32 = 1
    var descIndex:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.darkMode(sectionId, dark))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, tr(.generalSettingsDarkModeDescription)))
    descIndex += 1

    entries.append(.section(sectionId))
    sectionId += 1

    
    entries.append(.font(sectionId, settings?.fontSize ?? 13))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, tr(.generalSettingsFontDescription)))
    descIndex += 1
//
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<AppearanceViewEntry>], right: [AppearanceWrapperEntry<AppearanceViewEntry>], initialSize:NSSize, arguments:AppearanceViewArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class AppearanceViewController: TableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        let arguments = AppearanceViewArguments(account: account, toggleDarkMode: { enable in
            _ = updateThemeSettings(postbox: account.postbox, pallete: enable ? darkPallete : whitePallete, dark: enable).start()
        }, toggleFontSize: { size in
            _ = updateBaseAppSettingsInteractively(postbox: account.postbox, { settings -> BaseApplicationSettings in
                return settings.withUpdatedFontSize(size)
            }).start()
        })
        
        let initialSize = self.atomicSize

        
        let previous: Atomic<[AppearanceWrapperEntry<AppearanceViewEntry>]> = Atomic(value: [])
        genericView.merge(with:  combineLatest(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.baseAppSettings]) |> deliverOnMainQueue, appearanceSignal |> deliverOnMainQueue) |> map { pref, appearance in
            let entries = AppearanceViewEntries(dark: appearance.presentation.dark, settings: pref.values[ApplicationSpecificPreferencesKeys.baseAppSettings] as? BaseApplicationSettings).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> deliverOnMainQueue)
        readyOnce()
        
    }
    
}
