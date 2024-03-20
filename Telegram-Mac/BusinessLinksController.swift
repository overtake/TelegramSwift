//
//  BusinessLinksController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Cocoa
import TGUIKit
import SwiftSignalKit

private var linkIcon: CGImage {
    return generateImage(NSMakeSize(30, 30), contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.setFillColor(theme.colors.accent.cgColor)
        ctx.fillEllipse(in: size.bounds)
        let image = NSImage(resource: .iconExportedInvitationLink).precomposed(.white)
        ctx.draw(image, in: size.bounds.focus(image.backingSize))
    })!
}


private final class LinkRowItem : GeneralRowItem {
    let nameLayout: TextViewLayout
    let textLayout: TextViewLayout
    let clicksLayout: TextViewLayout
    let open: (State.Link)->Void
    let editName: (State.Link)->Void
    let remove: (State.Link)->Void
    let share: (State.Link)->Void
    let link: State.Link
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, link: State.Link, viewType: GeneralViewType, open: @escaping(State.Link)->Void, editName: @escaping(State.Link)->Void, remove: @escaping(State.Link)->Void, share: @escaping(State.Link)->Void) {
        self.nameLayout = .init(.initialize(string: link.name ?? link.link, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.textLayout = .init(.initialize(string: link.text.inputText.isEmpty ? "no message" : link.text.inputText, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        self.clicksLayout = .init(.initialize(string: link.clicks == nil ? "no clicks" : "\(link.clicks!) clicks", color: theme.colors.grayText, font: .normal(.small)), maximumNumberOfLines: 1)
        self.link = link
        self.open = open
        self.editName = editName
        self.remove = remove
        self.share = share
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        clicksLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 30 - 20 - clicksLayout.layoutSize.width)
        textLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 30 - 20)

        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        let link = self.link
        return .single([ContextMenuItem("Edit Name", handler: { [weak self] in
            self?.editName(link)
        }, itemImage: MenuAnimation.menu_edit.value), ContextMenuItem("Share", handler: { [weak self] in
            self?.share(link)
        }, itemImage: MenuAnimation.menu_share.value), ContextSeparatorItem(), ContextMenuItem("Remove", handler: { [weak self] in
            self?.remove(link)
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value)])
    }
    
    override func viewClass() -> AnyClass {
        return LinkRowView.self
    }
}

private final class LinkRowView: GeneralContainableRowView {
    private let nameView = TextView()
    private let textView = TextView()
    private let icon = ImageView()
    private let clicksView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(nameView)
        addSubview(textView)
        addSubview(icon)
        addSubview(clicksView)
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false

        textView.userInteractionEnabled = false
        textView.isSelectable = false

        clicksView.userInteractionEnabled = false
        clicksView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? LinkRowItem else {
                return
            }
            item.open(item.link)
        }, for: .Click)

    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? LinkRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? LinkRowItem else {
            return
        }
        
        icon.centerY(x: item.viewType.innerInset.left)
        nameView.setFrameOrigin(NSMakePoint(icon.frame.maxX + 10, 8))
        textView.setFrameOrigin(NSMakePoint(icon.frame.maxX + 10, frame.height - textView.frame.height - 8))
        clicksView.setFrameOrigin(NSMakePoint(containerView.frame.width - item.viewType.innerInset.right - clicksView.frame.width, 8))

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LinkRowItem else {
            return
        }
        
        nameView.update(item.nameLayout)
        textView.update(item.textLayout)
        clicksView.update(item.clicksLayout)
        
        icon.image = linkIcon
        icon.sizeToFit()
        
        needsLayout = true
    }
}

private final class Arguments {
    let context: AccountContext
    let shareMy:(String)->Void
    let add:()->Void
    let open: (State.Link)->Void
    let editName: (State.Link)->Void
    let remove: (State.Link)->Void
    let share: (State.Link)->Void
    init(context: AccountContext, shareMy:@escaping(String)->Void, add: @escaping()->Void, open: @escaping(State.Link)->Void, editName: @escaping(State.Link)->Void, remove: @escaping(State.Link)->Void, share: @escaping(State.Link)->Void) {
        self.context = context
        self.shareMy = shareMy
        self.add = add
        self.open = open
        self.editName = editName
        self.remove = remove
        self.share = share
    }
}

private struct State : Equatable {
    struct Link : Equatable {
        var link: String
        var text: ChatTextInputState
        var name: String?
        var clicks: Int32?
    }
    var links: [Link] = []
}



private let _id_header = InputDataIdentifier("_id_header")
private let _id_add = InputDataIdentifier("_id_add")
private func _id_link(_ id: State.Link) -> InputDataIdentifier {
    return .init("_id_link_\(id.link)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let headerAttr = NSMutableAttributedString()
    _ = headerAttr.append(string: "Give your customers short links that start a chat with you - and suggest the first message from them to you.", color: theme.colors.listGrayText, font: .normal(.text))

    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.business_quick_reply, text: headerAttr)
    }))

    // entries

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_add, data: .init(name: "Create Link to Chat", color: theme.colors.accent, icon: NSImage(resource: .iconBusinessLinksAdd).precomposed(theme.colors.accent, flipVertical: true), type: .none, viewType: .singleItem, action: arguments.add)))
    
    if let peer = arguments.context.myPeer as? TelegramUser {
        let text: String
        let phone = "[t.me/+\(peer.phone!)](https://t.me/+\(peer.phone!))"
        if let address = peer.addressName, !address.isEmpty {
            let tme = "[t.me/\(address)](https://t.me/\(address))"
            text = "You can also use a simple link for a chat with you — \(tme) or \(phone)."
        } else {
            text = "You can also use a simple link for a chat with you — \(phone)."
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: arguments.shareMy), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    struct Tuple : Equatable {
        let link: State.Link
        let viewType: GeneralViewType
    }
    var items: [Tuple] = []
    
    for (i, link) in state.links.enumerated() {
        items.append(.init(link: link, viewType: bestGeneralViewType(state.links, for: i)))
    }
    
    for item in items {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link(item.link), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return LinkRowItem(initialSize, stableId: stableId, context: arguments.context, link: item.link, viewType: item.viewType, open: arguments.open, editName: arguments.editName, remove: arguments.remove, share: arguments.share)
        }))
    }
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func BusinessLinksController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let editName:(State.Link)->Void = { link in
        showModal(with: BusinessLinkRenameController(context: context, name: link.name, callback: { updated in
            updateState { current in
                var current = current
                if let index = current.links.firstIndex(where: { $0.link == link.link }) {
                    current.links[index].name = updated
                }
                return current
            }
        }), for: context.window)}
    
    let open:(State.Link)->Void = { link in
        var contents: ChatCustomLinkContent = ChatCustomLinkContent(link: link.link, name: link.name ?? "")

        contents.editName = {
            editName(link)
        }
        contents.saveText = { input in
            updateState { current in
                var current = current
                if let index = current.links.firstIndex(where: { $0.link == link.link }) {
                    current.links[index].text = input
                }
                return current
            }
        }
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId), mode: .customLink(contents: contents)))
    }
    
    let share:(State.Link)->Void = { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link.link)), for: context.window)
    }
    

    let arguments = Arguments(context: context, shareMy: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, add: {
        let link = State.Link(link: "t.me/m/ak2JlwVl", text: .init())
        
        updateState { current in
            var current = current
            current.links.append(link)
            return current
        }
        open(link)
        
    }, open: open, editName: editName, remove: { link in
        updateState { current in
            var current = current
            current.links.removeAll(where: { $0.link == link.link })
            return current
        }
    }, share: share)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Links to Chat", removeAfterDisappear: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}



private struct NameState : Equatable {
    var name: String?
}

private final class NameArguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private let _id_input = InputDataIdentifier("_id_input")

private func entries(_ state: NameState, arguments: NameArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.name), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: "Name this link...", filter: { $0 }, limit: 32))
  
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func BusinessLinkRenameController(context: AccountContext, name: String?, callback:@escaping(String?)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = NameState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NameState) -> NameState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = NameArguments(context: context)
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Name Link to Chat")
    
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
            current.name = data[_id_input]?.stringValue
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        callback(stateValue.with { $0.name })
        
        return .success(.custom({
            close?()
        }))
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    
    return modalController
    
}


/*

 */


