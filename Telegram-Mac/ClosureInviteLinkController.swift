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

import Postbox

private final class InviteLinkArguments {
    let context: AccountContext
    let usageLimit:(Int32)->Void
    let limitDate: (Int32)->Void
    let tempCount:(Int32?)->Void
    let tempDate:(Int32?)->Void
    let toggleRequestApproval: (Bool)->Void
    init(context: AccountContext, usageLimit: @escaping(Int32)->Void, limitDate: @escaping(Int32)->Void, tempCount:@escaping(Int32?)->Void, tempDate: @escaping(Int32?)->Void, toggleRequestApproval: @escaping(Bool)->Void) {
        self.context = context
        self.usageLimit = usageLimit
        self.limitDate = limitDate
        self.tempCount = tempCount
        self.tempDate = tempDate
        self.toggleRequestApproval = toggleRequestApproval
    }
}

struct ClosureInviteLinkState: Equatable {
    fileprivate(set) var date:Int32
    fileprivate(set) var count: Int32
    fileprivate var tempCount: Int32?
    fileprivate var tempDate: Int32?
    fileprivate(set) var requestApproval: Bool
}

//
private let _id_period = InputDataIdentifier("_id_period")
private let _id_period_precise = InputDataIdentifier("_id_period_precise")

private let _id_count = InputDataIdentifier("_id_count")
private let _id_count_precise = InputDataIdentifier("_id_count_precise")


private let _id_request_approval = InputDataIdentifier("_id_request_approval")

private func inviteLinkEntries(state: ClosureInviteLinkState, arguments: InviteLinkArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.editInvitationLimitedByPeriod), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_period, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
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
    let dateString = state.date == .max ? L10n.editInvitationNever : dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(state.date)))
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_period_precise, data: .init(name: L10n.editInvitationExpiryDate, color: theme.colors.text, type: .context(dateString), viewType: .lastItem, action: {
        showModal(with: DateSelectorModalController(context: arguments.context, defaultDate: Date(timeIntervalSinceNow: TimeInterval(state.date == .max ? Int32.secondsInWeek : state.date)), mode: .date(title: L10n.editInvitationExpiryDate, doneTitle: L10n.editInvitationSave), selectedAt: { date in
            arguments.limitDate(Int32(date.timeIntervalSinceNow))
            arguments.tempDate(Int32(date.timeIntervalSinceNow))
            
        }), for: arguments.context.window)
    })))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.editInvitationExpiryDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.editInvitationLimitedByCount), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_count, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
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
    
    let value = state.count == .max ? L10n.editInvitationUnlimited : Int(state.count).prettyNumber
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_count_precise, data: .init(name: L10n.editInvitationNumberOfUsers, color: theme.colors.text, type: .context(value), viewType: .lastItem, action: {
        showModal(with: NumberSelectorController(base: state.count == .max ? nil : Int(state.count), title: L10n.editInvitationNumberOfUsers, placeholder: L10n.editInvitationEnterNumber, okTitle: L10n.editInvitationSave, updated: { updated in
            if let updated = updated {
                arguments.usageLimit(Int32(updated))
            } else {
                arguments.usageLimit(.max)
            }
            arguments.tempCount(updated != nil ? Int32(updated!) : nil)
        }), for: arguments.context.window)
    })))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.editInvitationLimitDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    
   
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_request_approval, data: .init(name: L10n.editInvitationRequestApproval, color: theme.colors.text, type: .switchable(state.requestApproval), viewType: .singleItem, action: {
        arguments.toggleRequestApproval(state.requestApproval)
    })))

    
    let requestApprovalText: String
    if state.requestApproval {
        requestApprovalText = L10n.editInvitationRequestApprovalChannelOn
    } else {
        requestApprovalText = L10n.editInvitationRequestApprovalChannelOff
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(requestApprovalText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

enum InviteLinkClosureMode {
    case new
    case edit(ExportedInvitation)
    
    var title: String {
        switch self {
        case .new:
            return L10n.editInvitationNewTitle
        case .edit:
            return L10n.editInvitationEditTitle
        }
    }
    var done: String {
        switch self {
        case .new:
            return L10n.editInvitationOKCreate
        case .edit:
            return L10n.editInvitationOKSave
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
    var initialState = ClosureInviteLinkState(date: 0, count: 0, requestApproval: false)
    let week: Int32 = 60 * 60 * 24 * 1 * 7
    switch mode {
    case .new:
        initialState.date = .max
        initialState.count = .max
    case let .edit(invitation):
        if let expireDate = invitation.expireDate {
            initialState.date = invitation.isExpired ? week : Int32(TimeInterval(expireDate) - Date().timeIntervalSince1970)
        } else {
            initialState.date = week
        }
        initialState.requestApproval = invitation.requestApproval
        initialState.tempDate = initialState.date
        if let alreadyCount = invitation.count, let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit - alreadyCount
        } else if let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit
        } else {
            initialState.count = .max
        }
        if initialState.count != .max {
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
    }, toggleRequestApproval: { value in
        updateState { current in
            var current = current
            current.requestApproval = !value
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
