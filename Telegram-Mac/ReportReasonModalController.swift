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


struct ReportReasonValue : Equatable {
    let reason: ReportReason
    let comment: String
}


func reportReasonSelector(context: AccountContext, buttonText: String = strings().reportReasonReport) -> Signal<ReportReasonValue, NoError> {
    let promise: ValuePromise<ReportReasonValue> = ValuePromise()
    let controller = ReportReasonController(callback: { reason in
        promise.set(reason)
    }, buttonText: buttonText)
    showModal(with: controller, for: context.window)
    
    return promise.get() |> take(1)
}




private final class ReportReasonArguments {
    let selectReason:(ReportReason)->Void
    init(selectReason:@escaping(ReportReason)->Void) {
        self.selectReason = selectReason
    }
}

private struct ReportReasonState : Equatable {
    let value: ReportReasonValue
    init(value: ReportReasonValue) {
        self.value = value
    }
    
    func withUpdatedReason(_ value: ReportReasonValue) -> ReportReasonState {
        return ReportReasonState(value: value)
    }
}

private let _id_spam = InputDataIdentifier("_id_spam")
private let _id_violence = InputDataIdentifier("_id_violence")
private let _id_porno = InputDataIdentifier("_id_porno")
private let _id_childAbuse = InputDataIdentifier("_id_childAbuse")
private let _id_copyright = InputDataIdentifier("_id_copyright")
private let _id_custom = InputDataIdentifier("_id_custom")
private let _id_fake = InputDataIdentifier("_id_fake")
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
        case .fake:
            return _id_fake
        default:
            fatalError("unsupported")
        }
    }
    var title: String {
        switch self {
        case .spam:
            return strings().reportReasonSpam
        case .violence:
            return strings().reportReasonViolence
        case .porno:
            return strings().reportReasonPorno
        case .childAbuse:
            return strings().reportReasonChildAbuse
        case .copyright:
            return strings().reportReasonCopyright
        case .custom:
            return strings().reportReasonOther
        case .fake:
            return strings().reportReasonFake
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
        case .fake:
            if case .fake = other {
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
    
    let reasons:[ReportReason] = [.spam, .fake, .violence, .porno, .childAbuse, .copyright]
    
    for (i, reason) in reasons.enumerated() {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: reason.id, data: InputDataGeneralData(name: reason.title, color: theme.colors.text, type: .none, viewType: bestGeneralViewType(reasons, for: i), action: {
            arguments.selectReason(reason)
        })))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

//    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.value.comment), error: nil, identifier: _id_custom_input, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().reportReasonOtherPlaceholder, filter: { $0 }, limit: 128))
//    index += 1
//
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}

func ReportReasonController(callback: @escaping(ReportReasonValue)->Void, buttonText: String = strings().reportReasonReport) -> InputDataModalController {
    let initialState = ReportReasonState(value: .init(reason: .spam, comment: ""))
    let state: ValuePromise<ReportReasonState> = ValuePromise(initialState)
    let stateValue: Atomic<ReportReasonState> = Atomic(value: initialState)
    
    let updateState:((ReportReasonState)->ReportReasonState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    var getModalController:(()->InputDataModalController?)? = nil
    
    let arguments = ReportReasonArguments(selectReason: { reason in
        callback(.init(reason: reason, comment: ""))
        getModalController?()?.close()
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return reportReasonEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    

    
    let controller = InputDataController(dataSignal: dataSignal, title: strings().peerInfoReport)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    controller.updateDatas = { data in
        updateState { current in
            return current.withUpdatedReason(.init(reason: current.value.reason, comment: data[_id_custom_input]?.stringValue ?? ""))
        }
        return .none
    }
    
    
    let modalInteractions = ModalInteractions(acceptTitle: buttonText, accept: { [weak controller] in
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
            callback(stateValue.with { $0.value })
            getModalController?()?.close()
        })
    }
    
    
    return modalController
}

