//
//  TranslateModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import Translate
import ObjcUtils
import Localization

private final class Arguments {
    let context: AccountContext
    let revealFrom:()->Void
    let revealTo:()->Void
    let updateFrom:(String?)->Void
    let updateTo:(String)->Void

    init(context: AccountContext, revealFrom:@escaping()->Void, revealTo:@escaping()->Void, updateFrom:@escaping(String?)->Void, updateTo:@escaping(String)->Void) {
        self.context = context
        self.revealFrom = revealFrom
        self.revealTo = revealTo
        self.updateFrom = updateFrom
        self.updateTo = updateTo
    }
}

private struct State : Equatable {
    let text: String
    var from: String?
    var to: String
    var translated: String?
    var fromIsRevealed: Bool
    var toIsRevealed: Bool
}

@available(macOS 10.14, *)
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    let from: String
    if let fr = state.from {
        from = _NSLocalizedString("Translate.Language.\(fr)")
    } else {
        from = strings().translateLanguageAuto
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().translateFrom(from).uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, contextMenu: {
        
        var items: [ContextMenuItem] = []
        for language in Translate.supportedTranslationLanguages {
            if let emoji = Translate.languagesEmojies[language] {
                items.append(ContextMenuItem(emoji + " " + language, handler: {
                    arguments.updateFrom(language)
                }))
            }
        }
        return items
    }, clickable: true)))
    index += 1
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("original"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return TranslateTableRowItem(initialSize, stableId: stableId, text: state.text, revealed: state.fromIsRevealed, viewType: .singleItem, reveal: arguments.revealFrom)
    }))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let to: String = _NSLocalizedString("Translate.Language.\(state.to)")
   
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().translateTo(to).uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, contextMenu: {
        
        var items: [ContextMenuItem] = []
        
        for language in Translate.supportedTranslationLanguages {
            if let emoji = Translate.languagesEmojies[language] {
                items.append(ContextMenuItem(emoji + " " + language, handler: {
                    arguments.updateTo(language)
                }))
            }
        }
        return items
    }, clickable: true)))
    index += 1
    
    if let text = state.translated {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("translated_\(state.to)"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return TranslateTableRowItem(initialSize, stableId: stableId, text: text, revealed: state.toIsRevealed, viewType: .singleItem, reveal: arguments.revealTo)
        }))
        index += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem.init(initialSize, stableId: stableId, viewType: .singleItem)
        }))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}
@available(macOS 10.14, *)
private func translate(from: String?, to: String, blocks: [String]) -> Signal<String, Translate.Error> {
    var signals:[Signal<String, Translate.Error>] = []
    for block in blocks {
        signals.append(Translate.translateText(text: block, from: from, to: to))
    }
    var signal: Signal<String, Translate.Error> = .single("")
    for current in signals {
        signal = signal |> mapToSignal { result in
            return current |> delay(2.0, queue: .mainQueue()) |> map {
                return result + $0
            }
        }
    }
    return signal
}
@available(macOS 10.14, *)
func TranslateModalController(context: AccountContext, from: String?, toLang: String, text: String) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    let disposable = MetaDisposable()
    actionsDisposable.add(disposable)
    
    
    let initialState = State(text: text, from: from, to: toLang, fromIsRevealed: false, toIsRevealed: true)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
   let blocks = cut_long_message(text, 1024)
    
    
    let request:()->Void = {
        disposable.set(translate(from: stateValue.with { $0.from }, to: stateValue.with { $0.to }, blocks: blocks).start(next: { result in
            updateState { current in
                var current = current
                current.translated = result
                return current
            }
        }, error: { error in
            var bp = 0
            bp += 1
        }))
    }
    

    let arguments = Arguments(context: context, revealFrom: {
        updateState { current in
            var current = current
            current.fromIsRevealed = true
            return current
        }
    }, revealTo: {
        updateState { current in
            var current = current
            current.toIsRevealed = true
            return current
        }
    }, updateFrom: { language in
        updateState { current in
            var current = current
            current.translated = nil
            current.from = language
            return current
        }
        request()
    }, updateTo: { language in
        updateState { current in
            var current = current
            current.translated = nil
            current.to = language
            return current
        }
        request()
    })
    
    request()
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().translateTitle)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


