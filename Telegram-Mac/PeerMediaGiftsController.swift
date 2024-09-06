//
//  PeerMediaGiftsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var gifts: [PeerStarGift] = []
    var perRowCount: Int = 3
}

private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
  
    let chunks = state.gifts.chunks(state.perRowCount)
    
    for (i, chunk) in chunks.enumerated() {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
            return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0) }, perRowCount: state.perRowCount, fitToSize: true, insets: NSEdgeInsets(), callback: { option in
                
            })
        }))
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PeerMediaGiftsController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    var starGifts: [PeerStarGift] = []
    let prices: [Int64] = [10, 25, 50, 100, 200, 500, 1000]
    let files: [TelegramMediaFile] = [LocalAnimatedSticker.premium_gift_3.file, LocalAnimatedSticker.premium_gift_6.file, LocalAnimatedSticker.premium_gift_12.file]

    for i in 0 ..< 100 {
        starGifts.append(.init(media: files[Int(abs(arc4random64())) % files.count], stars: prices[Int(abs(arc4random64())) % prices.count], limited: arc4random64() % 2 == 0))
    }
    
    
    let initialState = State(gifts: starGifts)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.didResize = { controller in
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, controller.atomicSize.with { $0.width })
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 110 {
                break
            } else {
                rowCount -= 1
            }
        }
        updateState { current in
            var current = current
            current.perRowCount = rowCount
            return current
        }
    }

    return controller
    
}




