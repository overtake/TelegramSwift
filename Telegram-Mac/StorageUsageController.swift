//
//  StorageUsageController.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import ApiCredentials
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let updateKeepMedia: (CacheStorageSettings.PeerStorageCategory, Int32) -> Void
    let updateMediaLimit: (Int32) -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearAll:()->Void
    let exceptions:(CacheStorageSettings.PeerStorageCategory)->Void
    let toggleOther:()->Void
    let toggleCategory:(StorageUsageCategory)->Void
    let segmentController:()->StorageUsageBlockController?
    init(context: AccountContext, updateKeepMedia: @escaping (CacheStorageSettings.PeerStorageCategory, Int32) -> Void, updateMediaLimit: @escaping(Int32)->Void, openPeerMedia: @escaping (PeerId) -> Void, clearAll: @escaping () -> Void, exceptions:@escaping(CacheStorageSettings.PeerStorageCategory)->Void, toggleOther:@escaping()->Void, toggleCategory:@escaping(StorageUsageCategory)->Void, segmentController:@escaping()->StorageUsageBlockController?) {
        self.context = context
        self.updateKeepMedia = updateKeepMedia
        self.openPeerMedia = openPeerMedia
        self.clearAll = clearAll
        self.updateMediaLimit = updateMediaLimit
        self.exceptions = exceptions
        self.toggleOther = toggleOther
        self.toggleCategory = toggleCategory
        self.segmentController = segmentController
    }
}

struct StorageCacheException : Equatable {
    let value: Int32
    let peer: PeerEquatable
}

func stringForKeepMediaTimeout(_ timeout: Int32) -> String {
    if timeout <= 7 * 24 * 60 * 60 {
        return strings().timerWeeksCountable(1)
    } else if timeout <= 1 * 31 * 24 * 60 * 60 {
        return strings().timerMonthsCountable(1)
    } else {
        return strings().timerForever
    }
}

enum StorageUsageCategory: Int32 {
    case photos
    case videos
    case files
    case music
    case other
    case stickers
    case avatars
    case misc
                
    var color: NSColor {
        switch self {
        case .photos:
            return NSColor(rgb: 0x5AC8FA)
        case .videos:
            return NSColor(rgb: 0x3478F6)
        case .files:
            return NSColor(rgb: 0x34C759)
        case .music:
            return NSColor(rgb: 0xFF2D55)
        case .other:
            return NSColor(rgb: 0xC4C4C6)
        case .stickers:
            return NSColor(rgb: 0x5856D6)
        case .avatars:
            return NSColor(rgb: 0xAF52DE)
        case .misc:
            return NSColor(rgb: 0xFF9500)
        }
    }
    
    var title: String {
        switch self {
        case .photos:
            return strings().storageUsageCategoryPhotos
        case .videos:
            return strings().storageUsageCategoryVideos
        case .files:
            return strings().storageUsageCategoryFiles
        case .music:
            return strings().storageUsageCategoryMusic
        case .other:
            return strings().storageUsageCategoryOther
        case .stickers:
            return strings().storageUsageCategoryStickers
        case .avatars:
            return strings().storageUsageCategoryAvatars
        case .misc:
            return strings().storageUsageCategoryMiscellaneous
        }
    }
    
    var native: StorageUsageStats.CategoryKey {
        switch self {
        case .photos:
            return .photos
        case .videos:
            return .videos
        case .files:
            return .files
        case .music:
            return .music
        case .other:
            fatalError()
        case .stickers:
            return .stickers
        case .avatars:
            return .avatars
        case .misc:
            return .misc
        }
    }
    var isOther: Bool {
        switch self {
        case .stickers, .avatars, .misc:
            return true
        default:
            return false
        }
    }
}

extension StorageUsageStats.CategoryKey {
    var mappedCategory: StorageUsageCategory {
        switch self {
        case .photos:
            return .photos
        case .videos:
            return .videos
        case .files:
            return .files
        case .music:
            return .music
        case .stickers:
            return .stickers
        case .avatars:
            return .avatars
        case .misc:
            return .misc
        }
    }
    var isOther: Bool {
        switch self {
        case .stickers, .avatars, .misc:
            return true
        default:
            return false
        }
    }
}
 

 func filterStorageCacheExceptions(_ peerIds:[StorageCacheException], for category: CacheStorageSettings.PeerStorageCategory) -> [StorageCacheException] {
    return peerIds.filter { value in
        switch category {
        case .channels:
            return value.peer.peer.isChannel
        case .groups:
            return value.peer.peer.isGroup || value.peer.peer.isSupergroup || value.peer.peer.isGigagroup
        case .privateChats:
            return value.peer.peer.isUser || value.peer.peer.isBot
        }
    }
}

extension CacheUsageStatsResult : Equatable {
    public static func == (lhs: CacheUsageStatsResult, rhs: CacheUsageStatsResult) -> Bool {
        switch lhs {
        case let .progress(value):
            if case .progress(value) = rhs {
                return true
            } else {
                return false
            }
        case let .result(value):
            if case .result(value) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    
}
extension CacheUsageStats : Equatable {
    public static func == (lhs: CacheUsageStats, rhs: CacheUsageStats) -> Bool {
        if lhs.media != rhs.media  {
            return false
        }
        if lhs.mediaResourceIds != rhs.mediaResourceIds {
            return false
        }
        if lhs.otherSize != rhs.otherSize {
            return false
        }
        if lhs.otherPaths != rhs.otherPaths {
            return false
        }
        if lhs.cacheSize != rhs.cacheSize {
            return false
        }
        if lhs.tempPaths != rhs.tempPaths {
            return false
        }
        if lhs.tempSize != rhs.tempSize {
            return false
        }
        if lhs.immutableSize != rhs.immutableSize {
            return false
        }
        if lhs.peers.count != rhs.peers.count {
            return false
        } else {
            for (key, lhsPeer) in lhs.peers {
                if let rhsPeer = rhs.peers[key] {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        
        return true
    }
    
    
}

extension AllStorageUsageStats : Equatable {
    public static func ==(lhs: AllStorageUsageStats, rhs: AllStorageUsageStats) -> Bool {
        return lhs === rhs
    }
}
extension StorageUsageStats : Equatable {
    public static func ==(lhs: StorageUsageStats, rhs: StorageUsageStats) -> Bool {
        return lhs === rhs
    }
}
extension StorageUsageStats.CategoryData : Equatable {
    public static func ==(lhs: StorageUsageStats.CategoryData, rhs: StorageUsageStats.CategoryData) -> Bool {
        return lhs.size == rhs.size
    }
}

extension StorageUsageStats {
    var totalCount: Int64 {
        return self.categories.reduce(0, { $0 + $1.value.size })
    }
}

private struct State : Equatable {
    var cacheSettings: CacheStorageSettings
    var accountSpecificCacheSettings: [StorageCacheException]
    var allStats: AllStorageUsageStats?
    var stats: StorageUsageStats?
    var ccTask: CCTaskData?
    var appearance: Appearance
    var systemSize: UInt64?
    var otherRevealed: Bool
    var unselected:Set<StorageUsageCategory>
    var peerId: PeerId?
    var cleared: Bool = false
    
    var debug: Bool = false
    
    var peer: Peer? {
        if let peerId = peerId {
            return allStats?.peers[peerId]?.peer._asPeer()
        } else {
            return nil
        }
    }
}

private let _id_pie_chart = InputDataIdentifier("_id_pie_chart")
private let _id_keep_media_private = InputDataIdentifier("_id_keep_media_private")
private let _id_keep_media_group = InputDataIdentifier("_id_keep_media_group")
private let _id_keep_media_channels = InputDataIdentifier("_id_keep_media_channels")
private let _id_usage = InputDataIdentifier("_id_usage")
private let _id_clear = InputDataIdentifier("_id_clear")
private let _id_cache_size = InputDataIdentifier("_id_cache_size")
private let _id_segments = InputDataIdentifier("_id_segments")
private func _id_category(_ hash: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_category_\(hash)")
}
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer\(id.toInt64())")
}
private func storageUsageControllerEntries(state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var index: Int32 = 0
    
    struct TuplePieChart : Equatable {
        var items: [PieChartView.Item]
        var dynamicString: String
        var viewType: GeneralViewType
    }
    struct TupleKeepMedia : Equatable {
        var category: CacheStorageSettings.PeerStorageCategory
        var exceptions: [StorageCacheException]
        var name: String
        var timeout: String
        var viewType: GeneralViewType
        let id: InputDataIdentifier
    }
    
    struct TupleCategory : Equatable {
        var name: String
        var categoryItem: StorageUsageCategoryItem.Category
        var category: StorageUsageCategory
        var categoryData: StorageUsageStats.CategoryData
        var totalSize: Int64
        var color: NSColor
        var selected: Bool
        var viewType: GeneralViewType
    }
    
    struct TupleUsage : Equatable {
        let string: String
        let header: String
        let progress: CGFloat
        let viewType: GeneralViewType
    }
    
    var pieChart = TuplePieChart(items: [], dynamicString: "...", viewType: .legacy)
    
    var usedBytesCount: Int = 0
    
    if let stats = state.stats, !state.cleared && stats.totalCount > 0 {
        
        
        var chartOrder: [StorageUsageCategory] = [
            .photos,
            .videos,
            .files,
            .music,
            .stickers,
            .avatars,
            .misc
        ].filter {
            stats.categories[$0.native] != nil
        }
        
        let otherIndex = chartOrder.firstIndex(where: { $0.isOther })
        
        var pieOrder = chartOrder
        
        let otherSize: Int64 = stats.categories.reduce(0, { current, value in
            if value.key.isOther {
                return current + value.value.size
            } else {
                return current
            }
        })
        
        if let index = otherIndex, otherSize > 0 {
            pieOrder.insert(.other, at: index)
            if !state.otherRevealed {
                chartOrder.removeAll(where: { $0.isOther })
                chartOrder.append(.other)
            } else {
                chartOrder.insert(.other, at: index)
            }
        }
        
        
        var items:[PieChartView.Item] = []
        
        var i: Int = 0
        
        for key in pieOrder {
            var size: Int64
            switch key {
            case .other:
                size = otherSize
            default:
                size = stats.categories[key.native]!.size
            }
            if state.unselected.contains(key) {
                size = 0
            } else if !state.otherRevealed, key.isOther {
                size = 0
            } else if state.otherRevealed, key == .other {
                size = 0
            }
            
            items.append(.init(id: key.rawValue, index: Int(key.rawValue), count: Int(size), color: key.color, badge: nil))
            i += 1
        }
        
        
        
        usedBytesCount = items.map { $0.count }.reduce(0, +)

        
        if usedBytesCount != 0 {
            pieChart.dynamicString = String.prettySized(with: items.reduce(0, { $0 + $1.count}))
            items.append(.init(id: 1000, index: 1000, count: 0, color: theme.colors.listGrayText.withAlphaComponent(0.2), badge: nil))
        } else {
            pieChart.dynamicString = strings().storageUsageSelectedMediaEmpty
            items.append(.init(id: 1000, index: 1000, count: stats.totalCount == 0 ? Int(1000) : Int(stats.totalCount), color: theme.colors.listGrayText.withAlphaComponent(0.2), badge: nil))
        }
        if state.peerId != nil {
            pieChart.dynamicString = ""
        }

        let counts = optimizeArray(array: items.map { $0.count }, minPercent: 0.01)
        for i in 0 ..< items.count {
            let category = chartOrder.first(where: { AnyHashable($0.rawValue) == items[i].id })
            if usedBytesCount > 0, let category = category {
                let count = items[i].count
                let badge = NSMutableAttributedString()
                let percent = CGFloat(items[i].count) / CGFloat(usedBytesCount) * 100
                let percentString = String(format: "%.02f%%", percent)
                _ = badge.append(string: percentString, color: theme.colors.text, font: .medium(.text))
                _ = badge.append(string: "  ")
                _ = badge.append(string: category.title, color: theme.colors.text, font: .normal(.text))
                _ = badge.append(string: "  ")
                _ = badge.append(string: String.prettySized(with: count), color: items[i].color, font: .bold(.text))
                
                items[i].badge = badge
            }
            items[i].count = counts[i]
        }
        
        pieChart.items = items
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pie_chart, equatable: InputDataEquatable(pieChart), comparable: nil, item: { initialSize, stableId in
            return StoragePieChartItem(initialSize, stableId: stableId, context: arguments.context, items: pieChart.items, dynamicText: pieChart.dynamicString, peer: state.peer, viewType: pieChart.viewType)
        }))
        index += 1
        
        

        
        let usageProgress: CGFloat
        if let _ = state.peerId, let allStats = state.allStats {
            usageProgress = CGFloat(stats.totalCount) / CGFloat(allStats.totalStats.totalCount) * 100.0
        } else {
            if let systemSize = state.systemSize {
                usageProgress = CGFloat(stats.totalCount) / CGFloat(systemSize * 1024 * 1024 * 1024) * 100.0
            } else {
                usageProgress = 0
            }
        }
        
        
        let usageText: String
        if usageProgress < 0.01 {
            if let _ = state.peer {
                usageText = strings().storageUsageTelegramUsageEmptyPeer
            } else {
                usageText = strings().storageUsageTelegramUsageEmpty
            }
        } else {
            if let _ = state.peer {
                usageText = strings().storageUsageTelegramUsageTextPeer(String(format: "%.02f%%", usageProgress))
            } else {
                usageText = strings().storageUsageTelegramUsageText(String(format: "%.02f%%", usageProgress))
            }
        }
        let usageHeader: String
        if let peer = state.peer {
            usageHeader = peer.displayTitle
        } else {
            usageHeader = strings().storageUsageHeader
        }
        
        let tupleUsage = TupleUsage(string: usageText, header: usageHeader, progress: max(0.03, usageProgress / 100.0), viewType: .legacy)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_usage, equatable: .init(tupleUsage), comparable: nil, item: { initialSize, stableId in
            return StorageUsageHeaderItem(initialSize, stableId: stableId, header: tupleUsage.header, string: tupleUsage.string, progress: tupleUsage.progress, viewType: tupleUsage.viewType)
        }))
        index += 1
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        i = 0
        var categoryItems:[TupleCategory] = []
        
        let totalSize: Int64 = stats.categories.filter {
            !state.unselected.contains($0.key.mappedCategory)
        }.reduce(0, {
            $0 + $1.value.size
        })
        
        chartOrder = chartOrder.filter { value in
            switch value {
            case .other:
                return true
            default:
                return stats.categories[value.native]?.size != 0
            }
        }
                
        for key in chartOrder {
            let categoryData: StorageUsageStats.CategoryData
            let itemCategory: StorageUsageCategoryItem.Category
            switch key {
            case .other:
                let total: Int64 = stats.categories.reduce(0, { current, value in
                    switch value.key {
                    case .misc, .avatars, .stickers:
                        return current + value.value.size
                    default:
                        return current
                    }
                })
                categoryData = .init(size: total, messages: [:])
                itemCategory = .basic(hasSub: otherIndex != nil, revealed: state.otherRevealed)
            default:
                if key.isOther {
                    itemCategory = .sub
                } else {
                    itemCategory = .basic(hasSub: false, revealed: false)
                }
                categoryData = stats.categories[key.native]!
            }
            
            let viewType: GeneralViewType
            if i != chartOrder.count - 1 {
                viewType = bestGeneralViewType(chartOrder, for: i)
            } else if chartOrder.count == 1 {
                viewType = .firstItem
            } else {
                viewType = .innerItem
            }
            categoryItems.append(.init(name: key.title, categoryItem: itemCategory, category: key, categoryData: categoryData, totalSize: totalSize, color: key.color, selected: !state.unselected.contains(key), viewType: viewType))

            i += 1
        }

        if !categoryItems.isEmpty {
            
            for item in categoryItems {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_category(item.category.hashValue), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                    
                    let nameAttr: NSMutableAttributedString = .init()
                    _ = nameAttr.append(string: item.name, color: theme.colors.text, font: .normal(.title))
                    
                    if item.selected {
                        _ = nameAttr.append(string: " ")
                        
                        let percent = CGFloat(item.categoryData.size) / CGFloat(item.totalSize) * 100
                        var formatted = String(format: "%.01f%%", percent)
                        if percent < 0.1 {
                            formatted = "<0.1%"
                        }
                        _ = nameAttr.append(string: formatted, color: theme.colors.grayText, font: .normal(.title))
                    }
                    
                    
                    let subAttr: NSAttributedString = .initialize(string: String.prettySized(with: item.categoryData.size), color: theme.colors.grayText, font: .normal(.title))
                    
                    let canToggle: Bool = true
//                    let selected = categoryItems.filter { $0.selected }
//                    if selected.count == 1, selected[0].category == item.category {
//                        canToggle = false
//                    } else if item.category == .other {
//                        canToggle = categoryItems.filter { $0.category.isOther }.count != selected.filter { $0.category != .other }.count
//                    } else {
//                        canToggle = true
//                    }
                    
                    return StorageUsageCategoryItem(initialSize, stableId: stableId, category: item.category, name: nameAttr, subString: subAttr, color: item.color, selected: item.selected, itemCategory: item.categoryItem, viewType: item.viewType, action: { action in
                        switch action {
                        case .selection:
                            if canToggle {
                                arguments.toggleCategory(item.category)
                            }
                        case .toggle:
                            arguments.toggleOther()
                        }
                    })
                }))
                index += 1
            }
            index = 1000
            
            struct TupleClear : Equatable {
                var text: String
                var enabled: Bool
                var viewType: GeneralViewType
            }
            
            
            let text: String
            let enabled: Bool
            
            let clearSize = stats.categories.filter {
                !state.unselected.contains($0.key.mappedCategory)
            }.map {
                $0.value.size
            }.reduce(0, +)
            
            if clearSize > 0 {
                text = strings().storageUsageClearFull(String.prettySized(with: clearSize))
                enabled = true
            } else {
                text = strings().storageUsageClearDisabled
                enabled = false
            }
            let tupleClear: TupleClear = .init(text: text, enabled: enabled, viewType: categoryItems.isEmpty ? .singleItem : .lastItem)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_clear, equatable: InputDataEquatable(tupleClear), comparable: nil, item: { initialSize, stableId in
                return StorageUsageClearButtonItem(initialSize, stableId: stableId, text: tupleClear.text, enabled: tupleClear.enabled, viewType: tupleClear.viewType, action: arguments.clearAll)
            }))
            index += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageCategoryText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1

                    
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
        
    } else if state.cleared || state.stats == nil || state.stats?.totalCount == 0 {
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pie_chart, equatable: InputDataEquatable(state.cleared), comparable: nil, item: { initialSize, stableId in
            return StorageUsageClearedItem(initialSize, stableId: stableId, viewType: .legacy)
        }))
        index += 1
        
        
        let tupleUsage = TupleUsage(string: strings().storageUsageClearedInfo, header: strings().storageUsageCleared, progress: 0, viewType: .legacy)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_usage, equatable: .init(tupleUsage), comparable: nil, item: { initialSize, stableId in
            return StorageUsageHeaderItem(initialSize, stableId: stableId, header: tupleUsage.header, string: tupleUsage.string, progress: tupleUsage.progress, viewType: tupleUsage.viewType)
        }))
        index += 1
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    if state.peerId == nil {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageLimitHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_cache_size, equatable: .init(state.cacheSettings), comparable: nil, item: { initialSize, stableId in
            let values = [5, 16, 32, Int32.max]
            var value = state.cacheSettings.defaultCacheStorageLimitGigabytes
            if !values.contains(value) {
                value = Int32.max
            }
            return SelectSizeRowItem(initialSize, stableId: stableId, current: value, sizes: values, hasMarkers: false, titles: ["5GB", "16GB", "32GB", strings().storageUsageLimitNoLimit], viewType: .singleItem, selectAction: { selected in
                arguments.updateMediaLimit(values[selected])
            })
        }))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageLimitInfoUpdated), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

        

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
            
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageKeepMediaHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        
        
        
        var keepMedias: [TupleKeepMedia] = []
        
        keepMedias.append(.init(category: .privateChats, exceptions: filterStorageCacheExceptions(state.accountSpecificCacheSettings, for: .privateChats), name: strings().storageUsageKeepMediaPrivate, timeout: stringForKeepMediaTimeout(state.cacheSettings.categoryStorageTimeout[.privateChats] ?? .max), viewType: .firstItem, id: _id_keep_media_private))
        
        keepMedias.append(.init(category: .groups, exceptions: filterStorageCacheExceptions(state.accountSpecificCacheSettings, for: .groups), name: strings().storageUsageKeepMediaGroups, timeout: stringForKeepMediaTimeout(state.cacheSettings.categoryStorageTimeout[.groups] ?? .max), viewType: .innerItem, id: _id_keep_media_group))
        
        keepMedias.append(.init(category: .channels, exceptions: filterStorageCacheExceptions(state.accountSpecificCacheSettings, for: .channels), name: strings().storageUsageKeepMediaChannels, timeout: stringForKeepMediaTimeout(state.cacheSettings.categoryStorageTimeout[.channels] ?? .max), viewType: .lastItem, id: _id_keep_media_channels))


        for keepMedia in keepMedias {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: keepMedia.id, equatable: .init(keepMedia), comparable: nil, item: { initialSize, stableId in
                var items = [ContextMenuItem(strings().timerDaysCountable(1), handler: {
                    arguments.updateKeepMedia(keepMedia.category, 1 * 24 * 60 * 60)
                }, itemImage: MenuAnimation.menu_autodelete_1d.value),
                ContextMenuItem(strings().timerWeeksCountable(1), handler: {
                      arguments.updateKeepMedia(keepMedia.category, 7 * 24 * 60 * 60)
                }, itemImage: MenuAnimation.menu_autodelete_1w.value),
                ContextMenuItem(strings().timerMonthsCountable(1), handler: {
                    arguments.updateKeepMedia(keepMedia.category, 1 * 31 * 24 * 60 * 60)
                }, itemImage: MenuAnimation.menu_autodelete_1m.value),
                ContextMenuItem(strings().timerForever, handler: {
                    arguments.updateKeepMedia(keepMedia.category, .max)
                }, itemImage: MenuAnimation.menu_forever.value)]
                
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().storageUsageKeepMediaExceptionsCountable(keepMedia.exceptions.count), handler: {
                    arguments.exceptions(keepMedia.category)
                }, itemImage: keepMedia.exceptions.isEmpty ? MenuAnimation.menu_add.value : MenuAnimation.menu_report.value))
                
                let icon: CGImage
                switch keepMedia.category {
                case .groups:
                    icon = NSImage(named: "Icon_Colored_Group")!.precomposed(flipVertical: true)
                case .channels:
                    icon = NSImage(named: "Icon_Colored_Channel")!.precomposed(flipVertical: true)
                case .privateChats:
                    icon = NSImage(named: "Icon_Colored_Private")!.precomposed(flipVertical: true)
                }
                let desc: String?
                if keepMedia.exceptions.isEmpty {
                    desc = nil
                } else {
                    desc = strings().storageUsageKeepMediaExceptionsCountable(keepMedia.exceptions.count)
                }
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: keepMedia.name, icon: icon, description: desc, type: .contextSelector(keepMedia.timeout, items), viewType: keepMedia.viewType)
            }))
            index += 1
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageKeepMediaDescription1), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

       
        if state.debug {
            if let stats = state.stats {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_segments, equatable: .init(stats), comparable: nil, item: { initialSize, stableId in
                    if let controller = arguments.segmentController() {
                        return StorageUsageBlockItem(initialSize, stableId: stableId, controller: controller, isVisible: true, viewType: .singleItem)
                    } else {
                        return GeneralRowItem(initialSize, stableId: stableId)
                    }
                }))
            }
        }
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        if let allStats = state.allStats, !allStats.peers.isEmpty, let stats = state.stats, stats.totalCount > 0 && !state.cleared {
            let sorted = allStats.peers.map { $0.value }.sorted(by: { $0.stats.totalCount > $1.stats.totalCount })
            
            struct TuplePeer : Equatable {
                let peer: PeerEquatable
                let count: String
                let viewType: GeneralViewType
            }
            var items:[TuplePeer] = []
            
            for (i, sort) in sorted.enumerated() {
                items.append(.init(peer: .init(sort.peer._asPeer()), count: String.prettySized(with: sort.stats.totalCount), viewType: bestGeneralViewType(sorted, for: i)))
            }
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageChatsHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            
            for item in items {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 42, photoSize: NSMakeSize(30, 30), isLookSavedMessage: true, inset: NSEdgeInsets(left: 30, right: 30), generalType: .context(item.count), viewType: item.viewType, action: {
                        arguments.openPeerMedia(item.peer.peer.id)
                    })
                }))
            }
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }
    
    return entries
}




class StorageUsageController: TableViewController {

    private let peerId: PeerId?
    private var segments: StorageUsageBlockController?
    init(_ context: AccountContext, peerId: PeerId? = nil) {
        self.peerId = peerId
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let initialSize = self.atomicSize
        let actionDisposables = DisposableSet()
        
        let clearDisposable = MetaDisposable()
        actionDisposables.add(clearDisposable)
        
        
        let initialState = State(cacheSettings: .defaultSettings, accountSpecificCacheSettings: [], appearance: appAppearance, otherRevealed: false, unselected: Set(), peerId: self.peerId)
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        
        let cacheSettingsPromise = Promise<CacheStorageSettings>()
        cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
                                 |> map { view -> CacheStorageSettings in
            return view.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) ?? CacheStorageSettings.defaultSettings
        })
        
        
        let accountSpecificCacheSettingsPromise = Promise<AccountSpecificCacheStorageSettings>()
        let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
        accountSpecificCacheSettingsPromise.set(context.account.postbox.combinedView(keys: [viewKey])
                                                |> map { views -> AccountSpecificCacheStorageSettings in
            let cacheSettings: AccountSpecificCacheStorageSettings
            if let view = views.views[viewKey] as? PreferencesView, let value = view.values[PreferencesKeys.accountSpecificCacheStorageSettings]?.get(AccountSpecificCacheStorageSettings.self) {
                cacheSettings = value
            } else {
                cacheSettings = AccountSpecificCacheStorageSettings.defaultSettings
            }
            
            return cacheSettings
        })
        
                
        let statsPromise = Promise<AllStorageUsageStats?>()
        statsPromise.set(context.engine.resources.collectStorageUsageStats() |> map(Optional.init))
        
        
        let updateStats:()->Void = {
            statsPromise.set(context.engine.resources.collectStorageUsageStats() |> map(Optional.init))
        }
        
        let arguments = Arguments(context: context, updateKeepMedia: { category, timeout in
            let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.categoryStorageTimeout[category] = timeout
                return current
            }).start()
        }, updateMediaLimit: { limit in
            let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.defaultCacheStorageLimitGigabytes = limit
                return current
            }).start()
        }, openPeerMedia: { [weak self] peerId in
            self?.navigationController?.push(StorageUsageController(context, peerId: peerId))
        }, clearAll: {
            
            let categories: [StorageUsageStats.CategoryKey] = stateValue.with { value in
                if let stats = value.stats {
                    return stats.categories.map { $0.key }.filter {
                        !value.unselected.contains($0.mappedCategory)
                    }
                }
                return []
            }
            
            _ = context.engine.resources.clearStorage(peerId: stateValue.with { $0.peerId }, categories: categories).start(completed: updateStats)
            
            let cleared = stateValue.with({ $0.unselected.filter({ $0 != .other }).isEmpty })
            updateState { current in
                var current = current
                current.cleared = cleared
                return current
            }
            
        }, exceptions: { category in
            context.bindings.rootNavigation().push(DataStorageExceptions(context: context, category: category))
        }, toggleOther: {
            updateState { current in
                var current = current
                current.otherRevealed = !current.otherRevealed
                return current
            }
        }, toggleCategory: { category in
            updateState { current in
                var current = current
                
                if current.unselected.contains(category) {
                    current.unselected.remove(category)
                } else {
                    current.unselected.insert(category)
                }
                
                switch category {
                case .other:
                    if current.unselected.contains(.other) {
                        current.unselected.insert(.stickers)
                        current.unselected.insert(.avatars)
                        current.unselected.insert(.misc)
                    } else {
                        current.unselected.remove(.stickers)
                        current.unselected.remove(.avatars)
                        current.unselected.remove(.misc)
                    }
                default:
                    if category.isOther {
                        if current.unselected.contains(category) {
                            current.unselected.insert(.other)
                        } else {
                            let contains = current.unselected.contains(where: { $0.isOther })
                            if !contains {
                                current.unselected.remove(.other)
                            }
                        }
                    }
                }
                
                return current
            }
        }, segmentController: { [weak self] in
            if let segments = self?.segments {
                return segments
            } else {
                let state = stateValue.with { $0 }
                if let stats = state.stats, let allStats = state.allStats {
                    let segments = StorageUsageBlockController(context: context, peerId: state.peerId, allStats: allStats, stats: stats)
                    self?.segments = segments
                }
            }
            return self?.segments
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        
        
        let accountSpecificCacheSettingsAndPeers: Signal<[StorageCacheException], NoError> = accountSpecificCacheSettingsPromise.get() |> mapToSignal { settings in
            return context.account.postbox.transaction { transaction in
                var data: [StorageCacheException] = []
                for value in settings.peerStorageTimeoutExceptions {
                    if let peer = transaction.getPeer(value.key) {
                        data.append(.init(value: value.value, peer: PeerEquatable(peer)))
                    }
                }
                return data
            }
        }
        
        
        let signal = combineLatest(queue: prepareQueue, cacheSettingsPromise.get(), accountSpecificCacheSettingsAndPeers, statsPromise.get(), context.cacheCleaner.task, appearanceSignal)
        
        self.onDeinit = {
            actionDisposables.dispose()
        }
        
        actionDisposables.add(signal.start(next: { cacheSettings, accountSpecificCacheSettings, allStats, ccTask, appearance in
            updateState { current in
                var current = current
                current.cacheSettings = cacheSettings
                current.accountSpecificCacheSettings = accountSpecificCacheSettings
                current.allStats = allStats
                if let allStats = allStats {
                    if let peerId = current.peerId {
                        current.stats = allStats.peers[peerId]?.stats
                    } else {
                        current.stats = allStats.totalStats
                    }
                }
                
                current.ccTask = ccTask
                current.appearance = appearance
                current.systemSize = systemSizeGigabytes()
                return current
            }
        }))
        
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {
            
        })
        
        let transition: Signal<TableUpdateTransition, NoError> = statePromise.get() |> mapToQueue { state in
            let entries = storageUsageControllerEntries(state: state, arguments: arguments).map {
                AppearanceWrapperEntry(entry: $0, appearance: state.appearance)
            }
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputArguments, onMainQueue: false)
        } |> deliverOnMainQueue
        
        actionDisposables.add(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        self.toggleDebug = {
            updateState { current in
                var current = current
                current.debug = !current.debug
                return current
            }
        }
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(40, controller: self)
    }
    private var toggleDebug:(()->Void)?
    override func returnKeyAction() -> KeyHandlerResult {
        #if DEBUG
        self.toggleDebug?()
        #endif
        return super.returnKeyAction()
    }
}




//
//    entries.append(.section(sectionId))
//    sectionId += 1
//
//
//    //
//    entries.append(.keepMediaLimitHeader(sectionId, strings().storageUsageLimitHeader, .textTopItem))
//    entries.append(.keepMediaLimit(sectionId, state.cacheSettings.defaultCacheStorageLimitGigabytes, .singleItem))
//    entries.append(.keepMediaLimitInfo(sectionId, strings().storageUsageLimitDesc, .textBottomItem))
//
//
//    entries.append(.section(sectionId))
//    sectionId += 1
//
//
//    if let ccTask = state.ccTask {
//        entries.append(.ccTaskValue(sectionId, ccTask, .singleItem))
//        entries.append(.ccTaskValueDesc(sectionId, strings().storageUsageCleaningProcess, .textBottomItem))
//    } else {
//
//        var exists:[PeerId:PeerId] = [:]
//        if let cacheStats = state.cacheStats, case let .result(stats) = cacheStats {
//
//            entries.append(.clearAll(sectionId, !stats.peers.isEmpty, .singleItem))
//
//            entries.append(.section(sectionId))
//            sectionId += 1
//
//            var statsByPeerId: [(PeerId, Int64)] = []
//            for (peerId, categories) in stats.media {
//                if exists[peerId] == nil {
//                    var combinedSize: Int64 = 0
//                    for (_, media) in categories {
//                        for (_, size) in media {
//                            combinedSize += size
//                        }
//                    }
//                    statsByPeerId.append((peerId, combinedSize))
//                    exists[peerId] = peerId
//                }
//
//            }
//            var index: Int32 = 0
//
//            let filtered = statsByPeerId.sorted(by: { $0.1 > $1.1 }).filter { peerId, size -> Bool in
//                return size >= 32 * 1024 && stats.peers[peerId] != nil && !stats.peers[peerId]!.isSecretChat
//            }
//
//            if !filtered.isEmpty {
//                entries.append(.peersHeader(sectionId, strings().storageUsageChatsHeader, .textTopItem))
//            }
//
//            for (i, value) in filtered.enumerated() {
//                let peer = stats.peers[value.0]!
//                entries.append(.peer(sectionId, index, peer, dataSizeString(Int(value.1), formatting: DataSizeStringFormatting.current), bestGeneralViewType(filtered, for: i)))
//                index += 1
//            }
//        } else {
//
//            entries.append(.clearAll(sectionId, true, .singleItem))
//
//            entries.append(.section(sectionId))
//            sectionId += 1
//
//            entries.append(.collecting(sectionId, strings().storageUsageCalculating, .singleItem))
//        }
//    }
//
//
//    entries.append(.section(sectionId))
//    sectionId += 1
//
//    return entries



//            let stats = stateValue.with { $0.cacheStats }
//            if let result = stats, case let .result(stats) = result {
//                if let categories = stats.media[peerId] {
//                    showModal(with: ChatStorageManagmentModalController(categories, clear: { sizeIndex in
//                        let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
//
//                        var clearMediaIds = Set<MediaId>()
//
//                        var media = stats.media
//                        if var categories = media[peerId] {
//                            for category in clearCategories {
//                                if let contents = categories[category] {
//                                    for (mediaId, _) in contents {
//                                        clearMediaIds.insert(mediaId)
//                                    }
//                                }
//                                categories.removeValue(forKey: category)
//                            }
//
//                            media[peerId] = categories
//                        }
//
//                        var clearResourceIds = Set<MediaResourceId>()
//                        for id in clearMediaIds {
//                            if let ids = stats.mediaResourceIds[id] {
//                                for resourceId in ids {
//                                    clearResourceIds.insert(resourceId)
//                                }
//                            }
//                        }
//                        updateState { current in
//                            var current = current
//                            current.cacheStats = .result(CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: stats.otherSize, otherPaths: stats.otherPaths, cacheSize: stats.cacheSize, tempPaths: stats.tempPaths, tempSize: stats.tempSize, immutableSize: stats.immutableSize))
//                            return current
//                        }
//                        clearDisposable.set(context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds).start())
//                    }), for: context.window)
//                }
//            }


//            confirm(for: context.window, information: strings().storageClearAllConfirmDescription, okTitle: strings().storageClearAll, successHandler: { _ in
//                context.cacheCleaner.run()
//                updateState { current in
//                    var current = current
//                    current.cacheStats = CacheUsageStatsResult.result(.init(media: [:], mediaResourceIds: [:], peers: [:], otherSize: 0, otherPaths: [], cacheSize: 0, tempPaths: [], tempSize: 0, immutableSize: 0))
//                    return current
//                }
//            })


/*
 
 private enum StorageUsageSection: Int32 {
     case keepMedia
     case peers
 }

 private enum StorageUsageEntry: TableItemListNodeEntry {
     case keepMedia(Int32, Int32, CacheStorageSettings.PeerStorageCategory, [StorageCacheException], String, String, GeneralViewType)
     case keepMediaInfo(Int32, String, GeneralViewType)
     case keepMediaLimitHeader(Int32, String, GeneralViewType)
     case keepMediaLimit(Int32, Int32, GeneralViewType)
     case keepMediaLimitInfo(Int32, String, GeneralViewType)
     case ccTaskValue(Int32, CCTaskData, GeneralViewType)
     case ccTaskValueDesc(Int32, String, GeneralViewType)
     case clearAll(Int32, Bool, GeneralViewType)
     case collecting(Int32, String, GeneralViewType)
     case peersHeader(Int32, String, GeneralViewType)
     case peer(Int32, Int32, Peer, String, GeneralViewType)
     case section(Int32)

     var stableId: Int64 {
         switch self {
         case let .keepMedia(_, index, _, _, _, _, _):
             return Int64(index)
         case .keepMediaInfo:
             return 6
         case .keepMediaLimitHeader:
             return 7
         case .keepMediaLimit:
             return 8
         case .keepMediaLimitInfo:
             return 9
         case .ccTaskValue:
             return 10
         case .ccTaskValueDesc:
             return 11
         case .clearAll:
             return 12
         case .collecting:
             return 13
         case .peersHeader:
             return 14
         case let .peer(_, _, peer, _, _):
             return peer.id.toInt64()
         case .section(let sectionId):
             return Int64((sectionId + 1) * 1000 - sectionId)
         }
     }
     
     var stableIndex: Int32 {
         switch self {
         case let .keepMedia(_, index, _, _, _, _, _):
             return index
         case .keepMediaInfo:
             return 5
         case .keepMediaLimitHeader:
             return 6
         case .keepMediaLimit:
             return 7
         case .keepMediaLimitInfo:
             return 8
         case .ccTaskValue:
             return 9
         case .ccTaskValueDesc:
             return 10
         case .clearAll:
             return 11
         case .collecting:
             return 12
         case .peersHeader:
             return 13
         case let .peer(_, index, _, _, _):
             return 14 + index
         case .section(let sectionId):
             return (sectionId + 1) * 1000 - sectionId
         }
     }
     
     var index:Int32 {
         switch self {
         case .keepMedia(let sectionId, _, _, _, _, _, _):
             return (sectionId * 1000) + stableIndex
         case .keepMediaInfo(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .keepMediaLimitHeader(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .keepMediaLimit(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .keepMediaLimitInfo(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .clearAll(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .ccTaskValue(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .ccTaskValueDesc(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .collecting(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case .peersHeader(let sectionId, _, _):
             return (sectionId * 1000) + stableIndex
         case let .peer(sectionId, _, _, _, _):
             return (sectionId * 1000) + stableIndex
         case .section(let sectionId):
             return (sectionId + 1) * 1000 - sectionId
         }
     }
     
     static func ==(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
         switch lhs {
         case let .keepMedia(sectionId, index, category, peerIds, text, value, viewType):
             if case .keepMedia(sectionId, index, category, peerIds, text, value, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .keepMediaInfo(sectionId, text, viewType):
             if case .keepMediaInfo(sectionId, text, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .keepMediaLimitHeader(sectionId, value, viewType):
             if case .keepMediaLimitHeader(sectionId, value, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .keepMediaLimit(sectionId, value, viewType):
             if case .keepMediaLimit(sectionId, value, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .keepMediaLimitInfo(sectionId, value, viewType):
             if case .keepMediaLimitInfo(sectionId, value, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .ccTaskValue(sectionId, task, viewType):
             if case .ccTaskValue(sectionId, task, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .ccTaskValueDesc(sectionId, value, viewType):
             if case .ccTaskValueDesc(sectionId, value, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .clearAll(sectionId, enabled, viewType):
             if case .clearAll(sectionId, enabled, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .collecting(sectionId, text, viewType):
             if case .collecting(sectionId, text, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .peersHeader(sectionId, text, viewType):
             if case .peersHeader(sectionId, text, viewType) = rhs {
                 return true
             } else {
                 return false
             }
         case let .section(sectionId):
             if case .section(sectionId) = rhs {
                 return true
             } else {
                 return false
             }
         case let .peer(lhsSectionId, lhsIndex, lhsPeer, lhsValue, lhsViewType):
             if case let .peer(rhsSectionId, rhsIndex, rhsPeer, rhsValue, rhsViewType) = rhs {
                 if lhsIndex != rhsIndex {
                     return false
                 }
                 if lhsSectionId != rhsSectionId {
                     return false
                 }
                 if !arePeersEqual(lhsPeer, rhsPeer) {
                     return false
                 }
                 if lhsViewType != rhsViewType {
                     return false
                 }
                 if lhsValue != rhsValue {
                     return false
                 }
                 return true
             } else {
                 return false
             }
         }
     }
     
     static func <(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
         return lhs.index < rhs.index
     }
     
     func item(_ arguments: Arguments, initialSize: NSSize) -> TableRowItem {
         
         switch self {
         case let .keepMedia(_, _, category, exceptions, text, value, viewType):
             var items = [ContextMenuItem(strings().timerDaysCountable(1), handler: {
                 arguments.updateKeepMedia(category, 1 * 24 * 60 * 60)
               }), ContextMenuItem(strings().timerWeeksCountable(1), handler: {
                   arguments.updateKeepMedia(category, 7 * 24 * 60 * 60)
             }), ContextMenuItem(strings().timerMonthsCountable(1), handler: {
                 arguments.updateKeepMedia(category, 1 * 31 * 24 * 60 * 60)
             }), ContextMenuItem(strings().timerForever, handler: {
                 arguments.updateKeepMedia(category, .max)
             })]
             
             items.append(ContextSeparatorItem())
             
             items.append(ContextMenuItem(strings().storageUsageKeepMediaExceptionsCountable(exceptions.count), handler: {
                 arguments.exceptions(category)
             }))
             
             let icon: CGImage
             switch category {
             case .groups:
                 icon = NSImage(named: "Icon_Colored_Group")!.precomposed(flipVertical: true)
             case .channels:
                 icon = NSImage(named: "Icon_Colored_Channel")!.precomposed(flipVertical: true)
             case .privateChats:
                 icon = NSImage(named: "Icon_Colored_Private")!.precomposed(flipVertical: true)
             }
             return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, icon: icon, type: .contextSelector(value, items), viewType: viewType, action: {
             })
         case let .keepMediaInfo(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
         case let .keepMediaLimitHeader(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
         case let .keepMediaLimit(_, value, viewType):
             let values = [5, 16, 32, Int32.max]
             var value = value
             if !values.contains(value) {
                 value = Int32.max
             }
             return SelectSizeRowItem(initialSize, stableId: stableId, current: value, sizes: values, hasMarkers: false, titles: ["5GB", "16GB", "32GB", strings().storageUsageLimitNoLimit], viewType: viewType, selectAction: { selected in
                 arguments.updateMediaLimit(values[selected])
             })
         case let .keepMediaLimitInfo(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
         case let .collecting(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, alignment: .center, additionLoading: true, viewType: viewType)
         case let .ccTaskValue(_, task, viewType):
             return StorageUsageCleanProgressRowItem(initialSize, stableId: stableId, task: task, viewType: viewType)
         case let .ccTaskValueDesc(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
         case let .clearAll(_, enabled, viewType):
             return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().storageClearAll, type: .next, viewType: viewType, action: {
                 arguments.clearAll()
             }, enabled: enabled)
         case let .peersHeader(_, text, viewType):
             return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
         case let .peer(_, _, peer, value, viewType):
             return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), isLookSavedMessage: true, inset: NSEdgeInsets(left: 30, right: 30), generalType: .context(value), viewType: viewType, action: {
                 arguments.openPeerMedia(peer.id)
             })
         case .section:
             return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
         }
     }
 }
 */
