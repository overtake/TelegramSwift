//
//  SelectCountryModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

private final class Arguments {
    let context: AccountContext
    let toggle: (Country)->Void
    init(context: AccountContext, toggle: @escaping(Country)->Void) {
        self.context = context
        self.toggle = toggle
    }
}

private struct State : Equatable {
    var countries: [Country] = []
    var selected: [Country] = []
    var limit: Int
}
private func _id_country(_ country: Country) -> InputDataIdentifier {
    return .init("_id_country_\(country.id)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    let limitReached = state.limit == state.selected.count
    
    for (i, country) in state.countries.enumerated() {
        let selected = state.selected.contains(country)
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_country(country), data: .init(name: country.emojiName, color: theme.colors.text, type: .selectableLeft(selected), viewType: bestGeneralViewType(state.countries, for: i), enabled: selected || !limitReached, action: {
            arguments.toggle(country)
        })))
    }
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func SelectCountries(context: AccountContext, selected: [Country] = [], limit: Int = 10, complete: @escaping([Country])->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    var close:(()->Void)? = nil

    let initialState = State(selected: selected, limit: limit)
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let getCountries = appearanceSignal |> mapToSignal { appearance in
        context.engine.localization.getCountriesList(accountManager: context.sharedContext.accountManager, langCode: appearance.language.baseLanguageCode)
    }
    
    actionsDisposable.add(getCountries.start(next: { countries in
        updateState { current in
            var current = current
            current.countries = countries
            return current
        }
    }))

    let arguments = Arguments(context: context, toggle: { country in
        let contains = stateValue.with { $0.selected.contains(country) }
        let count = stateValue.with { $0.selected.count }
        updateState { current in
            var current = current
            if contains {
                current.selected.removeAll(where: { $0 == country })
            } else {
                current.selected.append(country)
            }
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().selectCountriesTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        complete(stateValue.with { $0.selected })
        close?()
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().selectCountriesOK, accept: { [weak controller] in
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


