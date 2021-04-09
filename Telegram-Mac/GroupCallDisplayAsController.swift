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
    init(_ initialSize: NSSize, stableId: AnyHashable, isAlone: Bool, isGroup: Bool) {
        textLayout = .init(.initialize(string: isAlone ? L10n.displayMeAsAlone : isGroup ? L10n.displayMeAsTextGroup : L10n.displayMeAsText, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)
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
    let canBeScheduled: Bool
    let select:(PeerId)->Void
    let toggleSchedule:()->Void
    let updateScheduleDate:(Date)->Void

    init(context: AccountContext, canBeScheduled: Bool, select:@escaping(PeerId)->Void, toggleSchedule:@escaping()->Void, updateScheduleDate:@escaping(Date)->Void) {
        self.context = context
        self.select = select
        self.canBeScheduled = canBeScheduled
        self.toggleSchedule = toggleSchedule
        self.updateScheduleDate = updateScheduleDate
    }
}

private struct State : Equatable {
    var peer: PeerEquatable?
    var list: [FoundPeer]?
    var selected: PeerId
    var schedule: Bool
    var scheduleDate: Date?
    var next: Int
}

private func _id_peer(_ id:PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}
private let _id_schedule = InputDataIdentifier("_id_schedule")
private let _id_schedule_time = InputDataIdentifier("_id_schedule_time")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let isGroup = state.peer?.peer.isGroup == true || state.peer?.peer.isSupergroup == true
    
    let isEmpty = state.list?.isEmpty == true

    struct T : Equatable {
        let isGroup: Bool
        let isAlone: Bool
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(T(isGroup: isGroup, isAlone: isEmpty)), comparable: nil, item: { initialSize, stableId in
        return DisplayMeAsHeaderItem(initialSize, stableId: stableId, isAlone: isEmpty, isGroup: isGroup)
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
        
                
        let tuple = Tuple(peer: FoundPeer(peer: peer.peer, subscribers: nil), viewType: state.list == nil || !isEmpty ? .firstItem : .singleItem, selected: peer.peer.id == state.selected, status: L10n.displayMeAsPersonalAccount)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("self"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 30, right: 30), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                arguments.select(tuple.peer.peer.id)
            })
        }))
        
        if isEmpty {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.displayMeAsAloneDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        }
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
                
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.peer.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 30, right: 30), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                        arguments.select(tuple.peer.peer.id)
                    })

                }))
            }
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
        }))
        index += 1
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if arguments.canBeScheduled {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule, data: .init(name: L10n.displayMeAsScheduled, color: theme.colors.text, type: .switchable(state.schedule), viewType: state.schedule ? .firstItem : .singleItem, action: arguments.toggleSchedule)))
        index += 1
        if state.schedule, let scheduleDate = state.scheduleDate {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_schedule_time, equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DatePickerRowItem(initialSize, stableId: stableId, viewType: .lastItem, initialDate: scheduleDate, update: arguments.updateScheduleDate)
            }))
            index += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.displayMeAsScheduledDesc(timerText(Int(scheduleDate.timeIntervalSince1970) - Int(Date().timeIntervalSince1970)))), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

    }
    
    return entries
}

enum GroupCallDisplayAsMode {
    case join
    case create
}

func GroupCallDisplayAsController(context: AccountContext, mode: GroupCallDisplayAsMode, peerId: PeerId, list:[FoundPeer], completion: @escaping(PeerId, Date?)->Void, canBeScheduled: Bool) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    let initialState = State(list: list, selected: context.peerId, schedule: false, scheduleDate: Date(timeIntervalSinceNow: 1 * 60 * 60), next: 1)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = Arguments(context: context, canBeScheduled: canBeScheduled, select: { peerId in
        updateState { current in
            var current = current
            current.selected = peerId
            return current
        }
    }, toggleSchedule: {
        updateState { current in
            var current = current
            current.schedule = !current.schedule
            return current
        }
    }, updateScheduleDate: { date in
        updateState { current in
            var current = current
            current.scheduleDate = date
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
    
    let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: {
        updateState { current in
            var current = current
            current.next += 1
            return current
        }
    }, queue: .mainQueue())
    
    timer.start()
    
    let controller = InputDataController(dataSignal: signal, title: canBeScheduled ? L10n.displayMeAsNewTitle : L10n.displayMeAsTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.contextOject = timer

    
    controller.validateData = { _ in
        let value = stateValue.with { ($0.selected, $0.schedule ? $0.scheduleDate : nil) }
        
        if let date = value.1 {
            if date.timeIntervalSince1970 - Date().timeIntervalSince1970 <= 10 {
                return .fail(.fields([_id_schedule_time : .shake]))
            }
        }
        
        completion(value.0, value.1)
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
            let state = stateValue.with { $0 }
            if canBeScheduled {
                if state.schedule {
                    button.set(text: L10n.displayMeAsNewScheduleAs(title), for: .Normal)
                } else {
                    button.set(text: L10n.displayMeAsNewStartAs(title), for: .Normal)
                }
            } else {
                button.set(text: L10n.displayMeAsContinueAs(title), for: .Normal)
            }
            
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


func selectGroupCallJoiner(context: AccountContext, peerId: PeerId, completion: @escaping(PeerId, Date?)->Void, canBeScheduled: Bool = false) {
    _ = showModalProgress(signal: cachedGroupCallDisplayAsAvailablePeers(account: context.account, peerId: peerId), for: context.window).start(next: { displayAsList in
        if !displayAsList.isEmpty || canBeScheduled {
            showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: completion, canBeScheduled: canBeScheduled), for: context.window)
        } else {
            completion(context.peerId, nil)
        }
    })
}

/*
 
 */



