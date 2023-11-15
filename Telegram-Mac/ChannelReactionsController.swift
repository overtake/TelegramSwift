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
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, interactions: TextView_Interactions, viewType: GeneralViewType, state: Updated_ChatTextInputState, action: @escaping(Control?)->Void, updateState:@escaping(Updated_ChatTextInputState)->Void) {
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
        attr.append(self.state.inputText)
        let str: NSMutableAttributedString = .init()
        let ph_width = placeholder.attributedString.sizeFittingWidth(.greatestFiniteMagnitude).width
//        while true {
//            str.append(string: clown, font: .normal(18))
//            if str.sizeFittingWidth(.greatestFiniteMagnitude).width >= ph_width {
//                break
//            }
//        }
//        attr.append(str)
        attr.addAttribute(.font, value: NSFont.normal(18), range: attr.range)
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
        //addSubview(overlay)
        
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
        
        inputView.inputTheme = theme.inputTheme.withUpdatedFontSize(18)
        
        guard let item = item as? ReactionsRowItem else {
            return
        }
        inputView.context = item.context
        inputView.interactions.max_height = 500
        inputView.interactions.min_height = 20
        inputView.interactions.emojiPlayPolicy = .onceEnd
        inputView.interactions.canTransform = false
        
        item.interactions.min_height = 20
        item.interactions.max_height = 500
        item.interactions.emojiPlayPolicy = .onceEnd
        item.interactions.canTransform = false

        item.interactions.filterEvent = { event in
            if let chars = event.characters {
                return chars.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).isEmpty
            } else {
                return false
            }
        }

        self.inputView.set(item.state.textInputState())

        self.inputView.interactions = item.interactions
        
        item.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        
        overlay.update(item.placeholder)
        
        
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
                rect = NSMakeRect(lastSymbolRect.maxX + item.viewType.innerInset.left + 5, lastSymbolRect.minY + overlay.frame.height / 2 + 2, overlay.frame.width, overlay.frame.height)
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
    let addReactions:(Control?)->Void
    let updateState:(Updated_ChatTextInputState)->Void

    init(context: AccountContext, interactions: TextView_Interactions, toggleEnabled:@escaping()->Void, createPack:@escaping()->Void, addReactions:@escaping(Control?)->Void, updateState:@escaping(Updated_ChatTextInputState)->Void) {
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
    var available: AvailableReactions
    var state:Updated_ChatTextInputState = .init(inputText: .init())
    
    var stats: ChannelBoostStatus?
    var myStatus: MyBoostStatus?
    
    var selected: [Int64] {
        let attributes = chatTextAttributes(from: state.inputText)
        var files:[Int64] = []
        
        for attribute in attributes {
            switch attribute {
            case let .animated(_, _, fileId, file, _):
                files.append(fileId)
            default:
                break
            }
        }
        return files
    }
    
    var allowedReactions: PeerAllowedReactions {
        var reactions: [MessageReaction.Reaction] = []
        
        let attributes = chatTextAttributes(from: state.inputText)
        
        for attribute in attributes {
            switch attribute {
            case let .animated(_, _, fileId, _, _):
                if let builtin = available.reactions.first(where: { $0.activateAnimation.fileId.id == fileId }) {
                    reactions.append(builtin.value)
                } else {
                    reactions.append(.custom(fileId))
                }
            default:
                break
            }
        }
        return .limited(reactions)
    }
    
    var customCount: Int {
        var count: Int = 0
        for fileId in selected {
            if available.reactions.first(where: { $0.activateAnimation.fileId.id == fileId }) == nil {
                count += 1
            }
        }
        return count
    }
}



private let _id_enabled = InputDataIdentifier("_id_enabled")
private let _id_emojies = InputDataIdentifier("_id_emojies")
private let _id_add = InputDataIdentifier("_id_add")
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
        
        let error: InputDataValueError?
        if state.customCount > 0, let stats = state.stats, stats.level < state.customCount {
            error = .init(description: "\(state.customCount) Boost Level Required", target: .data)
        } else {
            error = nil
        }
        if let error = error {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error.description), data: .init(color: theme.colors.redUI, viewType: .textTopItem)))
            index += 1
        }

        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emojies, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return ReactionsRowItem(initialSize, stableId: stableId, context: arguments.context, interactions: arguments.interactions, viewType: .firstItem, state: state.state, action: arguments.addReactions, updateState: arguments.updateState)
        }))
        index += 1
        
       
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add, data: .init(name: "Add Reactions", color: theme.colors.text, type: .nextContext(""), viewType: .lastItem, action: {
            arguments.addReactions(nil)
        })))
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

func ChannelReactionsController(context: AccountContext, peerId: PeerId, allowedReactions: PeerAllowedReactions?, availableReactions: AvailableReactions) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil

    let textInteractions = TextView_Interactions()

    
    if let allowedReactions = allowedReactions {
        
        switch allowedReactions {
        case .all:
            for reaction in availableReactions.reactions {
                textInteractions.update { _ in
                    return textInteractions.insertText(.makeAnimated(reaction.activateAnimation, text: reaction.value.string))
                }
            }
        case let .limited(reactions):
            for reaction in reactions {
                switch reaction {
                case .builtin:
                    if let first = availableReactions.reactions.first(where: { $0.value == reaction }) {
                        textInteractions.update { _ in
                            return textInteractions.insertText(.makeAnimated(first.activateAnimation, text: first.value.string))
                        }
                    }
                case let .custom(fileId):
                    textInteractions.update { _ in
                        return textInteractions.insertText(.makeAnimated(fileId, text: clown))
                    }
                }
            }
        case .empty:
            break
        }
    }
    
    let initialState = State(available: availableReactions, state: textInteractions.presentation)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    

    
    textInteractions.processEnter = { event in
        return false
    }
    textInteractions.processAttriburedCopy = { attributedString in
        return globalLinkExecutor.copyAttributedString(attributedString)
    }
    textInteractions.processPaste = { pasteboard in
        if let data = pasteboard.data(forType: .kInApp) {
            let decoder = AdaptedPostboxDecoder()
            if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                let state = decoded.unique(isPremium: true)
                textInteractions.update { _ in
                    return textInteractions.insertText(state.attributedString())
                }
                return true
            }
        }
        return false
    }
    
    let emojis = EmojiesController(context, mode: .channelReactions, selectedItems: initialState.selected.map { .init(source: .custom($0), type: .normal) })
    emojis._frameRect = NSMakeRect(0, 0, 350, 300)
    let interactions = EntertainmentInteractions(.emoji, peerId: peerId)
    emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))


    
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
        emojis?.setSelectedItems(state.selected.map { .init(source: .custom($0), type: .normal) })
    }))
    
    var getControl:(()->Control?)? = nil

    
    let arguments = Arguments(context: context, interactions: textInteractions, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, createPack: {
        execute(inapp: inApp(for: "https://t.me/stickers", context: context, openInfo: { peerId, _, _, _ in
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
        }))
        close?()
    }, addReactions: { [weak emojis] control in
        let control = control ?? getControl?()
        if let emojis = emojis, let control = control {
            showPopover(for: control, with: emojis, edge: .maxY, inset: NSMakePoint(-325, -200))
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
    
    let controller = InputDataController(dataSignal: signal, title: "Reactions", removeAfterDisappear: false)
    
    controller.contextObject = emojis
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        
        _ = showModalProgress(signal: context.engine.peers.updatePeerAllowedReactions(peerId: peerId, allowedReactions: stateValue.with { $0.allowedReactions }), for: context.window).start(error: { error in
            
            switch error {
            case .boostRequired:
                
                let signal = context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue
                _ = signal.start(next: { peer in
                    
                    let stats = stateValue.with { $0.stats }
                    let myStatus = stateValue.with { $0.myStatus }
                    if let stats = stats {
                        showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .reactions), for: context.window)
                    }
                })
            case .generic:
                alert(for: context.window, info: strings().unknownError)
            }

            
        }, completed: {
            close?()
            //TODOLANG
            showModalText(for: context.window, text: "Reactions successfully updated")
        })
        return .none
    }
    
    actionsDisposable.add(combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus()).start(next: { stats, myStatus in
        updateState { current in
            var current = current
            current.stats = stats
            current.myStatus = myStatus
            return current
        }
    }))

    
    let modalInteractions = ModalInteractions(acceptTitle: "Update Reactions", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.didLoaded = { controller, _ in
        getControl = { [weak controller] in
            let view = controller?.tableView.item(stableId: InputDataEntryId.general(_id_add))?.view as? GeneralInteractedRowView
            return view?.textView
        }
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}

