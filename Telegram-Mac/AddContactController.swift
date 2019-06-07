//
//  AddContactController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

private struct NewContactState : Equatable {
    
}

private func newContactEntries(state: NewContactState, peer: Peer) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int = 0
    var index: Int = 0
    
    
    
    return entries
}

func NewContactController(context: AccountContext, peerId: PeerId) -> InputDataModalController {

    let initialState: NewContactState = NewContactState()
    let stateValue: Atomic<NewContactState> = Atomic(value: initialState)
    let statePromise: ValuePromise<NewContactState> = ValuePromise(initialState, ignoreRepeated: true)
    
    let updateState: (_ f:(NewContactState)->NewContactState)->Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let dataSignal = combineLatest(statePromise.get(), context.account.postbox.loadedPeerWithId(peerId)) |> map { state, peer in
        return newContactEntries(state: state, peer: peer)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.newContactTitle)
    
    let modalInteractions: ModalInteractions = ModalInteractions(acceptTitle: L10n.navigationAdd, accept: {
        
    }, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(300, 300))
    
    return modalController
}
