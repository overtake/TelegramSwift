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



private final class DisplayMeAsHeaderItem : GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, isAlone: Bool, isGroup: Bool) {
        textLayout = .init(.initialize(string: isAlone ? strings().displayMeAsAlone : isGroup ? strings().displayMeAsTextGroup : strings().displayMeAsText, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)
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
    let reveal:()->Void
    init(context: AccountContext, canBeScheduled: Bool, select:@escaping(PeerId)->Void, toggleSchedule:@escaping()->Void, updateScheduleDate:@escaping(Date)->Void, reveal:@escaping()->Void) {
        self.context = context
        self.select = select
        self.canBeScheduled = canBeScheduled
        self.toggleSchedule = toggleSchedule
        self.updateScheduleDate = updateScheduleDate
        self.reveal = reveal
    }
}

private struct State : Equatable {
    var peer: PeerEquatable?
    var list: [FoundPeer]?
    var selected: PeerId
    var schedule: Bool
    var scheduleDate: Date?
    var next: Int
    var isRevealed: Bool
}

private func _id_peer(_ id:PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}
private let _id_schedule = InputDataIdentifier("_id_schedule")
private let _id_schedule_time = InputDataIdentifier("_id_schedule_time")

private let _id_reveal = InputDataIdentifier("_id_reveal")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    let isGroup = state.peer?.peer.isGroup == true || state.peer?.peer.isSupergroup == true
    
    let isEmpty = state.list?.isEmpty == true

    struct T : Equatable {
        let isGroup: Bool
        let isAlone: Bool
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(T(isGroup: isGroup, isAlone: isEmpty)), comparable: nil, item: { initialSize, stableId in
        return DisplayMeAsHeaderItem(initialSize, stableId: stableId, isAlone: isEmpty, isGroup: isGroup)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    struct Tuple : Equatable {
        let peer: FoundPeer
        let viewType: GeneralViewType
        let selected: Bool
        let status: String?
    }
    
    if let peer = state.peer {
        
                
        let tuple = Tuple(peer: FoundPeer(peer: peer.peer, subscribers: nil), viewType: state.list == nil || !isEmpty ? .firstItem : .singleItem, selected: peer.peer.id == state.selected, status: strings().displayMeAsPersonalAccount)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("self"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                arguments.select(tuple.peer.peer.id)
            })
        }))
        
        if isEmpty {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().displayMeAsAloneDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        }
        index += 1
    }
    
    if let list = state.list {
        
        if !list.isEmpty {
            
            let conceal = !state.isRevealed && list.count > 1

            let count = list.count
            let list = state.isRevealed ? list : Array(list.prefix(1))
            
            
            for peer in list {
                var status: String?
                if let subscribers = peer.subscribers {
                    if peer.peer.isChannel {
                        status = strings().voiceChatJoinAsChannelCountable(Int(subscribers))
                    } else if peer.peer.isSupergroup || peer.peer.isGroup {
                        status = strings().voiceChatJoinAsGroupCountable(Int(subscribers))
                    }
                } else {
                    status = strings().chatChannelBadge
                }
                
                var viewType = bestGeneralViewType(list, for: peer)
                if list.first == peer {
                    if list.count == 1 {
                        if conceal {
                            viewType = .innerItem
                        } else {
                            viewType = .lastItem
                        }
                    } else {
                        viewType = .innerItem
                    }
                }
                
                let tuple = Tuple(peer: peer, viewType: viewType, selected: peer.peer.id == state.selected, status: status)
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.peer.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                        arguments.select(tuple.peer.peer.id)
                    })

                }))
                index += 1
            }
            if conceal {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_reveal, equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().statsShowMoreCountable(count - 1), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: arguments.reveal, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                }))
                index += 1
            }
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
        }))
        index += 1
    }
  
    // entries
    
    
    if arguments.canBeScheduled {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_schedule, data: .init(name: strings().displayMeAsScheduled, color: theme.colors.text, type: .switchable(state.schedule), viewType: state.schedule ? .firstItem : .singleItem, action: arguments.toggleSchedule)))
        index += 1
        if state.schedule, let scheduleDate = state.scheduleDate {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_schedule_time, equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DatePickerRowItem(initialSize, stableId: stableId, viewType: .lastItem, initialDate: scheduleDate, update: arguments.updateScheduleDate)
            }))
            index += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().displayMeAsScheduledDesc(timerText(Int(scheduleDate.timeIntervalSince1970) - Int(Date().timeIntervalSince1970)))), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        }
        
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum GroupCallDisplayAsMode {
    case join
    case create
}

func GroupCallDisplayAsController(context: AccountContext, mode: GroupCallDisplayAsMode, peerId: PeerId, list:[FoundPeer], completion: @escaping(PeerId, Date?, Bool)->Void, canBeScheduled: Bool, isCreator: Bool) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    

    let calendar = NSCalendar.current
    var components = calendar.dateComponents([.hour, .day, .year, .month], from: Date())
    
    components.setValue(components.hour! + 2, for: .hour)
    
    let initialState = State(list: list, selected: context.peerId, schedule: false, scheduleDate: calendar.date(from: components), next: 1, isRevealed: false)
    
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
    }, reveal: {
        updateState { current in
            var current = current
            current.isRevealed = true
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
        
    let list: Signal<[FoundPeer]?, NoError> = context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId) |> map(Optional.init)
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
    
    let controller = InputDataController(dataSignal: signal, title: canBeScheduled ? strings().displayMeAsNewTitle : strings().displayMeAsTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.contextObject = timer

    
    controller.validateData = { _ in
        let value = stateValue.with { ($0.selected, $0.schedule ? $0.scheduleDate : nil) }
        
        if let date = value.1 {
            if date.timeIntervalSince1970 - Date().timeIntervalSince1970 <= 10 {
                return .fail(.fields([_id_schedule_time : .shake]))
            }
        }
        
        completion(value.0, value.1, false)
        close?()
        return .none
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: "", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, cancelTitle: isCreator ? strings().displayMeAsStartWith : nil, cancel: {
        showModal(with: RTMPStartController(context: context, peerId: peerId, scheduleDate: stateValue.with { $0.schedule ? $0.scheduleDate : nil }, completion: completion), for: context.window)
        close?()
    }, singleButton: !isCreator)
    
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone { button in
            let title: String = stateValue.with { value in
                let peer = value.list?.first(where: { $0.peer.id == value.selected })?.peer ?? value.peer?.peer
                return peer?.compactDisplayTitle ?? ""
            }
            let state = stateValue.with { $0 }
            if canBeScheduled {
                if state.schedule {
                    button.set(text: strings().displayMeAsModernSchedule, for: .Normal)
                } else {
                    button.set(text: strings().displayMeAsModernStart, for: .Normal)
                }
            } else {
                button.set(text: strings().displayMeAsContinueAs(title), for: .Normal)
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


func selectGroupCallJoiner(context: AccountContext, peerId: PeerId, completion: @escaping(PeerId, Date?, Bool)->Void, canBeScheduled: Bool = false) {
    let combined = combineLatest(queue: .mainQueue(), context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId), context.account.postbox.loadedPeerWithId(peerId))
    _ = showModalProgress(signal: combined, for: context.window).start(next: { displayAsList, peer in
        if displayAsList.count > 1 || canBeScheduled {
            showModal(with: GroupCallDisplayAsController(context: context, mode: .create, peerId: peerId, list: displayAsList, completion: completion, canBeScheduled: canBeScheduled, isCreator: peer.groupAccess.isCreator), for: context.window)
        } else {
            completion(context.peerId, nil, false)
        }
    })
}

/*
 
 */



