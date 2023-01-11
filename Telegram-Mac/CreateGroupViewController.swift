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
    init(context: AccountContext, choicePicture:@escaping(Bool)->Void, updatedText:@escaping(String)->Void, setupGlobalAutoremove:@escaping(Int32)->Void, deletePeer:@escaping(PeerId)->Void, addMembers:@escaping()->Void) {
        self.context = context
        self.updatedText = updatedText
        self.choicePicture = choicePicture
        self.setupGlobalAutoremove = setupGlobalAutoremove
        self.deletePeer = deletePeer
        self.addMembers = addMembers
    }
}

struct CreateGroupResult {
    let title:String
    let picture: String?
    let peerIds:[PeerId]
    let autoremoveTimeout: Int32?
}

private struct State : Equatable {
    var picture: String?
    var text: String = ""
    var autoremoveTimeout: Int32?
    var privacy: AccountPrivacySettings?
    var editable: Bool = true
    var peerIds:[PeerId] = []
    var errors:[InputDataIdentifier : InputDataValueError] = [:]
}

private let _id_info = InputDataIdentifier("_id_info")
private let _id_timer = InputDataIdentifier("_id_timer")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}
private let _id_add = InputDataIdentifier("_id_add")

private func entries(_ view: MultiplePeersView, state: State, arguments: Arguments) -> [InputDataEntry] {
        
    var entries:[InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return GroupNameRowItem(initialSize, stableId:stableId, account: arguments.context.account, placeholder: strings().createGroupNameHolder, photo: state.picture, viewType: .singleItem, text: state.text, limit: 140, textChangeHandler: arguments.updatedText, pickPicture: arguments.choicePicture)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
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
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_timer, data: .init(name: strings().privacySettingsGlobalTimer, color: theme.colors.text, type: .contextSelector(text, items), viewType: .singleItem)))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().privacySettingsGlobalTimerGroup), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
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
        let editable: Bool
        let deletable: Bool
        let status: String
        let color: NSColor
    }
    let stableIndex:(PeerId)->Int32 = { peerId in
        var index: Int32 = 100
        for peer in peers {
            if peer.id == peerId {
                return index
            }
            index += 1
        }
        return index
    }
    
    if peers.count < 200 {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add, data: .init(name: strings().peerInfoAddMember, color: theme.colors.accent, icon: theme.icons.peerInfoAddMember, viewType: peers.isEmpty ? .singleItem : .firstItem, action: arguments.addMembers)))
        index += 1
        
        if let error = state.errors[_id_add] {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error.description), data: .init(color: theme.colors.redUI, viewType: .textBottomItem)))
            index += 1
        }
    }
    
    var items: [TuplePeer] = []
    for (i, peer) in peers.enumerated() {
        var color:NSColor = theme.colors.grayText
        var string:String = strings().peerStatusRecently
        if let presence = view.presences[peer.id] as? TelegramUserPresence {
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
        items.append(.init(peer: .init(peer), viewType: viewType, editable: peers.count > 1, deletable: peers.count > 1, status: string, color: color))
    }
    for item in items {
        entries.append(.custom(sectionId: sectionId, index: stableIndex(item.peer.peer.id), value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
            
            let interactionType: ShortPeerItemInteractionType = .plain
            
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, height: 50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: item.color), status: item.status, inset:NSEdgeInsets(left: 30, right:30), interactionType: interactionType, generalType: .nextContext(""), viewType: item.viewType, contextMenuItems: {
                
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


class CreateGroupViewController: ComposeViewController<CreateGroupResult, [PeerId], TableView> {
    private let disposable:MetaDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let statePromise: ValuePromise<State>
    private let stateValue: Atomic<State>
    private func updateState(_ f: (State) -> State) {
        statePromise.set(stateValue.modify { f($0) })
    }
    

    private let defaultText: String
    
    init(titles: ComposeTitles, context: AccountContext, defaultText: String = "") {
        self.defaultText = defaultText
        let initialState = State(text: defaultText)
        
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
        })
        
        let privacy:Signal<AccountPrivacySettings?, NoError> = .single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init))

        actionsDisposable.add(privacy.start(next: { privacy in
            updateState { current in
                var current = current
                current.privacy = privacy
                return current
            }
        }))
        
        let inputDataArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
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
    
    override func firstResponder() -> NSResponder? {
        if let view = genericView.viewNecessary(at: 1) as? GroupNameRowView {
            return view.textView
        }
        return nil
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
        let result = CreateGroupResult(title: state.text, picture: state.picture, peerIds: state.peerIds, autoremoveTimeout: state.autoremoveTimeout)
        if result.title.isEmpty {
            genericView.item(stableId: InputDataEntryId.custom(_id_info))?.view?.shakeView()
        } else if result.peerIds.isEmpty {
            genericView.item(stableId: InputDataEntryId.general(_id_add))?.view?.shakeView()
            updateState { current in
                var current = current
                current.errors[_id_add] = .init(description: strings().createGroupAddMemberError, target: .data)
                return current
            }
        } else {
            onComplete.set(.single(result))
        }
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    
    
}
