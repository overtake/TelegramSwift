
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InputView

private let maxTextLength:Int32 = 255
private let maxOptionLength: Int32 = 100


private class Arguments {
    let context: AccountContext
    let deleteOption:(InputDataIdentifier) -> Void
    let updateState:(Updated_ChatTextInputState)->Void
    let updateOptionState:(InputDataIdentifier, Updated_ChatTextInputState)->Void
    let toggleCanAdd:()->Void
    let toggleCanComplete:()->Void
    init(context: AccountContext, deleteOption: @escaping (InputDataIdentifier) -> Void, updateState: @escaping (Updated_ChatTextInputState) -> Void, updateOptionState:@escaping(InputDataIdentifier, Updated_ChatTextInputState)->Void, toggleCanAdd:@escaping()->Void, toggleCanComplete:@escaping()->Void) {
        self.context = context
        self.deleteOption = deleteOption
        self.updateState = updateState
        self.updateOptionState = updateOptionState
        self.toggleCanAdd = toggleCanAdd
        self.toggleCanComplete = toggleCanComplete
    }
}



private struct TodoOption : Equatable {
    let identifier: InputDataIdentifier
    let textState: Updated_ChatTextInputState
    let selected: Bool
    init(identifier: InputDataIdentifier, textState: Updated_ChatTextInputState, selected: Bool) {
        self.identifier = identifier
        self.textState = textState
        self.selected = selected
    }
    
    var text: String {
        return textState.inputText.string
    }
    
    func withUpdatedText(_ textState: Updated_ChatTextInputState) -> TodoOption {
        return TodoOption(identifier: self.identifier, textState: textState, selected: self.selected)
    }
    func withUpdatedSelected(_ selected: Bool) -> TodoOption {
        return TodoOption(identifier: self.identifier, textState: self.textState, selected: selected)
    }
}

private struct State : Equatable {
    var options: [TodoOption]
    var textState: Updated_ChatTextInputState

    var othersCanAdd: Bool = false
    var othersCanComplete: Bool = false
    
    
    func withUpdatedTitle(_ title: String) -> State {
        return State(options: self.options, textState: self.textState)
    }
    func withDeleteOption(_ identifier: InputDataIdentifier) -> State {
        var options = self.options
        options.removeAll(where: {$0.identifier == identifier})
        return State(options: options, textState: self.textState)
    }
    
    func withUnselectItems() -> State {
        return State(options: self.options.map { $0.withUpdatedSelected(false) }, textState: self.textState)
    }
    
    func withUpdatedOption(_ f:(TodoOption) -> TodoOption, forKey identifier: InputDataIdentifier) -> State {
        var options = self.options
        if let index = options.firstIndex(where: {$0.identifier == identifier}) {
            options[index] = f(options[index])
        }
        return State(options: options, textState: self.textState)
    }
    
    func withAddedOption(_ option: TodoOption) -> State {
        var options = self.options
        options.append(option)
        return State(options: options, textState: self.textState)
    }
    func withUpdatedPos(_ previous: Int, _ current: Int) -> State {
        var options = self.options
        options.move(at: previous, to: current)
        return State(options: options, textState: self.textState)
    }
    
    func indexOf(_ identifier: InputDataIdentifier) -> Int? {
        return options.firstIndex(where: { $0.identifier == identifier })
    }
    
    func withUpdatedState() -> State {
         return State(options: self.options, textState: self.textState)
    }
    
    var title: String {
        return textState.inputText.string
    }
    
    var isEnabled: Bool {
        let isEnabled = !title.trimmed.isEmpty && options.filter({!$0.text.trimmed.isEmpty}).count >= 2
        return isEnabled
    }
    
    var media: TelegramMediaTodo {
        
        var items: [TelegramMediaTodo.Item] = []
        
        for (i, item) in options.enumerated() {
            items.append(.init(text: item.text, entities: item.textState.textInputState().messageTextEntities(), id: Int32(i + 1)))
        }
        
        var flags: TelegramMediaTodo.Flags = .init()
        if othersCanAdd {
            flags.insert(.othersCanAppend)
        }
        if othersCanComplete {
            flags.insert(.othersCanComplete)
        }
        return .init(flags: flags, text: self.title, textEntities: self.textState.textInputState().messageTextEntities(), items: items, completions: [])
    }
}


private func _id_input_option() -> InputDataIdentifier {
    return InputDataIdentifier("_id_input_option_\(arc4random())")
}
private let _id_input_title = InputDataIdentifier("_id_input_title")
private let _id_input_add_option = InputDataIdentifier("_id_input_add_option")
private let _id_other_can_complete = InputDataIdentifier("_id_other_can_complete")
private let _id_other_can_add = InputDataIdentifier("_id_other_can_add")



private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //TODOLANG
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input_title, equatable: .init(state.textState), comparable: nil, item: { initialSize, stableId in
        return InputTextDataRowItem(initialSize, stableId: stableId, context: arguments.context, state: state.textState, viewType: .singleItem, placeholder: nil, inputPlaceholder: "Title...", filter: { text in
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
        }, updateState: arguments.updateState, limit: maxTextLength, hasEmoji: arguments.context.isPremium)
    }))
    index += 1
    
    let optionsLimit = Int(arguments.context.appConfiguration.getGeneralValue("poll_answers_max", orElse: 10))
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("TO DO LIST"), data: InputDataGeneralTextData(detectBold: false, viewType: .textTopItem)))
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
        let placeholder: InputDataInputPlaceholder = InputDataInputPlaceholder(hasLimitationText: true)
        let rightItem = InputDataRightItem.action(theme.icons.recentDismiss, .custom({ _, _ in
            arguments.deleteOption(option.identifier)
        }))
        
        struct Tuple : Equatable {
            let option: TodoOption
            let placeholder: InputDataInputPlaceholder?
            let viewType: GeneralViewType
            let rightItem: InputDataRightItem
        }
        let tuple = Tuple(option: option, placeholder: placeholder, viewType: viewType, rightItem: rightItem)
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: option.identifier, equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return InputTextDataRowItem(initialSize, stableId: stableId, context: arguments.context, state: tuple.option.textState, viewType: tuple.viewType, placeholder: tuple.placeholder, inputPlaceholder: "Task", rightItem: tuple.rightItem, filter: { text in
                return text.trimmingCharacters(in: CharacterSet.newlines)
            }, updateState: { state in
                arguments.updateOptionState(option.identifier, state)
            }, limit: maxOptionLength, hasEmoji: arguments.context.isPremium)
        }))
    }
    if state.options.count < optionsLimit {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_input_add_option, data: InputDataGeneralData(name: "Add Task", color: theme.colors.accent, icon: theme.icons.pollAddOption, type: .none, viewType: state.options.isEmpty ? .singleItem : .lastItem, action: nil)))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_other_can_complete, data: .init(name: "Others Can Complete", color: theme.colors.text, type: .switchable(state.othersCanComplete), viewType: .firstItem, action: arguments.toggleCanComplete)))

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_other_can_add, data: .init(name: "Others Can Append", color: theme.colors.text, type: .switchable(state.othersCanAdd), viewType: .lastItem, action: arguments.toggleCanAdd)))

  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func NewTodoController(chatInteraction: ChatInteraction) -> InputDataModalController {
    
    let context = chatInteraction.context

    let actionsDisposable = DisposableSet()

    let initialState = State(options: [TodoOption(identifier: _id_input_option(), textState: .init(), selected: false), TodoOption(identifier: _id_input_option(), textState: .init(), selected: false)], textState: .init())

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let optionsLimit = Int(context.appConfiguration.getGeneralValue("poll_answers_max", orElse: 10))
    
    var shouldMakeNextResponderAfterTransition: (InputDataIdentifier, Bool, InputDataIdentifier?, Bool)? = nil
    var shouldMakeNearResponderAfterTransition: (InputDataIdentifier, Int)? = nil

    let animated: Atomic<Bool> = Atomic(value: false)

    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    
    
    let arguments = Arguments(context: context, deleteOption: { identifier in
        let state = stateValue.with { $0 }
        updateState { state in
            return state.withDeleteOption(identifier)
        }
        shouldMakeNearResponderAfterTransition = (identifier, state.indexOf(identifier)!)
    }, updateState: { state in
        updateState { current in
            var current = current
            current.textState = state
            return current
        }
    }, updateOptionState: { identifier, state in
        updateState { current in
            var current = current
            if let index = current.options.firstIndex(where: { $0.identifier == identifier }) {
                current.options[index] = current.options[index].withUpdatedText(state)
            }
            return current
        }
    }, toggleCanAdd: {
        updateState { current in
            var current = current
            current.othersCanAdd = !current.othersCanAdd
            return current
        }
    }, toggleCanComplete: {
        updateState { current in
            var current = current
            current.othersCanComplete = !current.othersCanComplete
            return current
        }
    })
    
    
    let addOption:(Bool)-> InputDataValidation = { byClick in
        let option = TodoOption(identifier: _id_input_option(), textState: .init(), selected: false)
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
    
    let checkAndSend:()->Void = {
        let state = stateValue.with { $0 }
    
        if state.isEnabled {
            chatInteraction.sendMedias([state.media], ChatTextInputState(), false, nil, false, nil, false, nil, false)
            close?()
        }
    }
    
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let interactions = ModalInteractions(acceptTitle: "Send", accept: {
        checkAndSend()
    }, singleButton: true)

    
    let controller = InputDataController(dataSignal: signal, title: "New To Do List", validateData: { data -> InputDataValidation in
        
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
                        state = state.withAddedOption(TodoOption(identifier: _id_input_option(), textState: .init(), selected: false))
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
        return .none
    }, afterDisappear: {
        
    }, updateDoneValue: { data in
        return { f in
            f(.disabled(strings().navigationDone))
        }
    }, removeAfterDisappear: true, hasDone: true, identifier: "new-todo", afterTransaction: { controller in
        
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
                arguments.deleteOption(state.options[index].identifier)
                return .invoked
            }
        }
        
        return .default
    })
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: interactions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}



