//
//  ReportReasonModalController.swift
//  Telegram
//
//  Created by keepcoder on 01/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore


func reportReasonSelector(context: AccountContext) -> Signal<ReportReason, NoError> {
    let promise: ValuePromise<ReportReason> = ValuePromise()
    let controller = ReportReasonController(callback: { reason in
        promise.set(reason)
    })
    showModal(with: controller, for: context.window)
    
    return promise.get() |> take(1)
}




private final class ReportReasonArguments {
    let toggleReason:(ReportReason)->Void
    init(toggleReason:@escaping(ReportReason)->Void) {
        self.toggleReason = toggleReason
    }
}

private struct ReportReasonState : Equatable {
    let reason: ReportReason
    init(reason: ReportReason) {
        self.reason = reason
    }
    
    func withUpdatedReason(_ reason: ReportReason) -> ReportReasonState {
        return ReportReasonState(reason: reason)
    }
}

private let _id_spam = InputDataIdentifier("_id_spam")
private let _id_violence = InputDataIdentifier("_id_violence")
private let _id_porno = InputDataIdentifier("_id_porno")
private let _id_childAbuse = InputDataIdentifier("_id_childAbuse")
private let _id_copyright = InputDataIdentifier("_id_copyright")
private let _id_custom = InputDataIdentifier("_id_custom")
private let _id_custom_input = InputDataIdentifier("_id_custom_input")

private extension ReportReason {
    var id: InputDataIdentifier {
        switch self {
        case .spam:
            return _id_spam
        case .violence:
            return _id_violence
        case .porno:
            return _id_porno
        case .childAbuse:
            return _id_childAbuse
        case .copyright:
            return _id_copyright
        case .custom:
            return _id_custom
        default:
            fatalError("unsupported")
        }
    }
    var title: String {
        switch self {
        case .spam:
            return L10n.reportReasonSpam
        case .violence:
            return L10n.reportReasonViolence
        case .porno:
            return L10n.reportReasonPorno
        case .childAbuse:
            return L10n.reportReasonChildAbuse
        case .copyright:
            return L10n.reportReasonCopyright
        case .custom:
            return L10n.reportReasonOther
        default:
            fatalError("unsupported")
        }
    }
    
    func isEqual(to other: ReportReason) -> Bool {
        switch self {
        case .spam:
            if case .spam = other {
                return true
            }
        case .violence:
            if case .violence = other {
                return true
            }
        case .porno:
            if case .porno = other {
                return true
            }
        case .childAbuse:
            if case .childAbuse = other {
                return true
            }
        case .copyright:
            if case .copyright = other {
                return true
            }
        case .custom:
            if case .custom = other {
                return true
            }
        default:
            fatalError("unsupported")
        }
        return false
    }
}

private func reportReasonEntries(state: ReportReasonState, arguments: ReportReasonArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let reasons:[ReportReason] = [.spam, .violence, .porno, .childAbuse, .copyright, .custom("")]
    
    for (i, reason) in reasons.enumerated() {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: reason.id, data: InputDataGeneralData(name: reason.title, color: theme.colors.text, type: .selectable(state.reason.isEqual(to: reason)), viewType: bestGeneralViewType(reasons, for: i), action: {
            arguments.toggleReason(reason)
        })))
           index += 1
    }
    
    switch state.reason {
    case let .custom(text):
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.input(sectionId: sectionId, index: index, value: .string(text), error: nil, identifier: _id_custom_input, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.reportReasonOtherPlaceholder, filter: { $0 }, limit: 128))
        index += 1
        
    default:
        break
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ReportReasonController(callback: @escaping(ReportReason)->Void) -> InputDataModalController {
    let initialState = ReportReasonState(reason: .spam)
    let state: ValuePromise<ReportReasonState> = ValuePromise(initialState)
    let stateValue: Atomic<ReportReasonState> = Atomic(value: initialState)
    
    let updateState:((ReportReasonState)->ReportReasonState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    let arguments = ReportReasonArguments(toggleReason: { reason in
        updateState { current in
            if !current.reason.isEqual(to: reason) {
                return current.withUpdatedReason(reason)
            } else {
                return current
            }
        }
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return reportReasonEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil

    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.peerInfoReport)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    controller.updateDatas = { data in
        updateState { current in
            switch current.reason {
            case .custom:
                return current.withUpdatedReason(.custom(data[_id_custom_input]?.stringValue ?? ""))
            default:
                return current
            }
        }
        return .none
    }
    
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.reportReasonReport, accept: { [weak controller] in
          controller?.validateInputValues()
    }, drawBorder: true, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in
        f()
    }, size: NSMakeSize(300, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    controller.validateData = { data in
        return .success(.custom {
            callback(stateValue.with { $0.reason })
            getModalController?()?.close()
        })
    }
    
    
    return modalController
}

