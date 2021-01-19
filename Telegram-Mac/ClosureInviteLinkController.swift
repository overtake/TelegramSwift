//
//  ClosureInviteLinkController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import TGUIKit
import SwiftSignalKit
import SyncCore
import Postbox

private final class InviteLinkArguments {
    let context: AccountContext
    let usageLimit:(Int32)->Void
    let limitDate: (Int32)->Void
    let tempCount:(Int32?)->Void
    let tempDate:(Int32?)->Void
    init(context: AccountContext, usageLimit: @escaping(Int32)->Void, limitDate: @escaping(Int32)->Void, tempCount:@escaping(Int32?)->Void, tempDate: @escaping(Int32?)->Void) {
        self.context = context
        self.usageLimit = usageLimit
        self.limitDate = limitDate
        self.tempCount = tempCount
        self.tempDate = tempDate
    }
}

struct ClosureInviteLinkState: Equatable {
    fileprivate(set) var date:Int32
    fileprivate(set) var count: Int32
    fileprivate var tempCount: Int32?
    fileprivate var tempDate: Int32?
}

//
private let _id_period = InputDataIdentifier("_id_period")
private let _id_period_precise = InputDataIdentifier("_id_period_precise")

private let _id_count = InputDataIdentifier("_id_count")
private let _id_count_precise = InputDataIdentifier("_id_count_precise")

private func inviteLinkEntries(state: ClosureInviteLinkState, arguments: InviteLinkArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("LIMITED BY TIME PERIOD"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_period, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        let hour: Int32 = 60 * 60
        let day: Int32 = hour * 24 * 1
        var sizes:[Int32] = [hour, day, day * 7, Int32.max]
        
        if let temp = state.tempDate {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < temp {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = temp
        }
        
        let current = state.date
        if sizes.firstIndex(where: { $0 == current }) == nil {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < current {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = current
        }
        //TODOLANG
        let titles: [String] = sizes.map { value in
            if value == Int32.max {
                return "∞"
            } else {
                return autoremoveLocalized(Int(value))
            }
        }
        return SelectSizeRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, hasMarkers: false, titles: titles, viewType: .firstItem, selectAction: { index in
            arguments.limitDate(sizes[index])
        })
    }))
    index += 1
    
    
    let dateFormatter = makeNewDateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    //TODOLANG
    let dateString = state.date == .max ? "No Limit" : dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(state.date)))
    //TODOLANG
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_period_precise, data: .init(name: "Expiry Date", color: theme.colors.text, type: .context(dateString), viewType: .lastItem, action: {
        showModal(with: DateSelectorModalController(context: arguments.context, defaultDate: Date(timeIntervalSinceNow: TimeInterval(state.date)), mode: .date(title: "Expiry Date", doneTitle: "Save"), selectedAt: { date in
            arguments.limitDate(Int32(date.timeIntervalSinceNow))
            arguments.tempDate(Int32(date.timeIntervalSinceNow))
            
        }), for: arguments.context.window)
    })))
    index += 1
    
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("you can make the link expire after a certain time."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("LIMITED BY NUMBER OF USERS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_count, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        var sizes:[Int32] = [1, 10, 50, 100, Int32.max]
        
        if let temp = state.tempCount {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < temp {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = temp
        }
        
        let current: Int32 = state.count
        if sizes.firstIndex(where: { $0 == current }) == nil {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < current {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = current
        }
        //TODOLANG
        let titles: [String] = sizes.map { value in
            if value == Int32.max {
                return "∞"
            } else {
                return Int(value).prettyNumber
            }
        }
        return SelectSizeRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, hasMarkers: false, titles: titles, viewType: .firstItem, selectAction: { index in
            arguments.usageLimit(sizes[index])
        })
    }))
    index += 1
    
    //TODOLANG
    let value = state.count == .max ? "No Limit" : Int(state.count).prettyNumber
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_count_precise, data: .init(name: "Numbers of Users", color: theme.colors.text, type: .context(value), viewType: .lastItem, action: {
        showModal(with: NumberSelectorController(base: state.count == .max ? nil : Int(state.count), title: "Number of Users", placeholder: "Enter number", okTitle: "Save", updated: { updated in
            if let updated = updated {
                arguments.usageLimit(Int32(updated))
            } else {
                arguments.usageLimit(.max)
            }
            arguments.tempCount(updated != nil ? Int32(updated!) : nil)
        }), for: arguments.context.window)
    })))
    index += 1
    
    //TODOLANG
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("you can make the link expire after it has been used for a certain number of times."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum InviteLinkClosureMode {
    case new
    case edit(ExportedInvitation)
    
    //TODOLANG
    var title: String {
        switch self {
        case .new:
            return "New Link"
        case .edit:
            return "Edit Link"
        }
    }
    //TODOLANG
    var done: String {
        switch self {
        case .new:
            return "Create"
        case .edit:
            return "Save"
        }
    }
    var doneColor: NSColor {
        switch self {
        case .new:
            return theme.colors.accent
        case .edit:
            return theme.colors.redUI
        }
    }
}

func ClosureInviteLinkController(context: AccountContext, peerId: PeerId, mode: InviteLinkClosureMode, save:@escaping(ClosureInviteLinkState)->Void) -> InputDataModalController {
    var initialState = ClosureInviteLinkState(date: 0, count: 0)
    let week: Int32 = 60 * 60 * 24 * 1 * 7
    switch mode {
    case .new:
        initialState.date = week
        initialState.count = 50
    case let .edit(invitation):
        initialState.date = invitation.isExpired ? week : Int32(TimeInterval(invitation.expireDate!) - Date().timeIntervalSince1970)
        initialState.tempDate = initialState.date
        if let alreadyCount = invitation.count, let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit - alreadyCount
        } else if let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit
        } else {
            initialState.count = 50
        }
        if initialState.count != 50 {
            initialState.tempCount = initialState.count
        }
    }
    let state: ValuePromise<ClosureInviteLinkState> = ValuePromise(initialState)
    let stateValue: Atomic<ClosureInviteLinkState> = Atomic(value: initialState)
    
    let updateState:((ClosureInviteLinkState)->ClosureInviteLinkState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    let arguments = InviteLinkArguments(context: context, usageLimit: { value in
        updateState { current in
            var current = current
            current.count = value
            return current
        }
    }, limitDate: { value in
        updateState { current in
            var current = current
            current.date = value
            return current
        }
    }, tempCount: { value in
        updateState { current in
            var current = current
            current.tempCount = value
            return current
        }
    }, tempDate: { value in
        updateState { current in
            var current = current
            current.tempDate = value
            return current
        }
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return inviteLinkEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil

    
    let controller = InputDataController(dataSignal: dataSignal, title: mode.title)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    controller.updateDatas = { data in
       
        return .none
    }
    
    
    let modalInteractions = ModalInteractions(acceptTitle: mode.done, accept: { [weak controller] in
          controller?.validateInputValues()
    }, drawBorder: true, singleButton: true)
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in
        f()
    }, size: NSMakeSize(340, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    controller.validateData = { data in
        return .success(.custom {
            save(stateValue.with { $0 })
            getModalController?()?.close()
        })
    }
    
    
    return modalController
}
