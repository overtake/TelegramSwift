//
//  StorageUsageController.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class StorageUsageControllerArguments {
    let account: Account
    let updateKeepMedia: () -> Void
    let openPeerMedia: (PeerId) -> Void
    let clearAll:()->Void
    init(account: Account, updateKeepMedia: @escaping () -> Void, openPeerMedia: @escaping (PeerId) -> Void, clearAll: @escaping () -> Void) {
        self.account = account
        self.updateKeepMedia = updateKeepMedia
        self.openPeerMedia = openPeerMedia
        self.clearAll = clearAll
    }
}

private enum StorageUsageSection: Int32 {
    case keepMedia
    case peers
}

private enum StorageUsageEntry: TableItemListNodeEntry {
    case keepMedia(Int32, String, String)
    case keepMediaInfo(Int32, String)
    case clearAll(Int32, Bool)
    case collecting(Int32, String)
    case peersHeader(Int32, String)
    case peer(Int32, Int32, Peer, String)
    case section(Int32)

    var stableId: Int32 {
        switch self {
        case .keepMedia:
            return 0
        case .keepMediaInfo:
            return 1
        case .clearAll:
            return 2
        case .collecting:
            return 3
        case .peersHeader:
            return 4
        case let .peer(_, _, peer, _):
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
        case .clearAll:
            return 2
        case .collecting:
            return 3
        case .peersHeader:
            return 4
        case let .peer(_, index, _, _):
            return 5 + index
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .keepMedia(let sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case .keepMediaInfo(let sectionId, _):
            return (sectionId * 1000) + stableIndex
        case .clearAll(let sectionId, _):
            return (sectionId * 1000) + stableIndex
        case .collecting(let sectionId, _):
            return (sectionId * 1000) + stableIndex
        case .peersHeader(let sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .peer(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func ==(lhs: StorageUsageEntry, rhs: StorageUsageEntry) -> Bool {
        switch lhs {
        case let .keepMedia(sectionId, text, value):
            if case .keepMedia(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .keepMediaInfo(sectionId, text):
            if case .keepMediaInfo(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .clearAll(sectionId, enabled):
            if case .clearAll(sectionId, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .collecting(sectionId, text):
            if case .collecting(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .peersHeader(sectionId, text):
            if case .peersHeader(sectionId, text) = rhs {
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
        case let .peer(lhsSectionId, lhsIndex, lhsPeer, lhsValue):
            if case let .peer(rhsSectionId, rhsIndex, rhsPeer, rhsValue) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !arePeersEqual(lhsPeer, rhsPeer) {
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
        case let .keepMedia(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .context(value), action: {
                arguments.updateKeepMedia()
            })

        case let .keepMediaInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .collecting(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, alignment: .center, additionLoading: true)
        case .clearAll(_, let enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.storageClearAll), type: .next, action: {
                confirm(for: mainWindow, information: tr(L10n.storageClearAllConfirmDescription), successHandler: { _ in
                    arguments.clearAll()
                })
            }, enabled: enabled)
        case let .peersHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .peer(_, _, peer, value):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: true, height: 40, photoSize: NSMakeSize(30, 30), drawCustomSeparator: true, isLookSavedMessage: true, drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), generalType: .context(value), action: { 
                arguments.openPeerMedia(peer.id)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
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
    
    entries.append(.keepMedia(sectionId, tr(L10n.storageUsageKeepMedia), stringForKeepMediaTimeout(cacheSettings.defaultCacheStorageTimeout)))
    entries.append(.keepMediaInfo(sectionId, tr(L10n.storageUsageKeepMediaDescription)))
    
    var addedHeader = false
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var exists:[PeerId:PeerId] = [:]
    if let cacheStats = cacheStats, case let .result(stats) = cacheStats {
        
        entries.append(.clearAll(sectionId, !stats.peers.isEmpty))

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
        for (peerId, size) in statsByPeerId.sorted(by: { $0.1 > $1.1 }) {
            if size >= 32 * 1024 {
                if let peer = stats.peers[peerId], !peer.isSecretChat {
                    if !addedHeader {
                        addedHeader = true
                        entries.append(.peersHeader(sectionId, tr(L10n.storageUsageChatsHeader)))
                    }
                    entries.append(.peer(sectionId, index, peer, dataSizeString(Int(size))))
                    index += 1
                }
            }
        }
    } else {
        entries.append(.collecting(sectionId, tr(L10n.storageUsageCalculating)))
    }
    
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
        
        
        let account = self.account
        let initialSize = self.atomicSize
        let cacheSettingsPromise = Promise<CacheStorageSettings>()
        cacheSettingsPromise.set(account.postbox.preferencesView(keys: [PreferencesKeys.cacheStorageSettings])
            |> map { view -> CacheStorageSettings in
                let cacheSettings: CacheStorageSettings
                if let value = view.values[PreferencesKeys.cacheStorageSettings] as? CacheStorageSettings {
                    cacheSettings = value
                } else {
                    cacheSettings = CacheStorageSettings.defaultSettings
                }
                
                return cacheSettings
            })
        
        let statsPromise = Promise<CacheUsageStatsResult?>()
        statsPromise.set(.single(nil) |> then(collectCacheUsageStats(account: account) |> map { Optional($0) }))
        
        let actionDisposables = DisposableSet()
        
        let clearDisposable = MetaDisposable()
        actionDisposables.add(clearDisposable)
        
        let arguments = StorageUsageControllerArguments(account: account, updateKeepMedia: { [weak self] in
            if let strongSelf = self {
                let timeoutAction: (Int32) -> Void = { timeout in
                    let _ = updateCacheStorageSettingsInteractively(postbox: account.postbox, { current in
                        return current.withUpdatedDefaultCacheStorageTimeout(timeout)
                    }).start()
                }
                
                if let item = strongSelf.genericView.item(stableId: StorageUsageEntry.keepMedia(0, "", "").stableId), let view = (strongSelf.genericView.viewNecessary(at: item.index) as? GeneralInteractedRowView)?.textView {
                    
                    showPopover(for: view, with: SPopoverViewController(items: [SPopoverItem(tr(L10n.timerWeeksCountable(1)), {
                        timeoutAction(7 * 24 * 60 * 60)
                    }), SPopoverItem(tr(L10n.timerMonthsCountable(1)), {
                        timeoutAction(1 * 31 * 24 * 60 * 60)
                    }), SPopoverItem(tr(L10n.timerForever), {
                        timeoutAction(Int32.max)
                    })]), edge: .minX, inset: NSMakePoint(0,-30))
                }
            }
           
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
                                statsPromise.set(.single(.result(CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers, otherSize: stats.otherSize, otherPaths: stats.otherPaths, cacheSize: stats.cacheSize, tempPaths: stats.tempPaths, tempSize: stats.tempSize))))
                                
                                clearDisposable.set(clearCachedMediaResources(account: account, mediaResourceIds: clearResourceIds).start())
                            }

                        }), for: mainWindow)
                    }
                }
            })
        }, clearAll: {
            let path = account.postbox.mediaBox.basePath
            _ = showModalProgress(signal: combineLatest(clearCache(path), clearImageCache(), account.postbox.mediaBox.clearFileContexts()), for: mainWindow).start()
            statsPromise.set(.single(CacheUsageStatsResult.result(.init(media: [:], mediaResourceIds: [:], peers: [:], otherSize: 0, otherPaths: [], cacheSize: 0, tempPaths: [], tempSize: 0))))
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
