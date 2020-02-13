//
//  DeveloperViewController.swift
//  Telegram
//
//  Created by keepcoder on 30/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import MtProtoKit
import Postbox

private final class DeveloperArguments {
    let importColors:()->Void
    let exportColors:()->Void
    let toggleLogs:(Bool)->Void
    let navigateToLogs:()->Void
    let addAccount:()->Void
    let toggleFilters:(Bool)->Void
    init(importColors:@escaping()->Void, exportColors:@escaping()->Void, toggleLogs:@escaping(Bool)->Void, navigateToLogs:@escaping()->Void, addAccount: @escaping() -> Void, toggleFilters:@escaping(Bool)->Void) {
        self.importColors = importColors
        self.exportColors = exportColors
        self.toggleLogs = toggleLogs
        self.navigateToLogs = navigateToLogs
        self.addAccount = addAccount
        self.toggleFilters = toggleFilters
    }
}

private enum DeveloperEntryId : Hashable {
    case importColors
    case exportColors
    case toggleLogs
    case openLogs
    case accounts
    case enableFilters
    case section(Int32)
    var hashValue: Int {
        switch self {
        case .importColors:
            return 0
        case .exportColors:
            return 1
        case .toggleLogs:
            return 2
        case .openLogs:
            return 3
        case .accounts:
            return 4
        case .enableFilters:
            return 5
        case .section(let section):
            return 6 + Int(section)
        }
    }
}

private enum DeveloperEntry : TableItemListNodeEntry {
    
    case importColors(sectionId: Int32)
    case exportColors(sectionId: Int32)
    case toggleLogs(sectionId: Int32, enabled: Bool)
    case openLogs(sectionId: Int32)
    case accounts(sectionId: Int32)
    case enableFilters(sectionId: Int32, enabled: Bool)
    case section(Int32)
    
    var stableId:DeveloperEntryId {
        switch self {
        case .importColors:
            return .importColors
        case .exportColors:
            return .exportColors
        case .toggleLogs:
            return .toggleLogs
        case .openLogs:
            return .openLogs
        case .accounts:
            return .accounts
        case .enableFilters:
            return .enableFilters
        case .section(let section):
            return .section(section)
        }
    }
    
    var index:Int32 {
        switch self {
        case .importColors(let sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .exportColors(let sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .toggleLogs(let sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .openLogs(let sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .accounts(let sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .enableFilters(let sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: DeveloperEntry, rhs: DeveloperEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    
    func item(_ arguments: DeveloperArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .importColors:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Import Palette", type: .next, action: {
                arguments.importColors()
            })
        case .exportColors:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Export Palette", type: .next, action: {
                arguments.exportColors()
            })
        case .openLogs:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Open Logs", type: .next, action: {
                arguments.navigateToLogs()
            })
        case .accounts:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Add Account", type: .next, action: {
                arguments.addAccount()
            })
        case let .enableFilters(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Enable Filters", type: .switchable(enabled), action: {
                arguments.toggleFilters(!enabled)
            })
        case let .toggleLogs(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Enable Logs", type: .switchable(enabled), action: {
                arguments.toggleLogs(!enabled)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
    
}

private func developerEntries(_ chatListPreferences: ChatListFilterPreferences) -> [DeveloperEntry] {
    var entries:[DeveloperEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.accounts(sectionId: sectionId))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.toggleLogs(sectionId: sectionId, enabled: UserDefaults.standard.bool(forKey: "enablelogs")))
    
    entries.append(.openLogs(sectionId: sectionId))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.enableFilters(sectionId: sectionId, enabled: chatListPreferences.isEnabled))

    
    
    entries.append(.section(sectionId))
    sectionId += 1
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<DeveloperEntry>], right: [AppearanceWrapperEntry<DeveloperEntry>], initialSize:NSSize, arguments:DeveloperArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class DeveloperViewController: TableViewController {

    init(context: AccountContext) {
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.background
        }
        
        let context = self.context
        let previousEntries:Atomic<[AppearanceWrapperEntry<DeveloperEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let arguments = DeveloperArguments(importColors: {
            filePanel(with: ["palette"], allowMultiple: false, for: mainWindow, completion: { list in
                if let path = list?.first {
                    if let theme = importPalette(path) {
                        let palettesDir = "~/Library/Group Containers/\(ApiEnvironment.group)/Palettes/".nsstring.expandingTildeInPath
                        try? FileManager.default.createDirectory(atPath: palettesDir, withIntermediateDirectories: true, attributes: nil)
                        try? FileManager.default.removeItem(atPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        try? FileManager.default.copyItem(atPath: path, toPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                            return settings.withUpdatedPalette(theme).withUpdatedCloudTheme(nil)
                        }).start()
                    } else {
                        alert(for: mainWindow, info: "Parsing Error")
                    }
                }
            })
        }, exportColors: {
            exportPalette(palette: theme.colors)
        }, toggleLogs: { _ in
            let enabled = !UserDefaults.standard.bool(forKey: "enablelogs")
            MTLogSetEnabled(enabled)
            UserDefaults.standard.set(enabled, forKey: "enablelogs")
            Logger.shared.logToConsole = false
            Logger.shared.logToFile = enabled
        }, navigateToLogs: {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: "~/Library/Group Containers/\(ApiEnvironment.group)/logs".nsstring.expandingTildeInPath)])
        }, addAccount: {
            let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
        }, toggleFilters: { enabled in
            _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
                $0.withUpdatedEnabled(enabled)
            }).start()
        })
        
        let signal = combineLatest(queue: prepareQueue, context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatListSettings]), appearanceSignal)
        
        genericView.merge(with: signal |> map { preferences, appearance in
            
            let chatListFilters = preferences.values[ApplicationSpecificPreferencesKeys.chatListSettings] as? ChatListFilterPreferences ?? ChatListFilterPreferences.defaultSettings
            
            let entries = developerEntries(chatListFilters).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> deliverOnMainQueue)
        
        readyOnce()
    }
    
    override var defaultBarTitle: String {
        return "Developer"
    }
    
}
