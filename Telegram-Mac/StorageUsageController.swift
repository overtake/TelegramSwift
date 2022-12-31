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

final class StorageUsageArguments {
    let context: AccountContext
    let updateKeepMedia: (CacheStorageSettings.PeerStorageCategory, Int32) -> Void
    let updateMediaLimit: (Int32) -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearAll:()->Void
    let exceptions:(CacheStorageSettings.PeerStorageCategory)->Void
    let toggleOther:()->Void
    let toggleCategory:(StorageUsageCategory)->Void
    let segmentController:()->StorageUsageBlockController?
    let clearSelected:()->Void
    let clearPeer:(PeerId)->Void
    let clearMessage:(Message)->Void
    let selectCategory:(StorageUsageCategory)->Void
    init(context: AccountContext, updateKeepMedia: @escaping (CacheStorageSettings.PeerStorageCategory, Int32) -> Void, updateMediaLimit: @escaping(Int32)->Void, openPeerMedia: @escaping (PeerId) -> Void, clearAll: @escaping () -> Void, exceptions:@escaping(CacheStorageSettings.PeerStorageCategory)->Void, toggleOther:@escaping()->Void, toggleCategory:@escaping(StorageUsageCategory)->Void, segmentController:@escaping()->StorageUsageBlockController?, clearSelected:@escaping()->Void, clearPeer:@escaping(PeerId)->Void, clearMessage:@escaping(Message)->Void, selectCategory:@escaping(StorageUsageCategory)->Void) {
        self.context = context
        self.updateKeepMedia = updateKeepMedia
        self.openPeerMedia = openPeerMedia
        self.clearAll = clearAll
        self.updateMediaLimit = updateMediaLimit
        self.exceptions = exceptions
        self.toggleOther = toggleOther
        self.toggleCategory = toggleCategory
        self.segmentController = segmentController
        self.clearSelected = clearSelected
        self.clearPeer = clearPeer
        self.clearMessage = clearMessage
        self.selectCategory = selectCategory
    }
}

struct StorageCacheException : Equatable {
    let value: Int32
    let peer: PeerEquatable
}

func stringForKeepMediaTimeout(_ timeout: Int32) -> String {
    if timeout <= 1 * 24 * 60 * 60 {
        return strings().timerDaysCountable(1)
    } else if timeout <= 7 * 24 * 60 * 60 {
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
}

extension StorageUsageStats.CategoryKey {
    var mapped: StorageUsageCategory {
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
    
    var msgIds: Set<EngineMessage.Id> {
        var ids: [EngineMessage.Id] = []
        for (_, value) in categories {
            ids.append(contentsOf: value.messages.map { $0.key })
        }
        return Set(ids)
    }
    var msgSizes: [EngineMessage.Id : Int64] {
        var ids: [EngineMessage.Id : Int64] = [:]
        for (_, value) in categories {
            for (key, value) in value.messages {
                ids[key] = value
            }
        }
        return ids
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

struct StorageUsageUIState : Equatable {
    var cacheSettings: CacheStorageSettings
    var accountSpecificCacheSettings: [StorageCacheException]
    var allStats: AllStorageUsageStats?
    var stats: StorageUsageStats?
    var msgSizes: [EngineMessage.Id : Int64] = [:]
    var appearance: Appearance
    var systemSize: UInt64?
    var otherRevealed: Bool
    var unselected:Set<StorageUsageCategory>
    var peerId: PeerId?
    var cleared: Bool = false
    
    var ignorePeerIds:Set<PeerId> = Set()
    var ignoreMsgIds:Set<EngineMessage.Id> = Set()

    var collection: StorageUsageCollection = .peers
    
    var effectiveCollection: StorageUsageCollection? {
        let segments = self.segments
        if segments.contains(collection) {
            return collection
        } else {
            return segments.first
        }
    }
    var _messages: [EngineMessage.Id: Message] = [:]
    
    var messages: [EngineMessage.Id: Message] {
        get {
            _messages.filter {
                !ignoreMsgIds.contains($0.key)
            }
        }
        set {
            _messages = newValue
        }
    }
    
    var selectedMessages:Set<EngineMessage.Id> = Set()
    var selectedPeers: SelectPeerPresentation = SelectPeerPresentation()
    
    var editing: Bool = false
    
    var debug: Bool = true
    
    var peer: Peer? {
        if let peerId = peerId {
            return allStats?.peers[peerId]?.peer._asPeer()
        } else {
            return nil
        }
    }
    
    var peers: [PeerId: AllStorageUsageStats.PeerStats] {
        if let allStats = allStats {
            return allStats.peers.filter {
                !ignorePeerIds.contains($0.key)
            }
        }
        return [:]
    }
    
    func messageList(for tag: StorageUsageCollection) -> [Message] {
        var list:[Message] = []
        
        if cleared {
            return []
        }
        
        for (_, message) in messages {
            if message.anyMedia is TelegramMediaImage {
                switch tag {
                case .media:
                    list.append(message)
                default:
                    break
                }
            }
            if let file = message.anyMedia as? TelegramMediaFile {
                let type: MediaResourceUserContentType = .init(file: file)
                switch type {
                case .file:
                    switch tag {
                    case .files:
                        list.append(message)
                    default:
                        break
                    }
                case .video:
                    switch tag {
                    case .media:
                        list.append(message)
                    default:
                        break
                    }
                case .audio:
                    switch tag {
                    case .music:
                        list.append(message)
                    default:
                        break
                    }
                case .audioVideoMessage:
                    switch tag {
                    case .voice:
                        list.append(message)
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
        return list
    }
    
    var segments: [StorageUsageCollection] {
        var segments:[StorageUsageCollection] = []
        
        if cleared {
            return []
        }
        
        if peerId == nil {
            if !self.peers.isEmpty {
                segments.append(.peers)
            }
        }
        
        var hasMedia: Bool = false
        var hasFiles: Bool = false
        var hasMusic: Bool = false
        var hasVoice: Bool = false
        for (_, message) in messages {
            if message.media.first is TelegramMediaImage {
                hasMedia = true
            }
            if let file = message.media.first as? TelegramMediaFile {
                let type: MediaResourceUserContentType = .init(file: file)
                switch type {
                case .file:
                    hasFiles = true
                case .video:
                    hasMedia = true
                case .audio:
                    hasMusic = true
                case .audioVideoMessage:
                    hasVoice = true
                default:
                    break
                }
            }
        }
        if hasMedia {
            segments.append(.media)
        }
        if hasFiles {
            segments.append(.files)
        }
        if hasMusic {
            segments.append(.music)
        }
        if hasVoice {
            segments.append(.voice)
        }
        return segments
    }
    struct SelectedData {
        var text: String
        var enabled: Bool
        var size: Int64
    }
    var selectedData: SelectedData {
        var data = SelectedData(text: "", enabled: false, size: 0)
        
        if let stats = allStats {
            var size: Int64 = 0

            var ignoreMsgs: Set<MessageId> = Set()
            for id in selectedPeers.selected {
                if let peer = stats.peers[id] {
                    size += peer.stats.totalCount
                    
                    let intersection = peer.stats.msgIds.subtracting(selectedMessages)
                    for msgId in intersection {
                        if let sz = peer.stats.msgSizes[msgId] {
                            size -= sz
                        }
                    }
                    
                    ignoreMsgs = ignoreMsgs.union(peer.stats.msgIds)
                }
            }
            for selected in selectedMessages {
                if let sz = msgSizes[selected], !ignoreMsgs.contains(selected) {
                    size += sz
                }
            }
            
            if size > 0 {
                data.text = strings().storageUsageSelectedClearPart(String.prettySized(with: size, round: true))
                data.enabled = true
            } else {
                data.text = strings().storageUsageSelectedClearDisabled
                data.enabled = false
            }
            data.size = size
        }
        return data
    }
    var hasOther: Bool {
        if let stats = stats {
            let suffix = stats.categories.suffix(min(4, stats.categories.count))
            return (stats.categories.count - suffix.count) > 1
        }
        return false
    }
    func isOther(_ category: StorageUsageCategory) -> Bool {
        if let stats = stats, hasOther {
            let sorted = stats.categories.sorted(by: { lhs, rhs in
                return lhs.value.size < rhs.value.size
            })
            for (i, sort) in sorted.enumerated() {
                if sort.key.mapped == category {
                    if i < 3 {
                        return true
                    }
                }
            }
        }
        
        return false


        /*
         var isOther: Bool {
             switch self {
             case .stickers, .avatars, .misc:
                 return true
             default:
                 return false
             }
         }
         */
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
private func storageUsageControllerEntries(state: StorageUsageUIState, arguments: StorageUsageArguments) -> [InputDataEntry] {
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
        
        chartOrder = chartOrder.sorted(by: { lhs, rhs in
            let lhsSize = stats.categories[lhs.native]?.size ?? 0
            let rhsSize = stats.categories[rhs.native]?.size ?? 0
            return lhsSize > rhsSize
        })
        
        let otherIndex = chartOrder.firstIndex(where: { state.isOther($0) })
        
        var pieOrder = chartOrder
        
        let otherSize: Int64 = stats.categories.reduce(0, { current, value in
            if state.isOther(value.key.mapped) {
                return current + value.value.size
            } else {
                return current
            }
        })
        
        if let index = otherIndex, otherSize > 0 {
            pieOrder.insert(.other, at: index)
            if !state.otherRevealed {
                chartOrder.removeAll(where: { state.isOther($0) })
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
            } else if !state.otherRevealed, state.isOther(key) {
                size = 0
            } else if state.otherRevealed, key == .other {
                size = 0
            }
            
            items.append(.init(id: key.rawValue, index: Int(key.rawValue), count: Int(size), color: key.color, badge: nil))
            i += 1
        }
        
        
        
        usedBytesCount = items.map { $0.count }.reduce(0, +)

        
        if usedBytesCount != 0 {
            pieChart.dynamicString = String.prettySized(with: items.reduce(0, { $0 + $1.count}), round: true)
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
                _ = badge.append(string: String.prettySized(with: count, round: true), color: items[i].color, font: .bold(.text))
                
                items[i].badge = badge
            }
            items[i].count = counts[i]
        }
        
        pieChart.items = items
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pie_chart, equatable: InputDataEquatable(pieChart), comparable: nil, item: { initialSize, stableId in
            return StoragePieChartItem(initialSize, stableId: stableId, context: arguments.context, items: pieChart.items, dynamicText: pieChart.dynamicString, peer: state.peer, viewType: pieChart.viewType, toggleSelected: { item in
                if let id = item.id.base as? Int32 {
                    if let category = StorageUsageCategory(rawValue: id) {
                        arguments.selectCategory(category)
                    }
                }
            })
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
            !state.unselected.contains($0.key.mapped)
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
                    if state.isOther(value.key.mapped) {
                        return current + value.value.size
                    } else {
                        return current
                    }
                })
                categoryData = .init(size: total, messages: [:])
                itemCategory = .basic(hasSub: otherIndex != nil, revealed: state.otherRevealed)
            default:
                if state.isOther(key) {
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
                    
                    
                    let subAttr: NSAttributedString = .initialize(string: String.prettySized(with: item.categoryData.size, round: true), color: theme.colors.grayText, font: .normal(.title))
                    
                    let canToggle: Bool = true
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
                !state.unselected.contains($0.key.mapped)
            }.map {
                $0.value.size
            }.reduce(0, +)
            
            if clearSize > 0 {
                if state.unselected.isEmpty {
                    text = strings().storageUsageClearFull(String.prettySized(with: clearSize, round: true))
                } else {
                    text = strings().storageUsageClearPart(String.prettySized(with: clearSize, round: true))
                }
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
                    icon = generateSettingsIcon(NSImage(named: "Icon_Colored_Group")!.precomposed(flipVertical: true))
                case .channels:
                    icon = generateSettingsIcon(NSImage(named: "Icon_Colored_Channel")!.precomposed(flipVertical: true))
                case .privateChats:
                    icon = generateSettingsIcon(NSImage(named: "Icon_Colored_Private")!.precomposed(flipVertical: true))
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

    }
    
    if !state.segments.isEmpty {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_segments, equatable: nil, comparable: nil, item: { initialSize, stableId in
            if let controller = arguments.segmentController() {
                return StorageUsageBlockItem(initialSize, stableId: stableId, controller: controller, isVisible: true, viewType: .singleItem)
            } else {
                return GeneralRowItem(initialSize, stableId: stableId)
            }
        }))
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if !state.peers.isEmpty, let stats = state.stats, stats.totalCount > 0 && !state.cleared, state.segments.isEmpty, state.peerId == nil {
        let sorted = state.peers.map { $0.value }.sorted(by: { $0.stats.totalCount > $1.stats.totalCount })
        
        struct TuplePeer : Equatable {
            let peer: PeerEquatable
            let count: String
            let viewType: GeneralViewType
        }
        var items:[TuplePeer] = []
        
        for (i, sort) in sorted.enumerated() {
            items.append(.init(peer: .init(sort.peer._asPeer()), count: String.prettySized(with: sort.stats.totalCount, round: true), viewType: bestGeneralViewType(sorted, for: i)))
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
    
    return entries
}


final class StorageUsageView : View {
    
    private class SelectPanel: Control {
        let button = TitleButton()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            border = [.Top]
            addSubview(button)
            button.layer?.cornerRadius = 10
            button.autohighlight = false
            button.scaleOnClick = true
            updateLocalizationAndTheme(theme: theme)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
            backgroundColor = theme.colors.background
            button.set(background: theme.colors.accent, for: .Normal)
            button.set(font: .medium(.title), for: .Normal)
            button.set(color: theme.colors.underSelectedColor, for: .Normal)
        }
        
        func updateText(_ text: String, enabled: Bool) {
            button.set(text: text, for: .Normal)
            button.isEnabled = enabled
            button.sizeToFit(.zero, NSMakeSize(frame.width - 40, 40), thatFit: true)
        }
        
        override func layout() {
            super.layout()
            button.frame = NSMakeRect(20, 10, frame.width - 40, 40)
        }
    }
    
    fileprivate let tableView: TableView
    private var selectPanel: SelectPanel?
    required init(frame frameRect: NSRect) {
        self.tableView = .init(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            .clear
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.listBackground
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: tableView, frame: bounds)
        if let selectPanel = selectPanel {
            transition.updateFrame(view: selectPanel, frame: NSMakeRect(0, size.height - selectPanel.frame.height, size.width, selectPanel.frame.height))
        }
    }
    
    fileprivate func update(_ state: StorageUsageUIState, arguments: StorageUsageArguments, animated: Bool) {
        
        
        if state.editing, !state.selectedPeers.selected.isEmpty || !state.selectedMessages.isEmpty {
            let current: SelectPanel
            if let view = self.selectPanel {
                current = view
            } else {
                current = SelectPanel(frame: NSMakeRect(0, frame.height, frame.width, 60))
                self.selectPanel = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.button.set(handler: { _ in
                    arguments.clearSelected()
                }, for: .Click)
            }
            let data = state.selectedData
            current.updateText(data.text, enabled: data.enabled)
        } else if let view = self.selectPanel {
            performSubviewPosRemoval(view, pos: NSMakePoint(0, frame.height), animated: animated)
            self.selectPanel = nil
        }
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        updateLayout(size: frame.size, transition: transition)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class StorageUsageController: TelegramGenericViewController<StorageUsageView> {

    private let peerId: PeerId?
    private var segments: StorageUsageBlockController?
    private let updateMainState:(((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState)?
    init(_ context: AccountContext, peerId: PeerId? = nil, updateMainState:(((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState)? = nil) {
        self.updateMainState = updateMainState
        self.peerId = peerId
        super.init(context)
    }
    
    private var doneButton:TitleButton? = nil
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        doneButton?.set(color: theme.colors.accent, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self)
       
//
        let doneButton = TitleButton()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: strings().navigationEdit, for: .Normal)
        
        _ = doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton

        doneButton.set(handler: { [weak self] _ in
            self?.toggleEditing?()
        }, for: .Click)
                       
        return back
    }
    
    override var enableBack: Bool {
        return true
    }
    
    private func updateState() {
        doneButton?.set(font: .medium(.text), for: .Normal)
        doneButton?.set(text: isSelecting ? strings().navigationDone : strings().navigationEdit, for: .Normal)
        doneButton?.sizeToFit()
        doneButton?.isHidden = !canEdit
    }
    var canEdit: Bool {
        if let state = getState?() {
            if state.peerId != nil {
                return !state.messages.isEmpty
            } else {
                return !state.messages.isEmpty && !state.peers.isEmpty
            }
        } else {
            return false
        }
    }
    var isSelecting: Bool {
        if let state = getState?() {
            return state.editing
        } else {
            return false
        }
    }
    
    private var getState:(()->StorageUsageUIState)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let initialSize = self.atomicSize
        let actionDisposables = DisposableSet()
        
        let clearDisposable = MetaDisposable()
        actionDisposables.add(clearDisposable)
        
        
        let initialState = StorageUsageUIState(cacheSettings: .defaultSettings, accountSpecificCacheSettings: [], appearance: appAppearance, otherRevealed: false, unselected: Set(), peerId: self.peerId)
        
        let statePromise = ValuePromise<StorageUsageUIState>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((StorageUsageUIState) -> StorageUsageUIState) -> StorageUsageUIState = { f in
            let updated = stateValue.modify (f)
            statePromise.set(updated)
            return updated
        }
        
        self.getState = {
            return stateValue.with { $0 }
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
        
        let scrollup:()->Void = { [weak self] in
            self?.genericView.tableView.scroll(to: .up(true))
        }
        
                
        let statsPromise = Promise<AllStorageUsageStats?>()
        statsPromise.set(context.engine.resources.collectStorageUsageStats() |> map(Optional.init))
        
        let updateMainState = self.updateMainState
        
        let updateStats:()->Void = {
            DispatchQueue.main.async {
                let peerId = stateValue.with { $0.peerId }
                let cleared = stateValue.with { $0.cleared }
                
                if let updateMainState = updateMainState {
                    _ = updateMainState { current in
                        var current = current
                        if let peerId = peerId, cleared {
                            current.ignorePeerIds.insert(peerId)
                        }
                        return current
                    }
                }
                
                statsPromise.set(context.engine.resources.collectStorageUsageStats() |> map(Optional.init))
                let shouldBack = cleared && peerId != nil
                if shouldBack {
                    context.bindings.rootNavigation().back()
                } else if stateValue.with({ $0.cleared }) {
                    scrollup()
                }
            }
        }
        
        let arguments = StorageUsageArguments(context: context, updateKeepMedia: { category, timeout in
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
            self?.navigationController?.push(StorageUsageController(context, peerId: peerId, updateMainState: updateState))
        }, clearAll: {
            
            let categories: [StorageUsageStats.CategoryKey] = stateValue.with { value in
                if let stats = value.stats {
                    return stats.categories.map { $0.key }.filter {
                        !value.unselected.contains($0.mapped)
                    }
                }
                return []
            }
            
            let cleared = stateValue.with({ $0.unselected.filter({ $0 != .other }).isEmpty })
            
            let clearSize = stateValue.with { state in
                return state.stats?.categories.filter {
                    !state.unselected.contains($0.key.mapped)
                }.map {
                    $0.value.size
                }.reduce(0, +) ?? 0
            }
            
            
            
            confirm(for: context.window, information: strings().storageUsageClearConfirmInfo, okTitle: cleared ? strings().storageUsageClearConfirmOKAll : strings().storageUsageClearConfirmOKPart, successHandler: { _ in
                _ = context.engine.resources.clearStorage(peerId: stateValue.with { $0.peerId }, categories: categories, includeMessages: [], excludeMessages: []).start(completed: updateStats)
                
                _ = updateState { current in
                    var current = current
                    current.cleared = cleared
                    current.editing = false
                    current.selectedPeers = .init()
                    current.selectedMessages = Set()
                    current.unselected = Set()
                    return current
                }
                
                if clearSize > 0 {
                    showModalText(for: context.window, text: strings().storageUsageClearedText(String.prettySized(with: clearSize, round: true)))
                }
            })
        }, exceptions: { category in
            context.bindings.rootNavigation().push(DataStorageExceptions(context: context, category: category))
        }, toggleOther: {
            _ = updateState { current in
                var current = current
                current.otherRevealed = !current.otherRevealed
                return current
            }
        }, toggleCategory: { category in
            _ = updateState { current in
                var current = current
                
                if current.unselected.contains(category) {
                    current.unselected.remove(category)
                } else {
                    current.unselected.insert(category)
                }
                
                switch category {
                case .other:
                    let all = Set(current.stats?.categories.map {
                        $0.key.mapped
                    } ?? [])
                    if current.unselected.contains(.other) {
                        for cat in all {
                            if current.isOther(cat) {
                                current.unselected.insert(cat)
                            }
                        }
                    } else {
                        for cat in all {
                            if current.isOther(cat) {
                                current.unselected.remove(cat)
                            }
                        }
                    }
                default:
                    if current.isOther(category) {
                        if current.unselected.contains(category) {
                            current.unselected.insert(.other)
                        } else {
                            let contains = current.unselected.contains(where: { current.isOther($0) })
                            if !contains {
                                current.unselected.remove(.other)
                            }
                        }
                    }
                }
                
                return current
            }
        }, segmentController: { [weak self] in
            return self?.segments
        }, clearSelected: {
            
            let messages: [Message] = stateValue.with { state in
                var messages:[Message] = []
                for data in state.selectedMessages {
                    if let message = state.messages[data] {
                        messages.append(message)
                    }
                }
                return messages
            }
            let peerIds: Set<PeerId> = stateValue.with { state in
                return state.selectedPeers.selected
            }
                         
//            let _ = stateValue.with { state in
//                var all_p: Bool = true
//                var all_m: Bool = true
//                if let stats = state.allStats {
//                    if state.peerId == nil {
//                        for (peerId, _) in stats.peers {
//                            if !state.selectedPeers.selected.contains(peerId) {
//                                all_p = false
//                                break
//                            }
//                        }
//                    }
//                    for (key, _) in state.messages {
//                        if !state.selectedMessages.contains(key) {
//                            all_m = false
//                            break
//                        }
//                    }
//                }
//                return all_p && all_m
//            }
            
            let clearSize = stateValue.with { $0.selectedData.size }
            
            confirm(for: context.window, information: strings().storageUsageClearConfirmInfo, okTitle: strings().storageUsageClearConfirmOKPart, successHandler: { _ in
                                
                let includeMessages = messages
                var excludeMessages:[Message] = []
                
                let state = stateValue.with { $0 }
                for id in peerIds {
                    if let stats = state.allStats?.peers[id]?.stats {
                        let intersection = stats.msgIds.subtracting(state.selectedMessages)
                        for msgId in intersection {
                            if let message = state.messages[msgId] {
                                excludeMessages.append(message)
                            }
                        }
                    }
                }
                
                let signal = context.engine.resources.clearStorage(peerIds: peerIds, includeMessages: includeMessages, excludeMessages: excludeMessages)
                
                _ = signal.start(completed: updateStats)
                
                _ = updateState { current in
                    var current = current
                    current.editing = false
                    current.ignoreMsgIds = current.ignoreMsgIds.union(Set(messages.map { $0.id }))
                    current.ignorePeerIds = current.ignorePeerIds.union(peerIds)
                    current.selectedPeers = .init()
                    current.selectedMessages = Set()
                    return current
                }
                if clearSize > 0 {
                    showModalText(for: context.window, text: strings().storageUsageClearedText(String.prettySized(with: clearSize, round: true)))
                }
            })
            
        }, clearPeer: { peerId in
            confirm(for: context.window, information: strings().storageUsageClearConfirmInfo, okTitle: strings().storageUsageClearConfirmOKAll, successHandler: { _ in
                
               _ = context.engine.resources.clearStorage(peerIds: [peerId], includeMessages: [], excludeMessages: []).start(completed: updateStats)
                
                let clearSize = stateValue.with {
                    $0.allStats?.peers[peerId]?.stats.totalCount
                } ?? 0
                
                _ = updateState { current in
                    var current = current
                    current.ignorePeerIds.insert(peerId)
                    return current
                }
                if clearSize > 0 {
                    showModalText(for: context.window, text: strings().storageUsageClearedText(String.prettySized(with: clearSize, round: true)))
                }
            })

        }, clearMessage: { message in
            confirm(for: context.window, information: strings().storageUsageClearConfirmInfo, okTitle: strings().storageUsageClearConfirmOKPart, successHandler: { _ in
                
                let msgs = context.engine.resources.clearStorage(messages: [message])
                
                _ = msgs.start(completed: updateStats)
                
                let clearSize = stateValue.with {
                    return $0.allStats?.peers[message.id.peerId]?.stats.msgSizes[message.id] ?? 0
                }
                
                _ = updateState { current in
                    var current = current
                    current.ignoreMsgIds.insert(message.id)
                    current.selectedPeers = .init()
                    return current
                }
                if clearSize > 0 {
                    showModalText(for: context.window, text: strings().storageUsageClearedText(String.prettySized(with: clearSize, round: true)))
                }
            })

        }, selectCategory: { category in
            _ = updateState { current in
                var current = current
                var all = Set(current.stats?.categories.map {
                    $0.key.mapped
                } ?? [])
                
                if current.hasOther {
                    all.insert(.other)
                }
                var others:Set<StorageUsageCategory> = all.filter {
                    current.isOther($0)
                }
                let subtracting = category == .other ? others.union([category]) : [category]
                
                if current.unselected == all.subtracting(subtracting) {
                    all = Set()
                } else if !current.unselected.contains(category) {
                    all.remove(category)
                    if category == .other {
                        for cat in others {
                            all.remove(cat)
                        }
                    }
                }
                current.unselected = all
                
                return current
            }
        })
        
        let segments = StorageUsageBlockController(context: context, storageArguments: arguments, state: statePromise.get(), updateState: updateState)
        self.segments = segments

        
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
        
        
        let signal = combineLatest(queue: prepareQueue, cacheSettingsPromise.get(), accountSpecificCacheSettingsAndPeers, statsPromise.get(), appearanceSignal)
        
        self.onDeinit = {
            actionDisposables.dispose()
        }
        
        actionDisposables.add(signal.start(next: { cacheSettings, accountSpecificCacheSettings, allStats, appearance in
            _ = updateState { current in
                var current = current
                current.cacheSettings = cacheSettings
                current.accountSpecificCacheSettings = accountSpecificCacheSettings
                current.allStats = allStats
                if let allStats = allStats {
                    if let peerId = current.peerId {
                        current.stats = current.peers[peerId]?.stats
                    } else {
                        current.stats = allStats.totalStats
                    }
                    current.msgSizes = current.stats?.msgSizes ?? [:]
                }
                
                current.appearance = appearance
                current.systemSize = freeSystemGigabytes()
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
        
        let first = Atomic(value: true)
        actionDisposables.add(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
            self?.updateState()
            self?.genericView.update(stateValue.with { $0 }, arguments: arguments, animated: transition.animated && !first.swap(false))
        }))
        
        let messages: Signal<[EngineMessage.Id: Message], NoError> = statePromise.get() |> mapToSignal { state in
            if let stats = state.stats {
                let selected = stats.categories.map { $0.key }
                
                return context.engine.resources.renderStorageUsageStatsMessages(stats: stats, categories: selected, existingMessages: state.messages)
            } else {
                return .single([:])
            }
        }
        
        actionDisposables.add(messages.start(next: { messages in
            _ = updateState { current in
                var current = current
                current.messages = messages
                return current
            }
        }))
        
        self.toggleEditing = { [weak self] in
            if self?.canEdit == true {
                _ = updateState { current in
                    var current = current
                    current.editing = !current.editing
                    if !current.editing {
                        current.selectedMessages = Set()
                        current.selectedPeers = SelectPeerPresentation()
                    }
                    return current
                }
            }
        }
    }
    

    private var toggleEditing:(()->Void)?
    override func returnKeyAction() -> KeyHandlerResult {
        self.toggleEditing?()
        return super.returnKeyAction()
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if isSelecting {
            self.toggleEditing?()
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        super.updateFrame(frame, transition: transition)
        genericView.updateLayout(size: frame.size, transition: transition)
    }
    
}

