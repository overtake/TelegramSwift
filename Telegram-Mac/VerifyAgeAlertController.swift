//
//  VerifyAgeAlertController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import Localization

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {

}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    let attr = NSMutableAttributedString()
    
    attr.append(string: strings().ageVerificationTitle, color: theme.colors.text, font: .medium(.huge))
    attr.append(string: "\n", color: theme.colors.text, font: .medium(.text))
    let country = arguments.context.appConfiguration.getStringValue("verify_age_country", orElse: "")
    if country.isEmpty {
        attr.append(string: _NSLocalizedString("AgeVerification.Text"), color: theme.colors.text, font: .normal(.text))
    } else {
        attr.append(string: _NSLocalizedString("AgeVerification.Text.\(country)"), color: theme.colors.text, font: .normal(.text))
    }
    
    attr.detectBoldColorInString(with: .medium(.text))
    
    let image = generateImage(NSMakeSize(90, 90), contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.setFillColor(theme.colors.accent.cgColor)
        ctx.fillEllipse(in: size.bounds)
        let image = NSImage(resource: .iconAgeVerification).precomposed(theme.colors.underSelectedColor)
        ctx.draw(image, in: size.bounds.focus(image.backingSize))
    })

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("body"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: nil, text: attr, stickerSize: NSMakeSize(90, 90), image: image)
    }))
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func VerifyAgeAlertController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
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
    
    controller.validateData = { _ in
        let botUsername = context.appConfiguration.getStringValue("verify_age_bot_username", orElse: "")
        
        if !botUsername.isEmpty {
            _ = showModalProgress(signal: context.engine.peers.resolvePeerByName(name: botUsername, referrer: nil), for: window).start(next: { result in
                switch result {
                case let .result(peer):
                    if let peer {
                        BrowserStateContext.get(context).open(tab: .mainapp(bot: peer, source: .generic))
                    }
                default:
                    break
                }
            })
        }
        
        close?()
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().ageVerificationVerify, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}


/*
 
 */



