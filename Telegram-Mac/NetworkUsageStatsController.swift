//
//  NetworkUsageStatsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import SwiftSignalKit
import Postbox
import TGUIKit

private final class Arguments {
    let context: AccountContext
    let toggle: (NetworkItem)->Void
    let reset: ()->Void
    init(context: AccountContext, toggle: @escaping(NetworkItem)->Void, reset: @escaping()->Void) {
        self.context = context
        self.toggle = toggle
        self.reset = reset
    }
}

private enum NetworkItem : Int32 {
    case messages = 1
    case photos = 2
    case videos = 3
    case audio = 4
    case files = 5
    
    static var all: [NetworkItem] {
        return [.messages, .photos, .videos, .audio, .files]
    }
    static func totalCount(_ stats: NetworkUsageStats) -> Int {
        return all.reduce(0, {
            $0 + $1.count(stats)
        })
    }
    
    var string: String {
        switch self {
        case .messages:
            return "Messages"
        case .photos:
            return "Photos"
        case .videos:
            return "Videos"
        case .audio:
            return "Audio"
        case .files:
            return "Files"
        }
    }
    var color: NSColor {
        switch self {
        case .photos:
            return NSColor(rgb: 0x5AC8FA)
        case .videos:
            return NSColor(rgb: 0x3478F6)
        case .files:
            return NSColor(rgb: 0x34C759)
        case .audio:
            return NSColor(rgb: 0xFF2D55)
        case .messages:
            return NSColor(rgb: 0xFF9500)
        }
    }
    
    var icon: CGImage {
        switch self {
        case .photos:
            return generateSettingsIcon(NSImage(named: "Icon_DataUsage_Photos")!.precomposed(flipVertical: true))
        case .videos:
            return generateSettingsIcon(NSImage(named: "Icon_DataUsage_Videos")!.precomposed(flipVertical: true))
        case .files:
            return generateSettingsIcon(NSImage(named: "Icon_DataUsage_Files")!.precomposed(flipVertical: true))
        case .audio:
            return generateSettingsIcon(NSImage(named: "Icon_DataUsage_Audio")!.precomposed(flipVertical: true))
        case .messages:
            return generateSettingsIcon(NSImage(named: "Icon_DataUsage_Messages")!.precomposed(flipVertical: true))
        }
    }
    
    func entry(_ stats: NetworkUsageStats) -> NetworkUsageStatsDirectionsEntry {
        switch self {
        case .photos:
            return stats.image.wifi
        case .videos:
            return stats.video.wifi
        case .files:
            return stats.file.wifi
        case .audio:
            return stats.audio.wifi
        case .messages:
            return stats.generic.wifi
        }
    }
    func count(_ stats: NetworkUsageStats) -> Int {
        return Int(self.entry(stats).incoming + self.entry(stats).outgoing)
    }
    func badge(_ stats: NetworkUsageStats) -> NSAttributedString? {
        if count(stats) != 0 {
            let usedBytesCount: Int = NetworkItem.totalCount(stats)
            let badge = NSMutableAttributedString()
            let percent = CGFloat(count(stats)) / CGFloat(usedBytesCount) * 100
            let percentString = String(format: "%.02f%%", percent)
            _ = badge.append(string: percentString, color: theme.colors.text, font: .medium(.text))
            _ = badge.append(string: "  ")
            _ = badge.append(string: self.string, color: theme.colors.text, font: .normal(.text))
            _ = badge.append(string: "  ")
            _ = badge.append(string: String.prettySized(with: count(stats), round: true), color: self.color, font: .bold(.text))
            return badge
        } else {
            return nil
        }
    }
    
    var particle: CGImage? {
        switch self {
        case .photos:
            return NSImage(named: "Icon_Svg_Particle_Photos")?.precomposed()
        case .videos:
            return NSImage(named: "Icon_Svg_Particle_Videos")?.precomposed()
        case .files:
            return NSImage(named: "Icon_Svg_Particle_Files")?.precomposed()
        case .audio:
            return NSImage(named: "Icon_Svg_Particle_Music")?.precomposed()
        case .messages:
            return NSImage(named: "Icon_Svg_Particle_Other")?.precomposed()
        }
    }
}
private struct State : Equatable {
    var stats: NetworkUsageStats?
    var revealed:[NetworkItem : Bool] = [:]
}

private func generateBytes(_ name: String) -> CGImage {
    let image = NSImage.init(named: name)!.precomposed(theme.colors.text)
    return generateImage(NSMakeSize(24 + 10 + 18, 24), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        var rect = size.bounds.focus(NSMakeSize(18, 18))
        rect.origin.x = size.width - 18
        ctx.draw(image, in: rect)
    })!
}

private let _id_piechart = InputDataIdentifier("_id_piechart")
private let _id_cleared = InputDataIdentifier("_id_cleared")

private let _id_info_title = InputDataIdentifier("_id_info_title")

private let _id_info_since = InputDataIdentifier("_id_info_since")
private func _id_list(_ value: Int32) -> InputDataIdentifier {
    return .init("_id_list_\(value)")
}
private func _id_list_incoming(_ value: Int32) -> InputDataIdentifier {
    return .init("_id_list_incoming\(value)")
}
private func _id_list_outgoing(_ value: Int32) -> InputDataIdentifier {
    return .init("_id_list_outgoing\(value)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let stats = state.stats {
        
        var pieChart: [PieChartView.Item] = []
        
        
        let items:[NetworkItem] = [.messages, .photos, .videos, .audio, .files].sorted(by: { lhs, rhs in
            let lhsSize = lhs.count(stats)
            let rhsSize = rhs.count(stats)
            return lhsSize > rhsSize
        })
        for (i, item) in items.enumerated() {
            pieChart.append(.init(id: item.rawValue, index: i, count: max(item.count(stats), 1), color: item.color, badge: item.badge(stats), particle: item.particle))
        }
        
        if NetworkItem.totalCount(stats) != 0 {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_piechart, equatable: InputDataEquatable(stats), comparable: nil, item: { initialSize, stableId in
                return StoragePieChartItem(initialSize, stableId: stableId, context: arguments.context, items: pieChart, dynamicText: String.prettySized(with: NetworkItem.totalCount(stats), round: true), peer: nil, viewType: .legacy, toggleSelected: { value in
                    
                })
            }))
            index += 1
        } else {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_cleared, equatable: InputDataEquatable(stats), comparable: nil, item: { initialSize, stableId in
                return StorageUsageClearedItem(initialSize, stableId: stableId, viewType: .legacy)
            }))
            index += 1
        }
      
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1

        
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm"
        let dateStringPlain: String
        if stats.resetWifiTimestamp != 0 {
            dateStringPlain = strings().networkUsageNetworkUsageSince(formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp))))
        } else {
            dateStringPlain = strings().networkUsageNetworkUsageSinceNever
        }
        
        let header: String
        if NetworkItem.totalCount(stats) == 0 {
            header = strings().networkUsageNetworkUsageReset
        } else {
            header = strings().networkUsageNetworkUsage
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info_title, equatable: .init(header), comparable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string: header, color: theme.colors.text, font: .medium(.header)), centerViewAlignment: true, viewType: .modern(position: .inner, insets: .init()))
        }))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info_since, equatable: .init(dateStringPlain), comparable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: dateStringPlain, centerViewAlignment: true, viewType: .modern(position: .inner, insets: .init()))
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        for (i, item) in items.enumerated() {
            var viewType: GeneralViewType
            
            let revealed = state.revealed[item] ?? false
            viewType = bestGeneralViewType(items, for: i)
            if revealed, i == items.count - 1 {
                if items.count == 1 {
                    viewType = .firstItem
                } else {
                    viewType = .innerItem
                }
            }
            
            entries.append(.general(sectionId: sectionId, index: Int32((i + 1) * 10), value: .none, error: nil, identifier: _id_list(item.rawValue), data: InputDataGeneralData(name: item.string, color: theme.colors.text, icon: item.icon, type: .imageContext(revealed ? theme.icons.general_chevron_up : theme.icons.general_chevron_down,.prettySized(with: item.count(stats), round: true)), viewType: viewType, action: {
                arguments.toggle(item)
            })))
           
            if revealed {
                
                
                let viewType_outgoing: GeneralViewType = .innerItem
                let viewType_incoming: GeneralViewType
                if i == items.count - 1 {
                    viewType_incoming = .lastItem
                } else {
                    viewType_incoming = .innerItem
                }
                
                entries.append(.general(sectionId: sectionId, index: Int32((i + 1) * 10) + 1, value: .none, error: nil, identifier: _id_list_outgoing(item.rawValue), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: generateBytes("Icon_Bytes_Sent"), type: .context(.prettySized(with: item.entry(stats).outgoing, round: true)), viewType: viewType_outgoing, action: nil)))

                entries.append(.general(sectionId: sectionId, index: Int32((i + 1) * 10) + 2, value: .none, error: nil, identifier: _id_list_incoming(item.rawValue), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: generateBytes("Icon_Bytes_Received"), type: .context(.prettySized(with: item.entry(stats).incoming, round: true)), viewType: viewType_incoming, action: nil)))

            }
            
        }
    
        entries.append(.desc(sectionId: sectionId, index: 9999, text: .plain(strings().networkUsageSectionInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    
        entries.append(.general(sectionId: sectionId, index: 10000, value: .none, error: nil, identifier: .init("reset"), data: InputDataGeneralData(name: strings().networkUsageReset, color: theme.colors.redUI, icon: nil, type: .none, viewType: .singleItem, action: arguments.reset)))
    
    } else {
        
    }
    

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func networkUsageStatsController(context: AccountContext) -> ViewController {
    
    
    let initialState = State()
    let actionDisposable = DisposableSet()
    
    let promise: Promise<NetworkUsageStats> = Promise()
    
    promise.set(accountNetworkUsageStats(account: context.account, reset: []))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = Arguments(context: context, toggle: { value in
        updateState { current in
            var current = current
            let revealed: Bool = current.revealed[value] ?? false
            current.revealed[value] = !revealed
            return current
        }
    }, reset: {
        confirm(for: context.window, information: strings().networkUsageResetConfirmInfo, okTitle: strings().networkUsageResetConfirmOk, successHandler: { _ in
            let reset: ResetNetworkUsageStats = [.wifi, .cellular]
            promise.set(accountNetworkUsageStats(account: context.account, reset: reset))
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().networkUsageNetworkUsage, removeAfterDisappear: true, hasDone: false, identifier: "networkUsage")
    
    actionDisposable.add(promise.get().start(next: { value in
        updateState { current in
            var current = current
            current.stats = value
            return current
        }
    }))
    
    controller.onDeinit = {
        actionDisposable.dispose()
    }
    
    return controller
}
