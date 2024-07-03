//
//  MediaPaidSetterController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import InputView
//
private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let executeLink:(String)->Void
    let updateState: (Updated_ChatTextInputState)->Void
    init(context: AccountContext, interactions: TextView_Interactions, executeLink:@escaping(String)->Void, updateState: @escaping(Updated_ChatTextInputState)->Void) {
        self.context = context
        self.interactions = interactions
        self.executeLink = executeLink
        self.updateState = updateState
    }
}

private struct State : Equatable {
    var inputState: Updated_ChatTextInputState = .init()
}



private final class InputItem : GeneralRowItem {
    let inputState: Updated_ChatTextInputState
    let arguments: Arguments
    let interactions: TextView_Interactions
    let limit: Int32
    init(_ initialSize: NSSize, stableId: AnyHashable, inputState: Updated_ChatTextInputState, arguments: Arguments) {
        self.inputState = inputState
        self.arguments = arguments
        self.interactions = arguments.interactions
        self.limit = arguments.context.appConfiguration.getGeneralValue("stars_paid_post_amount_max", orElse: 10000)
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return InputView.self
    }
}


private final class InputView : GeneralRowView {
    
    private final class Input : View {
        
        private weak var item: InputItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        private let starView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(starView)
            addSubview(inputView)
                        

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: InputItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.background
            
            let attr = NSMutableAttributedString()
            attr.append(string: clown)
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
            
            let layout = TextViewLayout(attr)
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.starView.set(text: layout, context: item.arguments.context)

            
            inputView.placeholder = strings().paidMediaPlaceholder
            
            inputView.context = item.arguments.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            
            let value = Int64(item.inputState.string) ?? 0
            
            let limit = item.limit
            
            inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(value > limit || value == 0 ? theme.colors.redUI : theme.colors.text)
            
            
            item.interactions.filterEvent = { event in
                if let chars = event.characters {
                    return chars.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890\u{7f}")).isEmpty
                } else {
                    return false
                }
            }

            self.inputView.set(item.interactions.presentation.textInputState())

            self.inputView.interactions = item.interactions
            
            item.interactions.inputDidUpdate = { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.set(state)
                self.inputDidUpdateLayout(animated: true)
            }
            
        }
        
        
        var textWidth: CGFloat {
            return frame.width - 20
        }
        
        func textViewSize() -> (NSSize, CGFloat) {
            let w = textWidth
            let height = inputView.height(for: w)
            return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
        }
        
        private func inputDidUpdateLayout(animated: Bool) {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            let (textSize, textHeight) = textViewSize()
            
            transition.updateFrame(view: starView, frame: starView.centerFrameY(x: 10))
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: starView.frame.maxX + 10, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.arguments.updateState(state)
            
            item.redraw(animated: true)
        }
    }
    
    private let inputView = Input(frame: NSMakeRect(0, 0, 40, 40))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
    }
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InputItem else {
            return
        }
        
        self.inputView.update(item: item, animated: animated)
                
        self.inputView.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func shakeView() {
        inputView.shake(beep: true)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(20, 0, size.width - 40,40))
        inputView.updateLayout(size: inputView.frame.size, transition: transition)
    }
    
    override var firstResponder: NSResponder? {
        return inputView.inputView.inputView
    }
    
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().paidMediaHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return InputItem(initialSize, stableId: stableId, inputState: state.inputState, arguments: arguments)
    }))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().paidMediaInfo, linkHandler: arguments.executeLink), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func MediaPaidSetterController(context: AccountContext, callback:@escaping(Int64)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let interactions = TextView_Interactions(presentation: .init())
    let limit = context.appConfiguration.getGeneralValue("stars_paid_post_amount_max", orElse: 10000)
    
    let arguments = Arguments(context: context, interactions: interactions, executeLink: { link in
        execute(inapp: .external(link: link, false))
    }, updateState: { [weak interactions] value in
        var value = value
        
        let number = Int64(value.string) ?? 0
        if number > limit {
            let string = "\(limit)"
            value = .init(inputText: .initialize(string: string), selectionRange: string.length..<string.length)
            getController?()?.proccessValidation(.fail(.fields([_id_input : .shake])))
        }
        interactions?.update { _ in
            return value
        }
        updateState { current in
            var current = current
            current.inputState = value
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    

    let controller = InputDataController(dataSignal: signal, title: strings().paidMediaTitle)
    
    controller.validateData = { _ in
        let value = stateValue.with { $0.inputState.string }
        if let amount = Int64(value) {
            if amount != 0, amount <= limit {
                callback(amount)
                return .success(.custom({
                    close?()
                }))
            }
        }
        return .fail(.fields([_id_input: .shake]))
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().paidMediaOk, accept: { [weak controller] in
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

