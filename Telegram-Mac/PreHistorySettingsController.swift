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



private final class PreHistoryArguments {
    fileprivate let account: Account
    fileprivate let preHistory:(Bool)->Void
    init(account:Account, preHistory:@escaping(Bool)->Void) {
        self.account = account
        self.preHistory = preHistory
    }
}

private enum PreHistoryEntryId : Hashable {
    case type(Int32)
    case text(Int32)
    case section(Int32)
    var hashValue: Int {
        switch self {
        case .type(let index):
            return Int(index)
        case .text(let index):
            return Int(index)
        case .section(let index):
            return Int(index)
        }
    }
}


private enum PreHistoryEntry : TableItemListNodeEntry {
    case section(Int32)
    case type(sectionId:Int32, index: Int32, text: String, enabled: Bool, selected: Bool)
    case text(sectionId:Int32, index: Int32, text: String)
    
    var stableId: PreHistoryEntryId {
        switch self {
        case .type(_, let index, _, _, _):
            return .type(index)
        case .text(_, let index, _):
            return .text(index)
        case .section(let index):
            return .section(index)
        }
    }
    
    var index:Int32 {
        switch self {
        case let .type(sectionId, index, _, _, _):
            return (sectionId * 1000) + index
        case let .text(sectionId, index, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func item(_ arguments: PreHistoryArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .type(_, _, text, enabled, selected):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .selectable(enabled), action: {
                arguments.preHistory(selected)
            })
        case let .text(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        }
    }
    
}

private func <(lhs: PreHistoryEntry, rhs: PreHistoryEntry) -> Bool {
    return lhs.index < rhs.index
}


private struct PreHistoryControllerState : Equatable {
    let enabled: Bool?
    var applyingSetting: Bool = false
    

    init(enabled:Bool? = nil, applyingSetting: Bool = false) {
        self.enabled = enabled
        self.applyingSetting = applyingSetting
    }
    func withUpdatedEnabled(_ enabled: Bool) -> PreHistoryControllerState {
        return PreHistoryControllerState(enabled: enabled, applyingSetting: self.applyingSetting)
    }
    func withUpdatedApplyingSetting(_ applyingSetting: Bool) -> PreHistoryControllerState {
        return PreHistoryControllerState(enabled: enabled, applyingSetting: self.applyingSetting)
    }
}



fileprivate func prepareEntries(left:[AppearanceWrapperEntry<PreHistoryEntry>], right: [AppearanceWrapperEntry<PreHistoryEntry>], initialSize:NSSize, arguments:PreHistoryArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

fileprivate func preHistoryEntries(cachedData: CachedChannelData?, isGrpup: Bool, state: PreHistoryControllerState) -> [PreHistoryEntry] {
    
    var entries:[PreHistoryEntry] = []
    
    var index:Int32 = 0
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.text(sectionId: sectionId, index: index, text: L10n.preHistorySettingsHeader))
    index += 1
    
    let enabled =  state.enabled ?? cachedData?.flags.contains(.preHistoryEnabled) ?? false
    
    entries.append(.type(sectionId: sectionId, index: index, text: L10n.peerInfoPreHistoryVisible, enabled: enabled, selected: true))
    index += 1
    entries.append(.type(sectionId: sectionId, index: index, text: L10n.peerInfoPreHistoryHidden, enabled: !enabled, selected: false))
    index += 1
    
    entries.append(.text(sectionId: sectionId, index: index, text: enabled ? L10n.preHistorySettingsDescriptionVisible : isGrpup ? L10n.preHistorySettingsDescriptionGroupHidden : L10n.preHistorySettingsDescriptionHidden))
    index += 1
    
    return entries
}

class PreHistorySettingsController: EmptyComposeController<Void, PeerId?, TableView> {
    private let peerId: PeerId
    private let statePromise = ValuePromise(PreHistoryControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: PreHistoryControllerState())
    private let disposable = MetaDisposable()
    private let applyDisposable = MetaDisposable()
    init(_ account: Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let peerId = self.peerId
        
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
        
        
        let signal: Signal<(TableUpdateTransition, PreHistoryControllerState, Bool), NoError> = combineLatest(account.postbox.combinedView(keys: [key]) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, statePromise.get() |> deliverOnPrepareQueue) |> map { view, appearance, state in
            
            let cachedData = view.views[key] as? CachedPeerDataView
            let entries = preHistoryEntries(cachedData: cachedData?.cachedPeerData as? CachedChannelData, isGrpup: peerId.namespace == Namespaces.Peer.CloudGroup, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            let defaultValue: Bool = (cachedData?.cachedPeerData as? CachedChannelData)?.flags.contains(.preHistoryEnabled) ?? false
            

            return (prepareEntries(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), state, defaultValue)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition, state, defaultValue in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            
            self?.doneButton?.removeAllHandlers()
            self?.doneButton?.set(handler: { _ in
                var value: Bool?
                updateState { state in
                    value = state.enabled
                    return state.withUpdatedApplyingSetting(true)
                }
                if let value = value, value != defaultValue {
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let signal = convertGroupToSupergroup(account: account, peerId: peerId)
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<PeerId?, NoError> in
                                return .single(nil)
                            }
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .single(nil)
                                }
                                return updateChannelHistoryAvailabilitySettingsInteractively(postbox: account.postbox, network: account.network, accountStateManager: account.stateManager, peerId: upgradedPeerId, historyAvailableForNewMembers: value)
                                    |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                        return .complete()
                                    }
                                    |> then(.single(upgradedPeerId))
                            }
                            |> deliverOnMainQueue
                        
                        self?.onComplete.set(showModalProgress(signal: signal, for: mainWindow))
                    } else {
                        let signal: Signal<PeerId?, NoError> = updateChannelHistoryAvailabilitySettingsInteractively(postbox: account.postbox, network: account.network, accountStateManager: account.stateManager, peerId: peerId, historyAvailableForNewMembers: value) |> deliverOnMainQueue |> map { _ in return nil }
                        self?.onComplete.set(showModalProgress(signal: signal, for: mainWindow))
                    }
                } else {
                    self?.onComplete.set(.single(nil))
                }

            }, for: .SingleClick)
            
        }))
        
        //            _ = showModalProgress(signal: updateChannelHistoryAvailabilitySettingsInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: self.peerId, historyAvailableForNewMembers: enabled), for: mainWindow).start()

        
        //        onComplete.set(statePromise.get() |> filter {$0.enabled != nil} |> map {$0.enabled!})

    }
    
    var doneButton:Control? {
        return rightBarView
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: L10n.navigationDone)
        
        return button
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
        applyDisposable.dispose()
    }
}
