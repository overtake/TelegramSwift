//
//  InputURLFormatterModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

private struct InputURLFormatterState : Equatable {
    let text: String
    let url: String?
    init(text: String, url: String?) {
        self.text = text
        self.url = url
    }
    
    func withUpdatedUrl(_ url: String?) -> InputURLFormatterState {
        return InputURLFormatterState(text: self.text, url: url)
    }
}

private let _id_input_url = InputDataIdentifier("_id_input_url")

private func inputURLFormatterEntries(state: InputURLFormatterState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.inputFormatterTextHeader), data: InputDataGeneralTextData(color: theme.colors.text, viewType: .textTopItem)))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_text"), equatable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem.init(initialSize, stableId: stableId, viewType: .singleItem, text: state.text, font: .normal(.text))
    }))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.inputFormatterURLHeader), data: InputDataGeneralTextData(color: theme.colors.text, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.url), error: nil, identifier: _id_input_url, mode: .plain, data: InputDataRowData( viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.inputFormatterURLHeader, filter: { $0 }, limit: 10000))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InputURLFormatterModalController(string: String, defaultUrl: String? = nil, completion: @escaping(String) -> Void) -> InputDataModalController {
    
    
    let initialState = InputURLFormatterState(text: string, url: defaultUrl?.removingPercentEncoding)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InputURLFormatterState) -> InputURLFormatterState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let dataSignal = statePromise.get() |> map { state in
        return inputURLFormatterEntries(state: state)
    }
    
    var close: (() -> Void)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal |> map { InputDataSignalValue(entries: $0) }, title: L10n.inputFormatterURLHeader, validateData: { data in
        
        if let string = data[_id_input_url]?.stringValue {
            
            let attr = NSMutableAttributedString(string: string)
            
            attr.detectLinks(type: [.Links])
            
            var url:String? = nil

            
            attr.enumerateAttribute(NSAttributedString.Key.link, in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                
                if let value = value as? inAppLink {
                    switch value {
                    case let .external(link, _):
                        url = link
                        break
                    default:
                        break
                    }
                }
                
                let s: ObjCBool = (url != nil) ? true : false
                stop.pointee = s
                
            })
            
            if let url = url {
                completion(url)
                close?()
                return .none
            }
            
            
        }
        
        return .fail(.fields([_id_input_url: .shake]))
        
    }, updateDatas: { data in
        
        updateState {
            $0.withUpdatedUrl(data[_id_input_url]?.stringValue)
        }
        
        return .none
        
    })
    
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalOK, accept: { [weak controller] in
        controller?.validateInputValues()
    }, drawBorder: true, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
   
    
    return modalController
    
}
