//
//  ChannelLogsFIlterModalController.swift
//  Telegram
//
//  Created by keepcoder on 09/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac



private final class ChannelFilterArguments {
    let account:Account
    let toggleFlags:(FilterEvents)->Void
    let toggleAdmin:(PeerId)->Void
    let toggleAllAdmins:()->Void
    let toggleAllEvents:()->Void
    init(account:Account, toggleFlags:@escaping(FilterEvents)->Void, toggleAdmin:@escaping(PeerId)->Void, toggleAllAdmins:@escaping()->Void, toggleAllEvents:@escaping()->Void) {
        self.account = account
        self.toggleFlags = toggleFlags
        self.toggleAdmin = toggleAdmin
        self.toggleAllAdmins = toggleAllAdmins
        self.toggleAllEvents = toggleAllEvents
    }
}

private enum ChannelEventFilterEntryId : Hashable {
    case section(Int32)
    case header(Int32)
    case allEvents
    case filter(FilterEvents)
    case allAdmins
    case admin(PeerId)
    case adminsLoading
    var hashValue: Int {
        switch self {
        case .section:
            return 0
        case .header:
            return 1
        case .allEvents:
            return 2
        case .filter:
            return 3
        case .allAdmins:
            return 4
        case .admin:
            return 5
        case .adminsLoading:
            return 6
        }
    }
    static func ==(lhs: ChannelEventFilterEntryId, rhs: ChannelEventFilterEntryId) -> Bool {
        switch lhs {
        case .section(let value):
            if case .section(value) = rhs {
                return true
            } else {
                return false
            }
        case .header(let value):
            if case .header(value) = rhs {
                return true
            } else {
                return false
            }
        case .allEvents:
            if case .allEvents = rhs {
                return true
            } else {
                return false
            }
        case .filter(let value):
            if case .filter(value) = rhs {
                return true
            } else {
                return false
            }
        case .allAdmins:
            if case .allAdmins = rhs {
                return true
            } else {
                return false
            }
        case .admin(let value):
            if case .admin(value) = rhs {
                return true
            } else {
                return false
            }
        case .adminsLoading:
            if case .adminsLoading = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum ChannelEventFilterEntry : TableItemListNodeEntry {
    case section(Int32)
    case header(Int32, Int32, text: String)
    case allEvents(Int32, Int32, enabled: Bool)
    case filter(Int32, Int32, flag:FilterEvents, name:String, enabled: Bool)
    case allAdmins(Int32, Int32, enabled: Bool)
    case admin(Int32, Int32, peer: RenderedChannelParticipant, enabled: Bool)
    case adminsLoading(Int32, Int32)
    var stableId:ChannelEventFilterEntryId {
        switch self {
        case .section(let value):
            return .section(value)
        case .header(_, let value, _):
            return .header(value)
        case .allEvents:
            return .allEvents
        case .filter(_, _, let value, _, _):
            return .filter(value)
        case .adminsLoading:
            return .adminsLoading
        case .allAdmins:
            return .allAdmins
        case .admin(_, _, let value, _):
            return .admin(value.peer.id)
        }
    }
    
    var index:Int32 {
        switch self {
        case let .section(section):
            return (section * 1000) - section
        case let .header(section, index, _):
            return (section * 1000) + index
        case .allEvents(let section, let index, _):
            return (section * 1000) + index
        case let .filter(section, index, _, _, _):
            return (section * 1000) + index
        case .allAdmins(let section, let index, _):
            return (section * 1000) + index
        case let .admin(section, index, _, _):
            return (section * 1000) + index
        case let .adminsLoading(section, index):
            return (section * 1000) + index
        }
    }
    
    func item(_ arguments: ChannelFilterArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .header(_, _, let text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case .allAdmins(_, _, let enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chanelEventFilterAllAdmins, type: .switchable (enabled), action: {
                arguments.toggleAllAdmins()
            })
        case .allEvents(_, _, let enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.chanelEventFilterAllEvents, type: .switchable (enabled), action: {
                arguments.toggleAllEvents()
            })
        case let .filter(_, _, flag, name, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, type: .selectable(enabled), action: {
                arguments.toggleFlags(flag)
            })
        case .adminsLoading:
            return LoadingTableItem(initialSize, height: 30, stableId: stableId)
        case let .admin( _, _, participant, enabled):
            
            let status:String
            switch participant.participant {
            case .creator:
                status = tr(L10n.adminsCreator)
            case .member:
                status = tr(L10n.adminsAdmin)
            }
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.account, stableId: stableId, height: 40, photoSize: NSMakeSize(30, 30), status: status, inset: NSEdgeInsets(left: 30, right: 30), interactionType: .plain, generalType: .selectable(enabled), action: {
                arguments.toggleAdmin(participant.peer.id)
            })
        }
    }
}

private func ==(lhs:ChannelEventFilterEntry, rhs:ChannelEventFilterEntry) -> Bool {
    switch lhs {
    case let .section(section):
        if case .section(section) = rhs {
            return true
        } else {
            return false
        }
    case let .header(section, index, text):
        if case .header(section, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .allEvents(section, index, enabled):
        if case .allEvents(section, index, enabled) = rhs {
            return true
        } else {
            return false
        }
    case let .filter(section, index, flags, text, enabled):
        if case .filter(section, index, flags, text, enabled) = rhs {
            return true
        } else {
            return false
        }
    case let .allAdmins(section, index, enabled):
        if case .allAdmins(section, index, enabled) = rhs {
            return true
        } else {
            return false
        }
    case let .adminsLoading(section, index):
            if case .adminsLoading(section, index) = rhs {
                return true
            } else {
                return false
            }
    case let .admin(section, index, participant, enabled):
        if case .admin(section, index, participant, enabled) = rhs {
            return true
        } else {
            return false
        }
    }
}

private func <(lhs:ChannelEventFilterEntry, rhs: ChannelEventFilterEntry) -> Bool {
    return lhs.index < rhs.index
}

final class ChannelEventFilterState : Equatable {
    fileprivate let allEvents: Set<FilterEvents>
    fileprivate let allAdmins:Set<PeerId>
    fileprivate let adminsException:Set<PeerId>
    fileprivate let eventsException:Set<FilterEvents>
    init() {
        self.allEvents = []
        self.allAdmins = []
        self.adminsException = []
        self.eventsException = []
    }
    fileprivate  init(allEvents: Set<FilterEvents>, allAdmins: Set<PeerId>, adminsException:Set<PeerId>, eventsException:Set<FilterEvents>) {
        self.allEvents = allEvents
        self.allAdmins = allAdmins
        self.adminsException = adminsException
        self.eventsException = eventsException
    }
    
    fileprivate func withUpdatedAllEvents(_ events:Set<FilterEvents>) -> ChannelEventFilterState {
        return ChannelEventFilterState(allEvents: events, allAdmins: self.allAdmins, adminsException: self.adminsException, eventsException: self.eventsException)
    }
    fileprivate func withUpdatedAllAdmins(_ admins:Set<PeerId>) -> ChannelEventFilterState {
        return ChannelEventFilterState(allEvents: self.allEvents, allAdmins: admins, adminsException: self.adminsException, eventsException: self.eventsException)
    }
    fileprivate func withUpdatedAdminsException(_ exception:Set<PeerId>) -> ChannelEventFilterState {
        return ChannelEventFilterState(allEvents: self.allEvents, allAdmins: exception, adminsException: exception, eventsException: self.eventsException)
    }
    fileprivate func withUpdatedEventsException(_ exception:Set<FilterEvents>) -> ChannelEventFilterState {
        return ChannelEventFilterState(allEvents: exception, allAdmins: self.allAdmins, adminsException: self.adminsException, eventsException: exception)
    }
    
    fileprivate func withToggledAdminsException(_ admin:PeerId) -> ChannelEventFilterState {
        var exceptions = self.adminsException
        if exceptions.contains(admin) {
            exceptions.remove(admin)
        } else {
            exceptions.insert(admin)
        }
        return ChannelEventFilterState(allEvents: self.allEvents, allAdmins: self.allAdmins, adminsException: exceptions, eventsException: self.eventsException)
    }
    fileprivate func withToggledEventsException(_ flag:FilterEvents) -> ChannelEventFilterState {
        var exceptions = self.eventsException
        if exceptions.contains(flag) {
            exceptions.remove(flag)
        } else {
            exceptions.insert(flag)
        }
        return ChannelEventFilterState(allEvents: self.allEvents, allAdmins: self.allAdmins, adminsException: self.adminsException, eventsException: exceptions)
    }
    
    
    var selectedFlags:AdminLogEventsFlags {
        let events = allEvents.subtracting(eventsException)
        var flags: AdminLogEventsFlags = []
        for event in events {
            flags.insert(event.flags)
        }
        return eventsException.isEmpty ? AdminLogEventsFlags.flags : flags
    }
    var selectedAdmins:[PeerId]? {
        if adminsException.isEmpty {
            return nil
        } else {
            return Array(allAdmins.subtracting(adminsException))
        }
    }
    
    var isEmpty: Bool {
        return adminsException.isEmpty && eventsException.isEmpty
    }
}

func ==(lhs:ChannelEventFilterState, rhs: ChannelEventFilterState) -> Bool {
    return lhs.allEvents == rhs.allEvents && lhs.allAdmins == rhs.allAdmins && lhs.adminsException == rhs.adminsException && lhs.eventsException == rhs.eventsException
}

private enum FilterEvents {
    case restrictions
    case newMembers
    case newAdmins
    case groupInfo
    case deletedMessages
    case editedMessages
    case pinnedMessages
    case leavingMembers
    
    var flags:AdminLogEventsFlags {
        switch self {
        case .newMembers:
            return [AdminLogEventsFlags.join, AdminLogEventsFlags.unban]
        case .newAdmins:
            return [AdminLogEventsFlags.promote]
        case .leavingMembers:
            return  [AdminLogEventsFlags.leave, AdminLogEventsFlags.kick]
        case .restrictions:
            return [AdminLogEventsFlags.unban, AdminLogEventsFlags.ban]
        case .groupInfo:
            return [AdminLogEventsFlags.info, AdminLogEventsFlags.settings]
        case .pinnedMessages:
            return [AdminLogEventsFlags.pinnedMessages]
        case .editedMessages:
            return [AdminLogEventsFlags.editMessages]
        case .deletedMessages:
            return [AdminLogEventsFlags.deleteMessages]
        }
    }
    
    func localizedString(_ broadcast:Bool) -> String {
        switch self {
        case .newMembers:
            return tr(L10n.channelEventFilterNewMembers)
        case .newAdmins:
            return tr(L10n.channelEventFilterNewAdmins)
        case .leavingMembers:
            return  tr(L10n.channelEventFilterLeavingMembers)
        case .restrictions:
            return tr(L10n.channelEventFilterNewRestrictions)
        case .groupInfo:
            return broadcast ? tr(L10n.channelEventFilterChannelInfo) : tr(L10n.channelEventFilterGroupInfo)
        case .pinnedMessages:
            return tr(L10n.channelEventFilterPinnedMessages)
        case .editedMessages:
            return tr(L10n.channelEventFilterEditedMessages)
        case .deletedMessages:
            return tr(L10n.channelEventFilterDeletedMessages)
        }
    }
}

private func eventFilters(_ channel: Bool) -> [FilterEvents] {
    if channel {
        return [.newMembers, .newAdmins, .groupInfo, .deletedMessages, .editedMessages, .leavingMembers]
    } else {
        return [.restrictions, .newMembers, .newAdmins, .groupInfo, .deletedMessages, .editedMessages, .pinnedMessages, .leavingMembers]
    }
}


private func channelEventFilterEntries(state: ChannelEventFilterState, peer:Peer, admins:[RenderedChannelParticipant]?) -> [ChannelEventFilterEntry] {
    var entries:[ChannelEventFilterEntry] = []
    
    var section:Int32 = 1
    var index:Int32 = 1
    
    entries.append(.section(section))
    section += 1
    
    entries.append(.header(section, index, text: tr(L10n.channelEventFilterEventsHeader)))
    index += 1
    entries.append(.allEvents(section, index, enabled: state.eventsException.isEmpty))
    index += 1
    
    
    for flag in eventFilters(peer.isChannel) {
        entries.append(.filter(section, index, flag: flag, name: flag.localizedString(peer.isChannel), enabled: !state.eventsException.contains(flag)))
    }
    
    entries.append(.section(section))
    section += 1
    
    entries.append(.header(section, index, text: tr(L10n.channelEventFilterAdminsHeader)))
    index += 1
    
    entries.append(.allAdmins(section, index, enabled: state.adminsException.isEmpty))
    index += 1
    
    if let admins = admins {
        for admin in admins {
            entries.append(.admin(section, index, peer: admin, enabled: !state.adminsException.contains(admin.peer.id)))
        }
    } else {
        entries.append(.adminsLoading(section, index))
        index += 1
    }
    
    return entries
}

fileprivate func prepareTransition(left:[ChannelEventFilterEntry], right: [ChannelEventFilterEntry], initialSize:NSSize, arguments:ChannelFilterArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class ChannelEventFilterModalController: ModalViewController {
    private let peerId:PeerId
    private let account:Account
    private let stateValue = Atomic(value: ChannelEventFilterState())
    
    private let disposable = MetaDisposable()
    private let updated:(ChannelEventFilterState) -> Void
    private let admins: [RenderedChannelParticipant]
    init(account:Account, peerId:PeerId, admins: [RenderedChannelParticipant], state: ChannelEventFilterState = ChannelEventFilterState(), updated:@escaping(ChannelEventFilterState) -> Void) {
        self.account = account
        self.peerId = peerId
        self.admins = admins
        self.updated = updated
        _ = self.stateValue.swap(state)
        super.init(frame: NSMakeRect(0, 0, 300, 300))
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    private var genericView:TableView {
        return self.view as! TableView
    }
    
    private func updateSize(_ animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 70, genericView.listHeight)), animated: animated)
        }
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stateValue = self.stateValue
        let statePromise = ValuePromise(stateValue.modify({$0}), ignoreRepeated: true)
        let updateState: ((ChannelEventFilterState) -> ChannelEventFilterState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let arguments = ChannelFilterArguments(account: account, toggleFlags: { flags in
            updateState({$0.withToggledEventsException(flags)})
        }, toggleAdmin: { peerId in
            updateState({$0.withToggledAdminsException(peerId)})
        }, toggleAllAdmins: {
            updateState({$0.withUpdatedAdminsException($0.adminsException.isEmpty ? $0.allAdmins : [])})
        }, toggleAllEvents: {
            updateState({$0.withUpdatedEventsException($0.eventsException.isEmpty ? $0.allEvents : [])})
        })
        
        let previous: Atomic<[ChannelEventFilterEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let adminsSignal = Signal<[RenderedChannelParticipant], Void>.single(admins)
        let updatedSize:Atomic<Bool> = Atomic(value: false)
        let signal:Signal<TableUpdateTransition, Void> = combineLatest(statePromise.get(), account.postbox.loadedPeerWithId(peerId), adminsSignal) |> map { state, peer, admins -> (ChannelEventFilterState, Peer, [RenderedChannelParticipant]?) in
            
            let state = stateValue.swap(state.withUpdatedAllAdmins(Set(admins.map {$0.peer.id})).withUpdatedAllEvents(Set(eventFilters(peer.isChannel))))
            
            return (state, peer, admins)
        } |> map { state, peer, admins in
            
            let entries = channelEventFilterEntries(state: state, peer: peer, admins: admins)
            
            if let _ = admins {
                _ = updatedSize.swap(true)
            }
            let transition = prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
            return transition
        } |> deliverOnMainQueue
        
        
        genericView.merge(with: signal |> afterNext { [weak self] result -> TableUpdateTransition in
            self?.updateSize(false)
            return result
        })
        
        readyOnce()
    }
    
    private func noticeUpdated() {
        updated(stateValue.modify({$0}))
        close()
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            self?.noticeUpdated()
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
    }
    
    deinit {
        disposable.dispose()
    }
}
