//
//  PeerInfoController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

class PeerInfoTitleBarView : TitledBarView {
    private var search:ImageButton = ImageButton()
    init(controller: ViewController, title:NSAttributedString, handler:@escaping() ->Void) {
        super.init(controller: controller, title)
        search.set(handler: { _ in
            handler()
        }, for: .Click)
        addSubview(search)
        updateLocalizationAndTheme()
    }
    
    func updateSearchVisibility(_ visible: Bool) {
        search.isHidden = !visible
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        search.set(image: theme.icons.chatSearch, for: .Normal)
        _ = search.sizeToFit()
        backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        search.centerY(x: frame.width - search.frame.width)
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class PeerInfoArguments {
    let peerId:PeerId
    let account:Account
    let isAd: Bool
    let pushViewController:(ViewController) -> Void
    
    let pullNavigation:()->NavigationViewController?
    
    private let peerInfoDisposable = MetaDisposable()
    private let toggleNotificationsDisposable = MetaDisposable()
    private let deleteDisposable = MetaDisposable()
    private let _statePromise = Promise<PeerInfoState>()
    
    var statePromise:Signal<PeerInfoState, Void> {
        return _statePromise.get()
    }
    
    private let value:Atomic<PeerInfoState>
    
    var state:PeerInfoState {
        return value.modify {$0}
    }
    
    func updateInfoState(_ f: (PeerInfoState) -> PeerInfoState) -> Void {
        _statePromise.set(.single(value.modify(f)))
    }
    
    func updateEditable(_ editable:Bool, peerView:PeerView) {
        
    }
    
    func dismissEdition() {
        
    }
    
    func peerInfo(_ peerId:PeerId) {
        peerInfoDisposable.set((account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.pushViewController(PeerInfoController(account: strongSelf.account, peer: peer))
            }
        }))
    }
    
    func peerChat(_ peerId:PeerId) {
        pushViewController(ChatController(account: account, chatLocation: .peer(peerId)))
    }
    
    func toggleNotifications() {
        toggleNotificationsDisposable.set(togglePeerMuted(account: account, peerId: peerId).start())
    }
    
    func delete() {
        let account = self.account
        let peerId = self.peerId
               
        deleteDisposable.set((removeChatInteractively(account: account, peerId:peerId) |> deliverOnMainQueue).start(next: { [weak self] success in
            if success {
                self?.pullNavigation()?.close()
            }
        }))
        
    }
    
    func sharedMedia() {
        pushViewController(PeerMediaController(account: account, peerId: peerId, tagMask: .photoOrVideo))
    }
    
    init(account:Account, peerId:PeerId, state:PeerInfoState, isAd: Bool, pushViewController:@escaping(ViewController)->Void, pullNavigation:@escaping()->NavigationViewController?) {
        self.value = Atomic(value: state)
        _statePromise.set(.single(state))
        self.account = account
        self.peerId = peerId
        self.isAd = isAd
        self.pushViewController = pushViewController
        self.pullNavigation = pullNavigation
    }
    
    deinit {
        toggleNotificationsDisposable.dispose()
        peerInfoDisposable.dispose()
        deleteDisposable.dispose()
    }
}

struct TemporaryParticipant: Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let timestamp: Int32
    
    static func ==(lhs: TemporaryParticipant, rhs: TemporaryParticipant) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        return true
    }
}

private struct PeerInfoSortableStableId: Hashable {
    let id: PeerInfoEntryStableId
    
    static func ==(lhs: PeerInfoSortableStableId, rhs: PeerInfoSortableStableId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
    
    var hashValue: Int {
        return self.id.hashValue
    }
}

private struct PeerInfoSortableEntry: Identifiable, Comparable {
    let entry: PeerInfoEntry
    
    var stableId: PeerInfoSortableStableId {
        return PeerInfoSortableStableId(id: self.entry.stableId)
    }
    
    static func ==(lhs: PeerInfoSortableEntry, rhs: PeerInfoSortableEntry) -> Bool {
        return lhs.entry.isEqual(to: rhs.entry)
    }
    
    static func <(lhs: PeerInfoSortableEntry, rhs: PeerInfoSortableEntry) -> Bool {
        return lhs.entry.isOrderedBefore(rhs.entry)
    }
}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<PeerInfoSortableEntry>]?, to:[AppearanceWrapperEntry<PeerInfoSortableEntry>], account:Account, initialSize:NSSize, peerId:PeerId, arguments: PeerInfoArguments, animated:Bool) -> TableUpdateTransition {
    

    
    let (deleted,inserted, updated) = proccessEntries(from, right: to, { (peerInfoSortableEntry) -> TableRowItem in
        return peerInfoSortableEntry.entry.entry.item(initialSize: initialSize, arguments: arguments)
    })
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated:animated, state: animated ? .none(nil) : .saveVisible(.lower), animateVisibleOnly: false)
    
}


class PeerInfoController: EditableViewController<TableView> {
    
    private let updatedChannelParticipants:MetaDisposable = MetaDisposable()
    let peerId:PeerId
    private let peerViewDisposable:MetaDisposable = MetaDisposable()
    private let peerAtomic:Atomic<Peer>
    private let peerView:Atomic<PeerView?> = Atomic(value: nil)
    private let peerInputActivitiesDisposable = MetaDisposable()
    private var _groupArguments:GroupInfoArguments!
    private var _userArguments:UserInfoArguments!
    private var _channelArguments:ChannelInfoArguments!
    var disposable:MetaDisposable = MetaDisposable()
    init(account:Account, peer:Peer, isAd: Bool = false) {
        peerAtomic = Atomic(value: peer)
        self.peerId = peer.id
        super.init(account)
        
        
        
        let pushViewController:(ViewController) -> Void = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        _groupArguments = GroupInfoArguments(account: account, peerId: peerId, state: GroupInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
            return self?.navigationController
        })
        
        _userArguments = UserInfoArguments(account: account, peerId: peerId, state: UserInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
            return self?.navigationController
        })
        
        
        _channelArguments = ChannelInfoArguments(account: account, peerId: peerId, state: ChannelInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
            return self?.navigationController
        })

    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return PeerInfoTitleBarView(controller: self, title:.initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title)), handler: { [weak self] in
            self?.searchSupergroupUsers()
        })
    }
    
    func searchSupergroupUsers() {
        _ = (selectModalPeers(account: account, title: "", behavior: SelectChannelMembersBehavior(peerId: peerId, limit: 1, settings: [])) |> deliverOnMainQueue |> map {$0.first}).start(next: { [weak self] peerId in
            if let peerId = peerId {
                self?._channelArguments.peerInfo(peerId)
            }
        })
    }
    
    deinit {
        disposable.dispose()
        updatedChannelParticipants.dispose()
        peerInputActivitiesDisposable.dispose()
        window?.removeAllHandlers(for: self)
    }
    
    private var arguments:PeerInfoArguments {
        let peer = peerAtomic.modify({$0})
        if peer.isGroup || peer.isSupergroup {
            return _groupArguments
        } else if peer.isChannel {
            return _channelArguments
        } else {
            return _userArguments
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .rejected
        }, with: self, for: .Return, priority: .high)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .rejected
        }, with: self, for: .Return, priority: .high, modifierFlags: [.command])
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        genericView.reloadData()
    }
    
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent, state == .Edit {
            if FastSettings.checkSendingAbility(for: currentEvent) {
                changeState()
                return .invoked
            }
        }
        
        return .invokeNext
    }

    override func viewDidLoad() -> Void {
        super.viewDidLoad()
        
        let previousEntries = Atomic<[AppearanceWrapperEntry<PeerInfoSortableEntry>]?>(value: nil)
        let account = self.account
        let peerId = self.peerId
        let initialSize = atomicSize
        let arguments = self.arguments
        let peer = peerAtomic.modify({$0})
        
        let inputActivity = self.account.peerInputActivities(peerId: peerId)
            |> map { activities -> [PeerId : PeerInputActivity] in
                return activities.reduce([:], { (current, activity) -> [PeerId : PeerInputActivity] in
                    var current = current
                    current[activity.0] = activity.1
                    return current
                })
        }
        
        let inputActivityState: Promise<[PeerId : PeerInputActivity]> = Promise([:])
        
        if peer.isGroup || peer.isSupergroup {
            inputActivityState.set(inputActivity)
        }
        
        
        let transition = combineLatest(account.viewTracker.peerView(peerId) |> deliverOnPrepareQueue, arguments.statePromise |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, inputActivityState.get() |> deliverOnPrepareQueue)
            |> map { [weak peerAtomic] view, state, appearance, inputActivities -> (PeerView, TableUpdateTransition) in
                
                let entries:[AppearanceWrapperEntry<PeerInfoSortableEntry>] = peerInfoEntries(view: view, arguments: arguments, inputActivities: inputActivities).map({PeerInfoSortableEntry(entry: $0)}).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                
                let previous = previousEntries.swap(entries)
                
                _ = peerAtomic?.modify{ (previous) -> Peer in
                    if let peer = peerViewMainPeer(view) {
                        return peer
                    } else {
                        return previous
                    }
                }
                
                return (view, prepareEntries(from: previous, to: entries, account: account, initialSize: initialSize.modify({$0}), peerId: peerId, arguments:arguments, animated: previous != nil))
                
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] (peerView, transition) in
           
            _ = self?.peerView.swap(peerView)
            
            let editable:Bool
            if let peer = peerViewMainPeer(peerView) {
                if let peer = peer as? TelegramChannel {
                    switch peer.info {
                    case .broadcast:
                        editable = peer.hasAdminRights(.canChangeInfo)
                    case .group:
                        editable = true //peer.adminRights != nil || peer.flags.contains(.isCreator)
                    }
                    
                } else if let peer = peer as? TelegramGroup {
                    editable = peer.role == .creator || peer.role == .admin || !peer.flags.contains(.adminsEnabled)
                } else if peer is TelegramUser {
                    editable = account.peerId != peer.id
                } else {
                    editable = false
                }
                (self?.centerBarView as? PeerInfoTitleBarView)?.updateSearchVisibility(peer.isSupergroup)
            } else {
                editable = false
            }
            self?.set(editable: editable)
            
            self?.readyOnce()
            self?.genericView.merge(with:transition)
        }))
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            let fetchParticipants = account.viewTracker.peerView(peerId) |> filter {$0.cachedData != nil} |> take(1) |> deliverOnMainQueue |> mapToSignal {_ -> Signal<Void, Void> in
                return account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true)
            }
            updatedChannelParticipants.set(fetchParticipants.start())
        }
        
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        if state == .Edit {
            return .invokeNext
        }
        return .rejected
    }
    

    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        if let peerView = peerView.modify({$0}) {
            self.arguments.updateEditable(state == .Edit, peerView: peerView)
        }
    }
    
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if state == .Edit {
            arguments.dismissEdition()
            state = .Normal
            return .invoked
        }
        return .rejected
    }
    
}

