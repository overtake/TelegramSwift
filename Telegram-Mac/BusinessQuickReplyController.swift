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


final class QuickReplyRowItem : GeneralRowItem {
    
    let reply: ShortcutMessageList.Item
    let context: AccountContext
    let editing: Bool
    let open: (ShortcutMessageList.Item)->Void
    let editName: (ShortcutMessageList.Item)->Void
    let remove: (ShortcutMessageList.Item)->Void
    
    let _badge: TextViewLayout?
    let _textLayout: TextViewLayout
    
    let selected_badge: TextViewLayout?
    let selected_textLayout: TextViewLayout

    var badge: TextViewLayout? {
        if isSelected {
            return selected_badge
        } else {
            return _badge
        }
    }
    
    var textLayout: TextViewLayout {
        if isSelected {
            return selected_textLayout
        } else {
            return _textLayout
        }
    }

    init(_ initialSize: NSSize, stableId: AnyHashable, reply: ShortcutMessageList.Item, context: AccountContext, editing: Bool, viewType: GeneralViewType, open: @escaping(ShortcutMessageList.Item)->Void, editName: @escaping(ShortcutMessageList.Item)->Void, remove: @escaping(ShortcutMessageList.Item)->Void, selected: String? = nil) {
        self.reply = reply
        self.context = context
        self.editing = editing
        self.editName = editName
        self.open = open
        self.remove = remove
        let attr = NSMutableAttributedString()
        attr.append(string: "/\(reply.shortcut)", color: theme.colors.text, font: .normal(.text))
        attr.append(string: " ", color: theme.colors.text, font: .normal(.text))
        
        if let selected = selected {
            let range = attr.string.lowercased().nsstring.range(of: selected)
            if range.location != NSNotFound {
                attr.addAttribute(.foregroundColor, value: theme.colors.accent, range: range)
            }
        }
        
        let texts = chatListText(account: context.account, for: reply.topMessage._asMessage())
        
        if reply.totalCount > 1 {
            _badge = .init(.initialize(string: strings().businessQuickReplyMore1Countable(reply.totalCount - 1), color: theme.colors.grayText, font: .medium(.small)), alignment: .center)
            _badge?.measure(width: .greatestFiniteMagnitude)
            
            selected_badge = .init(.initialize(string: strings().businessQuickReplyMore1Countable(reply.totalCount - 1), color: theme.colors.accentSelect, font: .medium(.small)), alignment: .center)
            selected_badge?.measure(width: .greatestFiniteMagnitude)

        } else {
            _badge = nil
            selected_badge = nil
        }
        
        
        let prevRange = attr.range
        attr.append(texts)
       // attr.addAttribute(.foregroundColor, value: theme.colors.grayText, range: NSMakeRange(prevRange.location, texts.length))

        let selectedAttr = attr.mutableCopy() as! NSMutableAttributedString
        selectedAttr.addAttribute(.foregroundColor, value: theme.colors.underSelectedColor, range: selectedAttr.range)
        
        self.selected_textLayout = TextViewLayout(selectedAttr, maximumNumberOfLines: 1)
        
        self._textLayout = TextViewLayout(attr, maximumNumberOfLines: 1)

        super.init(initialSize, stableId: stableId, viewType: viewType, inset: viewType == .legacy ? .init() : .init(left: 20, right: 20))
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if viewType != .legacy {
            return .single([ContextMenuItem(strings().businessQuickReplyEditName, handler: { [weak self] in
                if let self {
                    self.editName(self.reply)
                }
            }, itemImage: MenuAnimation.menu_edit.value)])
        } else {
            return .single([])
        }
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
        
        if let badge {
            width -= (badge.layoutSize.width + 5)
        }
        
        return width
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        textLayout.measure(width: textWidth)
        selected_textLayout.measure(width: textWidth)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return QuickReplyRowItemView.self
    }
    
    override var height: CGFloat {
        return max(44, 10 + textLayout.layoutSize.height)
    }
    
    override var hasBorder: Bool {
        if self.viewType == .legacy {
            return self != self.table?.lastItem
        } else {
            return super.hasBorder
        }
    }
    
    var leftInset: CGFloat {
        if self.viewType == .legacy {
            return 0
        } else {
            return 20
        }
    }
}

private final class QuickReplyRowItemView: GeneralContainableRowView {
    private let textView = InteractiveTextView(frame: .zero)
    private let imageView = AvatarControl(font: .avatar(10))
    private let container = View()
    private var badgeView: TextView?
    
    private var remove: ImageButton?
    private var sort: ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(imageView)
        container.addSubview(textView)
        
        
        imageView.setFrameSize(NSMakeSize(30, 30))
        
        imageView.layer?.cornerRadius = imageView.frame.height / 2
        
        textView.userInteractionEnabled = false
       // textView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? QuickReplyRowItem {
                item.open(item.reply)
            }
        }, for: .Click)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Hover)
    }
    
    override var backdorColor: NSColor {
        if let item = item as? GeneralRowItem, item.viewType == .legacy {
            if item.isHighlighted {
                return theme.colors.grayBackground
            }
            if item.isSelected {
                return theme.colors.accentSelect
            }
            return containerView.controlState != .Highlight ? super.backdorColor : theme.colors.grayBackground.withAlphaComponent(0.2)
        }
        return super.backdorColor
    }
    
    override var borderColor: NSColor {
        if let item = item as? GeneralRowItem {
            if item.viewType == .legacy {
                if item.isSelected {
                    return .clear
                } else {
                    return super.borderColor
                }
            }
        }
        return super.borderColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var additionBorderInset: CGFloat {
        guard let item = item as? GeneralRowItem else {
            return 0
        }
        return 30 + 10 + (item.viewType == .legacy ? 16 : 0)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? QuickReplyRowItem else {
            return
        }
        
        containerView.userInteractionEnabled = item.viewType != .legacy && !item.editing
        
        imageView.setPeer(account: item.context.account, peer: item.context.myPeer)
        
        textView.set(text: item.textLayout, context: item.context)
        
        if let badge = item.badge {
            let current: TextView
            if let view = self.badgeView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.badgeView = current
                container.addSubview(current)
                
                current.centerY(x: textView.frame.maxX + 5)
            }
            current.update(badge)
            current.setFrameSize(NSMakeSize(badge.layoutSize.width + 6, badge.layoutSize.height + 4))
            current.layer?.cornerRadius = 4
            current.backgroundColor = item.isSelected ? theme.colors.underSelectedColor : theme.colors.grayText.withAlphaComponent(0.2)
        } else if let badgeView {
            performSubviewRemoval(badgeView, animated: animated)
            self.badgeView = nil
        }
        
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
        
//        self.updateLayout(size: nsmakesi, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
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
        
        transition.updateFrame(view: imageView, frame: CGRect(origin: NSMakePoint(0, 7), size: imageView.frame.size))
        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: imageView.frame.maxX + 10))
        
        if let badgeView {
            transition.updateFrame(view: badgeView, frame: badgeView.centerFrameY(x: textView.frame.maxX + 5))
        }
    }
    
}


private final class Arguments {
    let context: AccountContext
    let add:()->Void
    let edit:(ShortcutMessageList.Item)->Void
    let open:(ShortcutMessageList.Item)->Void
    let editName:(ShortcutMessageList.Item)->Void
    let remove:(ShortcutMessageList.Item)->Void
    init(context: AccountContext, add:@escaping()->Void, edit:@escaping(ShortcutMessageList.Item)->Void, remove:@escaping(ShortcutMessageList.Item)->Void, editName:@escaping(ShortcutMessageList.Item)->Void, open:@escaping(ShortcutMessageList.Item)->Void) {
        self.context = context
        self.add = add
        self.edit = edit
        self.remove = remove
        self.editName = editName
        self.open = open
    }
}

private struct State : Equatable {
    var replies: ShortcutMessageList?
    
    var editing: Bool = false
    
    var creatingName: String?
    var input_error: InputDataValueError?
    
    var isEmpty: Bool {
        if let replies {
            return replies.items.isEmpty
        }
        return true
    }
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_add = InputDataIdentifier("_id_add")
private func _id_reply(_ id: ShortcutMessageList.Item) -> InputDataIdentifier {
    return .init("_id_reply__\(id.shortcut)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
        
    let headerAttr = NSMutableAttributedString()
    _ = headerAttr.append(string: strings().businessQuickReplyHeader, color: theme.colors.listGrayText, font: .normal(.text))
    
    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.business_quick_reply, text: headerAttr)
    }))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var limit = arguments.context.appConfiguration.getGeneralValue("quick_replies_limit", orElse: 20) - 2
    
    let hasAway = state.replies?.items.contains(where: { $0.shortcut == "away" || $0.shortcut == "_away" }) ?? false
    let hasGreeting = state.replies?.items.contains(where: { $0.shortcut == "greeting" || $0.shortcut == "_greeting" }) ?? false

    if hasGreeting {
        limit += 1
    }
    if hasAway {
        limit += 1
    }
    
    let count = state.replies?.items.count ?? 0
    let isFull = limit <= count
    
    if !isFull {
        entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_add, data: .init(name: strings().businessQuickReplyAdd, color: theme.colors.accent, icon: theme.icons.stickersAddFeatured, type: .none, viewType: state.isEmpty ? .singleItem : .firstItem, action: {
            arguments.add()
        })))
    }
    
    
    if let replies = state.replies {
        struct Tuple : Equatable {
            var reply: ShortcutMessageList.Item
            var viewType: GeneralViewType
            var editing: Bool
            var index: Int
        }
        var tuples: [Tuple] = []
        
        for (i, reply) in replies.items.enumerated() {
            var viewType: GeneralViewType = bestGeneralViewType(replies.items, for: i)
            if i == 0, !isFull {
                if i < replies.items.count - 1 {
                    viewType = .innerItem
                } else {
                    viewType = .lastItem
                }
            }
            tuples.append(.init(reply: reply, viewType: viewType, editing: state.editing, index: i))
        }
        
        for tuple in tuples {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_reply(tuple.reply), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return QuickReplyRowItem(initialSize, stableId: stableId, reply: tuple.reply, context: arguments.context, editing: tuple.editing, viewType: tuple.viewType, open: arguments.open, editName: arguments.editName, remove: arguments.remove)
            }))
        }
    }
    
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}


func BusinessQuickReplyController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let nextTransactionNonAnimated = Atomic(value: false)
    
    
    let shortcutList = context.engine.accountData.shortcutMessageList(onlyRemote: false)
    
    actionsDisposable.add(shortcutList.start(next: { value in
        updateState { current in
            var current = current
            current.replies = value
            return current
        }
    }))
    
    actionsDisposable.add(context.engine.accountData.keepShortcutMessageListUpdated().startStrict())

    let arguments = Arguments(context: context, add: {
        showModal(with: BusinessAddQuickReply(context: context, actionsDisposable: actionsDisposable, stateSignal: statePromise.get(), stateValue: stateValue, updateState: updateState, reply: nil), for: context.window)
    }, edit: { reply in
        
    }, remove: { reply in
        if let shortcutId = reply.id {
            verifyAlert(for: context.window, information: strings().businessQuickReplyConfirmDelete, ok: strings().modalDelete, successHandler: { _ in
                context.engine.accountData.deleteMessageShortcuts(ids: [shortcutId])
            })
        }
    }, editName: { reply in
        showModal(with: BusinessAddQuickReply(context: context, actionsDisposable: actionsDisposable, stateSignal: statePromise.get(), stateValue: stateValue, updateState: updateState, reply: reply), for: context.window)
    }, open: { reply in
        let messages = AutomaticBusinessMessageSetupChatContents(context: context, kind: .quickReplyMessageInput(shortcut: reply.shortcut), shortcutId: reply.id)
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId),mode: .customChatContents(contents: messages)))
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), animated: !nextTransactionNonAnimated.swap(false))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessQuickReplyTitle, removeAfterDisappear: false, identifier: "business_quick_reply")
    
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
                var replies = stateValue.with { $0.replies?.items ?? [] }
                replies.move(at: fromValue, to: toValue)
                _ = nextTransactionNonAnimated.swap(true)
                
                context.engine.accountData.reorderMessageShortcuts(ids: replies.compactMap { $0.id }, completion: {
                    
                })

               
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

private func newReplyEntries(_ state: State, reply: ShortcutMessageList.Item?) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    //
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(reply == nil ? strings().businessQuickReplyAddInfo : strings().businessQuickReplyEditInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.input(sectionId: sectionId, index: 0, value: .string(state.creatingName), error: state.input_error, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem, defaultText: ""), placeholder: nil, inputPlaceholder: strings().businessQuickReplyAddPlaceholder, filter: { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }, limit: 40))

  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private func BusinessAddQuickReply(context: AccountContext, actionsDisposable: DisposableSet, stateSignal: Signal<State, NoError>, stateValue: Atomic<State>, updateState: @escaping((State) -> State) -> Void, reply: ShortcutMessageList.Item?) -> InputDataModalController {
    
    var close:(()->Void)? = nil

    updateState { current in
        var current = current
        current.creatingName = reply?.shortcut
        return current
    }
    
    let signal = stateSignal |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: newReplyEntries(state, reply: reply))
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: reply == nil ? strings().businessQuickReplyAddInfo : strings().businessQuickReplyEditInfo)
    
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
        
        guard let value else {
            return .fail(.fields([_id_input : .shake]))
        }
        
        let replies = stateValue.with { $0.replies?.items ?? [] }
        let contains = replies.contains(where: { $0.shortcut == value })
        
        if contains, reply?.shortcut != value {
            updateState { current in
                var current = current
                current.input_error = .init(description: strings().businessQuickReplyAddError, target: .data)
                return current
            }
            return .fail(.fields([_id_input : .shake]))
        }
        
        if value.isEmpty {
            return .fail(.fields([_id_input : .shake]))
        }
        
        if reply == nil {
            let messages = AutomaticBusinessMessageSetupChatContents(context: context, kind: .quickReplyMessageInput(shortcut: value), shortcutId: nil)
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId),mode: .customChatContents(contents: messages)))
        } else if let reply, let shortcutId = reply.id {
            let name = stateValue.with { $0.creatingName ?? "" }
            if !name.isEmpty {
                context.engine.accountData.editMessageShortcut(id: shortcutId, shortcut: name)
            } else {
                return .fail(.fields([_id_input : .shake]))
            }
        }
        close?()
        return .none
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    
    return modalController

    
}

/*
 */
