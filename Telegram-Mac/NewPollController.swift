//
//  NewPollController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

private let optionsLimit: Int = 10
private let maxTextLength:Int32 = 255
private let maxOptionLength: Int32 = 100


private func _id_input_option() -> InputDataIdentifier {
    return InputDataIdentifier("_id_input_option_\(arc4random())")
}
private let _id_input_title = InputDataIdentifier("_id_input_title")
private let _id_input_add_option = InputDataIdentifier("_id_input_add_option")
private struct NewPollOption : Equatable {
    let identifier: InputDataIdentifier
    let text: String
    init(identifier: InputDataIdentifier, text: String) {
        self.identifier = identifier
        self.text = text
    }
    func withUpdatedText(_ text: String) -> NewPollOption {
        return NewPollOption(identifier: self.identifier, text: text)
    }
}

private struct NewPollState : Equatable {
    let title: String
    let options: [NewPollOption]
    private let random: UInt32
    init(title: String, options: [NewPollOption], random: UInt32) {
        self.title = title
        self.options = options
        self.random = random
    }
    
    func withUpdatedTitle(_ title: String) -> NewPollState {
        return NewPollState(title: title, options: self.options, random: self.random)
    }
    func withDeleteOption(_ identifier: InputDataIdentifier) -> NewPollState {
        var options = self.options
        options.removeAll(where: {$0.identifier == identifier})
        return NewPollState(title: title, options: options, random: self.random)
    }
    
    func withUpdatedOption(_ f:(NewPollOption) -> NewPollOption, forKey identifier: InputDataIdentifier) -> NewPollState {
        var options = self.options
        if let index = options.firstIndex(where: {$0.identifier == identifier}) {
            options[index] = f(options[index])
        }
        return NewPollState(title: self.title, options: options, random: self.random)
    }
    
    func withUpdatedOptions(_ data:[InputDataIdentifier : InputDataValue]) -> NewPollState {
        var options = self.options
        for (key, value) in data {
            if let index = self.indexOf(key) {
                options[index] = options[index].withUpdatedText(value.stringValue ?? options[index].text)
            }
        }
        return NewPollState(title: self.title, options: options, random: self.random)
    }
    
    func withAddedOption(_ option: NewPollOption) -> NewPollState {
        var options = self.options
        options.append(option)
        return NewPollState(title: self.title, options: options, random: self.random)
    }
    func withUpdatedPos(_ previous: Int, _ current: Int) -> NewPollState {
        var options = self.options
        options.move(at: previous, to: current)
        return NewPollState(title: self.title, options: options, random: self.random)
    }
    
    func indexOf(_ identifier: InputDataIdentifier) -> Int? {
        return options.firstIndex(where: { $0.identifier == identifier })
    }
    
    func withUpdatedState() -> NewPollState {
         return NewPollState(title: self.title, options: self.options, random: arc4random())
    }
    
    var isEnabled: Bool {
        return !title.trimmed.isEmpty && options.filter({!$0.text.trimmed.isEmpty}).count >= 2
    }
    
    var media: TelegramMediaPoll {
        var options: [TelegramMediaPollOption] = []
        for (i, option) in self.options.enumerated() {
            if !option.text.trimmed.isEmpty {
                options.append(TelegramMediaPollOption(text: option.text.trimmed, opaqueIdentifier: "\(i)".data(using: .utf8)!))
            }
        }
        return TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: arc4random64()), text: title.trimmed, options: options, results: TelegramMediaPollResults(voters: nil, totalVoters: nil), isClosed: false)
    }
}

private func newPollEntries(_ state: NewPollState, deleteOption:@escaping(InputDataIdentifier) -> Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.title.length > maxTextLength / 3 * 2 ? L10n.newPollQuestionHeaderLimit(Int(maxTextLength) - state.title.length) : L10n.newPollQuestionHeader), color: theme.colors.grayText, detectBold: false))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_input_title, mode: .plain, placeholder: nil, inputPlaceholder: L10n.newPollQuestionPlaceholder, filter: { text in
        
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.newPollOptionsHeader), color: theme.colors.grayText, detectBold: false))
    index += 1
    
    for (_, option) in state.options.enumerated() {
        entries.append(.input(sectionId: sectionId, index: index, value: .string(option.text), error: nil, identifier: option.identifier, mode: .plain, placeholder: InputDataInputPlaceholder(nil, icon: theme.icons.pollDeleteOption, drawBorderAfterPlaceholder: true, hasLimitationText: true, rightResoringImage: theme.icons.resort, action: {
            deleteOption(option.identifier)
        }), inputPlaceholder: L10n.newPollOptionsPlaceholder, filter: { text in
            return text.trimmingCharacters(in: CharacterSet.newlines)
        }, limit: maxOptionLength))
        index += 1
    }
    
    if state.options.count < optionsLimit {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_input_add_option, data: InputDataGeneralData(name: L10n.newPollOptionsAddOption, color: theme.colors.blueUI, icon: theme.icons.pollAddOption, type: .none, action: nil)))
        index += 1
    }


    index = 50
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.options.count < 2 ? L10n.newPollOptionsDescriptionMinimumCountable(2) : optionsLimit == state.options.count ? L10n.newPollOptionsDescriptionLimitReached : L10n.newPollOptionsDescriptionCountable(optionsLimit - state.options.count)), color: theme.colors.grayText, detectBold: false))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func NewPollController(chatInteraction: ChatInteraction) -> InputDataModalController {
    
    
    let initialState = NewPollState(title: "", options: [NewPollOption(identifier: _id_input_option(), text: ""), NewPollOption(identifier: _id_input_option(), text: "")], random: arc4random())
    
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
    let addOption:(Bool)-> InputDataValidation = { byClick in
        let option = NewPollOption(identifier: _id_input_option(), text: "")
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
    
        if state.isEnabled {
            chatInteraction.sendMedias([state.media], ChatTextInputState(), false, nil)
            close?()
        }
    }
    
    
    let interactions = ModalInteractions(acceptTitle: L10n.modalSend, accept: {
       checkAndSend()
    }, cancelTitle: L10n.modalCancel, cancel: nil, drawBorder: true, height: 50, alignCancelLeft: false)
    
    
   
    
    
    let signal: Signal<InputDataSignalValue, NoError> = statePromise.get() |> map { value in
        return InputDataSignalValue(entries: newPollEntries(value, deleteOption: deleteOption), animated: animated.swap(true))
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: L10n.newPollTitle, validateData: { data -> InputDataValidation in
        
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
                        state = state.withAddedOption(NewPollOption(identifier: _id_input_option(), text: ""))
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
        
        controller.genericView.enumerateItems(with: { item -> Bool in
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
        
        
        let resort = TableResortController(resortRange: range, startTimeout: 0.1, start: { _ in
            
        }, resort: { _ in
            
        }, complete: { [weak controller] previous, current in
            if previous != current {
                _ = animated.swap(false)
                
                updateState { state in
                    return state.withUpdatedPos(previous - range.location, current - range.location)
                }
            } else {
                updateState { state in
                    return state.withUpdatedState()
                }
            }
            if let identifier = controller?.currentFirstResponderIdentifier {
                shouldMakeNextResponderAfterTransition = (identifier, false, nil, false)
            }

        })
        controller.genericView.resortController = resort
        
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
            confirm(for: mainWindow, information: L10n.newPollDisacardConfirm, okTitle: L10n.newPollDisacardConfirmYes, cancelTitle: L10n.newPollDisacardConfirmNo, successHandler: { _ in
                f()
            })
        } else {
            f()
        }
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    mainWindow.set(handler: { [weak controller] () -> KeyHandlerResult in
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
