//
//  CreateGroupViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import SwiftSignalKit
import TGUIKit


fileprivate final class Arguments {
    let context: AccountContext
    let choicePicture:(Bool)->Void
    let updatedText:(String)->Void
    let setupGlobalAutoremove:(Int32)->Void
    let deletePeer:(PeerId)->Void
    let addMembers:()->Void
    let revokePeerId:(PeerId)->Void
    let forumAlert:()->Void
    init(context: AccountContext, choicePicture:@escaping(Bool)->Void, updatedText:@escaping(String)->Void, setupGlobalAutoremove:@escaping(Int32)->Void, deletePeer:@escaping(PeerId)->Void, addMembers:@escaping()->Void, revokePeerId:@escaping(PeerId)->Void, forumAlert:@escaping()->Void) {
        self.context = context
        self.updatedText = updatedText
        self.choicePicture = choicePicture
        self.setupGlobalAutoremove = setupGlobalAutoremove
        self.deletePeer = deletePeer
        self.addMembers = addMembers
        self.revokePeerId = revokePeerId
        self.forumAlert = forumAlert
    }
}

struct CreateGroupStateResult {
    let title:String
    let picture: String?
    let peerIds:[PeerId]
    let autoremoveTimeout: Int32?
    let username: String?
    let isForum: Bool
}

struct CreateGroupRequires : OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let username = CreateGroupRequires(rawValue: 1 << 1)
    static let forum = CreateGroupRequires(rawValue: 1 << 2)
}

private struct State : Equatable {
    var picture: String?
    var text: String = ""
    var autoremoveTimeout: Int32?
    var privacy: AccountPrivacySettings?
    var peerIds:[PeerId] = []
    var errors:[InputDataIdentifier : InputDataValueError] = [:]
    var requires: CreateGroupRequires
    var editingPublicLinkText: String?
    var addressNameValidationStatus: AddressNameValidationStatus?
    var updatingAddressName: Bool = false
    var publicChannelsToRevoke: [PeerEquatable]?
    var revokingPeerId: PeerId?
}

private let _id_info = InputDataIdentifier("_id_info")
private let _id_timer = InputDataIdentifier("_id_timer")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}
private func _id_peer_channel(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_channel\(id.toInt64())")
}
private let _id_add = InputDataIdentifier("_id_add")
private let _id_forum = InputDataIdentifier("_id_forum")
private let _id_username = InputDataIdentifier("_id_username")

private func entries(_ view: MultiplePeersView, state: State, arguments: Arguments) -> [InputDataEntry] {
        
    var entries:[InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_info, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return GroupNameRowItem(initialSize, stableId:stableId, account: arguments.context.account, placeholder: strings().createGroupNameHolder, photo: state.picture, viewType: .singleItem, text: state.text, limit: 140, textChangeHandler: arguments.updatedText, pickPicture: arguments.choicePicture)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if !state.requires.isEmpty {
        
        if state.requires.contains(.username) {
            
            if let publicChannelsToRevoke = state.publicChannelsToRevoke {
                
                entries.append(.desc(sectionId: sectionId, index: 100, text: .plain(strings().createChannelTooManyErrorTitle), data: .init(color: theme.colors.redUI, viewType: .textTopItem)))

                let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                    var lhsDate: Int32 = 0
                    var rhsDate: Int32 = 0
                    if let lhs = lhs.peer as? TelegramChannel {
                        lhsDate = lhs.creationDate
                    }
                    if let rhs = rhs.peer as? TelegramChannel {
                        rhsDate = rhs.creationDate
                    }
                    return lhsDate > rhsDate
                })
                
                struct TuplePeer: Equatable {
                    let peer: PeerEquatable
                    let viewType: GeneralViewType
                    let index: Int32
                    let enabled: Bool
                }
                var items: [TuplePeer] = []
                for (i, peer) in sorted.enumerated() {
                    items.append(.init(peer: peer, viewType: bestGeneralViewType(sorted, for: i), index: 201 + Int32(i), enabled: peer.peer.id != state.revokingPeerId))
                }
                for item in items {
                    entries.append(.custom(sectionId: sectionId, index: item.index, value: .none, identifier: _id_peer_channel(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                        return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: item.enabled, height: 42, photoSize: NSMakeSize(32, 32), status: "t.me/\(item.peer.peer.addressName ?? "unknown")", inset: NSEdgeInsets(left: 20, right: 20), interactionType:.deletable(onRemove: { peerId in
                            arguments.revokePeerId(peerId)
                        }, deletable: true), viewType: item.viewType)
                    }))
                }
            } else {
                entries.append(.desc(sectionId: sectionId, index: 100, text: .plain(strings().createGroupRequiresUsernameHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                index += 1

                
                entries.append(.input(sectionId: sectionId, index: 200, value: .string(state.editingPublicLinkText), error: state.errors[_id_username], identifier: _id_username, mode: .plain, data: .init(viewType: .singleItem, defaultText: "t.me/"), placeholder: nil, inputPlaceholder: strings().createGroupRequiresUsernamePlaceholder, filter: { value in
                    return value
                }, limit: 30))
                
                if let status = state.addressNameValidationStatus, let addressName = state.editingPublicLinkText {
                    
                    var text:String = ""
                    var color:NSColor = theme.colors.listGrayText
                    
                    switch status {
                    case let .invalidFormat(format):
                        text = format.description
                        color = theme.colors.redUI
                    case let .availability(availability):
                        text = availability.description(for: addressName, target: .channel)
                        switch availability {
                        case .available:
                            color = theme.colors.listGrayText
                        case .purchaseAvailable:
                            color = theme.colors.listGrayText
                        default:
                            color = theme.colors.redUI
                        }
                    case .checking:
                        text = strings().channelVisibilityChecking
                        color = theme.colors.listGrayText
                    }
                    
                    entries.append(.desc(sectionId: sectionId, index: 300, text: .markdown(text, linkHandler: { link in
                        if link == "fragment" {
                            let link: String = "fragment.com/username/\(addressName)"
                            execute(inapp: inApp(for: link.nsstring))
                        }
                    }), data: .init(color: color, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(5, 16, 0, 0)))))

                } else {
                    entries.append(.desc(sectionId: sectionId, index: 400, text: .plain(strings().createGroupRequiresUsernameInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
                }
            }

            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
        
        if state.requires.contains(.forum) {
            entries.append(.general(sectionId: sectionId, index: 500, value: .none, error: nil, identifier: _id_forum, data: .init(name: strings().peerInfoForum, color: theme.colors.text, icon: theme.icons.profile_group_topics, type: .switchable(true), viewType: .singleItem, enabled: false, disabledAction: arguments.forumAlert)))
            
            entries.append(.desc(sectionId: sectionId, index: 600, text: .plain(strings().peerInfoForumInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))

            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }
    
    if let privacy = state.privacy, let _ = privacy.messageAutoremoveTimeout {
        let timeout = state.autoremoveTimeout ?? privacy.messageAutoremoveTimeout
        if let timeout = timeout {
            let text = timeout == 0 ? strings().privacySettingsGlobalTimerNever : timeIntervalString(Int(timeout))
            
            
            let timeoutAction:(Int32)->Void = { value in
                arguments.setupGlobalAutoremove(value)
            }
            
            let timeoutValues: [Int32] = [
                1 * 24 * 60 * 60,
                2 * 24 * 60 * 60,
                3 * 24 * 60 * 60,
                4 * 24 * 60 * 60,
                5 * 24 * 60 * 60,
                6 * 24 * 60 * 60,
                7 * 24 * 60 * 60,
                14 * 24 * 60 * 60,
                21 * 24 * 60 * 60,
                1 * 30 * 24 * 60 * 60,
                3 * 30 * 24 * 60 * 60,
                180 * 24 * 60 * 60,
                365 * 24 * 60 * 60
            ]
            var items: [ContextMenuItem] = []

                        
            if timeout > 0 {
                items.append(ContextMenuItem(strings().privacySettingsGlobalTimerDisable, handler: {
                    timeoutAction(0)
                }))
            }
            
            for timeoutValue in timeoutValues {
                items.append(ContextMenuItem(timeIntervalString(Int(timeoutValue)), handler: {
                    timeoutAction(timeoutValue)
                }))
            }
            entries.append(.general(sectionId: sectionId, index: 700, value: .none, error: nil, identifier: _id_timer, data: .init(name: strings().privacySettingsGlobalTimer, color: theme.colors.text, type: .contextSelector(text, items), viewType: .singleItem)))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: 800, text: .plain(strings().privacySettingsGlobalTimerGroup), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
        }
    }
    
    let peers = state.peerIds.compactMap {
        view.peers[$0]
    }
    
    struct TuplePeer: Equatable {
        let peer: PeerEquatable
        let viewType: GeneralViewType
        let status: String
        let color: NSColor
    }
    let stableIndex:(PeerId)->Int32 = { peerId in
        var index: Int32 = 10000
        for peer in peers {
            if peer.id == peerId {
                return index
            }
            index += 1
        }
        return index
    }
    
    if peers.count < 200 {
        entries.append(.general(sectionId: sectionId, index: 900, value: .none, error: nil, identifier: _id_add, data: .init(name: strings().peerInfoAddMember, color: theme.colors.accent, icon: theme.icons.peerInfoAddMember, viewType: peers.isEmpty ? .singleItem : .firstItem, action: arguments.addMembers)))
        index += 1
        
        if let error = state.errors[_id_add] {
            entries.append(.desc(sectionId: sectionId, index: 1000, text: .plain(error.description), data: .init(color: theme.colors.redUI, viewType: .textBottomItem)))
            index += 1
        }
    }
    
    var items: [TuplePeer] = []
    for (i, peer) in peers.enumerated() {
        var color:NSColor = theme.colors.grayText
        var string:String = peer.isBot ? strings().presenceBot : strings().peerStatusRecently
        if let presence = view.presences[peer.id] as? TelegramUserPresence, !peer.isBot {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
        }
        let viewType: GeneralViewType
        if i == 0 {
            if peers.count == 1 {
                viewType = .lastItem
            } else {
                viewType = .innerItem
            }
        } else {
            viewType = bestGeneralViewType(items, for: i)
        }
        items.append(.init(peer: .init(peer), viewType: viewType, status: string, color: color))
    }
    for item in items {
        entries.append(.custom(sectionId: sectionId, index: stableIndex(item.peer.peer.id), value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
            
            let interactionType: ShortPeerItemInteractionType = .plain
            
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, height: 50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: item.color), status: item.status, inset:NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, generalType: .nextContext(""), viewType: item.viewType, contextMenuItems: {
                
                var items: [ContextMenuItem] = []
                
                items.append(.init(strings().contextRemove, handler: {
                    arguments.deletePeer(item.peer.peer.id)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                
                return .single(items)
            })
        }))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


class CreateGroupViewController: ComposeViewController<CreateGroupStateResult, [PeerId], TableView> {
    
    private let disposable:MetaDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let statePromise: ValuePromise<State>
    private let stateValue: Atomic<State>
    private func updateState(_ f: (State) -> State) {
        statePromise.set(stateValue.modify { f($0) })
    }
    

    private let defaultText: String
    
    init(titles: ComposeTitles, context: AccountContext, defaultText: String = "", requires: CreateGroupRequires = []) {
        self.defaultText = defaultText
        let initialState = State(text: defaultText, requires: requires)
        
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)
        self.stateValue = Atomic(value: initialState)

        super.init(titles: titles, context: context)
    }
    
    override func restart(with result: ComposeState<[PeerId]>) {
        super.restart(with: result)
        assert(isLoaded())
        let initialSize = self.atomicSize
        let stateValue = self.stateValue
        let context = self.context
        let updateState = self.updateState
        let actionsDisposable = self.actionsDisposable
        
        let checkAddressNameDisposable = MetaDisposable()
        actionsDisposable.add(checkAddressNameDisposable)
        
        let revokeAddressNameDisposable = MetaDisposable()
        actionsDisposable.add(revokeAddressNameDisposable)
        
        updateState { current in
            var current = current
            current.peerIds = result.result
            return current
        }
        
        if self.defaultText == "" && result.result.count < 5 {
            let peers: Signal<String, NoError> = context.account.postbox.transaction { transaction in
                let main = transaction.getPeer(context.peerId)
                
                let rest = result.result
                .map {
                    transaction.getPeer($0)
                }
                .compactMap { $0 }
                .map { $0.compactDisplayTitle }
                .joined(separator: ", ")
                
                if let main = main, !rest.isEmpty {
                    return main.compactDisplayTitle + " & " + rest
                } else {
                    return ""
                }
                
            } |> deliverOnMainQueue
            
            _ = peers.start(next: { [weak self] title in
                updateState { current in
                    var current = current
                    current.text = title
                    return current
                }
                delay(0.2, closure: { [weak self] in
                    self?.genericView.enumerateItems(with: { item in
                        if let item = item as? GroupNameRowItem {
                            let textView = item.view?.firstResponder as? NSTextView
                            textView?.selectAll(nil)
                            return false
                        }
                        return true
                    })
                })
                
            })
        }
        let previous:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value:[])

        let arguments = Arguments(context: context, choicePicture: { select in
            if select {
                
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: context.window, animationType: .scaleCenter)
                            
                            let signal = controller.result
                            |> map { Optional($0.0.path) }
                            |> deliverOnMainQueue
                            
                            _ = signal.start(next: { value in
                                updateState { current in
                                    var current = current
                                    current.picture = value
                                    return current
                                }
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
                
            } else {
                updateState { current in
                    var current = current
                    current.picture = nil
                    return current
                }
            }
            
        }, updatedText: { text in
            updateState { current in
                var current = current
                current.text = text
                return current
            }
        }, setupGlobalAutoremove: { timeout in
            updateState { current in
                var current = current
                current.autoremoveTimeout = timeout
                return current
            }
        }, deletePeer: { peerId in
            updateState { current in
                var current = current
                current.peerIds.removeAll(where: {
                    $0 == peerId
                })
                return current
            }
        }, addMembers: {
            actionsDisposable.add(selectModalPeers(window: context.window, context: context, title: strings().composeSelectUsers, settings: [.contacts, .remote], excludePeerIds: stateValue.with { $0.peerIds }).start(next: { peerIds in
                updateState { current in
                    var current = current
                    current.peerIds.append(contentsOf: peerIds)
                    current.errors.removeValue(forKey: _id_add)
                    return current
                }
            }))
        }, revokePeerId: { peerId in
            revokeAddressNameDisposable.set((verifyAlertSignal(for: context.window, information: strings().channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
                if result == nil {
                    return .fail(.generic)
                } else {
                    return .single(true)
                }
            } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
                return context.engine.peers.updateAddressName(domain: .peer(peerId), name: nil)
            } |> deliverOnMainQueue).start(error: { _ in
                updateState { current in
                    var current = current
                    current.revokingPeerId = nil
                    return current
                }
            }, completed: {
                updateState { current in
                    var current = current
                    current.revokingPeerId = nil
                    current.publicChannelsToRevoke = nil
                    return current
                }
            }))
        }, forumAlert: {
            showModalText(for: context.window, text: strings().createChannelForumError)
        })
        
        let privacy:Signal<AccountPrivacySettings?, NoError> = .single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init))

        actionsDisposable.add(privacy.start(next: { privacy in
            updateState { current in
                var current = current
                current.privacy = privacy
                return current
            }
        }))
        
        let addressNameAssignment: Signal<[Peer]?, NoError> = .single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
            if case .addressNameLimitReached = result {
                return context.engine.peers.adminedPublicChannels()
                |> map { Optional($0.map { $0.peer._asPeer() } ) }
            } else {
                return .single(nil)
            }
        })

        
        actionsDisposable.add(addressNameAssignment.start(next: { peers in
            updateState { current in
                var current = current
                if peers?.isEmpty == false, current.requires.contains(.username) {
                    current.publicChannelsToRevoke = peers?.compactMap {
                        .init($0)
                    }
                } else {
                    current.publicChannelsToRevoke = nil
                }
                
                return current
            }
        }))
        
        
        
        let inputDataArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: { [weak self] in
            guard let tableView = self?.genericView else {
                return
            }
            let input = tableView.item(stableId: InputDataEntryId.input(_id_username)) as? InputDataRowItem
            let text = input?.currentText.string ?? ""
            let currentAddress = stateValue.with { $0.editingPublicLinkText }
            if text.length < 5 {
                checkAddressNameDisposable.set(nil)
                updateState { current in
                    var current = current
                    current.editingPublicLinkText = text
                    current.addressNameValidationStatus = nil
                    return current
                }
            } else if currentAddress != text {
                updateState { current in
                    var current = current
                    current.editingPublicLinkText = text
                    return current
                }
                checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(.init(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(0))), name: text) |> deliverOnMainQueue).start(next: { result in
                    updateState { current in
                        var current = current
                        current.addressNameValidationStatus = result
                        return current
                    }
                }))
            }
            updateState { current in
                var current = current
                current.errors.removeValue(forKey: _id_username)
                return current
            }
        })
        
        let multiplePeerView = statePromise.get() |> mapToSignal { state in
            return context.account.postbox.multiplePeersView(state.peerIds)
        }
        
        let signal:Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, multiplePeerView, appearanceSignal, self.statePromise.get()) |> mapToQueue { view, appearance, state in
            let list = entries(view, state: state, arguments: arguments).map {
                AppearanceWrapperEntry(entry: $0, appearance: appearance)
            }
            let previous = previous.swap(list)
            return prepareInputDataTransition(left: previous, right: list, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputDataArguments, onMainQueue: false, animateEverything: true, grouping: false)
            
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    private var firstTake: Bool = true
    override func firstResponder() -> NSResponder? {
        
        if firstTake {
            if let view = genericView.viewNecessary(at: 1) as? GroupNameRowView {
                firstTake = false
                return view.textView
            }
        }
        return window?.firstResponder
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    deinit {
        disposable.dispose()
        actionsDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
    }
    
    override func executeNext() -> Void {
        let state = stateValue.with { $0 }
        let result = CreateGroupStateResult(title: state.text, picture: state.picture, peerIds: state.peerIds, autoremoveTimeout: state.autoremoveTimeout, username: state.editingPublicLinkText, isForum: state.requires.contains(.forum))
        if result.title.isEmpty {
            genericView.item(stableId: InputDataEntryId.custom(_id_info))?.view?.shakeView()
        } else if state.publicChannelsToRevoke != nil, state.requires.contains(.username) {
            showModalText(for: context.window, text: strings().createChannelUsernameError)
        } else if state.requires.contains(.username), state.addressNameValidationStatus != .availability(.available) {
            genericView.item(stableId: InputDataEntryId.input(_id_username))?.view?.shakeView()
        } else {
            onComplete.set(.single(result))
        }
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    
    
}
