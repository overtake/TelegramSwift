//
//  Star_Transaction.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let transaction: StarsContext.State.Transaction
    fileprivate let peer: EnginePeer?
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: StarsContext.State.Transaction, peer: EnginePeer?) {
        self.context = context
        self.transaction = transaction
        self.peer = peer
        super.init(initialSize, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
}

private final class HeaderView : GeneralContainableRowView {
    private let photoView: AvatarControl = .init(font: .avatar(15))
    private let sceneView: GoldenStarSceneView
    required init(frame frameRect: NSRect) {
        self.sceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, frameRect.width, 150))
        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(80, 80))
        addSubview(sceneView)
        addSubview(photoView)
        
        sceneView.hideStar()

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        photoView.setPeer(account: item.context.account, peer: item.peer?._asPeer())
    }
    
    override func layout() {
        super.layout()
        sceneView.centerX(y: -10)
        photoView.centerX(y: 30)
    }
    
    
}

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var transaction: StarsContext.State.Transaction
    var peer: EnginePeer
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, transaction: state.transaction, peer: state.peer)
    }))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func Star_Transaction(context: AccountContext, peer: EnginePeer, transaction: StarsContext.State.Transaction) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    let initialState = State(transaction: transaction, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


