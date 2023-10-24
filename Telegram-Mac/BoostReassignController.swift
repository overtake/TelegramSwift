//
//  BoostReassignController.swift
//  Telegram
//
//  Created by Mike Renoir on 20.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class ReassignHeaderRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peer: Peer
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer) {
        self.context = context
        self.peer = peer
        let text = NSMutableAttributedString()
        let boosts_per_sent_gift = context.appConfiguration.getGeneralValue("boosts_per_sent_gift", orElse: 3)
        text.append(string: strings().boostReassignInfo(peer.displayTitle, "\(boosts_per_sent_gift)"), color: theme.colors.text, font: .normal(.text))
        text.detectBoldColorInString(with: .medium(.text))
        textLayout = .init(text, alignment: .center)
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 40)
        return true
    }
    
    override var height: CGFloat {
        return 60 + 20 + textLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return ReassignHeaderRowView.self
    }
}

private final class ReassignHeaderRowView : TableRowView {
    private let textView = TextView()
    private let avatar = AvatarControl(font: .avatar(15))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(60, 60))
        addSubview(avatar)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ReassignHeaderRowItem else {
            return
        }
        
        textView.update(item.textLayout)
        avatar.setPeer(account: item.context.account, peer: item.peer)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        avatar.centerX(y: 0)
        textView.centerX(y: avatar.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class Arguments {
    let context: AccountContext
    let toggle:(State.Key)->Void
    init(context: AccountContext, toggle:@escaping(State.Key)->Void) {
        self.context = context
        self.toggle = toggle
    }
}

private struct State : Equatable {
    
    struct Key : Hashable {
        let peerId: PeerId
        let slot: Int32
    }
    
    var peer: PeerEquatable
    var boosts: [MyBoostStatus.Boost]
    var selected: Set<Key> = Set()
    var currentTime: Int32 = Int32(Date().timeIntervalSince1970)
}

private let _id_header: InputDataIdentifier = .init("_id_header")
private func _id_peer(_ id: PeerId, slot: Int32) -> InputDataIdentifier {
    return .init("_peer_\(id.toInt64())_\(slot)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return ReassignHeaderRowItem(initialSize, stableId: stableId, context: arguments.context, peer: state.peer.peer)
    }))
    // entries
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let activeList = state.boosts.filter { $0.peer != nil }
    
    struct Tuple : Equatable {
        let boost: MyBoostStatus.Boost
        let viewType: GeneralViewType
        let selected: Bool
        let subtitle: String
        let enabled: Bool
    }
    var items: [Tuple] = []
    for (i, active) in activeList.enumerated() {
        let subtitle: String
        if let cooldownUntil = active.cooldownUntil, cooldownUntil > state.currentTime {
            let duration = cooldownUntil - state.currentTime
            let durationValue = stringForDuration(duration)
            subtitle = strings().boostReassignStatusAvailableIn(durationValue)
        } else {
            let expiresValue = stringForFullDate(timestamp: active.expires)
            subtitle = strings().boostReassignStatusExpiresOn(expiresValue)
        }
        items.append(.init(boost: active, viewType: bestGeneralViewType(activeList, for: i), selected: state.selected.contains(.init(peerId: active.peer!.id, slot: active.slot)), subtitle: subtitle, enabled: active.cooldownUntil == nil))
    }
    
    
    for item in items {
        
        let interaction = SelectPeerInteraction()
        if item.selected {
            interaction.update {
                $0.withToggledSelected(item.boost.peer!.id, peer: item.boost.peer!._asPeer())
            }
        }
        
        interaction.action = { peerId, _ in
            arguments.toggle(.init(peerId: peerId, slot: item.boost.slot))
        }
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.boost.peer!.id, slot: item.boost.slot), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: item.boost.peer!._asPeer(), account: arguments.context.account, context: nil, stableId: stableId, enabled: item.enabled, status: item.subtitle, inset: NSEdgeInsets(left: 20, right: 20), interactionType: .selectable(interaction, side: .left), viewType: item.viewType)
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func BoostReassignController(context: AccountContext, peer: Peer, boosts: [MyBoostStatus.Boost]) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: .init(peer), boosts: boosts)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, toggle: { key in
        updateState { current in
            var current = current
            if current.selected.contains(key) {
                current.selected.remove(key)
            } else {
                current.selected.insert(key)
            }
            return current
        }
    })
    
    
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().boostReassignTitle)
    
    let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: {
        updateState { current in
            var current = current
            current.currentTime = Int32(Date().timeIntervalSince1970)
            return current
        }
    }, queue: .mainQueue())
    timer.start()
    
    controller.contextObject = timer
    
    controller.validateData = { _ in
        
        let selected: [MyBoostStatus.Boost] = stateValue.with { state in
            return state.boosts.filter { boost in
                if let peerId = boost.peer?.id {
                    return state.selected.contains(.init(peerId: peerId, slot: boost.slot))
                } else {
                    return false
                }
            }
        }
        if !selected.isEmpty {
            _ = context.engine.peers.applyChannelBoost(peerId: peer.id, slots: selected.map { $0.slot }).start()
            PlayConfetti(for: context.window)
            var inChannels: Int = 0
            var calculated:Set<PeerId> = Set()
            for select in selected {
                if let peerId = select.peer?.id {
                    if !calculated.contains(peerId) {
                        calculated.insert(peerId)
                        inChannels += 1
                    }
                }
            }
            showModalText(for: context.window, text: strings().boostReassignSuccessCountable(selected.count, inChannels))
            close?()
        }
        
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().boostReassignOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    controller.afterTransaction = { [weak modalInteractions] controller in
        if let modalInteractions = modalInteractions {
            modalInteractions.updateDone({ button in
                button.isEnabled = stateValue.with { !$0.selected.isEmpty }
            })
        }
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}



