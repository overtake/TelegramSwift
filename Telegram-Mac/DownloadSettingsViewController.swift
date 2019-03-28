//
//  DownloadSettingsViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit

private final class DownloadSettingsArguments {
    let context: AccountContext
    let toggleCategory:(AutomaticMediaDownloadCategoryPeers)->Void
    let togglePreloadLargeVideos:(Bool)->Void
    init(_ context: AccountContext, toggleCategory: @escaping(AutomaticMediaDownloadCategoryPeers)->Void, togglePreloadLargeVideos: @escaping(Bool)->Void) {
        self.context = context
        self.toggleCategory = toggleCategory
        self.togglePreloadLargeVideos = togglePreloadLargeVideos
    }
}

private enum DownloadSettingsEntry : TableItemListNodeEntry {
    case contacts(sectionId: Int32, enabled: Bool, category: AutomaticMediaDownloadCategoryPeers)
    case groupChats(sectionId: Int32, enabled: Bool, category: AutomaticMediaDownloadCategoryPeers)
    case channels(sectionId: Int32, enabled: Bool, category: AutomaticMediaDownloadCategoryPeers)
    case fileSizeLimitHeader(sectionId: Int32)
    case fileSizeLimitText(sectionId: Int32, limit: Int32)
    case fileSizeLimit(sectionId: Int32, limit: Int32, category: AutomaticMediaDownloadCategoryPeers)
    case preloadLargeVideos(sectionId: Int32, Bool, Bool)
    case preloadLargeVideosDesc(sectionId: Int32, String)
    case sectionId(Int32)
    
    var stableId: Int32 {
        switch self {
        case .contacts:
            return 0
        case .groupChats:
            return 1
        case .channels:
            return 2
        case .fileSizeLimitHeader:
            return 3
        case .fileSizeLimitText:
            return 4
        case .fileSizeLimit:
            return 5
        case .preloadLargeVideos:
            return 6
        case .preloadLargeVideosDesc:
            return 7
        case .sectionId(let id):
            return 1000 + id
        }
    }
    
    
    func item(_ arguments: DownloadSettingsArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .contacts(_, enabled, category):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageCategorySettingsPrivateChats, type: .switchable(enabled), action: {
                arguments.toggleCategory(category.withUpdatedPrivateChats(!enabled))
            })
        case let .groupChats(_, enabled, category):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageCategorySettingsGroupChats, type: .switchable(enabled), action: {
                arguments.toggleCategory(category.withUpdatedGroupChats(!enabled))
            })
        case let .channels(_, enabled, category):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageCategorySettingsChannels, type: .switchable(enabled), action: {
                arguments.toggleCategory(category.withUpdatedChannels(!enabled))
            })
        case .fileSizeLimitHeader:
            return GeneralTextRowItem(initialSize, text: L10n.dataAndStorageCateroryFileSizeLimitHeader, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .fileSizeLimitText(_, current):
            
            return GeneralTextRowItem(initialSize, stableId: stableId, text: NSAttributedString.initialize(string: current == INT32_MAX ? L10n.dataAndStorageCateroryFileSizeUnlimited : String.prettySized(with: Int(current)), color: theme.colors.text, font: .medium(.text)), alignment: .center, centerViewAlignment: true)
        case let .fileSizeLimit(_, limit, category):
            let list:[Int32] = [Int32(1 * 1024 * 1024), Int32(5 * 1024 * 1024), Int32(10 * 1024 * 1024), Int32(50 * 1024 * 1024), Int32(100 * 1024 * 1024), Int32(300 * 1024 * 1024), Int32(500 * 1024 * 1024), INT32_MAX]
            return SelectSizeRowItem(initialSize, stableId: stableId, current: limit, sizes: list, hasMarkers: false, selectAction: { select in
                arguments.toggleCategory(category.withUpdatedSizeLimit(list[select]))
            })
        case let .preloadLargeVideos(_, enabled, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageCategoryPreloadLargeVideos, type: .switchable(value), action: {
                arguments.togglePreloadLargeVideos(!value)
            }, enabled: enabled)
        case let .preloadLargeVideosDesc(_, limit):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.dataAndStorageCategoryPreloadLargeVideosDesc(limit))
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .contacts(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .groupChats(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .channels(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .fileSizeLimitHeader(sectionId):
            return (sectionId * 1000) + stableId
        case let .fileSizeLimitText(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .fileSizeLimit(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .preloadLargeVideos(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .preloadLargeVideosDesc(sectionId, _):
            return (sectionId * 1000) + stableId
        case .sectionId(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
}

private func <(lhs: DownloadSettingsEntry, rhs: DownloadSettingsEntry) -> Bool {
    return lhs.index < rhs.index
}


private func downloadSettingsEntries(state: AutomaticMediaDownloadCategoryPeers, isVideo: Bool, autoplayMedia: AutoplayMediaPreferences) -> [DownloadSettingsEntry] {
    var entries:[DownloadSettingsEntry] = []
    var sectionId:Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.contacts(sectionId: sectionId, enabled: state.privateChats, category: state))
    entries.append(.groupChats(sectionId: sectionId, enabled: state.groupChats, category: state))
    entries.append(.channels(sectionId: sectionId, enabled: state.channels, category: state))
    
    if let fileSizeLimit = state.fileSize {
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        entries.append(.fileSizeLimitHeader(sectionId: sectionId))
        entries.append(.sectionId(sectionId))
        sectionId += 1

        entries.append(.fileSizeLimitText(sectionId: sectionId, limit: fileSizeLimit))
        entries.append(.fileSizeLimit(sectionId: sectionId, limit: fileSizeLimit, category: state))
        
        
        if isVideo {
            let preloadEnabled = fileSizeLimit >= 5 * 1024 * 1024
            
            entries.append(.preloadLargeVideos(sectionId: sectionId, preloadEnabled, autoplayMedia.preloadVideos))
            entries.append(.preloadLargeVideosDesc(sectionId: sectionId, "\(fileSizeLimit / 1024 / 1024)"))
        }
       
    }
    
   
    
    return entries
    
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<DownloadSettingsEntry>], right: [AppearanceWrapperEntry<DownloadSettingsEntry>], initialSize:NSSize, arguments:DownloadSettingsArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class DownloadSettingsViewController: TableViewController {
    private let disposable = MetaDisposable()
    private let stateValue: ValuePromise<AutomaticMediaDownloadCategoryPeers>
    private let title: String
    private let isVideo: Bool
    private let updateCategory:(AutomaticMediaDownloadCategoryPeers)->Void
    init(_ context: AccountContext, _ state: AutomaticMediaDownloadCategoryPeers, _ title: String, updateCategory:@escaping(AutomaticMediaDownloadCategoryPeers) -> Void) {
        self.stateValue = ValuePromise(state, ignoreRepeated: true)
        self.title = title
        self.isVideo = L10n.dataAndStorageAutomaticDownloadVideo == title
        self.updateCategory = updateCategory
        super.init(context)
    }
    
    override var defaultBarTitle: String {
        return title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        let arguments = DownloadSettingsArguments(context, toggleCategory: { [weak self] category in
            self?.updateCategory(category)
            self?.stateValue.set(category)
        }, togglePreloadLargeVideos: { enabled in
            _ = updateAutoplayMediaSettingsInteractively(postbox: context.account.postbox, {
                $0.withUpdatedAutoplayPreloadVideos(enabled)
            }).start()
        })
        
        let initialSize = self.atomicSize
        let isVideo = self.isVideo
        
        let previous: Atomic<[AppearanceWrapperEntry<DownloadSettingsEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(stateValue.get(), appearanceSignal, autoplayMediaSettings(postbox: context.account.postbox)) |> map { state, appearance, autoplayMedia -> TableUpdateTransition in
            let entries = downloadSettingsEntries(state: state, isVideo: isVideo, autoplayMedia: autoplayMedia).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
}
