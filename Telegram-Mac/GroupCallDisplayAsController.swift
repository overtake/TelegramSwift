//
//  GroupCallDisplayAsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore


private final class DisplayMeAsHeaderItem : GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable) {
        textLayout = .init(.initialize(string: L10n.displayMeAsText, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)
        super.init(initialSize, stableId: stableId)
    }
    override var height: CGFloat {
        return textLayout.layoutSize.height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 60)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return DisplayMeAsHeaderView.self
    }
}

private final class DisplayMeAsHeaderView : TableRowView {
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? DisplayMeAsHeaderItem else {
            return
        }
        textView.update(item.textLayout)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class Arguments {
    let context: AccountContext
    let select:(PeerId)->Void
    init(context: AccountContext, select:@escaping(PeerId)->Void) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    var peer: PeerEquatable?
    var list: [FoundPeer]?
    var selected: PeerId
}

private func _id_peer(_ id:PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, item: { initialSize, stableId in
        return DisplayMeAsHeaderItem(initialSize, stableId: stableId)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    struct Tuple : Equatable {
        let peer: FoundPeer
        let viewType: GeneralViewType
        let selected: Bool
        let status: String?
    }
    
    if let peer = state.peer {
        let tuple = Tuple(peer: FoundPeer(peer: peer.peer, subscribers: nil), viewType: state.list == nil || state.list?.isEmpty == false ? .firstItem : .singleItem, selected: peer.peer.id == state.selected, status: L10n.displayMeAsPersonalAccount)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("self"), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 30, right: 30), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                arguments.select(tuple.peer.peer.id)
            })
        }))
        index += 1
    }
    
    if let list = state.list {
        
        if !list.isEmpty {
            //TODOLANG
            for peer in list {
                
                var status: String?
                if let subscribers = peer.subscribers {
                    if peer.peer.isChannel {
                        status = L10n.voiceChatJoinAsChannelCountable(Int(subscribers))
                    } else if peer.peer.isSupergroup || peer.peer.isGroup {
                        status = L10n.voiceChatJoinAsGroupCountable(Int(subscribers))
                    }
                } else {
                    status = L10n.chatChannelBadge
                }
                
                var viewType = bestGeneralViewType(list, for: peer)
                if list.first == peer {
                    if list.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                }
                
                let tuple = Tuple(peer: peer, viewType: viewType, selected: peer.peer.id == state.selected, status: status)
                
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.peer.id), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 30, right: 30), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                        arguments.select(tuple.peer.peer.id)
                    })

                }))
            }
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
        }))
        index += 1
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum GroupCallDisplayAsMode {
    case join
    case create
}

func GroupCallDisplayAsController(context: AccountContext, mode: GroupCallDisplayAsMode, peerId: PeerId, list:[FoundPeer], completion: @escaping(PeerId)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    let initialState = State(list: list, selected: context.peerId)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = Arguments(context: context, select: { peerId in
        updateState { current in
            var current = current
            current.selected = peerId
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
        
    let list: Signal<[FoundPeer]?, NoError> = cachedGroupCallDisplayAsAvailablePeers(account: context.account, peerId: peerId) |> map(Optional.init)
    let peerSignal = context.account.postbox.loadedPeerWithId(context.peerId)
    
    actionsDisposable.add(combineLatest(list, peerSignal).start(next: { list, peer in
        updateState { current in
            var current = current
            current.list = list
            current.peer = PeerEquatable(peer)
            return current
        }
    }))
    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: L10n.displayMeAsTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    controller.validateData = { _ in
        let selected = stateValue.with { $0.selected }
        completion(selected)
        close?()
        return .none
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: "", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone { button in
            let title: String = stateValue.with { value in
                let peer = value.list?.first(where: { $0.peer.id == value.selected })?.peer ?? value.peer?.peer
                return peer?.compactDisplayTitle ?? ""
            }
            button.set(text: L10n.displayMeAsContinueAs(title), for: .Normal)
        }
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


func selectGroupCallJoiner(context: AccountContext, peerId: PeerId, completion: @escaping(PeerId)->Void) {
    _ = showModalProgress(signal: cachedGroupCallDisplayAsAvailablePeers(account: context.account, peerId: peerId), for: context.window).start(next: { displayAsList in
        if !displayAsList.isEmpty {
            showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: completion), for: context.window)
        } else {
            completion(context.peerId)
        }
    })
}

/*
 
 */



