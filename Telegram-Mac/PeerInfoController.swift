//
//  PeerInfoController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox



class PeerInfoArguments {
    let peerId:PeerId
    let context: AccountContext
    let isAd: Bool
    let pushViewController:(ViewController) -> Void
    
    let pullNavigation:()->NavigationViewController?
    let mediaController: ()->PeerMediaController?
    
    
    let toggleNotificationsDisposable = MetaDisposable()
    private let deleteDisposable = MetaDisposable()
    private let _statePromise = Promise<PeerInfoState>()
    
    var statePromise:Signal<PeerInfoState, NoError> {
        return _statePromise.get()
    }
    
    private let value:Atomic<PeerInfoState>
    
    var state:PeerInfoState {
        return value.modify {$0}
    }
    
    func updateInfoState(_ f: (PeerInfoState) -> PeerInfoState) -> Void {
        _statePromise.set(.single(value.modify(f)))
    }
    
    func copy(_ string: String) {
        copyToClipboard(string)
        pullNavigation()?.controller.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
    }

    func updateEditable(_ editable:Bool, peerView:PeerView, controller: PeerInfoController) -> Bool {
        return true
    }
    
    func dismissEdition() {
        
    }
    
    func peerInfo(_ peerId:PeerId) {
        pushViewController(PeerInfoController(context: context, peerId: peerId))
    }
    
    func peerChat(_ peerId:PeerId, postId: MessageId? = nil) {
        pushViewController(ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: postId))
    }
    
    func toggleNotifications(_ currentlyMuted: Bool) {
        
        toggleNotificationsDisposable.set(context.engine.peers.togglePeerMuted(peerId: peerId, threadId: nil).start())
        
        pullNavigation()?.controller.show(toaster: ControllerToaster(text: currentlyMuted ? strings().toastUnmuted : strings().toastMuted))
    }
    
    func delete() {
        let context = self.context
        let peerId = self.peerId
        
        let isEditing = (state as? GroupInfoState)?.editingState != nil || (state as? ChannelInfoState)?.editingState != nil
        
        let signal = context.account.postbox.peerView(id: peerId) |> take(1) |> mapToSignal { view -> Signal<Bool, NoError> in
            return removeChatInteractively(context: context, peerId: peerId, userId: peerViewMainPeer(view)?.id, deleteGroup: isEditing && peerViewMainPeer(view)?.groupAccess.isCreator == true)
        } |> deliverOnMainQueue
        
        deleteDisposable.set(signal.start(completed: { [weak self] in
            self?.pullNavigation()?.close()
        }))
    }
    
    func sharedMedia() {
        if let controller = self.mediaController() {
            pushViewController(controller)
        }
    }
    
    init(context: AccountContext, peerId:PeerId, state:PeerInfoState, isAd: Bool, pushViewController:@escaping(ViewController)->Void, pullNavigation:@escaping()->NavigationViewController?, mediaController: @escaping()->PeerMediaController?) {
        self.value = Atomic(value: state)
        _statePromise.set(.single(state))
        self.context = context
        self.peerId = peerId
        self.isAd = isAd
        self.pushViewController = pushViewController
        self.pullNavigation = pullNavigation
        self.mediaController = mediaController
    }

    
    deinit {
        toggleNotificationsDisposable.dispose()
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id.hashValue)
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

struct PeerMediaTabsData : Equatable {
    let collections:[PeerMediaCollectionMode]
    let loaded: Bool
}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<PeerInfoSortableEntry>]?, to:[AppearanceWrapperEntry<PeerInfoSortableEntry>], account:Account, initialSize:NSSize, peerId:PeerId, arguments: PeerInfoArguments, animated:Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        
        var cancelled = false
        
        if Thread.isMainThread {
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(to)
            
            let index:Int = 0
            
            for i in index ..< entries.count {
                let item = entries[i].entry.entry.item(initialSize: initialSize, arguments: arguments)
                height += item.height
                firstInsertion.append((i, item))
                if initialSize.height < height {
                    break
                }
            }
            
            
            initialIndex = firstInsertion.count
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: .none(nil)))
            
            prepareQueue.async {
                if !cancelled {
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []
                    
                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = entries[i].entry.entry.item(initialSize: initialSize, arguments: arguments)
                        insertions.append((i, item))
                    }
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .none(nil)))
                    subscriber.putCompletion()
                }
            }
        } else {
            let (deleted,inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { (peerInfoSortableEntry) -> TableRowItem in
                return peerInfoSortableEntry.entry.entry.item(initialSize: initialSize, arguments: arguments)
            })
            
            subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, state: animated ? .none(nil) : .saveVisible(.lower), grouping: true, animateVisibleOnly: false))
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            cancelled = true
        }
    }
    
    
}

final class PeerInfoView : View {
    let tableView: TableView
    required init(frame frameRect: NSRect) {
        tableView = .init(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
}

class PeerInfoController: EditableViewController<PeerInfoView> {
    
    enum Source {
        case none
        case reaction(MessageId)
    }
    
    private let updatedChannelParticipants:MetaDisposable = MetaDisposable()
    let peerId:PeerId
    
    private let arguments:Promise<PeerInfoArguments> = Promise()
    
    private let peerView:Atomic<PeerView?> = Atomic(value: nil)
    private var _groupArguments:GroupInfoArguments!
    private var _userArguments:UserInfoArguments!
    private var _channelArguments:ChannelInfoArguments!
    private var _topicArguments:TopicInfoArguments!

    private let peerInputActivitiesDisposable = MetaDisposable()
    
    private var argumentsAction: DisposableSet = DisposableSet()
    var disposable:MetaDisposable = MetaDisposable()
    
    private let mediaController: PeerMediaController
    
    let threadInfo: ThreadInfo?
    
    let source: Source
    
    
    
    
    init(context: AccountContext, peerId:PeerId, threadInfo: ThreadInfo? = nil, isAd: Bool = false, source: Source = .none) {
        self.peerId = peerId
        self.source = source
        self.threadInfo = threadInfo
        self.mediaController = PeerMediaController(context: context, peerId: peerId, threadInfo: threadInfo, isProfileIntended: true)
        super.init(context)
        
        let pushViewController:(ViewController) -> Void = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        _groupArguments = GroupInfoArguments(context: context, peerId: peerId, state: GroupInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
            return self?.navigationController
        }, mediaController: { [weak self] in
            return self?.mediaController
        })
        
        _userArguments = UserInfoArguments(context: context, peerId: peerId, state: UserInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
             return self?.navigationController
        }, mediaController: { [weak self] in
             return self?.mediaController
        })
        
        
        _channelArguments = ChannelInfoArguments(context: context, peerId: peerId, state: ChannelInfoState(), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
            return self?.navigationController
        }, mediaController: { [weak self] in
              return self?.mediaController
        })
        if let threadInfo = threadInfo {
            _topicArguments = TopicInfoArguments(context: context, peerId: peerId, state: TopicInfoState(threadId: makeMessageThreadId(threadInfo.message.messageId)), isAd: isAd, pushViewController: pushViewController, pullNavigation:{ [weak self] () -> NavigationViewController? in
                return self?.navigationController
            }, mediaController: { [weak self] in
                  return self?.mediaController
            })
        }
        
        
    }
    
    deinit {
        disposable.dispose()
        updatedChannelParticipants.dispose()
        peerInputActivitiesDisposable.dispose()
        argumentsAction.dispose()
        window?.removeAllHandlers(for: self)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .rejected
        }, with: self, for: .Return, priority: .high)
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
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
        genericView.tableView.reloadData()
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
        
        self.genericView.tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        
        let previousEntries = Atomic<[AppearanceWrapperEntry<PeerInfoSortableEntry>]?>(value: nil)
        let context = self.context
        let peerId = self.peerId
        let initialSize = atomicSize
        let onMainQueue: Atomic<Bool> = Atomic(value: true)
        let threadId = threadInfo?.message.messageId
                
        mediaController.navigationController = self.navigationController
        mediaController._frameRect = bounds
        mediaController.bar = .init(height: 0)
        
        mediaController.loadViewIfNeeded()
        
        let inputActivity = context.account.peerInputActivities(peerId: .init(peerId: peerId, category: .global))
            |> map { activities -> [PeerId : PeerInputActivity] in
                return activities.reduce([:], { (current, activity) -> [PeerId : PeerInputActivity] in
                    var current = current
                    current[activity.0] = activity.1
                    return current
                })
        }
        
        let inputActivityState: Promise<[PeerId : PeerInputActivity]> = Promise([:])
        

        arguments.set(context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { [weak self] peer in
            guard let `self` = self else {return .never()}
            
            if peer.isForum && threadId != nil {
                return .single(self._topicArguments)
            }
            if peer.isGroup || peer.isSupergroup {
                inputActivityState.set(inputActivity)
            }
            
            if peer.isGroup || peer.isSupergroup {
                return .single(self._groupArguments)
            } else if peer.isChannel {
                return .single(self._channelArguments)
            } else {
                return .single(self._userArguments)
            }
        })
        
        let actionsDisposable = DisposableSet()
        
        var loadMoreControl: PeerChannelMemberCategoryControl?
        
        let channelMembersPromise = Promise<[RenderedChannelParticipant]>()
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            let (disposable, control) = context.peerChannelMemberCategoriesContextsManager.recent(peerId: peerId, updated: { state in
                channelMembersPromise.set(.single(state.list))
            })
            actionsDisposable.add(disposable)

            let (contactsDisposable, _) = context.peerChannelMemberCategoriesContextsManager.contacts(peerId: peerId, updated: { _ in
                
            })
            actionsDisposable.add(contactsDisposable)
            
            loadMoreControl = control
        } else {
            channelMembersPromise.set(.single([]))
        }
        
        
        let mediaTabsData: Signal<PeerMediaTabsData, NoError> = mediaController.tabsValue
        let mediaReady = mediaController.ready.get() |> take(1)
        
        
        let source = self.source
        
        
        let transition: Signal<(PeerView, TableUpdateTransition, MessageHistoryThreadData?), NoError> = arguments.get() |> mapToSignal { arguments in
            
            let inviteLinksCount: Signal<Int32, NoError>
            if let arguments = arguments as? GroupInfoArguments {
                inviteLinksCount = arguments.linksManager.state |> map {
                    $0.effectiveCount
                }
            } else if let arguments = arguments as? ChannelInfoArguments {
                inviteLinksCount = arguments.linksManager.state |> map {
                    $0.effectiveCount
                }
            } else {
                inviteLinksCount = .single(0)
            }
            
            let joinRequestsCount: Signal<Int32, NoError>
            if let arguments = arguments as? GroupInfoArguments {
                joinRequestsCount = arguments.requestManager.state |> map {
                    Int32($0.waitingCount)
                }
            } else if let arguments = arguments as? ChannelInfoArguments {
                joinRequestsCount = arguments.requestManager.state |> map {
                    Int32($0.waitingCount)
                }
            } else {
                joinRequestsCount = .single(0)
            }
            
            let availableReactions: Signal<AvailableReactions?, NoError> = context.reactions.stateValue
            
            
            let threadData: Signal<MessageHistoryThreadData?, NoError>
            if let threadId = threadId {
                let key: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: makeMessageThreadId(threadId))
                threadData = context.account.postbox.combinedView(keys: [key]) |> map { views in
                    let view = views.views[key] as? MessageHistoryThreadInfoView
                    let data = view?.info?.data.get(MessageHistoryThreadData.self)
                    return data
                }
            } else {
                threadData = .single(nil)
            }
            
            return combineLatest(queue: prepareQueue, context.account.viewTracker.peerView(peerId, updateData: true), arguments.statePromise, appearanceSignal, inputActivityState.get(), channelMembersPromise.get(), mediaTabsData, mediaReady, inviteLinksCount, joinRequestsCount, availableReactions, threadData)
                |> mapToQueue { view, state, appearance, inputActivities, channelMembers, mediaTabsData, _, inviteLinksCount, joinRequestsCount, availableReactions, threadData -> Signal<(PeerView, TableUpdateTransition, MessageHistoryThreadData?), NoError> in
                    
                    let entries:[AppearanceWrapperEntry<PeerInfoSortableEntry>] = peerInfoEntries(view: view, threadData: threadData, arguments: arguments, inputActivities: inputActivities, channelMembers: channelMembers, mediaTabsData: mediaTabsData, inviteLinksCount: inviteLinksCount, joinRequestsCount: joinRequestsCount, availableReactions: availableReactions, source: source).map({PeerInfoSortableEntry(entry: $0)}).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                    let previous = previousEntries.swap(entries)
                    return prepareEntries(from: previous, to: entries, account: context.account, initialSize: initialSize.modify({$0}), peerId: peerId, arguments:arguments, animated: previous != nil) |> runOn(onMainQueue.swap(false) ? .mainQueue() : prepareQueue) |> map { (view, $0, threadData) }
                    
            } |> deliverOnMainQueue
            } |> afterDisposed {
                actionsDisposable.dispose()
            }
                
        disposable.set(transition.start(next: { [weak self] (peerView, transition, threadData) in
            
            _ = self?.peerView.swap(peerView)
            
            let editable:Bool
            if let peer = peerViewMainPeer(peerView) {
                if let peer = peer as? TelegramChannel {
                    switch peer.info {
                    case .broadcast:
                        editable = peer.adminRights != nil || peer.flags.contains(.isCreator)
                    case .group:
                        if let threadData = threadData {
                            let right = peer.adminRights?.rights.contains(.canManageTopics) ?? false
                            editable = (peer.isAdmin && right) || threadData.isOwnedByMe
                        } else {
                            editable = peer.adminRights != nil || peer.flags.contains(.isCreator)
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    switch group.role {
                    case .admin, .creator:
                        editable = true
                    default:
                        editable = group.groupAccess.canEditGroupInfo || group.groupAccess.canEditMembers
                    }
                } else if peer is TelegramUser, !peer.isBot, peerView.peerIsContact {
                    editable = context.account.peerId != peer.id
                } else {
                    editable = false
                }
            } else {
                editable = false
            }
            self?.set(editable: editable)
            
            self?.genericView.tableView.merge(with:transition)
            self?.readyOnce()

        }))
        
     
        genericView.tableView.setScrollHandler { position in
            if let loadMoreControl = loadMoreControl {
                switch position.direction {
                case .bottom:
                    context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
                default:
                    break
                }
            }
        }
       
        
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        if state == .Edit {
            return .invokeNext
        }
        return .rejected
    }
    
    func updateArguments(_ f:@escaping(PeerInfoArguments) -> Void) {
        argumentsAction.add((arguments.get() |> take(1)).start(next: { arguments in
            f(arguments)
        }))
    }
    
    override func update(with state: ViewControllerState) {
        
        if let peerView = peerView.with ({$0}) {
            updateArguments({ [weak self] arguments in
                guard let `self` = self else {
                    return
                }
                let updateState = arguments.updateEditable(state == .Edit, peerView: peerView, controller: self)
                self.genericView.tableView.scroll(to: .up(true))
                
                if updateState {
                    self.applyState(state)
                }
            })
        }
    }
    
    private func applyState(_ state: ViewControllerState) {
        super.update(with: state)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if state == .Edit {
            updateArguments({ arguments in
                arguments.dismissEdition()
            })
            state = .Normal
            return .invoked
        }
        return .rejected
    }
    
}

