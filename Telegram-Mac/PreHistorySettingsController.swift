//
//  PreHistorySettingsController.swift
//  Telegram
//
//  Created by keepcoder on 10/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit



private final class PreHistoryArguments {
    fileprivate let context: AccountContext
    fileprivate let preHistory:(Bool)->Void
    init(context: AccountContext, preHistory:@escaping(Bool)->Void) {
        self.context = context
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
    case type(sectionId:Int32, index: Int32, text: String, enabled: Bool, selected: Bool, viewType: GeneralViewType)
    case text(sectionId:Int32, index: Int32, text: String, viewType: GeneralViewType)
    
    var stableId: PreHistoryEntryId {
        switch self {
        case .type(_, let index, _, _, _, _):
            return .type(index)
        case .text(_, let index, _, _):
            return .text(index)
        case .section(let index):
            return .section(index)
        }
    }
    
    var index:Int32 {
        switch self {
        case let .type(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index
        case let .text(sectionId, index, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func item(_ arguments: PreHistoryArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        case let .type(_, _, text, enabled, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .selectable(enabled), viewType: viewType, action: {
                arguments.preHistory(selected)
            })
        case let .text(_, _, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
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
    
    entries.append(.text(sectionId: sectionId, index: index, text: strings().preHistorySettingsHeader, viewType: .textTopItem))
    index += 1
    
    let enabled =  state.enabled ?? cachedData?.flags.contains(.preHistoryEnabled) ?? false
    
    entries.append(.type(sectionId: sectionId, index: index, text: strings().peerInfoPreHistoryVisible, enabled: enabled, selected: true, viewType: .firstItem))
    index += 1
    entries.append(.type(sectionId: sectionId, index: index, text: strings().peerInfoPreHistoryHidden, enabled: !enabled, selected: false, viewType: .lastItem))
    index += 1
    
    entries.append(.text(sectionId: sectionId, index: index, text: enabled ? strings().preHistorySettingsDescriptionVisible : isGrpup ? strings().preHistorySettingsDescriptionGroupHidden : strings().preHistorySettingsDescriptionHidden, viewType: .textBottomItem))
    index += 1
    
    return entries
}

class PreHistorySettingsController: EmptyComposeController<Void, PeerId?, TableView> {
    private let peerId: PeerId
    private let statePromise = ValuePromise(PreHistoryControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: PreHistoryControllerState())
    private let disposable = MetaDisposable()
    private let applyDisposable = MetaDisposable()
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let context = self.context
        let peerId = self.peerId
        
        let previous:Atomic<[AppearanceWrapperEntry<PreHistoryEntry>]> = Atomic(value: [])
        
        let updateState: ((PreHistoryControllerState) -> PreHistoryControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        let initialSize = self.atomicSize
        
        let arguments = PreHistoryArguments(context: context, preHistory: { enabled in
            updateState({$0.withUpdatedEnabled(enabled)})
        })
        
        let key = PostboxViewKey.cachedPeerData(peerId: peerId)
        
        
        let signal: Signal<(TableUpdateTransition, PreHistoryControllerState, Bool, CachedChannelData?, Peer?), NoError> = combineLatest(queue: prepareQueue, context.account.postbox.peerView(id: peerId), appearanceSignal, statePromise.get()) |> map { peerView, appearance, state in
            
            let cachedData = peerView.cachedData as? CachedChannelData
            let peer = peerViewMainPeer(peerView)
            let entries = preHistoryEntries(cachedData: cachedData, isGrpup: peerId.namespace == Namespaces.Peer.CloudGroup, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            let defaultValue: Bool = cachedData?.flags.contains(.preHistoryEnabled) ?? false
            

            return (prepareEntries(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), state, defaultValue, cachedData, peer)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition, state, defaultValue, cachedData, peer in
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
                        let signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                            |> map(Optional.init)
                            |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                guard let upgradedPeerId = upgradedPeerId else {
                                    return .single(nil)
                                }
                                return  context.engine.peers.updateChannelHistoryAvailabilitySettingsInteractively(peerId: upgradedPeerId, historyAvailableForNewMembers: value)
                                    |> mapError { _ in
                                        return ConvertGroupToSupergroupError.generic
                                    }
                                    |> mapToSignal { _ -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                        return .complete()
                                    }
                                    |> then(.single(upgradedPeerId) |> mapError { ConvertGroupToSupergroupError.generic })
                            }
                            |> deliverOnMainQueue
                        
                        _ = showModalProgress(signal: signal, for: context.window).start(next: { [weak self] peerId in
                            self?.onComplete.set(.single(peerId))
                        }, error: { error in
                            switch error {
                            case .tooManyChannels:
                                showInactiveChannels(context: context, source: .upgrade)
                            case .generic:
                                alert(for: context.window, info: strings().unknownError)
                            }
                        })
                        
                    } else {
                        let signal: Signal<PeerId?, NoError> = context.engine.peers.updateChannelHistoryAvailabilitySettingsInteractively(peerId: peerId, historyAvailableForNewMembers: value) |> deliverOnMainQueue |> `catch` { _ in return .complete() } |> map { _ in return nil }
                        
                        if let cachedData = cachedData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId.peerId, let peer = peer as? TelegramChannel {
                            verifyAlert_button(for: context.window, information: strings().preHistoryConfirmUnlink(peer.displayTitle), successHandler: { [weak self] _ in
                                if peer.adminRights == nil || !peer.hasPermission(.pinMessages) {
                                    alert(for: context.window, info: strings().channelErrorDontHavePermissions)
                                } else {
                                    let signal =  context.engine.peers.updateGroupDiscussionForChannel(channelId: linkedDiscussionPeerId, groupId: nil)
                                        |> `catch` { _ in return .complete() }
                                        |> map { _ -> PeerId? in return nil }
                                        |> then(signal)
                                    self?.onComplete.set(showModalProgress(signal: signal, for: context.window))
                                }
                                
                            })
                        } else {
                            self?.onComplete.set(showModalProgress(signal: signal, for: context.window))
                        }
                        
                    }
                } else {
                    self?.onComplete.set(.single(nil))
                }

            }, for: .SingleClick)
            
        }))
    }
    
    var doneButton:Control? {
        return rightBarView
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: strings().navigationDone)
        
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
