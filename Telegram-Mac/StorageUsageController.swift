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
import SyncCore
import SwiftSignalKit

private final class StorageUsageControllerArguments {
    let context: AccountContext
    let updateKeepMedia: () -> Void
    let updateMediaLimit: (Int32) -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearAll:()->Void
    init(context: AccountContext, updateKeepMedia: @escaping () -> Void, updateMediaLimit: @escaping(Int32)->Void, openPeerMedia: @escaping (PeerId) -> Void, clearAll: @escaping () -> Void) {
        self.context = context
        self.updateKeepMedia = updateKeepMedia
        self.openPeerMedia = openPeerMedia
        self.clearAll = clearAll
        self.updateMediaLimit = updateMediaLimit
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case peers
}

private enum StorageUsageEntry: TableItemListNodeEntry {
    case keepMedia(Int32, String, String, GeneralViewType)
    case keepMediaInfo(Int32, String, GeneralViewType)
    case keepMediaLimitHeader(Int32, String, GeneralViewType)
    case keepMediaLimit(Int32, Int32, GeneralViewType)
    case keepMediaLimitInfo(Int32, String, GeneralViewType)
    case clearAll(Int32, Bool, GeneralViewType)
    case collecting(Int32, String, GeneralViewType)
    case peersHeader(Int32, String, GeneralViewType)
    case peer(Int32, Int32, Peer, String, GeneralViewType)
    case section(Int32)

    var stableId: Int32 {
        switch self {
        case .keepMedia:
            return 0
        case .keepMediaInfo:
            return 1
        case .keepMediaLimitHeader:
            return 2
        case .keepMediaLimit:
            return 3
        case .keepMediaLimitInfo:
            return 4
        case .clearAll:
            return 5
        case .collecting:
            return 6
        case .peersHeader:
            return 7
        case let .peer(_, _, peer, _, _):
            return Int32(peer.id.hashValue)
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var stableIndex: Int32 {
        switch self {
        case .keepMedia:
            return 0
        case .keepMediaInfo:
            return 1
        case .keepMediaLimitHeader:
            return 2
        case .keepMediaLimit:
            return 3
        case .keepMediaLimitInfo:
            return 4
        case .clearAll:
            return 5
        case .collecting:
            return 6
        case .peersHeader:
            return 7
        case let .peer(_, index, _, _, _):
            return 8 + index
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .keepMedia(let sectionId, _, _, _):
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
        case let .keepMedia(sectionId, text, value, viewType):
            if case .keepMedia(sectionId, text, value, viewType) = rhs {
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
    
    func item(_ arguments: StorageUsageControllerArguments, initialSize: NSSize) -> TableRowItem {
        
        switch self {
        case let .keepMedia(_, text, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .context(value), viewType: viewType, action: {
                arguments.updateKeepMedia()
            })
        case let .keepMediaInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .keepMediaLimitHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .keepMediaLimit(_, value, viewType):
            let values = [5, 16, 36, Int32.max]
            var value = value
            if !values.contains(value) {
                value = Int32.max
            }
            return SelectSizeRowItem(initialSize, stableId: stableId, current: value, sizes: values, hasMarkers: false, titles: ["5GB", "16GB", "32GB", L10n.storageUsageLimitNoLimit], viewType: viewType, selectAction: { selected in
                arguments.updateMediaLimit(values[selected])
            })
        case let .keepMediaLimitInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .collecting(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, alignment: .center, additionLoading: true, viewType: viewType)
        case let .clearAll(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.storageClearAll), type: .next, viewType: viewType, action: {
                arguments.clearAll()
            }, enabled: enabled)
        case let .peersHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .peer(_, _, peer, value, viewType):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), isLookSavedMessage: true, inset: NSEdgeInsets(left: 30, right: 30), generalType: .context(value), viewType: viewType, action: {
                arguments.openPeerMedia(peer.id)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
    }
}

private func stringForKeepMediaTimeout(_ timeout: Int32) -> String {
    if timeout <= 7 * 24 * 60 * 60 {
        return tr(L10n.timerWeeksCountable(1))
    } else if timeout <= 1 * 31 * 24 * 60 * 60 {
        return tr(L10n.timerMonthsCountable(1))
    } else {
        return tr(L10n.timerForever)
    }
}

private func storageUsageControllerEntries(cacheSettings: CacheStorageSettings, cacheStats: CacheUsageStatsResult?) -> [StorageUsageEntry] {
    var entries: [StorageUsageEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.keepMedia(sectionId, L10n.storageUsageKeepMedia, stringForKeepMediaTimeout(cacheSettings.defaultCacheStorageTimeout), .singleItem))
    
    entries.append(.keepMediaInfo(sectionId, L10n.storageUsageKeepMediaDescription1, .textBottomItem))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    //
    entries.append(.keepMediaLimitHeader(sectionId, L10n.storageUsageLimitHeader, .textTopItem))
    entries.append(.keepMediaLimit(sectionId, cacheSettings.defaultCacheStorageLimitGigabytes, .singleItem))
    entries.append(.keepMediaLimitInfo(sectionId, L10n.storageUsageLimitDesc, .textBottomItem))

    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var exists:[PeerId:PeerId] = [:]
    if let cacheStats = cacheStats, case let .result(stats) = cacheStats {
        
        entries.append(.clearAll(sectionId, !stats.peers.isEmpty, .singleItem))

        entries.append(.section(sectionId))
        sectionId += 1
        
        var statsByPeerId: [(PeerId, Int64)] = []
        for (peerId, categories) in stats.media {
            if exists[peerId] == nil {
                var combinedSize: Int64 = 0
                for (_, media) in categories {
                    for (_, size) in media {
                        combinedSize += size
                    }
                }
                statsByPeerId.append((peerId, combinedSize))
                exists[peerId] = peerId
            }
            
        }
        var index: Int32 = 0
        
        let filtered = statsByPeerId.sorted(by: { $0.1 > $1.1 }).filter { peerId, size -> Bool in
            return size >= 32 * 1024 && stats.peers[peerId] != nil && !stats.peers[peerId]!.isSecretChat
        }
        
        if !filtered.isEmpty {
            entries.append(.peersHeader(sectionId, L10n.storageUsageChatsHeader, .textTopItem))
        }
        
        for (i, value) in filtered.enumerated() {
            let peer = stats.peers[value.0]!
            entries.append(.peer(sectionId, index, peer, dataSizeString(Int(value.1)), bestGeneralViewType(filtered, for: i)))
            index += 1
        }
    } else {
        
        entries.append(.clearAll(sectionId, true, .singleItem))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.collecting(sectionId, L10n.storageUsageCalculating, .singleItem))
    }
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries
}


private func prepareTransition(left:[AppearanceWrapperEntry<StorageUsageEntry>], right: [AppearanceWrapperEntry<StorageUsageEntry>], initialSize: NSSize, arguments: StorageUsageControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class StorageUsageController: TableViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyOnce()
        
        
        let context = self.context
        let initialSize = self.atomicSize
        let cacheSettingsPromise = Promise<CacheStorageSettings>()
        cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
            |> map { view -> CacheStorageSettings in
                return view.entries[SharedDataKeys.cacheStorageSettings] as? CacheStorageSettings ?? CacheStorageSettings.defaultSettings
            })
        
        let statsPromise = Promise<CacheUsageStatsResult?>()
        statsPromise.set(.single(nil) |> then(collectCacheUsageStats(account: context.account, additionalCachePaths: [], logFilesPath: "~/Library/Group Containers/\(ApiEnvironment.group)/logs".nsstring.expandingTildeInPath) |> map { Optional($0) }))
        
        let actionDisposables = DisposableSet()
        
        let clearDisposable = MetaDisposable()
        actionDisposables.add(clearDisposable)
        
        let arguments = StorageUsageControllerArguments(context: context, updateKeepMedia: { [weak self] in
            if let strongSelf = self {
                let timeoutAction: (Int32) -> Void = { timeout in
                    let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                        return current.withUpdatedDefaultCacheStorageTimeout(timeout)
                    }).start()
                }
                
                if let item = strongSelf.genericView.item(stableId: StorageUsageEntry.keepMedia(0, "", "", .singleItem).stableId), let view = (strongSelf.genericView.viewNecessary(at: item.index) as? GeneralInteractedRowView)?.textView {
                    
                    showPopover(for: view, with: SPopoverViewController(items: [SPopoverItem(tr(L10n.timerWeeksCountable(1)), {
                        timeoutAction(7 * 24 * 60 * 60)
                    }), SPopoverItem(tr(L10n.timerMonthsCountable(1)), {
                        timeoutAction(1 * 31 * 24 * 60 * 60)
                    }), SPopoverItem(tr(L10n.timerForever), {
                        timeoutAction(Int32.max)
                    })]), edge: .minX, inset: NSMakePoint(0,-30))
                }
            }
           
        }, updateMediaLimit: { limit in
            let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedDefaultCacheStorageLimitGigabytes(limit)
            }).start()
        }, openPeerMedia: { peerId in
            let _ = (statsPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak statsPromise] result in
                if let result = result, case let .result(stats) = result {
                    if let categories = stats.media[peerId] {
                        
                        showModal(with: ChatStorageManagmentModalController(categories, clear: { sizeIndex in
                            if let statsPromise = statsPromise {
                                let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                                
                                var clearMediaIds = Set<MediaId>()
                                
                                var media = stats.media
                                if var categories = media[peerId] {
                                    for category in clearCategories {
                                        if let contents = categories[category] {
                                            for (mediaId, _) in contents {
                                                clearMediaIds.insert(mediaId)
                                            }
                                        }
                                        categories.removeValue(forKey: category)
                                    }
                                    
                                    media[peerId] = categories
                                }
                                
                                var clearResourceIds = Set<WrappedMediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(WrappedMediaResourceId(resourceId))
                                        }
                                    }
                                }
                                statsPromise.set(.single(.result(CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: stats.otherSize, otherPaths: stats.otherPaths, cacheSize: stats.cacheSize, tempPaths: stats.tempPaths, tempSize: stats.tempSize, immutableSize: stats.immutableSize))))
                                
                                clearDisposable.set(clearCachedMediaResources(account: context.account, mediaResourceIds: clearResourceIds).start())
                            }

                        }), for: mainWindow)
                    }
                }
            })
        }, clearAll: {
            confirm(for: context.window, information: L10n.storageClearAllConfirmDescription, okTitle: L10n.storageClearAll, successHandler: { _ in
                let path = context.account.postbox.mediaBox.basePath
                _ = showModalProgress(signal: combineLatest(clearImageCache(), context.account.postbox.mediaBox.allFileContexts() |> mapToSignal { clearCache(path, excludes: $0) }), for: context.window).start()
                statsPromise.set(.single(CacheUsageStatsResult.result(.init(media: [:], mediaResourceIds: [:], peers: [:], otherSize: 0, otherPaths: [], cacheSize: 0, tempPaths: [], tempSize: 0, immutableSize: 0))))
            })
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<StorageUsageEntry>]> = Atomic(value: [])
        
        
        self.genericView.merge(with: combineLatest(cacheSettingsPromise.get() |> deliverOnPrepareQueue, statsPromise.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue)
           
        |> map { cacheSettings, cacheStats, appearance -> TableUpdateTransition in
                
            let entries = storageUsageControllerEntries(cacheSettings: cacheSettings, cacheStats: cacheStats).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
                
        } |> afterDisposed {
            actionDisposables.dispose()
        } |> deliverOnMainQueue)
        
    }
    override func getRightBarViewOnce() -> BarView {
        return BarView(40, controller: self)
    }
}
