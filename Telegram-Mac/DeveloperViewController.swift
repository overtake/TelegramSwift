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
import ApiCredentials
import MtProtoKit
import Postbox
import ThemeSettings

private final class DeveloperArguments {
    let importColors:()->Void
    let exportColors:()->Void
    let toggleLogs:(Bool)->Void
    let navigateToLogs:()->Void
    let addAccount:()->Void
    let toggleMenu:(Bool)->Void
    let toggleAnimatedInputEmoji:()->Void
    let toggleNativeGraphicContext:()->Void
    let toggleDebugWebApp:()->Void
    let toggleNetwork:()->Void
    let toggleDownloads:()->Void
    let toggleCanViewPeerId:()->Void
    init(importColors:@escaping()->Void, exportColors:@escaping()->Void, toggleLogs:@escaping(Bool)->Void, navigateToLogs:@escaping()->Void, addAccount: @escaping() -> Void, toggleMenu:@escaping(Bool)->Void, toggleDebugWebApp:@escaping()->Void, toggleAnimatedInputEmoji: @escaping()->Void, toggleNativeGraphicContext:@escaping()->Void, toggleNetwork:@escaping()->Void, toggleDownloads:@escaping()->Void, toggleCanViewPeerId:@escaping()->Void) {
        self.importColors = importColors
        self.exportColors = exportColors
        self.toggleLogs = toggleLogs
        self.navigateToLogs = navigateToLogs
        self.addAccount = addAccount
        self.toggleMenu = toggleMenu
        self.toggleDebugWebApp = toggleDebugWebApp
        self.toggleAnimatedInputEmoji = toggleAnimatedInputEmoji
        self.toggleNativeGraphicContext = toggleNativeGraphicContext
        self.toggleNetwork = toggleNetwork
        self.toggleDownloads = toggleDownloads
        self.toggleCanViewPeerId = toggleCanViewPeerId
    }
}

private enum DeveloperEntryId : Hashable {
    case importColors
    case exportColors
    case toggleLogs
    case openLogs
    case accounts
    case enableFilters
    case toggleMenu
    case animateInputEmoji
    case nativeGraphicContext
    case crash
    case debugWebApp
    case network
    case downloads
    case showPeerId
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
        case .toggleMenu:
            return 6
        case .animateInputEmoji:
            return 7
        case .nativeGraphicContext:
            return 8
        case .debugWebApp:
            return 9
        case .crash:
            return 10
        case .network:
            return 11
        case .downloads:
            return 12
        case .showPeerId:
            return 13
        case .section(let section):
            return 14 + Int(section)
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
    case toggleMenu(sectionId: Int32, enabled: Bool)
    case animateInputEmoji(sectionId: Int32, enabled: Bool)
    case nativeGraphicContext(sectionId: Int32, enabled: Bool)
    case crash(sectionId: Int32)
    case debugWebApp(sectionId: Int32)
    case network(sectionId: Int32, enabled: Bool)
    case downloads(sectionId: Int32, enabled: Bool)
    case showPeerId(sectionId: Int32, enabled: Bool)
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
        case .toggleMenu:
            return .toggleMenu
        case .animateInputEmoji:
            return .animateInputEmoji
        case .nativeGraphicContext:
            return .nativeGraphicContext
        case .crash:
            return .crash
        case .debugWebApp:
            return .debugWebApp
        case .network:
            return .network
        case .downloads:
            return .downloads
        case .showPeerId:
            return .showPeerId
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
        case let .toggleMenu(sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .animateInputEmoji(sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .nativeGraphicContext(sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .crash(sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .debugWebApp(sectionId):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .network(sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .downloads(sectionId, _):
            return (sectionId * 1000) + Int32(stableId.hashValue)
        case let .showPeerId(sectionId, _):
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
            })
        case let .toggleLogs(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Enable Logs", type: .switchable(enabled), action: {
                arguments.toggleLogs(!enabled)
            })
        case let .toggleMenu(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Native Context Menu (Get Ready for glitches)", type: .switchable(enabled), action: {
                arguments.toggleMenu(!enabled)
            })
        case let .animateInputEmoji(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Animate Emoji to Input", type: .switchable(enabled), action: arguments.toggleAnimatedInputEmoji)
        case let .nativeGraphicContext(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Use Native Graphic Context", type: .switchable(enabled), action: arguments.toggleNativeGraphicContext)
        case .crash:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Crash App", type: .none, action: {
                var array:[Int] = []
                array[1] = 0
            })
        case .debugWebApp:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Debug Web App", type: .switchable(FastSettings.debugWebApp), action: arguments.toggleDebugWebApp)
        case let .network(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Experimental Network", type: .switchable(enabled), action: arguments.toggleNetwork)
        case let .downloads(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Experimental Downloads", type: .switchable(enabled), action: arguments.toggleDownloads)
        case let .showPeerId(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Show Peer Id on Profile Page", type: .switchable(enabled), action: arguments.toggleCanViewPeerId)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
    
}

private func developerEntries(loginSettings: LoggingSettings, networkSettings: NetworkSettings) -> [DeveloperEntry] {
    var entries:[DeveloperEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.accounts(sectionId: sectionId))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.toggleLogs(sectionId: sectionId, enabled: loginSettings.logToFile))
    
    entries.append(.openLogs(sectionId: sectionId))
    entries.append(.toggleMenu(sectionId: sectionId, enabled: System.legacyMenu))
    entries.append(.animateInputEmoji(sectionId: sectionId, enabled: FastSettings.animateInputEmoji))
    entries.append(.nativeGraphicContext(sectionId: sectionId, enabled: FastSettings.useNativeGraphicContext))
    entries.append(.debugWebApp(sectionId: sectionId))
    entries.append(.network(sectionId: sectionId, enabled: networkSettings.useNetworkFramework ?? false))
    entries.append(.downloads(sectionId: sectionId, enabled: networkSettings.useExperimentalDownload ?? false))
    entries.append(.showPeerId(sectionId: sectionId, enabled: FastSettings.canViewPeerId))

    entries.append(.crash(sectionId: sectionId))

    entries.append(.section(sectionId))
    sectionId += 1
    
    
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
            filePanel(with: ["palette"], allowMultiple: false, for: context.window, completion: { list in
                if let path = list?.first {
                    if let theme = importPalette(path) {
                        let palettesDir = ApiEnvironment.containerURL!.appendingPathComponent("Palettes").path
                        try? FileManager.default.createDirectory(atPath: palettesDir, withIntermediateDirectories: true, attributes: nil)
                        try? FileManager.default.removeItem(atPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        try? FileManager.default.copyItem(atPath: path, toPath: palettesDir + "/" + path.nsstring.lastPathComponent)
                        _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                            return settings.withUpdatedPalette(theme).withUpdatedCloudTheme(nil)
                        }).start()
                    } else {
                        alert(for: context.window, info: "Parsing Error")
                    }
                }
            })
        }, exportColors: {
            exportPalette(palette: theme.colors)
        }, toggleLogs: { enabled in
            MTLogSetEnabled(enabled)
            _ = updateLoggingSettings(accountManager: context.sharedContext.accountManager, {
                $0.withUpdatedLogToFile(enabled)
            }).start()
            Logger.shared.logToConsole = false
            Logger.shared.logToFile = enabled
        }, navigateToLogs: {
            NSWorkspace.shared.activateFileViewerSelecting([ApiEnvironment.containerURL!.appendingPathComponent("logs")])
        }, addAccount: {
            let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
        }, toggleMenu: { value in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedLegacyMenu(value)
            }).start()
        }, toggleDebugWebApp: {
            FastSettings.toggleDebugWebApp()
        }, toggleAnimatedInputEmoji: {
            FastSettings.toggleAnimateInputEmoji()
        }, toggleNativeGraphicContext: {
            FastSettings.toggleNativeGraphicContext()
            appDelegate?.updateGraphicContext()
        }, toggleNetwork: {
            _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { current in
                var current = current
                if let value = current.useNetworkFramework {
                    current.useNetworkFramework = !value
                } else {
                    current.useNetworkFramework = true
                }
                return current
            }).start()
        }, toggleDownloads: {
            _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { current in
                var current = current
                if let value = current.useExperimentalDownload {
                    current.useExperimentalDownload = !value
                } else {
                    current.useExperimentalDownload = true
                }
                return current
            }).start()
        }, toggleCanViewPeerId: {
            FastSettings.canViewPeerId = !FastSettings.canViewPeerId
        })
        
        let network = context.account.postbox.preferencesView(keys: [PreferencesKeys.networkSettings]) |> map {
            return $0.values[PreferencesKeys.networkSettings]?.get(NetworkSettings.self) ?? .defaultSettings
        }
        
        let signal = combineLatest(queue: prepareQueue, context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.loggingSettings]), appearanceSignal, themeSettingsView(accountManager: context.sharedContext.accountManager), network)
        
        
            
        
        genericView.merge(with: signal |> map { preferences, appearance, theme, network in
            let entries = developerEntries(loginSettings: preferences.entries[SharedDataKeys.loggingSettings]?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings, networkSettings: network).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> deliverOnMainQueue)
        
        readyOnce()
    }
    
    override var defaultBarTitle: String {
        return "Developer"
    }
    
}
