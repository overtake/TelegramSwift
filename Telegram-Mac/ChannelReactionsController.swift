//
//  ReactionsSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InputView
import KeyboardKey

private final class ReactionsRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let interactions: TextView_Interactions
    fileprivate let state: Updated_ChatTextInputState
    fileprivate let _action:(Control)->Void
    fileprivate let updateState:(Updated_ChatTextInputState)->Void
    fileprivate let placeholder: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, interactions: TextView_Interactions, viewType: GeneralViewType, state: Updated_ChatTextInputState, action: @escaping(Control)->Void, updateState:@escaping(Updated_ChatTextInputState)->Void) {
        self.context = context
        self._action = action
        self.updateState = updateState
        self.interactions = interactions
        self.state = state
        self.placeholder = TextViewLayout.init(.initialize(string: strings().channelReactionsPlaceholder, color: theme.colors.grayText, font: .normal(.title)))
        self.placeholder.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return ReactionsRowView.self
    }
    
    
    override var height: CGFloat {
        let attr = NSMutableAttributedString()
        let attributedString = self.state.inputText
        attr.append(self.state.inputText)
        var str: NSMutableAttributedString = .init()
        let ph_width = placeholder.attributedString.sizeFittingWidth(.greatestFiniteMagnitude).width
        while true {
            str.append(string: clown, font: .normal(15))
            if str.sizeFittingWidth(.greatestFiniteMagnitude).width >= ph_width {
                break
            }
        }
        attr.append(str)
        attr.addAttribute(.font, value: NSFont.normal(15), range: attr.range)
        let size = attr.sizeFittingWidth(blockWidth)
        return size.height + 10 + (viewType.innerInset.top + viewType.innerInset.bottom - 10)
    }
}

private final class ReactionsRowView: GeneralContainableRowView {
    private let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 50))
    private let overlay = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
        addSubview(overlay)
        
        overlay.isSelectable = false
                
        
        overlay.set(handler: { [weak self] control in
            guard let item = self?.item as? ReactionsRowItem else {
                return
            }
            item._action(control)
        }, for: .Click)
        
        overlay.set(cursor: NSCursor.arrow, for: .Normal)
        overlay.set(cursor: NSCursor.pointingHand, for: .Hover)
        overlay.set(cursor: NSCursor.pointingHand, for: .Highlight)
        overlay.scaleOnClick = true
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)

    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        guard let item = item as? ReactionsRowItem else {
            return
        }
        
        item.updateState(state)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        inputView.inputTheme = theme.inputTheme.withUpdatedFontSize(15)
        
        guard let item = item as? ReactionsRowItem else {
            return
        }
        
        item.interactions.min_height = 20
        item.interactions.emojiPlayPolicy = .onceEnd
        
        item.interactions.filterEvent = { event in
            if let chars = event.characters {
                return chars.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).isEmpty
            } else {
                return false
            }
        }

        inputView.interactions = item.interactions
        
        item.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        item.interactions.processEnter = { event in
            return false
        }
        
        overlay.update(item.placeholder)
        
        inputView.interactions.canTransform = false
        inputView.context = item.context
        
        window?.makeFirstResponder(inputView.inputView)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override var firstResponder: NSResponder? {
        return inputView.inputView
    }
    
    var textWidth: CGFloat {
        guard let item = item as? ReactionsRowItem else {
            return frame.width
        }
        return item.blockWidth
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = inputView.height(for: w)
        return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? ReactionsRowItem else {
            return
        }
        
        let (textSize, textHeight) = textViewSize()
                
        
        transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left, y: item.viewType.innerInset.top - 5), size: textSize))
        inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        
        let lastSymbol = inputView.string().last.flatMap { String($0) } ?? ""
        let lastRange = NSMakeRange(inputView.string().length - lastSymbol.length, lastSymbol.length)
        
        let lastSymbolRect = inputView.highlight(for: lastRange, whole: false)
        
        var rect: NSRect
        if inputView.string().isEmpty {
            rect = NSMakeRect(item.viewType.innerInset.left + 1, (containerView.frame.height - overlay.frame.height) / 2, overlay.frame.width, overlay.frame.height)
        } else {
            let maybeHeight = containerView.frame.height - (item.viewType.innerInset.top + item.viewType.innerInset.bottom - inputView.inputView.textContainerOrigin.y * 2)
            if textSize.height < maybeHeight {
                rect = NSMakeRect(item.viewType.innerInset.left + 1, lastSymbolRect.maxY + 9, overlay.frame.width, overlay.frame.height)
            } else {
                rect = NSMakeRect(lastSymbolRect.maxX + item.viewType.innerInset.left + 4, lastSymbolRect.minY + overlay.frame.height / 2, overlay.frame.width, overlay.frame.height)
                if lastSymbolRect.origin.y == inputView.inputView.textContainerOrigin.y {
                    rect.origin.y -= 2
                }
            }
        }
        ContainedViewLayoutTransition.immediate.updateFrame(view: overlay, frame: rect)
    }
}

private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let toggleEnabled:()->Void
    let createPack:()->Void
    let addReactions:(Control)->Void
    let updateState:(Updated_ChatTextInputState)->Void

    init(context: AccountContext, interactions: TextView_Interactions, toggleEnabled:@escaping()->Void, createPack:@escaping()->Void, addReactions:@escaping(Control)->Void, updateState:@escaping(Updated_ChatTextInputState)->Void) {
        self.context = context
        self.interactions = interactions
        self.toggleEnabled = toggleEnabled
        self.createPack = createPack
        self.addReactions = addReactions
        self.updateState = updateState
    }
}

private struct State : Equatable {
    var enabled: Bool = true
    var state:Updated_ChatTextInputState = .init(inputText: .init())
    
    var selected: [TelegramMediaFile] {
        let attributes = chatTextAttributes(from: state.inputText)
        var files:[TelegramMediaFile] = []
        
        for attribute in attributes {
            switch attribute {
            case let .animated(_, _, _, file, _):
                if let file = file {
                    files.append(file)
                }
            default:
                break
            }
        }
        return files
    }
}



private let _id_enabled = InputDataIdentifier("_id_enabled")
private let _id_emojies = InputDataIdentifier("_id_emojies")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: "Enable Reactions", color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("You can add emoji from any emoji pack as a reaction."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        //emojies
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emojies, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return ReactionsRowItem(initialSize, stableId: stableId, context: arguments.context, interactions: arguments.interactions, viewType: .singleItem, state: state.state, action: arguments.addReactions, updateState: arguments.updateState)
        }))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("You can also [create your own]() emoji packs and use them.", linkHandler: { _ in
            arguments.createPack()
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
   
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChannelReactionsController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    
    let emojis = EmojiesController(context, mode: .forumTopic, selectedItems: [])
    emojis._frameRect = NSMakeRect(0, 0, 350, 300)
    let interactions = EntertainmentInteractions(.emoji, peerId: peerId)
    emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))

    let textInteractions = TextView_Interactions()

    
    interactions.sendAnimatedEmoji = { sticker, _, _, _ in

        
        let text = stateValue.with { $0.state.inputText }
        
        var removeRange: NSRange? = nil
        
        text.enumerateAttribute(TextInputAttributes.customEmoji, in: text.range, using: { value, range, stop in
            if let value = value as? TextInputTextCustomEmojiAttribute {
                if value.fileId == sticker.file.fileId.id {
                    removeRange = range
                    stop.pointee = true
                }
            }
        })
        
        let updatedState: Updated_ChatTextInputState
        if let removeRange = removeRange {
            updatedState = textInteractions.insertText(.init(), selectedRange: removeRange.lowerBound ..< removeRange.upperBound)
        } else {
            let text = sticker.file.customEmojiText ?? sticker.file.stickerText ?? clown
            updatedState = textInteractions.insertText(.makeAnimated(sticker.file, text: text))
        }
        
        textInteractions.update { _ in
            return updatedState
        }
        updateState { current in
            var current = current
            current.state = updatedState
            return current
        }
    }
    
    actionsDisposable.add((statePromise.get() |> deliverOnMainQueue).start(next: { [weak emojis] state in
        emojis?.setSelectedItems(state.selected.map { .init(source: .custom($0.fileId.id), type: .normal) })
    }))
    
    
    let arguments = Arguments(context: context, interactions: textInteractions, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, createPack: {
        
    }, addReactions: { [weak emojis] control in
        if let emojis = emojis {
            showPopover(for: control, with: emojis, edge: .maxY, inset: NSMakePoint(0, -60))
        }
    }, updateState: { state in
        textInteractions.update { _ in
            return state
        }
        updateState { current in
            var current = current
            current.state = state
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Reactions")
    
    controller.contextObject = emojis
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}

