//
//  BusinessQuickReplyController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

#if DEBUG

private final class QuickReplyRowItem : GeneralRowItem {
    
    let reply: State.Reply
    let context: AccountContext
    let textLayout: TextViewLayout
    let editing: Bool
    let open: (State.Reply)->Void
    let editName: (State.Reply)->Void
    let remove: (State.Reply)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, reply: State.Reply, context: AccountContext, editing: Bool, viewType: GeneralViewType, open: @escaping(State.Reply)->Void, editName: @escaping(State.Reply)->Void, remove: @escaping(State.Reply)->Void) {
        self.reply = reply
        self.context = context
        self.editing = editing
        self.editName = editName
        self.open = open
        self.remove = remove
        let attr = NSMutableAttributedString()
        attr.append(string: "/\(reply.name)", color: theme.colors.text, font: .normal(.text))
        attr.append(string: " ", color: theme.colors.text, font: .normal(.text))
        attr.append(string: reply.messages[0], color: theme.colors.grayText, font: .normal(.text))
        
        self.textLayout = TextViewLayout(attr)
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single([ContextMenuItem("Edit Name", handler: { [weak self] in
            if let self {
                self.editName(self.reply)
            }
        }, itemImage: MenuAnimation.menu_edit.value)])
    }
    
    private var textWidth: CGFloat {
        var width = blockWidth
        width -= (leftInset + viewType.innerInset.left)
        
        width -= 40 // photo
        width -= viewType.innerInset.left // photo


        if editing {
            width -= 30 //left control
            width -= 30 // sort control
        }
        
        return width
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        textLayout.measure(width: textWidth)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return QuickReplyRowItemView.self
    }
    
    override var height: CGFloat {
        return 44
    }
    
    var leftInset: CGFloat {
        return 20
    }
}

private final class QuickReplyRowItemView: GeneralContainableRowView {
    private let textView = TextView()
    private let imageView = ImageView(frame: NSMakeRect(0, 0, 30, 30))
    private let container = View()
    
    private var remove: ImageButton?
    private var sort: ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(imageView)
        container.addSubview(textView)
        
        imageView.layer?.backgroundColor = theme.colors.grayIcon.cgColor
        imageView.layer?.cornerRadius = imageView.frame.height / 2
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? QuickReplyRowItem else {
            return
        }
        
        textView.update(item.textLayout)
        
        if item.editing {
            if "".isEmpty {
                let current: ImageButton
                var isNew = false
                if let view = self.remove {
                    current = view
                } else {
                    current = ImageButton()
                    current.scaleOnClick = true
                    current.autohighlight = false
                    addSubview(current)
                    self.remove = current
                    
                    current.set(handler: { [weak self] _ in
                        if let item = self?.item as? QuickReplyRowItem {
                            item.remove(item.reply)
                        }
                    }, for: .Click)
                    
                    isNew = true
                }
                current.set(image: theme.icons.deleteItem, for: .Normal)
                current.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
                
                if isNew {
                    current.centerY(x: item.leftInset)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            }
            if "".isEmpty {
                let current: ImageButton
                var isNew = false
                if let view = self.sort {
                    current = view
                } else {
                    current = ImageButton()
                    current.scaleOnClick = true
                    current.autohighlight = false
                    addSubview(current)
                    self.sort = current
                    
                    
                    current.set(handler: { [weak self] _ in
                        if let event = NSApp.currentEvent {
                            self?.mouseDown(with: event)
                        }
                    }, for: .Down)
                    
                    current.set(handler: { [weak self] _ in
                        if let event = NSApp.currentEvent {
                            self?.mouseDragged(with: event)
                        }
                    }, for: .MouseDragging)
                    
                    current.set(handler: { [weak self] _ in
                        if let event = NSApp.currentEvent {
                            self?.mouseUp(with: event)
                        }
                    }, for: .Up)
                    
                    isNew = true
                }
                current.set(image: theme.icons.resort, for: .Normal)
                current.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
                
                if isNew {
                    current.centerY(x: containerView.frame.width - current.frame.width - item.viewType.innerInset.right)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            }
        } else {
            if let view = remove {
                performSubviewRemoval(view, animated: animated)
                self.remove = nil
            }
            if let view = sort {
                performSubviewRemoval(view, animated: animated)
                self.sort = nil
            }
        }
        
        self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? QuickReplyRowItem else {
            return
        }
        
        if let remove = remove {
            transition.updateFrame(view: remove, frame: remove.centerFrameY(x: item.leftInset))
        }
        
        let contentInset = item.editing ? item.leftInset * 2 + 18 : 16
        
        let containerRect = NSMakeRect(contentInset, 0, containerView.frame.width - contentInset, containerView.frame.height)
        
        transition.updateFrame(view: container, frame: containerRect)
        
        
        if let sort = sort {
            transition.updateFrame(view: sort, frame: sort.centerFrameY(x: containerView.frame.width - sort.frame.width - item.viewType.innerInset.right))
        }
        
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 0))
        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: imageView.frame.maxX + 10))
    }
}


private final class Arguments {
    let context: AccountContext
    let add:()->Void
    let edit:(State.Reply)->Void
    let editName:(State.Reply)->Void
    let remove:(State.Reply)->Void
    init(context: AccountContext, add:@escaping()->Void, edit:@escaping(State.Reply)->Void, remove:@escaping(State.Reply)->Void, editName:@escaping(State.Reply)->Void) {
        self.context = context
        self.add = add
        self.edit = edit
        self.remove = remove
        self.editName = editName
    }
}

private struct State : Equatable {
    struct Reply : Equatable {
        var name: String
        var messages: [String]
        var id: Int64
    }
    
    var replies: [Reply] = []
    
    var editing: Bool = false
    
    var creatingName: String?
    var input_error: InputDataValueError?
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_add = InputDataIdentifier("_id_add")
private func _id_reply(_ id: Int64) -> InputDataIdentifier {
    return .init("_id_reply_\(id)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
        
    let headerAttr = NSMutableAttributedString()
    _ = headerAttr.append(string: "Set up shortcuts with rich text and media to respond to messages faster.", color: theme.colors.listGrayText, font: .normal(.text))
    
    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.fly_dollar, text: headerAttr)
    }))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_add, data: .init(name: "Add Quick Reply", color: theme.colors.accent, icon: theme.icons.stickersAddFeatured, type: .none, viewType: state.replies.isEmpty ? .singleItem : .firstItem, action: {
        arguments.add()
    })))
    
    struct Tuple : Equatable {
        var reply: State.Reply
        var viewType: GeneralViewType
        var editing: Bool
    }
    var tuples: [Tuple] = []
    
    for (i, reply) in state.replies.enumerated() {
        var viewType: GeneralViewType = bestGeneralViewType(state.replies, for: i)
        if i == 0 {
            if i < state.replies.count - 1 {
                viewType = .innerItem
            } else {
                viewType = .lastItem
            }
        }
        tuples.append(.init(reply: reply, viewType: viewType, editing: state.editing))
    }
    
    for tuple in tuples {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_reply(tuple.reply.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
            return QuickReplyRowItem(initialSize, stableId: stableId, reply: tuple.reply, context: arguments.context, editing: tuple.editing, viewType: tuple.viewType, open: arguments.edit, editName: arguments.editName, remove: arguments.remove)
        }))
    }
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}


func BusinessQuickReplyController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let nextTransactionNonAnimated = Atomic(value: false)


    let arguments = Arguments(context: context, add: {
        showModal(with: BusinessAddQuickReply(context: context, stateSignal: statePromise.get(), stateValue: stateValue, updateState: updateState, reply: nil), for: context.window)
    }, edit: { reply in
        
    }, remove: { reply in
        updateState { current in
            var current = current
            current.replies.removeAll(where: { $0.id == reply.id })
            return current
        }
    }, editName: { reply in
        showModal(with: BusinessAddQuickReply(context: context, stateSignal: statePromise.get(), stateValue: stateValue, updateState: updateState, reply: reply), for: context.window)
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), animated: !nextTransactionNonAnimated.swap(false))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Quick Replies", removeAfterDisappear: false)
    
    controller.updateDoneValue = { data in
        return { f in
            if !stateValue.with({ $0.editing }) {
                f(.enabled(strings().navigationEdit))
            } else {
                f(.enabled(strings().navigationDone))
            }
        }
    }
    controller.validateData = { _ in
        updateState { current in
            var current = current
            current.editing = !current.editing
            return current
        }
        return .none
    }
    
    
    controller.afterTransaction = { controller in
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        
        controller.tableView.enumerateItems(with: { item in
            if let item = item as? QuickReplyRowItem {
                if item.editing {
                    if range.location == NSNotFound {
                        range.location = item.index
                    }
                    range.length += 1
                } else {
                    return false
                }
            }
            return true
        })
        
        if range.location != NSNotFound {
            controller.tableView.resortController = .init(resortRange: range, start: { _ in
                
            }, resort: { _ in }, complete: { from, to in
                let fromValue = from - range.location
                let toValue = to - range.location
                var replies = stateValue.with { $0.replies }
                replies.move(at: fromValue, to: toValue)
                _ = nextTransactionNonAnimated.swap(true)
                updateState { current in
                    var current = current
                    current.replies = replies
                    return current
                }
            })
        } else {
            controller.tableView.resortController = nil
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}



private let _id_input = InputDataIdentifier("_id_input")

private func newReplyEntries(_ state: State) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Add a shortcut for your quick reply."), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.input(sectionId: sectionId, index: 0, value: .string(state.creatingName), error: state.input_error, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem, defaultText: ""), placeholder: nil, inputPlaceholder: "Enter name...", filter: { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }, limit: 40))

  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private func BusinessAddQuickReply(context: AccountContext, stateSignal: Signal<State, NoError>, stateValue: Atomic<State>, updateState: @escaping((State) -> State) -> Void, reply: State.Reply?) -> InputDataModalController {
    
    var close:(()->Void)? = nil

    let actionsDisposable = DisposableSet()

    updateState { current in
        var current = current
        current.creatingName = reply?.name
        return current
    }
    
    let signal = stateSignal |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: newReplyEntries(state))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "New Quick Reply")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.creatingName = data[_id_input]?.stringValue
            current.input_error = nil
            return current
        }
        return .none
    }
    
    controller.validateData = { data in
        
        let value = data[_id_input]?.stringValue
        
        let replies = stateValue.with { $0.replies }
        let contains = replies.contains(where: { $0.name == value })
        
        if contains, reply?.name != value {
            updateState { current in
                var current = current
                current.input_error = .init(description: "Shortcut with that name already exists.", target: .data)
                return current
            }
            return .fail(.fields([_id_input : .shake]))
        }
        
        if value?.isEmpty == true {
            return .fail(.fields([_id_input : .shake]))
        }
        
        updateState { current in
            var current = current
            if let input = current.creatingName, !input.isEmpty {
                if let index = current.replies.firstIndex(where: { $0.id == reply?.id }) {
                    current.replies[index].name = input
                } else {
                    current.replies.append(.init(name: input, messages: ["text"], id: arc4random64()))
                }
            }
            return current
        }
        close?()
        return .none
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    
    return modalController

    
}

#endif

/*
 */
