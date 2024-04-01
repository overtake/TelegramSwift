//
//  ComplicatedReportController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


struct ComplicatedReport : Equatable {
    struct Report : Equatable {
        var string: String
        var id: Data
        var inner: ComplicatedReport?
    }
    var list: [Report] = []
    var title: String
}

func showComplicatedReport(context: AccountContext, title: String, info: String?, data: ComplicatedReport, report: @escaping(ComplicatedReport.Report)->Signal<ComplicatedReport?, NoError>) {
    showModal(with: ReportController(context: context, title: title, info: info, data: data, reportCallback: report), for: context.window)
}




private final class Arguments {
    let context: AccountContext
    let select:(ComplicatedReport.Report)->Void
    init(context: AccountContext, select:@escaping(ComplicatedReport.Report)->Void) {
        self.context = context
        self.select = select
    }
}

private struct State : Equatable {
    var data: ComplicatedReport
    var info: String?
}

private func _id_report(_ report: ComplicatedReport.Report) -> InputDataIdentifier {
    return .init("_id_report_\(report.id)_\(report.string.hashValue)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatMessageSponsoredReportOptionTitle.uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    for (i, report) in state.data.list.enumerated() {
        let viewType: GeneralViewType = bestGeneralViewType(state.data.list, for: i)
        let type: GeneralInteractedType = report.inner != nil ? .next : .next
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_report(report), data: .init(name: report.string, color: theme.colors.text, type: type, viewType: viewType, action: {
            arguments.select(report)
        })))
    }
    
    if let info = state.info {
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(info, linkHandler: { link in
            execute(inapp: .external(link: link, false))
        }), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private func ReportController(context: AccountContext, title: String, info: String?, data: ComplicatedReport, reportCallback: @escaping(ComplicatedReport.Report)->Signal<ComplicatedReport?, NoError>) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: data, info: info)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    
    var getModalController:(()->InputDataModalController?)? = nil

    let arguments = Arguments(context: context, select: { report in
        if let complicated = report.inner {
            if let controller = getModalController?() {
                controller.push(ReportController(context: context, title: complicated.title, info: info, data: complicated, modalController: controller, reportCallback: reportCallback), animated: true)
            }
        } else {
            actionsDisposable.add((reportCallback(report) |> deliverOnMainQueue).startStandalone(next: { value in
                if let complicated = value {
                    if let controller = getModalController?() {
                        controller.push(ReportController(context: context, title: complicated.title, info: info, data: complicated, modalController: controller, reportCallback: reportCallback), animated: true)
                    }
                } else {
                    close?()
                }
            }))
        }
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().chatMessageSponsoredReport, hasDone: false)
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    
    return modalController
    
}



private func ReportController(context: AccountContext, title: String, info: String?, data: ComplicatedReport, modalController: InputDataModalController, reportCallback: @escaping(ComplicatedReport.Report)->Signal<ComplicatedReport?, NoError>) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: data, info: info)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = Arguments(context: context, select: { [weak modalController] report in
        if let complicated = report.inner {
            if let controller = modalController {
                controller.push(ReportController(context: context, title: complicated.title, info: info, data: complicated, modalController: controller, reportCallback: reportCallback), animated: true)
            }
        } else {
            actionsDisposable.add((reportCallback(report) |> deliverOnMainQueue).startStandalone(next: { value in
                if let complicated = value {
                    if let controller = modalController {
                        controller.push(ReportController(context: context, title: complicated.title, info: info, data: complicated, modalController: controller, reportCallback: reportCallback), animated: true)
                    }
                } else {
                    modalController?.close()
                }
            }))
        }
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, hasDone: false)
    controller._frameRect = modalController.frame.size.bounds
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.chatNavigationBack, handler: { [weak modalController] in
        modalController?.pop(animated: true)
    })
    
    return controller
    
}
