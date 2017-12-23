//
//  DeveloperViewController.swift
//  Telegram
//
//  Created by keepcoder on 30/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import MtProtoKitMac

private final class DeveloperArguments {
    let importColors:()->Void
    let exportColors:()->Void
    let toggleLogs:(Bool)->Void
    let navigateToLogs:()->Void
    init(importColors:@escaping()->Void, exportColors:@escaping()->Void, toggleLogs:@escaping(Bool)->Void, navigateToLogs:@escaping()->Void) {
        self.importColors = importColors
        self.exportColors = exportColors
        self.toggleLogs = toggleLogs
        self.navigateToLogs = navigateToLogs
    }
}

private enum DeveloperEntryId : Hashable {
    case importColors
    case exportColors
    case toggleLogs
    case openLogs
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
        case .section(let section):
            return 4 + Int(section)
        }
    }
    
    static func ==(lhs: DeveloperEntryId, rhs: DeveloperEntryId) -> Bool {
        switch lhs {
        case .importColors:
            if case .importColors = rhs {
                return true
            } else {
                return false
            }
        case .exportColors:
            if case .exportColors = rhs {
                return true
            } else {
                return false
            }
        case .toggleLogs:
            if case .toggleLogs = rhs {
                return true
            } else {
                return false
            }
        case .openLogs:
            if case .openLogs = rhs {
                return true
            } else {
                return false
            }
        case .section(let id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum DeveloperEntry : TableItemListNodeEntry {
    
    case importColors(sectionId: Int32)
    case exportColors(sectionId: Int32)
    case toggleLogs(sectionId: Int32, enabled: Bool)
    case openLogs(sectionId: Int32)
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
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: DeveloperEntry, rhs: DeveloperEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    
    static func ==(lhs: DeveloperEntry, rhs: DeveloperEntry) -> Bool {
        switch lhs {
        case .importColors(let sectionId):
            if case .importColors(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case .exportColors(let sectionId):
            if case .exportColors(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case let .toggleLogs(sectionId, enabled):
            if case .toggleLogs(sectionId, enabled) = rhs {
                return true
            } else {
                return false
            }
        case .openLogs(let sectionId):
            if case .openLogs(sectionId) = rhs {
                return true
            } else {
                return false
            }
        case .section(let id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        }
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
        case let .toggleLogs(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Enable Logs", type: .switchable(stateback: {
                return enabled
            }), action: {
                arguments.toggleLogs(!enabled)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
    
}

private func developerEntries() -> [DeveloperEntry] {
    var entries:[DeveloperEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.importColors(sectionId: sectionId))
    entries.append(.exportColors(sectionId: sectionId))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.toggleLogs(sectionId: sectionId, enabled: UserDefaults.standard.bool(forKey: "enablelogs")))
    
    entries.append(.openLogs(sectionId: sectionId))

    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<DeveloperEntry>], right: [AppearanceWrapperEntry<DeveloperEntry>], initialSize:NSSize, arguments:DeveloperArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class DeveloperViewController: TableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<DeveloperEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let account = self.account
        let arguments = DeveloperArguments(importColors: {
            filePanel(with: ["palette"], allowMultiple: false, for: mainWindow, completion: { list in
                if let path = list?.first {
                    if let theme = importPalette(path) {
                        let palettesDir = "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/Palettes/".nsstring.expandingTildeInPath
                        try? FileManager.default.createDirectory(atPath: palettesDir, withIntermediateDirectories: true, attributes: nil)
                        try? FileManager.default.removeItem(atPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        try? FileManager.default.copyItem(atPath: path, toPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        _ = updateThemeSettings(postbox: account.postbox, palette: theme).start()
                    } else {
                        alert(for: mainWindow, info: "Parsing Error")
                    }
                }
            })
        }, exportColors: {
            exportCurrentPalette()
        }, toggleLogs: { _ in
            let enabled = !UserDefaults.standard.bool(forKey: "enablelogs")
            MTLogSetEnabled(enabled)
            UserDefaults.standard.set(enabled, forKey: "enablelogs")
            Logger.shared.logToConsole = false
            Logger.shared.logToFile = enabled
        }, navigateToLogs: {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/logs".nsstring.expandingTildeInPath)])
        })
        
        genericView.merge(with: appearanceSignal |> deliverOnPrepareQueue |> map { appearance in
            let entries = developerEntries().map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> deliverOnMainQueue)
        
        readyOnce()
    }
    
    override var defaultBarTitle: String {
        return "Developer"
    }
    
}
