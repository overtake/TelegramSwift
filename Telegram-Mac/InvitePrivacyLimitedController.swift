//
//  InvitePrivacyLimitedController.swift
//  Telegram
//
//  Created by Mike Renoir on 10.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TGUIKit
import TelegramCore
import Postbox

private final class InviteViaLinkHeaderItem : GeneralRowItem {
    let textLayout: TextViewLayout
    init(_ initialSize: NSSize, peers: [Peer], cantInvite: Bool, stableId: AnyHashable, viewType: GeneralViewType) {
        
        let text: String
        if cantInvite {
            if peers.count == 1 {
                text = strings().inviteFailedTextCantSingle(peers[0].compactDisplayTitle)
            } else {
                text = strings().inviteFailedTextCantMultipleCountable(peers.count)
            }
        } else {
            if peers.count == 1 {
                text = strings().inviteFailedTextSingle(peers[0].compactDisplayTitle)
            } else {
                text = strings().inviteFailedTextMultipleCountable(peers.count)
            }
        }
        
        
        self.textLayout = .init(.initialize(string: text, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 40 + 10 + self.textLayout.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return InviteViaLinkHeaderView.self
    }
}

private final class InviteViaLinkHeaderView : GeneralContainableRowView {
    private let textView = TextView()
    private let button = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(button)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        button.userInteractionEnabled = false
    }
    
    override func layout() {
        super.layout()
        
        button.layer?.cornerRadius = button.frame.height / 2
        button.centerX(y: 0)
        textView.centerX(y: button.frame.maxY + 10)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InviteViaLinkHeaderItem else {
            return
        }
        textView.update(item.textLayout)
        
        button.autohighlight = false
        button.set(image: NSImage(named: "Icon_ExportedInvitation_Link")!.precomposed(theme.colors.underSelectedColor), for: .Normal)
        button.set(background: theme.colors.accent, for: .Normal)
        button.sizeToFit(.zero, NSMakeSize(60, 40), thatFit: true)
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class Arguments {
    let context: AccountContext
    let select: SelectPeerInteraction
    init(context: AccountContext, select: SelectPeerInteraction) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    let peerId: PeerId
    let peers: [PeerEquatable]
    var peer: PeerEquatable?
    var cachedData: CachedDataEquatable?
    
    var canInvite: Bool {
        var link: String?
        if let data = self.cachedData?.data as? CachedGroupData {
            link = data.exportedInvitation?.link
        } else if let data = self.cachedData?.data as? CachedChannelData {
            link = data.exportedInvitation?.link
        }
        return link != nil
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .customModern(10)))
//    sectionId += 1
    
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return InviteViaLinkHeaderItem(initialSize, peers: state.peers.map { $0.peer }, cantInvite: !state.canInvite, stableId: stableId, viewType: .legacy)
    }))
    index += 1
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
    }
    
    var items: [Tuple] = []
    
    for (i, peer) in state.peers.enumerated() {
        items.append(.init(peer: peer, selected: arguments.select.presentation.selected.contains(peer.peer.id), viewType: bestGeneralViewType(state.peers, for: i), selectable: state.canInvite))
    }
    
    for item in items {
        
        let interactionType: ShortPeerItemInteractionType
        if item.selectable {
            interactionType = .selectable(arguments.select, side: .right)
        } else {
            interactionType = .plain
        }
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, viewType: item.viewType)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    
    return entries
}

func InvitePrivacyLimitedController(context: AccountContext, peerId: PeerId, peers:[Peer]) -> InputDataModalController {
    
    let peers: [PeerEquatable] = peers.compactMap { $0 }.map { .init($0) }

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    let initialState = State(peerId: peerId, peers: peers)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let selected = SelectPeerInteraction()
    for peer in peers {
        selected.toggleSelection(peer.peer)
    }

    let arguments = Arguments(context: context, select: selected)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
   
    let controller = InputDataController(dataSignal: signal, title: strings().inviteFailedTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    let data = combineLatest(queue: .mainQueue(), getPeerView(peerId: peerId, postbox: context.account.postbox), getCachedDataView(peerId: peerId, postbox: context.account.postbox))

    actionsDisposable.add(data.start(next: { peer, cachedData in
        updateState { current in
            var current = current
            current.peer = .init(peer)
            current.cachedData = .init(cachedData)
            return current
        }
    }))
    
   
    controller.validateData = { _ in
                
        return .fail(.doSomething(next: { f in
            
            if stateValue.with({ $0.canInvite }) {
                let data = stateValue.with { $0.cachedData?.data }
                let peer = stateValue.with { $0.peer?.peer }

                var link: String?
                if let data = data as? CachedGroupData {
                    link = data.exportedInvitation?.link
                } else if let data = data as? CachedChannelData {
                    link = data.exportedInvitation?.link
                }
                
                if link == nil, let addressName = peer?.addressName {
                    link = "https://t.me/\(addressName)"
                }
                if let link = link {
                    let combine = peers.filter {
                        selected.presentation.selected.contains($0.peer.id)
                    }.map {
                        return enqueueMessages(account: context.account, peerId: $0.peer.id, messages: [EnqueueMessage.message(text: link, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                    }
                    _ = combineLatest(combine).start()
                    
                    delay(0.2, closure: {
                        _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 0.3).start()
                    })
                }
            }
        
            close?()
            f(.none)
        }))
        
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().inviteFailedOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)

    arguments.select.singleUpdater = { [weak modalInteractions] updated in
        modalInteractions?.updateDone { title in
            if stateValue.with({ $0.canInvite }) {
                title.set(text: updated.selected.isEmpty ? strings().inviteFailedSkip : strings().inviteFailedOK, for: .Normal)
            } else {
                title.set(text: strings().modalOK, for: .Normal)
            }
        }
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }

    return modalController
}




func showInvitePrivacyLimitedController(context: AccountContext, peerId: PeerId, ids:[PeerId]) {
    let peers:Signal<[Peer], NoError> = context.account.postbox.transaction { transaction in
        var peers: [Peer?] = []
        for id in ids {
            peers.append(transaction.getPeer(id))
        }
        return peers.compactMap { $0 }
    } |> deliverOnMainQueue
    
    _ = peers.start(next: { peers in
        showModal(with: InvitePrivacyLimitedController(context: context, peerId: peerId, peers: peers), for: context.window)
    })
    
}
