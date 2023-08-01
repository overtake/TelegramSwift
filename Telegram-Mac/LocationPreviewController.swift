//
//  LocationPreviewController.swift
//  Telegram
//
//  Created by Mike Renoir on 01.08.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context:AccountContext
    let presentation: TelegramPresentationTheme
    init(context: AccountContext, presentation: TelegramPresentationTheme) {
        self.context = context
        self.presentation = presentation
    }
}


private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer != nil) != (rhs.peer != nil) {
            return false
        }
        return lhs.map == rhs.map
    }
    
    var map: MediaArea.Venue
    var peer: Peer?
    init(map: MediaArea.Venue, peer: Peer?) {
        self.map = map
        self.peer = peer
    }
}

private let _id_map = InputDataIdentifier("_id_map")
@available(macOS 10.13, *)
private func entries(_ state:State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map, equatable: InputDataEquatable(state.map), comparable: nil, item: { initialSize, stableId in
        return LocationPreviewMapRowItem(initialSize, height: 330, stableId: stableId, context: arguments.context, latitude: state.map.latitude, longitude: state.map.longitude, peer: state.peer, viewType: .legacy, presentation: arguments.presentation)
    }))
    index += 1
    
    return entries
}
@available(macOS 10.13, *)
func LocationModalPreview(_ context: AccountContext, venue: MediaArea.Venue, peer: Peer?, presentation: TelegramPresentationTheme) -> InputDataModalController {
    
    let initialState = State(map: venue, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = Arguments(context: context, presentation: presentation)
    
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().locationPreviewTitle)
    

    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().locationPreviewOpenInMaps, accept: {
        close?()
        execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", stateValue.with { $0.map.latitude })),\(String(format:"%f", stateValue.with { $0.map.longitude }))", false))
    }, height: 50, singleButton: true, customTheme: {
        .init(presentation: presentation)
    })
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 330))
    
    modalController.getModalTheme = {
        .init(presentation: presentation)
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
