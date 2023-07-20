//
//  InputURLFormatterModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private struct State : Equatable {
    var text: String
    var url: String?
    init(text: String, url: String?) {
        self.text = text
        self.url = url
    }
}

private let _id_input_url = InputDataIdentifier("_id_input_url")
private let _id_text = InputDataIdentifier("_id_text")

private func entries(state: State, presentation: TelegramPresentationTheme) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().inputFormatterTextHeader), data: InputDataGeneralTextData(color: presentation.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    let itemTheme = GeneralRowItem.Theme.initialize(presentation)
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.text), error: nil, identifier: _id_text, mode: .plain, data: InputDataRowData( viewType: .singleItem, customTheme: itemTheme), placeholder: nil, inputPlaceholder: strings().inputFormatterTextPlaceholder, filter: { $0 }, limit: 10000))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().inputFormatterURLHeader), data: InputDataGeneralTextData(color: presentation.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.url), error: nil, identifier: _id_input_url, mode: .plain, data: InputDataRowData( viewType: .singleItem, customTheme: itemTheme), placeholder: nil, inputPlaceholder: strings().inputFormatterURLPlaceholder, filter: { $0 }, limit: 10000))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InputURLFormatterModalController(string: String, defaultUrl: String? = nil, completion: @escaping(String, String?) -> Void, presentation: TelegramPresentationTheme? = nil) -> InputDataModalController {
    
    
    let initialState = State(text: string, url: defaultUrl?.removingPercentEncoding)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let dataSignal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return entries(state: state, presentation: presentation ?? theme)
    }
    
    var close: (() -> Void)? = nil
    
    let controller = InputDataController(dataSignal: dataSignal |> map { InputDataSignalValue(entries: $0) }, title: strings().inputFormatterURLHeader, validateData: { data in
        
        let url = data[_id_input_url]?.stringValue
        let text = data[_id_text]?.stringValue ?? ""
        
        if text.isEmpty {
            return .fail(.fields([_id_text : .shake]))
        }
        
        if let string = url {
            
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
            
            completion(text, url)
            close?()
            return .none
        }
        
        return .fail(.fields([_id_input_url: .shake]))
        
    }, updateDatas: { data in
        updateState { current in
            var current = current
            current.url = data[_id_input_url]?.stringValue
            current.text = data[_id_text]?.stringValue ?? ""
            return current
        }
        return .none
    })
    
    let modalTheme: ModalController.Theme?
    
    if let presentation = presentation {
        modalTheme = ModalController.Theme(text: presentation.colors.text, grayText: presentation.colors.grayText, background: presentation.colors.background, border: presentation.colors.border, accent: presentation.colors.accent, grayForeground: presentation.colors.grayForeground)
    } else {
        modalTheme = nil
    }
    let modalInteractions = ModalInteractions(acceptTitle: strings().modalOK, accept: { [weak controller] in
        controller?.validateInputValues()
    }, drawBorder: true, singleButton: true, customTheme: {
        return modalTheme ?? .init()
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    modalController.getModalTheme = {
        return modalTheme ?? .init()
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.getBackgroundColor = {
        return presentation?.colors.listBackground ?? theme.colors.listBackground
    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.didAppear = { controller in
        controller.makeFirstResponderIfPossible(for: _id_input_url, focusIdentifier: nil, scrollDown: false, scrollIfNeeded: true)
    }
   
    
    return modalController
    
}
