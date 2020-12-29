//
//  DesktopCaptureListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TgVoipWebrtc
import SwiftSignalKit

private final class DesktopCaptureListArguments {
    let select:(DesktopCaptureSource)->Void
    init(select:@escaping(DesktopCaptureSource)->Void) {
        self.select = select
    }
}

private struct DesktopCaptureListState : Equatable {
    var windows: [DesktopCaptureSource]
    var selected: DesktopCaptureSource?
    init(windows: [DesktopCaptureSource], selected: DesktopCaptureSource?) {
        self.windows = windows
        self.selected = selected
    }
}

private let _id_input = InputDataIdentifier("frame")

private func entries(_ state: DesktopCaptureListState, windows: DesktopCaptureSourceManager?, arguments: DesktopCaptureListArguments) -> [InputDataEntry] {
    
    
    
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    let windowsList = state.windows.chunks(2)
    for sources in windowsList {
        let id: String = sources.reduce("", { current, value in
            return current + value.uniqueKey()
        })
    
        struct Tuple : Equatable {
            let source: [DesktopCaptureSource]
            let selected: DesktopCaptureSource?
        }
        
        let selected = state.selected != nil && sources.contains(state.selected!) ? state.selected : nil
        let tuple = Tuple(source: sources, selected: selected)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), item: { [weak windows] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, sources: sources, selectedSource: selected, manager: windows, select: arguments.select)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func desktopCapturerController(context: AccountContext) -> InputDataModalController {
    
    
    
    let manager = DesktopCaptureSourceManager(_w: ())

    let list = manager.list()
    
    let initialState = DesktopCaptureListState(windows: list, selected: nil)

    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((DesktopCaptureListState) -> DesktopCaptureListState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let updateSignal = Signal<NoValue, NoError> { [weak manager] subscriber in
        
        updateState { current in
            var current = current
            current.windows = manager?.list() ?? []
            if let selected = current.selected, !current.windows.contains(selected) {
                current.selected = nil
            }
            return current
        }
        
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
    
    let disposable = ((updateSignal |> then(.complete() |> suspendAwareDelay(2, queue: .mainQueue()))) |> restart).start()
    
    let arguments = DesktopCaptureListArguments(select: { source in
        updateState { current in
            var current = current
            current.selected = source
            return current
        }
    })
    
    
    let signal = statePromise.get() |> map { [weak manager] state in
        return InputDataSignalValue(entries: entries(state, windows: manager, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Windows")
    
    controller.contextOject = manager
    
    controller.afterDisappear = {
        disposable.dispose()
    }
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: "Share", accept: {
        close?()
    }, height: 50, singleButton: true)
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        return .none
    }
    
    controller.didLoaded = { controller, _ in
        controller.genericView.tableView.needUpdateVisibleAfterScroll = true
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
        
    return modalController
    
}
