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
import TelegramCore
import Postbox

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
    let textEntities: [MessageTextEntity]
    
    var from: String?
    var to: String
    var translated: String?
    var translatedEntities: [MessageTextEntity] = []
    var fromIsRevealed: Bool
    var toIsRevealed: Bool
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
  
    let from: String
    if let fr = state.from, let value = Translate.find(fr) {
        from = _NSLocalizedString("Translate.Language.\(value.language)")
    } else {
        from = strings().translateLanguageAuto
    }
    
    let attributedFrom = NSMutableAttributedString()
    let fromText = strings().translateFrom(from)
    attributedFrom.append(string: fromText.uppercased(), color: theme.colors.listGrayText, font: .normal(.small))
    do {
        let range = fromText.nsstring.range(of: from)
        attributedFrom.addAttribute(.foregroundColor, value: theme.colors.accent, range: range)
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .attributed(attributedFrom), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, contextMenu: {
        
        var items: [ContextMenuItem] = []
        for language in Translate.codes {
            items.append(ContextMenuItem(language.language, handler: {
                arguments.updateFrom(language.code[0])
            }, state: language.code.contains(state.from ?? "") ? .on : nil))
        }
        return items
    }, clickable: true)))
    index += 1
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("original"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return TranslateTableRowItem(initialSize, stableId: stableId, context: arguments.context, text: state.text, entities: state.textEntities, revealed: state.fromIsRevealed, viewType: .singleItem, reveal: arguments.revealFrom)
    }))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let to: String
    if let value = Translate.find(state.to) {
        to = _NSLocalizedString("Translate.Language.\(value.language)")
    } else {
        to = strings().translateLanguageAuto
    }
    
    let attributedTo = NSMutableAttributedString()
    let toText = strings().translateTo(to)
    attributedTo.append(string: toText.uppercased(), color: theme.colors.listGrayText, font: .normal(.small))
    do {
        let range = toText.nsstring.range(of: to)
        attributedTo.addAttribute(.foregroundColor, value: theme.colors.accent, range: range)
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .attributed(attributedTo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, contextMenu: {
        
        var items: [ContextMenuItem] = []
        
        for language in Translate.codes {
            items.append(ContextMenuItem(language.language, handler: {
                arguments.updateTo(language.code[0])
            }, state: language.code.contains(state.to) ? .on : nil))
        }
        return items
    }, clickable: true)))
    index += 1
    
    if let text = state.translated {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("translated_\(state.to)"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return TranslateTableRowItem(initialSize, stableId: stableId, context: arguments.context, text: text, entities: state.translatedEntities, revealed: state.toIsRevealed, viewType: .singleItem, reveal: arguments.revealTo)
        }))
        index += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
        }))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}




func translateBlocks(context: AccountContext, from: String?, to: String, blocks: [(String, [MessageTextEntity])], configState: AppConfigTranslateState) -> Signal<(detect: String?, result: String, entities: [MessageTextEntity]), Translate.Error> {
    var signals:[Signal<(detect: String?, result: String, entities: [MessageTextEntity]), Translate.Error>] = []
    for block in blocks {
        switch configState {
        case .enabled:
            signals.append(context.engine.messages.translate(text: block.0, toLang: to, entities: block.1) |> `catch` { error in
                switch error {
                case .tryAlternative:
                    return .single(nil)
                default:
                    #if DEBUG
                    return .single(nil)
                    #endif
                    return .fail(.generic)
                }
            } |> mapToSignal { value in
                if let value = value {
                    return .single((detect: nil, result: value.0, entities: value.1))
                } else {
                    return Translate.translateText(text: block.0, from: from, to: to) |> map {
                        (detect: $0.detect, result: $0.result, entities: [])
                    }
                }
            })
        case .alternative:
            signals.append(Translate.translateText(text: block.0, from: from, to: to) |> map {
                (detect: $0.detect, result: $0.result, entities: [])
            })
        case .disabled, .system:
            continue
        }
        
    }
    var signal: Signal<(detect: String?, result: String, entities: [MessageTextEntity]), Translate.Error> = .single((detect: nil, result: "", entities: []))
    for current in signals {
        signal = signal |> mapToSignal { result in
            return current |> delay(2.0, queue: .mainQueue()) |> map { value in
                var entities: [MessageTextEntity] = []
                for entity in value.entities {
                    var current = entity
                    current.range = entity.range.lowerBound + result.result.length ..< entity.range.upperBound + result.result.length
                    entities.append(current)
                }
                return (detect: value.detect, result.result + value.result, entities: result.entities + entities)
            }
        }
    }
    
    return signal
}
func TranslateModalController(context: AccountContext, from: String?, toLang: String, text: String, entities: [MessageTextEntity] = [], canBreak: Bool = true, configState: AppConfigTranslateState = .enabled) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    let disposable = MetaDisposable()
    actionsDisposable.add(disposable)
    
    
    
    let initialState = State(text: text, textEntities: entities, from: from, to: toLang, fromIsRevealed: !canBreak, toIsRevealed: true)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let input = ChatTextInputState(inputText: text, selectionRange: 0..<0, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: entities), associatedMedia: [:]))
    
    var inset: Int = 0
    let blocks:[(String, [MessageTextEntity])] = cut_long_message(text, 1024).compactMap { value in
        let text = input.subInputState(from: NSMakeRange(inset, value.length))
        inset += value.length
        return (value, text.messageTextEntities())
    }

    
    let request:()->Void = {
        disposable.set(translateBlocks(context: context, from: stateValue.with { $0.from }, to: stateValue.with { $0.to }, blocks: blocks, configState: configState).start(next: { result in
            updateState { current in
                var current = current
                current.translated = result.result
                current.translatedEntities = result.entities
                if current.from == nil {
                    current.from = result.detect
                }
                return current
            }
        }, error: { error in
            updateState { current in
                var current = current
                current.translated = strings().unknownError
                return current
            }
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


