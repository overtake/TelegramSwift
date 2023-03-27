//
//  JoinCloudFolderController.swift
//  Telegram
//
//  Created by Mike Renoir on 16.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class JoinCloudFolderHeaderItem : GeneralRowItem {
    let nameLayout: TextViewLayout
    let leftLayout: TextViewLayout
    let rightLayout: TextViewLayout
    
    let badgeNode: BadgeNode?
    init(initialSize: NSSize, stableId: AnyHashable, name: String, count: Int) {
        
        if count > 0 {
            self.badgeNode = .init(.initialize(string: "\(count)", color: theme.colors.underSelectedColor, font: .medium(.short)), theme.colors.accent)
        } else {
            self.badgeNode = nil
        }
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.accent, font: .medium(.title)))
        self.leftLayout = .init(.initialize(string: "All Chats", color: theme.colors.listGrayText, font: .normal(.text)))
        self.rightLayout = .init(.initialize(string: "Personal", color: theme.colors.listGrayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: initialSize.width / 2.5)
        leftLayout.measure(width: .greatestFiniteMagnitude)
        rightLayout.measure(width: .greatestFiniteMagnitude)

        return true
    }
    
    override var height: CGFloat {
        return 36
    }
    
    override func viewClass() -> AnyClass {
        return JoinCloudFolderHeaderView.self
    }
}

private final class JoinCloudFolderHeaderView : TableRowView {
    private let nameView = TextView()
    private let leftView = TextView()
    private let rightView = TextView()
    
    private let leftShadow = ShadowView()
    private let rightShadow = ShadowView()

    private let nameContainer = View()
    
    private let lineView = View()
    
    private var badgeView: View?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        leftView.userInteractionEnabled = false
        rightView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false

        leftView.isSelectable = false
        rightView.isSelectable = false
        nameView.isSelectable = false

        
        addSubview(leftView)
        addSubview(rightView)

        addSubview(leftShadow)
        addSubview(rightShadow)
        
        nameContainer.addSubview(nameView)
        nameContainer.addSubview(lineView)
        addSubview(nameContainer)
        
        nameContainer.layer?.masksToBounds = false
        
        lineView.layer?.cornerRadius = 3
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? JoinCloudFolderHeaderItem else {
            return
        }
        var nameSize: CGFloat = nameView.frame.width
        if let badge = item.badgeNode {
            nameSize = nameSize + 5 + badge.size.width
        }
        transition.updateFrame(view: nameContainer, frame: focus(NSMakeSize(nameSize, frame.height)))
        
        transition.updateFrame(view: nameView, frame: nameView.centerFrameY())
        
        if let view = self.badgeView {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: nameView.frame.width + 5))
        }
        transition.updateFrame(view: lineView, frame: NSMakeRect(0, nameContainer.frame.height - 3, nameContainer.frame.width, 6))
        
        transition.updateFrame(view: rightView, frame: rightView.centerFrameY(x: nameContainer.frame.maxX + 20))
        transition.updateFrame(view: leftView, frame: leftView.centerFrameY(x: nameContainer.frame.minX - leftView.frame.width - 20))
        
        transition.updateFrame(view: leftShadow, frame: leftView.frame)
        transition.updateFrame(view: rightShadow, frame: rightView.frame)
        
    }
    
 
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? JoinCloudFolderHeaderItem else {
            return
        }
        
        rightView.update(item.rightLayout)
        leftView.update(item.leftLayout)
        nameView.update(item.nameLayout)
        
        if let badge = item.badgeNode {
            let current: View
            if let view = self.badgeView {
                current = view
            } else {
                current = View(frame: CGRect(origin: CGPoint.init(x: nameView.frame.maxX + 5, y: floorToScreenPixels(backingScaleFactor, (frame.height - badge.size.height) / 2)), size: badge.size))
                self.badgeView = current
                nameContainer.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.setFrameSize(badge.size)
            badge.view = current
            badge.setNeedDisplay()
        } else if let view = self.badgeView {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.badgeView = nil
        }
        
        rightShadow.direction = .horizontal(true)
        leftShadow.direction = .horizontal(false)
        
        leftShadow.shadowBackground = theme.colors.listBackground
        rightShadow.shadowBackground = theme.colors.listBackground

        lineView.backgroundColor = theme.colors.accent

    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class Arguments {
    let context: AccountContext
    let select: SelectPeerInteraction
    let alreadyError:(Peer)->Void
    init(context: AccountContext, select: SelectPeerInteraction, alreadyError: @escaping(Peer)->Void) {
        self.context = context
        self.select = select
        self.alreadyError = alreadyError
    }
}

private struct State : Equatable {
    var title: String
    var peers: [PeerEquatable] = []
    var selected: Set<PeerId> = Set()
    var alreadyMemberPeerIds: Set<EnginePeer.Id>
    
    var hasSelectedToJoin: Bool {
        let to_join = peers
            .filter { !alreadyMemberPeerIds.contains($0.peer.id) }
            .filter { selected.contains($0.peer.id) }
        
        return !to_join.isEmpty
        
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
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    //header
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return JoinCloudFolderHeaderItem(initialSize: initialSize, stableId: stableId, name: state.title, count: state.selected.count)
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("Do you want to add **\(state.selected.count)** chats to your folder **\(state.title)**?", linkHandler: { _ in }), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
   
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
        let enabled: Bool
    }
    
    var toJoin: [Tuple] = []
    var joined: [Tuple] = []
    
    let _to_list = state.peers.filter { !state.alreadyMemberPeerIds.contains($0.peer.id) }
    let _already_list = state.peers.filter { state.alreadyMemberPeerIds.contains($0.peer.id) }

    for (i, peer) in _to_list.enumerated() {
        toJoin.append(.init(peer: peer, selected: state.selected.contains(peer.peer.id), viewType: bestGeneralViewType(_to_list, for: i), selectable: true, enabled: true))
    }
    for (i, peer) in _already_list.enumerated() {
        joined.append(.init(peer: peer, selected: true, viewType: bestGeneralViewType(_already_list, for: i), selectable: true, enabled: false))
    }
    
    
    if !toJoin.isEmpty {
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("\(toJoin.count) CHATS TO JOIN"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for item in toJoin {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.peer.peer.isChannel ? strings().peerStatusChannel : strings().peerStatusGroup, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType)
            }))
            index += 1
        }
    }
    
    
    if !joined.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("\(joined.count) CHATS ALREADY JOINED"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for item in joined {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.peer.peer.isChannel ? strings().peerStatusChannel : strings().peerStatusGroup, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType, disabledAction: {
                    arguments.alreadyError(item.peer.peer)
                })
            }))
            index += 1
        }
    }
    
   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func JoinCloudFolderController(context: AccountContext, slug: String, content: ChatFolderLinkContents) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let peers: [PeerEquatable] = content.peers.map { $0._asPeer() }.compactMap { .init($0) }

    let initialState = State(title: content.title ?? "", peers: peers, selected: Set(peers.map { $0.peer.id }), alreadyMemberPeerIds: content.alreadyMemberPeerIds)
    
    var close:(()->Void)? = nil
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    

    let selected = SelectPeerInteraction()
    
    selected.action = { peerId, _ in
        let peer = stateValue.with { $0.peers.first(where: { $0.peer.id == peerId }) }?.peer
        if let peer = peer {
            selected.update({
                $0.withToggledSelected(peerId, peer: peer)
            })
        }
        updateState { current in
            var current = current
            current.selected = selected.presentation.selected
            return current
        }
    }
    
    for peer in peers {
        selected.toggleSelection(peer.peer)
    }

    let arguments = Arguments(context: context, select: selected, alreadyError: { peer in
        let text: String
        if peer.isChannel {
            text = "You are already a member of this group."
        } else {
            text = "You are already a member of this channel."
        }
        showModalText(for: context.window, text: text)
    })

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Add Folder")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Add Folder", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        return .fail(.doSomething(next: { _ in
            close?()
            _ = showModalProgress(signal: context.engine.peers.joinChatFolderLink(slug: slug, peerIds: Array(state.selected)), for: context.window).start(completed: {
                showModalText(for: context.window, text: "Added")
            })
        }))
    }
    
    controller.afterTransaction = { [weak modalInteractions] controller in
        modalInteractions?.updateDone { title in
            let state = stateValue.with { $0 }
            title.isEnabled = true
            title.set(text: state.hasSelectedToJoin ? "Join Chats" : "Add Folder", for: .Normal)
        }
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}







func loadAndShowChatFolder(context: AccountContext, slug: String) -> Void {
    _ = showModalProgress(signal: context.engine.peers.checkChatFolderLink(slug: slug), for: context.window).start(next: { content in
        showModal(with: JoinCloudFolderController(context: context, slug: slug, content: content), for: context.window)
    }, error: { error in
        alert(for: context.window, info: strings().unknownError)
    })
}
