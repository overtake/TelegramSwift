//
//  LiveLocationViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import MapKit
import TelegramCore

import SwiftSignalKit
import Postbox

private final class LocationPreviewArguments {
    let context:AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}


private struct LocationPreviewState : Equatable {
    static func == (lhs: LocationPreviewState, rhs: LocationPreviewState) -> Bool {
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer != nil) != (rhs.peer != nil) {
            return false
        }
        return lhs.map == rhs.map
    }
    
    let map: TelegramMediaMap
    let peer: Peer?
    init(map: TelegramMediaMap, peer: Peer?) {
        self.map = map
        self.peer = peer
    }
    func withUpdatedMap(_ map: TelegramMediaMap) -> LocationPreviewState {
        return LocationPreviewState(map: map, peer: self.peer)
    }
    func withUpdatedPeer(_ peer: Peer?) -> LocationPreviewState {
        return LocationPreviewState(map: self.map, peer: peer)
    }
}

private let _id_map = InputDataIdentifier("_id_map")
@available(macOS 10.13, *)
private func entries(_ state:LocationPreviewState, arguments: LocationPreviewArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map, equatable: InputDataEquatable(state.map), comparable: nil, item: { initialSize, stableId in
        return LocationPreviewMapRowItem(initialSize, height: 330, stableId: stableId, context: arguments.context, latitude: state.map.latitude, longitude: state.map.longitude, peer: state.peer, viewType: .legacy, presentation: theme)
    }))
    index += 1
    
    entries.append(.sectionId(index, type: .customModern(20)))
    sectionId += 1
    
    return entries
}
@available(macOS 10.13, *)
func LocationModalPreview(_ context: AccountContext, map mapValue: TelegramMediaMap, peer: Peer?, messageId: MessageId) -> InputDataModalController {
    
    let initialState = LocationPreviewState(map: mapValue, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((LocationPreviewState) -> LocationPreviewState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let arguments = LocationPreviewArguments(context: context)
    
    let messageView = context.account.postbox.messageView(messageId) |> map {
        $0.message
    }
    
    let disposable = messageView.start(next: { message in
        updateState { value in
            var value = value.withUpdatedPeer(message?.effectiveAuthor)
            if let map = message?.anyMedia as? TelegramMediaMap {
                value = value.withUpdatedMap(map)
            }
            return value
        }
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().locationPreviewTitle)
    
    controller.afterDisappear = {
        disposable.dispose()
    }
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().locationPreviewOpenInMaps, accept: {
        close?()
        execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", stateValue.with { $0.map.latitude })),\(String(format:"%f", stateValue.with { $0.map.longitude }))", false))
    }, singleButton: true)
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(380, 330))
    
    
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
