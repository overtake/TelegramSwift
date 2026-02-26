//
//  ModalOptionSetController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TGUIKit

private final class ModalOptionsArguments {
    let context: AccountContext
    let toggleOption: (Int)->Void
    init(context: AccountContext, toggleOption:@escaping(Int)->Void) {
        self.context = context
        self.toggleOption = toggleOption
    }
}

struct ModalOptionSet : Equatable {
    let title: String
    let selected: Bool
    let editable: Bool
    init(title: String, selected: Bool, editable: Bool) {
        self.title = title
        self.selected = selected
        self.editable = editable
    }
    func withUpdatedSelected(_ selected: Bool) -> ModalOptionSet {
        return ModalOptionSet(title: self.title, selected: selected, editable: self.editable)
    }
}
enum ModalOptionSetResult {
    case selected
    case none
}

private struct ModalOptionsState: Equatable {
    let options: [ModalOptionSet]
    let selectOne: Bool
    init(options:[ModalOptionSet], selectOne: Bool) {
        self.options = options
        self.selectOne = selectOne
    }
    
    func withToggledOptionAt(_ index: Int) -> ModalOptionsState {
        var options = self.options
        options[index] = options[index].withUpdatedSelected(!options[index].selected)
        if selectOne {
            for i in 0 ..< options.count {
                options[i] = options[i].withUpdatedSelected(false)
            }
            options[index] = options[index].withUpdatedSelected(true)
        }
        
        return ModalOptionsState(options: options, selectOne: self.selectOne)
    }
}

private let _id_title: InputDataIdentifier = InputDataIdentifier("_id_title")
private let _id_border: InputDataIdentifier = InputDataIdentifier("_id_border")
private func _id_option(_ index: Int)->InputDataIdentifier {
    return InputDataIdentifier("_id_option_\(index)")
}
private func modalOptionsSetEntries(state: ModalOptionsState, desc: String?, header: String?, arguments: ModalOptionsArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1

    
    if let header {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(header), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }
    
    if let desc = desc {
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_title, equatable: InputDataEquatable(desc), comparable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem.init(initialSize, stableId: stableId, viewType: .singleItem, text: desc, font: .normal(.text))
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

    } 
    

    
    
    for (i, option) in state.options.enumerated() {
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(i), equatable: InputDataEquatable(option), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: option.title, type: .selectable(option.selected), viewType: bestGeneralViewType(state.options, for: i), action: {
                arguments.toggleOption(i)
            }, enabled: option.editable, disabledAction: {
                
            })
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

func ModalOptionSetController(context: AccountContext, options: [ModalOptionSet], selectOne: Bool = false, actionText: (String, NSColor), desc: String? = nil, header: String? = nil, title: String, result: @escaping ([ModalOptionSetResult])->Void) -> InputDataModalController {
    
    let initialState: ModalOptionsState = ModalOptionsState(options: options, selectOne: selectOne)
    let stateValue: Atomic<ModalOptionsState> = Atomic(value: initialState)
    let statePromise: ValuePromise<ModalOptionsState> = ValuePromise(initialState, ignoreRepeated: true)
    
    let updateState: (_ f:(ModalOptionsState)->ModalOptionsState)->Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let arguments = ModalOptionsArguments(context: context, toggleOption: { index in
        updateState {
            $0.withToggledOptionAt(index)
        }
    })
    
    let actionsDisposable = DisposableSet()
    
    let dataSignal = statePromise.get() |> mapToSignal { state in
        return .single(modalOptionsSetEntries(state: state, desc: desc, header: header, arguments: arguments))
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    var dismiss:(()->Void)?
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: title, validateData: { data in
        
        result(stateValue.with { state in
            return state.options.map { option in
                if option.selected {
                    return .selected
                } else {
                    return .none
                }
            }
        })
        
        dismiss?()
        
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    })
    
    let modalInteractions: ModalInteractions = ModalInteractions(acceptTitle: actionText.0, accept: { [weak controller] in
        controller?.validateInputValues()
    }, singleButton: true)
    
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(300, 300))
    
    dismiss = { [weak modalController] in
        modalController?.close()
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: dismiss)
    
    
    
    
    return modalController
}
