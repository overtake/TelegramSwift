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


fileprivate final class CreateGroupArguments {
    let context: AccountContext
    let choicePicture:(Bool)->Void
    let updatedText:(String)->Void
    let setupGlobalAutoremove:(AccountPrivacySettings?)->Void
    init(context: AccountContext, choicePicture:@escaping(Bool)->Void, updatedText:@escaping(String)->Void, setupGlobalAutoremove:@escaping(AccountPrivacySettings?)->Void) {
        self.context = context
        self.updatedText = updatedText
        self.choicePicture = choicePicture
        self.setupGlobalAutoremove = setupGlobalAutoremove
    }
}

fileprivate enum CreateGroupEntry : Comparable, Identifiable {
    case info(Int32, String?, String, GeneralViewType)
    case timer(Int32, Int32, AccountPrivacySettings?, GeneralViewType)
    case timerInfo(Int32, GeneralViewType)
    case peer(Int32, Peer, Int32, PeerPresence?, GeneralViewType)
    case section(Int32)
    fileprivate var stableId:AnyHashable {
        switch self {
        case .info:
            return -3
        case .timer:
            return -2
        case .timerInfo:
            return -1
        case let .peer(_, peer, _, _, _):
            return peer.id
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .info(sectionId, _, _, _):
            return (sectionId * 1000) + 0
        case let .timer(sectionId, _, _, _):
            return (sectionId * 1000) + 1
        case let .timerInfo(sectionId, _):
            return (sectionId * 1000) + 2
        case let .peer(sectionId, _, index, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
             return (sectionId + 1) * 1000 - sectionId
        }
    }
}

fileprivate func ==(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    switch lhs {
    case let .info(section, photo, text, viewType):
        if case .info(section, photo, text, viewType) = rhs {
            return true
        } else {
            return false
        }
    case let .timer(section, timer, privacy, viewType):
        if case .timer(section, timer, privacy, viewType) = rhs {
            return true
        } else {
            return false
        }
    case let .timerInfo(section, viewType):
        if case .timerInfo(section, viewType) = rhs {
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
    case let .peer(sectionId, lhsPeer, index, lhsPresence, viewType):
        if case .peer(sectionId, let rhsPeer, index, let rhsPresence, viewType) = rhs {
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
            } else if (lhsPresence != nil) != (rhsPresence != nil) {
                return false
            }
            return lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    }
}

fileprivate func <(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    return lhs.index < rhs.index
}

struct CreateGroupResult {
    let title:String
    let picture: String?
    let peerIds:[PeerId]
    let autoremoveTimeout: Int32?
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<CreateGroupEntry>], to:[AppearanceWrapperEntry<CreateGroupEntry>], arguments: CreateGroupArguments, initialSize:NSSize, animated:Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
            
            switch entry.entry {
            case let .info(_, photo, currentText, viewType):
                return GroupNameRowItem(initialSize, stableId:entry.stableId, account: arguments.context.account, placeholder: strings().createGroupNameHolder, photo: photo, viewType: viewType, text: currentText, limit:140, textChangeHandler: arguments.updatedText, pickPicture: arguments.choicePicture)
            case let .timer(_, time, privacy, viewType):
                let text = time == 0 ? strings().privacySettingsGlobalTimerNever : timeIntervalString(Int(time))
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().privacySettingsGlobalTimer, type: .context(text), viewType: viewType, action: {
                    arguments.setupGlobalAutoremove(privacy)
                })
            case let .timerInfo(_, viewType):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: strings().privacySettingsGlobalTimerGroup, viewType: viewType)
            case let .peer(_, peer, _, presence, viewType):
                
                var color:NSColor = theme.colors.grayText
                var string:String = strings().peerStatusRecently
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
                }
                return  ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, height:50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: color), status: string, inset:NSEdgeInsets(left: 30, right:30), viewType: viewType)
            case .section:
                return GeneralRowItem(initialSize, height: 30, stableId: entry.stableId, viewType: .separator)
            }
        })
        
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state:.none(nil))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}


private struct State : Equatable {
    var picture: String?
    var text: String = ""
    var autoremoveTimeout: Int32?
}

private func createGroupEntries(_ view: MultiplePeersView, privacy: AccountPrivacySettings?, state: State, appearance: Appearance) -> [AppearanceWrapperEntry<CreateGroupEntry>] {
    
    
    var entries:[CreateGroupEntry] = []
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    entries.append(.info(sectionId, state.picture, state.text, .singleItem))

    entries.append(.section(sectionId))
    sectionId += 1
    
    if let privacy = privacy, let _ = privacy.messageAutoremoveTimeout {
        let timeout = state.autoremoveTimeout ?? privacy.messageAutoremoveTimeout
        if let timeout = timeout {
            entries.append(.timer(sectionId, timeout, privacy, .singleItem))
            entries.append(.timerInfo(sectionId, .textBottomItem))
        }
    }
    

    entries.append(.section(sectionId))
    sectionId += 1
    
    var index:Int32 = 0
    let peers = view.peers.map({$1})
    for (i, peer) in peers.enumerated() {
        entries.append(.peer(sectionId, peer, index, view.presences[peer.id], bestGeneralViewType(peers, for: i)))
        index += 1
    }
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
}


class CreateGroupViewController: ComposeViewController<CreateGroupResult, [PeerId], TableView> { // Title, photo path
    private let entries:Atomic<[AppearanceWrapperEntry<CreateGroupEntry>]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
   
    
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
        let table = self.genericView
        let stateValue = self.stateValue
        let context = self.context
        let updateState = self.updateState
        
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

        let entries = self.entries
        let arguments = CreateGroupArguments(context: context, choicePicture: { select in
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
        }, setupGlobalAutoremove: { [weak self] privacy in
            
            let timeoutAction:(Int32)->Void = { value in
                updateState { current in
                    var current = current
                    current.autoremoveTimeout = value
                    return current
                }
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

            
            let value = stateValue.with { $0.autoremoveTimeout } ?? privacy?.messageAutoremoveTimeout
            
            if let value = value, value > 0 {
                items.append(ContextMenuItem(strings().privacySettingsGlobalTimerDisable, handler: {
                    timeoutAction(0)
                }))
            }
            
            for timeoutValue in timeoutValues {
                items.append(ContextMenuItem(timeIntervalString(Int(timeoutValue)), handler: {
                    timeoutAction(timeoutValue)
                }))
            }

            let stableId = CreateGroupEntry.timer(0, 0, nil, .singleItem).stableId
            
            if let index = self?.genericView.index(hash: stableId) {
                if let view = (self?.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                    if let event = NSApp.currentEvent {
                        let menu = ContextMenu()
                        for item in items {
                            menu.addItem(item)
                        }
                        let value = AppMenu(menu: menu)
                        value.show(event: event, view: view)
                    }
                }
            }
        })
        
        let privacy:Signal<AccountPrivacySettings?, NoError> = .single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init))

        
        let signal:Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, context.account.postbox.multiplePeersView(result.result), appearanceSignal, self.statePromise.get(), privacy) |> mapToQueue { view, appearance, state, privacy in
            let list = createGroupEntries(view, privacy: privacy, state: state, appearance: appearance)
           
            return prepareEntries(from: entries.swap(list), to: list, arguments: arguments, initialSize: initialSize.modify({$0}), animated: true)
            
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { (transition) in
            table.merge(with: transition)
            //table.reloadData()
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
        _ = entries.swap([])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        readyOnce()
    }
    
    override func executeNext() -> Void {
        if let previousResult = previousResult {
            let result = statePromise.get()
            |> take(1)
            |> map {
                return CreateGroupResult(title: $0.text, picture: $0.picture, peerIds: previousResult.result, autoremoveTimeout: $0.autoremoveTimeout)
            }
            onComplete.set(result |> filter {
                !$0.title.isEmpty
            })
        }
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    
    
}
