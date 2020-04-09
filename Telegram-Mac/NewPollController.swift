//
//  NewPollController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit

private let optionsLimit: Int = 10
private let maxTextLength:Int32 = 255
private let maxOptionLength: Int32 = 100


private func _id_input_option() -> InputDataIdentifier {
    return InputDataIdentifier("_id_input_option_\(arc4random())")
}
private let _id_input_title = InputDataIdentifier("_id_input_title")
private let _id_input_add_option = InputDataIdentifier("_id_input_add_option")

private let _id_anonymous = InputDataIdentifier("_id_anonymous")
private let _id_multiple_choice = InputDataIdentifier("_id_multiple_choice")
private let _id_quiz = InputDataIdentifier("_id_quiz")
private let _id_explanation = InputDataIdentifier("_id_explanation")


private struct NewPollOption : Equatable {
    let identifier: InputDataIdentifier
    let text: String
    let selected: Bool
    init(identifier: InputDataIdentifier, text: String, selected: Bool) {
        self.identifier = identifier
        self.text = text
        self.selected = selected
    }
    func withUpdatedText(_ text: String) -> NewPollOption {
        return NewPollOption(identifier: self.identifier, text: text, selected: self.selected)
    }
    func withUpdatedSelected(_ selected: Bool) -> NewPollOption {
        return NewPollOption(identifier: self.identifier, text: self.text, selected: selected)
    }
}

private enum NewPollMode : Equatable {
    case normal(anonymous: Bool)
    case quiz(anonymous: Bool)
    case multiple(anonymous: Bool)
    
    var isAnonymous: Bool {
        switch self {
        case let .normal(anonymous):
            return anonymous
        case let .quiz(anonymous):
            return anonymous
        case let .multiple(anonymous):
            return anonymous
        }
    }
    func withUpdatedIsAnonymous(_ anonymous: Bool) -> NewPollMode {
        switch self {
        case .normal:
            return .normal(anonymous: anonymous)
        case .quiz:
            return .quiz(anonymous: anonymous)
        case .multiple:
            return .multiple(anonymous: anonymous)
        }
    }
    
    var isQuiz: Bool {
        switch self {
        case .quiz:
            return true
        default:
            return false
        }
    }
    var isMultiple: Bool {
        switch self {
        case .multiple:
            return true
        default:
            return false
        }
    }
    
    func isModeEqual(to mode: NewPollMode) -> Bool {
        switch self {
        case .normal:
            return !mode.isQuiz && !mode.isMultiple
        case .quiz:
            return mode.isQuiz
        case .multiple:
            return mode.isMultiple
        }
    }
    
    var publicity: TelegramMediaPollPublicity {
        if isAnonymous {
            return .anonymous
        } else {
            return .public
        }
    }
    var kind: TelegramMediaPollKind {
        switch self {
        case .normal:
            return .poll(multipleAnswers: false)
        case .multiple:
            return .poll(multipleAnswers: true)
        case .quiz:
            return .quiz
        }
    }
}

private struct NewPollState : Equatable {
    let title: String
    let options: [NewPollOption]
    private let random: UInt32
    let mode: NewPollMode
    let isQuiz: Bool?
    init(title: String, options: [NewPollOption], random: UInt32, mode: NewPollMode, isQuiz: Bool?) {
        self.title = title
        self.options = options
        self.random = random
        self.mode = mode
        self.isQuiz = isQuiz
    }
    
    func withUpdatedTitle(_ title: String) -> NewPollState {
        return NewPollState(title: title, options: self.options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    func withDeleteOption(_ identifier: InputDataIdentifier) -> NewPollState {
        var options = self.options
        options.removeAll(where: {$0.identifier == identifier})
        return NewPollState(title: title, options: options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    
    func withUnselectItems() -> NewPollState {
        return NewPollState(title: self.title, options: self.options.map { $0.withUpdatedSelected(false) }, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    
    func withUpdatedOption(_ f:(NewPollOption) -> NewPollOption, forKey identifier: InputDataIdentifier) -> NewPollState {
        var options = self.options
        if let index = options.firstIndex(where: {$0.identifier == identifier}) {
            options[index] = f(options[index])
        }
        return NewPollState(title: self.title, options: options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    
    func withUpdatedOptions(_ data:[InputDataIdentifier : InputDataValue]) -> NewPollState {
        var options = self.options
        for (key, value) in data {
            if let index = self.indexOf(key) {
                options[index] = options[index].withUpdatedText(value.stringValue ?? options[index].text)
            }
        }
        return NewPollState(title: self.title, options: options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    
    func withAddedOption(_ option: NewPollOption) -> NewPollState {
        var options = self.options
        options.append(option)
        return NewPollState(title: self.title, options: options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    func withUpdatedPos(_ previous: Int, _ current: Int) -> NewPollState {
        var options = self.options
        options.move(at: previous, to: current)
        return NewPollState(title: self.title, options: options, random: self.random, mode: self.mode, isQuiz: self.isQuiz)
    }
    
    func indexOf(_ identifier: InputDataIdentifier) -> Int? {
        return options.firstIndex(where: { $0.identifier == identifier })
    }
    
    func withUpdatedState() -> NewPollState {
         return NewPollState(title: self.title, options: self.options, random: arc4random(), mode: self.mode, isQuiz: self.isQuiz)
    }
    func withUpdatedMode(_ mode: NewPollMode) -> NewPollState {
        return NewPollState(title: self.title, options: self.options, random: self.random, mode: mode, isQuiz: self.isQuiz)
    }
    
    var isEnabled: Bool {
        let isEnabled = !title.trimmed.isEmpty && options.filter({!$0.text.trimmed.isEmpty}).count >= 2
        switch self.mode {
        case .quiz:
            if let option = self.options.first(where: {$0.selected }) {
                if option.text.trimmed.isEmpty {
                    return false
                }
            }
            return isEnabled
        default:
            return isEnabled
        }
    }
    
    var shouldShowTooltipForQuiz: Bool {
        return self.mode.isQuiz && !self.options.contains(where: { $0.selected })
    }
    
    var media: TelegramMediaPoll {
        var options: [TelegramMediaPollOption] = []
        var answers: [Data]?
        for (i, option) in self.options.enumerated() {
            if !option.text.trimmed.isEmpty {
                options.append(TelegramMediaPollOption(text: option.text.trimmed, opaqueIdentifier: "\(i)".data(using: .utf8)!))
                if option.selected {
                    answers = [options.last!.opaqueIdentifier]
                }
            }
        }
        
        return TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: arc4random64()), publicity: mode.publicity, kind: mode.kind, text: title.trimmed, options: options, correctAnswers: answers, results: TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: [], solution: nil), isClosed: false, deadlineTimeout: nil)
    }
}

private func newPollEntries(_ state: NewPollState, context: AccountContext, canBePublic: Bool, deleteOption:@escaping(InputDataIdentifier) -> Void, updateQuizSelected:@escaping(InputDataIdentifier) -> Void, updateMode: @escaping(NewPollMode)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.title.length > maxTextLength / 3 * 2 ? L10n.newPollQuestionHeaderLimit(Int(maxTextLength) - state.title.length) : L10n.newPollQuestionHeader), data: InputDataGeneralTextData(detectBold: false, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_input_title, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.newPollQuestionPlaceholder, filter: { text in
        
        var text = text
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        if !text.isEmpty {
            while text.range(of: "\n")?.lowerBound == text.startIndex {
                text = String(text[text.index(after: text.startIndex)...])
            }
        }
        
        return text
        
    }, limit: maxTextLength))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.newPollOptionsHeader), data: InputDataGeneralTextData(detectBold: false, viewType: .textTopItem)))
    index += 1
    
    let sorted = state.options
    
    
    
    for (i, option) in sorted.enumerated() {
        
        var viewType: GeneralViewType = bestGeneralViewType(sorted, for: i)
        if i == sorted.count - 1, state.options.count < optionsLimit {
            if i == 0 {
                viewType = .firstItem
            } else {
                viewType = .innerItem
            }
        }
        let placeholder: InputDataInputPlaceholder?
        switch state.mode {
        case .multiple:
            placeholder = InputDataInputPlaceholder(hasLimitationText: true)
        case .normal:
            placeholder = InputDataInputPlaceholder(hasLimitationText: true)
        case .quiz:
            
            placeholder = InputDataInputPlaceholder(nil, icon: option.selected ? theme.icons.chatToggleSelected : theme.icons.poll_quiz_unselected, drawBorderAfterPlaceholder: true, hasLimitationText: true, action: {
                updateQuizSelected(option.identifier)
                //deleteOption(option.identifier)
            })
        }
        
        
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(option.text), error: nil, identifier: option.identifier, mode: .plain, data: InputDataRowData(viewType: viewType, rightItem: .action(theme.icons.recentDismiss, .custom({ _, _ in 
            deleteOption(option.identifier)
        }))), placeholder: placeholder, inputPlaceholder: L10n.newPollOptionsPlaceholder, filter: { text in
            return text.trimmingCharacters(in: CharacterSet.newlines)
        }, limit: maxOptionLength))
        index += 1
    }
    if state.options.count < optionsLimit {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_input_add_option, data: InputDataGeneralData(name: L10n.newPollOptionsAddOption, color: theme.colors.accent, icon: theme.icons.pollAddOption, type: .none, viewType: state.options.isEmpty ? .singleItem : .lastItem, action: nil)))
        index += 1
    }


    index = 50
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.options.count < 2 ? L10n.newPollOptionsDescriptionMinimumCountable(2) : optionsLimit == state.options.count ? L10n.newPollOptionsDescriptionLimitReached : L10n.newPollOptionsDescriptionCountable(optionsLimit - state.options.count)), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    
    var hideMultiple: Bool = false
    var hideQuiz: Bool = false
    if let isQuiz = state.isQuiz {
        hideMultiple = isQuiz
        hideQuiz = true
    }
    
    if canBePublic {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_anonymous, data: InputDataGeneralData(name: L10n.newPollAnonymous, color: theme.colors.text, type: .switchable(state.mode.isAnonymous), viewType: hideQuiz && hideMultiple ? .singleItem : .firstItem, justUpdate: arc4random64(), action: {
            updateMode(state.mode.withUpdatedIsAnonymous(!state.mode.isAnonymous))
        })))
        index += 1
    }
    
    
    
    if !hideMultiple {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_multiple_choice, data: InputDataGeneralData(name: L10n.newPollMultipleChoice, color: theme.colors.text, type: .switchable(state.mode.isMultiple), viewType: canBePublic ? hideQuiz ? .lastItem : .innerItem : hideQuiz ? .lastItem : .firstItem, enabled: !state.mode.isQuiz, justUpdate: arc4random64(), action: {
            if state.mode.isMultiple {
                updateMode(.normal(anonymous: state.mode.isAnonymous))
            } else {
                updateMode(.multiple(anonymous: state.mode.isAnonymous))
            }
        }, disabledAction: {
            alert(for: context.window, info: L10n.newPollQuizMultipleError)
        })))
        index += 1
    }
    
   
    
    if !hideQuiz {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_quiz, data: InputDataGeneralData(name: L10n.newPollQuiz, color: theme.colors.text, type: .switchable(state.mode.isQuiz), viewType: .lastItem, enabled: !state.mode.isMultiple, justUpdate: arc4random64(), action: {
            if state.mode.isQuiz {
                updateMode(.normal(anonymous: state.mode.isAnonymous))
            } else {
                updateMode(.quiz(anonymous: state.mode.isAnonymous))
            }
        })))
        index += 1
        
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.newPollQuizDesc), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        
        
    } else if state.isQuiz == true {
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain(L10n.newPollQuizDesc), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    
    switch state.mode {
    case .quiz:
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain("EXPLANATION"), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        
        entries.append(.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_explanation, mode: .plain, data: InputDataRowData(viewType: .singleItem, rightItem: .action(theme.icons.recentDismiss, .custom { _, _ in
            
            })), placeholder: nil, inputPlaceholder: "Add a Comment (Optional)", filter: { text in
                return text.trimmingCharacters(in: CharacterSet.newlines)
        }, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: .plain("Users will see this comment after choosing a wrong answer, good for educational purposes."), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    default:
        break
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func NewPollController(chatInteraction: ChatInteraction, isQuiz: Bool? = nil) -> InputDataModalController {
    
    
    let mode: NewPollMode
    if let isQuiz = isQuiz, isQuiz {
        mode = .quiz(anonymous: true)
    } else {
        mode = .normal(anonymous: true)
    }
    
    let initialState = NewPollState(title: "", options: [NewPollOption(identifier: _id_input_option(), text: "", selected: false), NewPollOption(identifier: _id_input_option(), text: "", selected: false)], random: arc4random(), mode: mode, isQuiz: isQuiz)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NewPollState) -> NewPollState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var shouldMakeNextResponderAfterTransition: (InputDataIdentifier, Bool, InputDataIdentifier?, Bool)? = nil
    var shouldMakeNearResponderAfterTransition: (InputDataIdentifier, Int)? = nil

    let animated: Atomic<Bool> = Atomic(value: false)
    
    let deleteOption:(InputDataIdentifier)-> Void = { identifier in
        let state = stateValue.with { $0 }
        updateState { state in
            return state.withDeleteOption(identifier)
        }
        shouldMakeNearResponderAfterTransition = (identifier, state.indexOf(identifier)!)
    }
    let updateQuizSelected:(InputDataIdentifier)-> Void = { identifier in
        updateState { state in
            return state.withUnselectItems().withUpdatedOption({ option -> NewPollOption in
                return option.withUpdatedSelected(true)
            }, forKey: identifier)
        }
    }
    
    
    var showTooltipForQuiz:(()->Void)? = nil

    
    let updateMode:(NewPollMode)->Void = { mode in
        let oldMode = stateValue.with { $0.mode }

        updateState { state in
            if state.mode.isModeEqual(to: mode) {
                return state.withUpdatedMode(mode)
            } else {
                return state.withUnselectItems().withUpdatedMode(mode)
            }
        }
        if mode.isQuiz && !oldMode.isQuiz {
            showTooltipForQuiz?()
        }
    }
    
    let addOption:(Bool)-> InputDataValidation = { byClick in
        let option = NewPollOption(identifier: _id_input_option(), text: "", selected: false)
        updateState { state in
            if state.options.count < optionsLimit {
                return state.withAddedOption(option)
            } else {
                return state
            }
        }
        shouldMakeNextResponderAfterTransition = (option.identifier, false, byClick ? _id_input_add_option : nil, true)
        
        return .none
    }
    
    var close: (() -> Void)? = nil
    
    
    
    let checkAndSend:() -> Void = {
        let state = stateValue.with { $0 }
    
        if state.isEnabled && !state.shouldShowTooltipForQuiz {
            chatInteraction.sendMedias([state.media], ChatTextInputState(), false, nil, false, nil)
            close?()
        } else if state.shouldShowTooltipForQuiz {
            showTooltipForQuiz?()
        }
    }
    
    
    let interactions = ModalInteractions(acceptTitle: L10n.modalSend, accept: {
       checkAndSend()
    }, drawBorder: true, height: 50, singleButton: true)
    
    
    let canBePublic: Bool
    if let peer = chatInteraction.presentation.mainPeer {
        canBePublic = !peer.isChannel
    } else {
        canBePublic = true
    }
    
    let context = chatInteraction.context
    
    let signal: Signal<InputDataSignalValue, NoError> = statePromise.get() |> map { value in
        return InputDataSignalValue(entries: newPollEntries(value, context: context, canBePublic: canBePublic, deleteOption: deleteOption, updateQuizSelected: updateQuizSelected, updateMode: updateMode), animated: animated.swap(true))
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: isQuiz == true ? L10n.newPollTitleQuiz : L10n.newPollTitle, validateData: { data -> InputDataValidation in
        
        if let _ = data[_id_input_add_option] {
            return addOption(true)
        }
        
        var fails: [InputDataIdentifier : InputDataValidationFailAction] = [:]
        for (key, value) in data {
            if let string = value.stringValue, string.trimmed.isEmpty {
                fails[key] = .shake
            }
        }
        if !fails.isEmpty {
            
            let state = stateValue.with { $0 }
            
            if fails.contains(where: {$0.key == _id_input_title}) {
                shouldMakeNextResponderAfterTransition = (_id_input_title, true, nil, true)
            } else {
                for option in state.options {
                    if fails.contains(where: {$0.key == option.identifier}) {
                        shouldMakeNextResponderAfterTransition = (option.identifier, true, nil, true)
                        break
                    }
                }
            }
        }
        
        return .fail(.doSomething { f in
            
            f(.fail(.fields(fails)))
            
            var addedOptions: Int? = nil
            updateState { state in
                var state = state
                if fails.isEmpty {
                    if state.options.count < 2 {
                        state = state.withAddedOption(NewPollOption(identifier: _id_input_option(), text: "", selected: false))
                        if addedOptions == nil {
                            addedOptions = state.options.count - 1
                        }
                    }
                }
                return state.withUpdatedState()
            }
            
            if let addedOptions = addedOptions {
                let state = stateValue.with { $0 }
                shouldMakeNextResponderAfterTransition = (state.options[addedOptions].identifier, false, nil, true)
            }
        })
        
    }, updateDatas: { data in
        updateState { state in
            return state.withUpdatedTitle(data[_id_input_title]?.stringValue ?? state.title).withUpdatedOptions(data)
        }
        return .none
    }, afterDisappear: {
        
    }, updateDoneValue: { data in
        return { f in
            f(.disabled(L10n.navigationDone))
        }
    }, removeAfterDisappear: true, hasDone: true, identifier: "new-poll", afterTransaction: { controller in
        
        if let (identifier, checkEmptyCurrent, focusIdentifier, scrollIfNeeded) = shouldMakeNextResponderAfterTransition {
            var markResponder: Bool = true
            let state = stateValue.with { $0 }
            if let current = controller.currentFirstResponderIdentifier, checkEmptyCurrent {
                if current == _id_input_title, state.title.trimmed.isEmpty  {
                    markResponder = false
                }
                if let option = state.options.first(where: {$0.identifier == current}), option.text.trimmed.isEmpty {
                    markResponder = false
                }
            }
            if markResponder {
                controller.makeFirstResponderIfPossible(for: identifier, focusIdentifier: focusIdentifier, scrollIfNeeded: scrollIfNeeded)
            }
            shouldMakeNextResponderAfterTransition = nil
        }
        
        if let (_, index) = shouldMakeNearResponderAfterTransition {
            
            let state = stateValue.with { $0 }
            if !state.options.isEmpty {
                if controller.currentFirstResponderIdentifier == nil {
                    if index == 0 {
                        if !state.options.isEmpty {
                            controller.makeFirstResponderIfPossible(for: state.options[0].identifier)
                        }
                    } else {
                        controller.makeFirstResponderIfPossible(for: state.options[index - 1].identifier)
                    }
                }
            } else {
                controller.makeFirstResponderIfPossible(for: _id_input_title)
            }
            
            
            
            shouldMakeNearResponderAfterTransition = nil
        }
        
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        let state = stateValue.with { $0 }
        
        controller.tableView.enumerateItems(with: { item -> Bool in
            if let identifier = (item.stableId.base as? InputDataEntryId)?.identifier {
                if let _ = state.indexOf(identifier) {
                    if range.location == NSNotFound {
                        range.location = item.index
                    }
                    range.length += 1
                }
            }
            
            return true
        })
        
//
//        let resort = TableResortController(resortRange: range, startTimeout: 0.1, start: { _ in
//
//        }, resort: { _ in
//
//        }, complete: { [weak controller] previous, current in
//            if previous != current {
//                _ = animated.swap(false)
//
//                updateState { state in
//                    return state.withUpdatedPos(previous - range.location, current - range.location)
//                }
//            } else {
//                updateState { state in
//                    return state.withUpdatedState()
//                }
//            }
//            if let identifier = controller?.currentFirstResponderIdentifier {
//                shouldMakeNextResponderAfterTransition = (identifier, false, nil, false)
//            }
//
//        }, updateItems: { currentView, items in
//
////            let items = items.compactMap { $0 as? GeneralRowItem }.filter({ $0.view?.identifier != NSUserInterfaceItemIdentifier("-1")})
////            for (i, item) in items.enumerated() {
////                NSLog("\(item.view)")
////                item.updateViewType(bestGeneralViewType(items, for: i))
////                item.view?.set(item: item, animated: true)
////            }
////            if let item = currentView?.item as? GeneralRowItem {
////                //item.updateViewType(.singleItem)
////                currentView?.set(item: item, animated: true)
////            }
//
//        })
//        controller.tableView.resortController = resort
//
        interactions.updateDone { done in
            done.isEnabled = state.isEnabled
        }
        
    }, returnKeyInvocation: { identifier, event in
        
        if FastSettings.checkSendingAbility(for: event) {
            checkAndSend()
            return .default
        } else {
            let state = stateValue.with { $0 }
            
            
            if identifier == _id_input_title {
                if state.options.isEmpty {
                    _ = addOption(false)
                    return .nothing
                }
                return .invokeEvent
            }
            
            if let identifier = identifier {
                
                let index: Int? = state.indexOf(identifier)
                let isLast = index == state.options.count - 1
                
                if isLast {
                    if state.options.count == optionsLimit {
                        return .nothing
                    } else {
                        _ = addOption(false)
                        return .nothing
                    }
                } else {
                    return .nextResponder
                }
            }
        }
        

        return .nothing
    }, deleteKeyInvocation: { identifier in
        
        let state = stateValue.with { $0 }
        if let index = state.options.firstIndex(where: { $0.identifier == identifier}) {
            if state.options[index].text.isEmpty {
                deleteOption(state.options[index].identifier)
                return .invoked
            }
        }
        
        return .default
    })
    
    
    let modalController = InputDataModalController(controller, modalInteractions: interactions, closeHandler: { f in
        let state = stateValue.with { $0 }
        
        if !state.title.isEmpty || !state.options.filter({!$0.text.isEmpty}).isEmpty {
            confirm(for: mainWindow, header: L10n.newPollDisacardConfirmHeader, information: L10n.newPollDisacardConfirm, okTitle: L10n.newPollDisacardConfirmYes, cancelTitle: L10n.newPollDisacardConfirmNo, successHandler: { _ in
                f()
            })
        } else {
            f()
        }
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    showTooltipForQuiz = { [weak controller] in
        let firstOption = stateValue.with({ $0.options.first })
        if let option = firstOption {
            let view = controller?.tableView.item(stableId: InputDataEntryId.input(option.identifier))?.view as? InputDataRowView
            delay(0.2, closure: { [weak view] in
                view?.showPlaceholderActionTooltip(L10n.newPollQuizTooltip)
            })
        }
        
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: close)
    
    
    chatInteraction.context.window.set(handler: { [weak controller] () -> KeyHandlerResult in
        if let controller = controller {
            let state = stateValue.with {$0}
            
            let id = controller.currentFirstResponderIdentifier
            
            if let id = id, let index = state.indexOf(id) {
                let option = state.options[index]
                if state.options.count - 1 == index, state.options.count < 10 {
                    if !option.text.isEmpty {
                        _ = addOption(false)
                        return .invoked
                    }
                }
            }
            
        }
        return .rejected
    }, with: controller, for: .Tab, priority: .supreme)
    
    return modalController
    
}
