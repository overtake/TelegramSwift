//
//  SessionModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.11.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TelegramCore
import TGUIKit
import DateUtils

private final class Arguments {
    let context: AccountContext
    let toggleChats:(Bool)->Void
    let toggleIncomingCalls: (Bool) -> Void
    init(context: AccountContext, toggleChats:@escaping(Bool)->Void, toggleIncomingCalls: @escaping(Bool) -> Void) {
        self.context = context
        self.toggleChats = toggleChats
        self.toggleIncomingCalls = toggleIncomingCalls
    }
}

private struct State : Equatable {
    let session: RecentAccountSession
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    let icon = iconForSession(state.session)
    if let sticker = icon.1 {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            
            let attr: NSMutableAttributedString = .init()
            
            _ = attr.append(string: state.session.deviceModel, color: theme.colors.text, font: .medium(.title))
            _ = attr.append(string: "\n", color: theme.colors.text, font: .medium(.title))
            _ = attr.append(string: DateUtils.string(forLastSeen: state.session.activityDate), color: theme.colors.listGrayText, font: .normal(.text))

            return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: sticker, text: attr, stickerSize: NSMakeSize(60, 60), bgColor: icon.2)
        }))
        index += 1

    }
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("application"), data: InputDataGeneralData(name: strings().sessionPreviewApp, color: theme.colors.text, type: .context(state.session.appName + ", " + state.session.appVersion), viewType: .firstItem, enabled: true)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("ip"), data: InputDataGeneralData(name: strings().sessionPreviewIp, color: theme.colors.text, type: .context(state.session.ip), viewType: .innerItem, enabled: true)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("location"), data: InputDataGeneralData(name: strings().sessionPreviewLocation, color: theme.colors.text, type: .context(state.session.country), viewType: .lastItem, enabled: true)))
    index += 1

    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().sessionPreviewIpDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().sessionPreviewAcceptHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1


    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("secret"), data: InputDataGeneralData(name: strings().sessionPreviewAcceptSecret, color: theme.colors.text, type: .switchable(state.session.flags.contains(.acceptsSecretChats)), viewType: .firstItem, enabled: true, action: {
        arguments.toggleChats(!state.session.flags.contains(.acceptsSecretChats))
    })))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("calls"), data: InputDataGeneralData(name: strings().sessionPreviewAcceptCalls, color: theme.colors.text, type: .switchable(state.session.flags.contains(.acceptsSecretChats)), viewType: .lastItem, enabled: true, action: {
        arguments.toggleChats(!state.session.flags.contains(.acceptsSecretChats))
    })))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func SessionModalController(context: AccountContext, session: RecentAccountSession) -> InputDataModalController {

    let actionsDisposable = MetaDisposable()

    let initialState = State(session: session)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, toggleChats: { updated in
        actionsDisposable.set(context.activeSessionsContext.updateSessionAcceptsSecretChats(session, accepts: updated).start())
    }, toggleIncomingCalls: { updated in
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().sessionPreviewTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().sessionPreviewTerminateSession, accept: {
        confirm(for: context.window, information: strings().recentSessionsConfirmRevoke, successHandler: { _ in
            _ = context.activeSessionsContext.remove(hash: session.hash).start()
            close?()
        })
    }, drawBorder: true, height: 50, singleButton: true)
    
    DispatchQueue.main.async {
        modalInteractions.updateDone { button in
            button.set(color: theme.colors.redUI, for: .Normal)
        }
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    /*

     */
    
    return modalController
    
}


/*
 
 */



