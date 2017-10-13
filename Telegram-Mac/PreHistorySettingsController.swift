//
//  PreHistorySettingsController.swift
//  Telegram
//
//  Created by keepcoder on 10/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

fileprivate func prepareEntries(left:[AppearanceWrapperEntry<PreHistoryEntry>], right: [AppearanceWrapperEntry<PreHistoryEntry>], initialSize:NSSize, arguments:PreHistoryArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

fileprivate func preHistoryEntries(cachedData: CachedChannelData?, state: PreHistoryControllerState) -> [PreHistoryEntry] {
    
    var entries:[PreHistoryEntry] = []
    
    var index:Int32 = 0
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.text(sectionId: sectionId, index: index, text: tr(.preHistorySettingsHeader)))
    index += 1
    
    let enabled =  state.enabled ?? cachedData?.flags.contains(.preHistoryEnabled) ?? false
    
    entries.append(.type(sectionId: sectionId, index: index, text: tr(.peerInfoPreHistoryVisible), enabled: true, selected: enabled))
    index += 1
    entries.append(.type(sectionId: sectionId, index: index, text: tr(.peerInfoPreHistoryHidden), enabled: false, selected: !enabled))
    index += 1
    
    entries.append(.text(sectionId: sectionId, index: index, text: enabled ? tr(.preHistorySettingsDescriptionVisible) : tr(.preHistorySettingsDescriptionHidden)))
    index += 1
    
    return entries
}

class PreHistorySettingsController: EmptyComposeController<Void, Bool, TableView> {
    private let peerId: PeerId
    private let statePromise = ValuePromise(PreHistoryControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: PreHistoryControllerState())
    private let disposable = MetaDisposable()
    init(_ account: Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previous:Atomic<[AppearanceWrapperEntry<PreHistoryEntry>]> = Atomic(value: [])
        
        let updateState: ((PreHistoryControllerState) -> PreHistoryControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        let initialSize = self.atomicSize
        
        let arguments = PreHistoryArguments(account: account, preHistory: { enabled in
            updateState({$0.withUpdatedEnabled(enabled)})
        })
        
        let key = PostboxViewKey.cachedPeerData(peerId: peerId)
        
        let signal: Signal<(TableUpdateTransition, PreHistoryControllerState), Void> = combineLatest(account.postbox.combinedView(keys: [key]) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, statePromise.get() |> deliverOnPrepareQueue) |> map { view, appearance, state in
            
            let cachedData = view.views[key] as? CachedPeerDataView
            let entries = preHistoryEntries(cachedData: cachedData?.cachedPeerData as? CachedChannelData, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            
            return (prepareEntries(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), state)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition, state in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
    
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onComplete.set(statePromise.get() |> filter {$0.enabled != nil} |> map {$0.enabled!})
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
    }
}
