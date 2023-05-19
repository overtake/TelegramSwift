//
//  RTMPStartController.swift
//  Telegram
//
//  Created by Mike Renoir on 23.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let copyToClipboard: (String)->Void
    let toggleHideKey:()->Void
    init(context: AccountContext, copyToClipboard: @escaping(String)->Void, toggleHideKey:@escaping()->Void) {
        self.context = context
        self.copyToClipboard = copyToClipboard
        self.toggleHideKey = toggleHideKey
    }
}

private struct State : Equatable {
    var credentials: GroupCallStreamCredentials?
    var error: String? = nil
    var hideKey: Bool = true
}

private let _id_server_url = InputDataIdentifier("_id_server_url")
private let _id_stream_key = InputDataIdentifier("_id_stream_key")
private let _id_loading = InputDataIdentifier("_id_loading")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatRTMPInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    if let credentials = state.credentials {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_server_url, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return TextAndLabelItem(initialSize, stableId: stableId, label: strings().voiceChatRTMPServerURL, copyMenuText: strings().contextAlertCopied, labelColor: theme.colors.text, textColor: theme.colors.accent, text: credentials.url, context: arguments.context, viewType: .firstItem, isTextSelectable: false, callback: {
                arguments.copyToClipboard(credentials.url)
            }, selectFullWord: true, canCopy: true, _copyToClipboard: {
                arguments.copyToClipboard(credentials.url)
            }, textFont: .code(.title))
        }))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stream_key, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return TextAndLabelItem(initialSize, stableId: stableId, label: strings().voiceChatRTMPStreamKey, copyMenuText: strings().contextAlertCopied, labelColor: theme.colors.text, textColor: theme.colors.accent, text: credentials.streamKey, context: arguments.context, viewType: .lastItem, isTextSelectable: false, callback: {
                arguments.copyToClipboard(credentials.streamKey)
            }, selectFullWord: true, canCopy: true, _copyToClipboard: {
                arguments.copyToClipboard(credentials.streamKey)
            }, textFont: .code(.title), hideText: state.hideKey, toggleHide: arguments.toggleHideKey)
        }))
        index += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatRTMPDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    } else if let error = state.error {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error), data: .init(color: theme.colors.redUI, viewType: .textBottomItem)))
        index += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
        }))
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func RTMPStartController(context: AccountContext, peerId: PeerId, scheduleDate: Date?, completion: @escaping(PeerId, Date?, Bool)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    var close:(()->Void)? = nil
    var getController:(()->ViewController?)? = nil
    
    let arguments = Arguments(context: context, copyToClipboard: {  value in
        copyToClipboard(value)
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
    }, toggleHideKey: {
        updateState { current in
            var current = current
            current.hideKey = !current.hideKey
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().voiceChatRTMPTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.validateData = { _ in
        completion(peerId, scheduleDate, true)
        return .success(.custom({
            close?()
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().voiceChatRTMPOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    let getSignal = context.engine.calls.getGroupCallStreamCredentials(peerId: EnginePeer.Id.init(peerId.toInt64()), revokePreviousCredentials: false)
    
    actionsDisposable.add(getSignal.start(next: { credentials in
        updateState { current in
            var current = current
            current.credentials = credentials
            current.error = nil
            return current
        }
    }, error: { error in
        updateState { current in
            var current = current
            current.credentials = nil
            current.error = strings().unknownError
            return current
        }
    }))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}


