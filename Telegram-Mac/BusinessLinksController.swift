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

private extension TelegramBusinessChatLinks.Link {
    var stateLink: State.Link {
        let attributes = chatTextAttributes(from: TextEntitiesMessageAttribute(entities: self.entities), associatedMedia: [:])
        return State.Link(link: self.url, text: .init(inputText: self.message, selectionRange: self.message.length ..< self.message.length, attributes: attributes), name: self.title, clicks: self.viewCount)
    }
}

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
    let copy: (State.Link)->Void
    let link: State.Link
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, link: State.Link, viewType: GeneralViewType, open: @escaping(State.Link)->Void, editName: @escaping(State.Link)->Void, remove: @escaping(State.Link)->Void, share: @escaping(State.Link)->Void, copy: @escaping(State.Link)->Void) {
        self.nameLayout = .init(.initialize(string: link.name ?? link.link, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        if link.text.inputText.isEmpty {
            self.textLayout = .init(.initialize(string: strings().businessLinksItemNoText, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        } else {
            let attr = link.text.attributedString().mutableCopy() as! NSMutableAttributedString
            InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: link.text.messageTextEntities(), isPremium: true)

            attr.addAttribute(.foregroundColor, value: theme.colors.grayText, range: attr.range)
            attr.addAttribute(.font, value: NSFont.normal(.text), range: attr.range)
            self.textLayout = .init(attr, maximumNumberOfLines: 1)
        }
        self.clicksLayout = .init(.initialize(string: strings().businessLinksItemClicksCountable(Int(link.clicks ?? 0)), color: theme.colors.grayText, font: .normal(.small)), maximumNumberOfLines: 1)
        self.link = link
        self.open = open
        self.editName = editName
        self.remove = remove
        self.share = share
        self.copy = copy
        self.context = context
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
        return .single([ContextMenuItem(strings().businessLinksItemCopy, handler: { [weak self] in
            self?.copy(link)
        }, itemImage: MenuAnimation.menu_copy.value), ContextMenuItem(strings().businessLinksItemShare, handler: { [weak self] in
            self?.share(link)
        }, itemImage: MenuAnimation.menu_share.value), ContextMenuItem(strings().businessLinksItemEditName, handler: { [weak self] in
            self?.editName(link)
        }, itemImage: MenuAnimation.menu_edit.value), ContextSeparatorItem(), ContextMenuItem(strings().businessLinksItemDelete, handler: { [weak self] in
            self?.remove(link)
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value)])
    }
    
    override func viewClass() -> AnyClass {
        return LinkRowView.self
    }
}

private final class LinkRowView: GeneralContainableRowView {
    private let nameView = TextView()
    private let textView = InteractiveTextView(frame: .zero)
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
        textView.set(text: item.textLayout, context: item.context)
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
    let copy: (State.Link)->Void
    init(context: AccountContext, shareMy:@escaping(String)->Void, add: @escaping()->Void, open: @escaping(State.Link)->Void, editName: @escaping(State.Link)->Void, remove: @escaping(State.Link)->Void, share: @escaping(State.Link)->Void, copy: @escaping(State.Link)->Void) {
        self.context = context
        self.shareMy = shareMy
        self.add = add
        self.open = open
        self.editName = editName
        self.remove = remove
        self.share = share
        self.copy = copy
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
    _ = headerAttr.append(string: strings().businessLinksInfo, color: theme.colors.listGrayText, font: .normal(.text))

    entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.business_links, text: headerAttr)
    }))

    // entries

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: 0, value: .none, error: nil, identifier: _id_add, data: .init(name: strings().businessLinksCreate, color: theme.colors.accent, icon: NSImage(resource: .iconBusinessLinksAdd).precomposed(theme.colors.accent, flipVertical: true), type: .none, viewType: .singleItem, action: arguments.add)))
    
    if let peer = arguments.context.myPeer as? TelegramUser {
        let text: String
        let phone = "[t.me/+\(peer.phone!)](https://t.me/+\(peer.phone!))"
        if let address = peer.addressName, !address.isEmpty {
            let tme = "[t.me/\(address)](https://t.me/\(address))"
            text = strings().businessLinksCreateInfoFull(tme, phone)
        } else {
            text = strings().businessLinksCreateInfoPhone(phone)
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
    
    if !items.isEmpty {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessLinksBlock), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link(item.link), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return LinkRowItem(initialSize, stableId: stableId, context: arguments.context, link: item.link, viewType: item.viewType, open: arguments.open, editName: arguments.editName, remove: arguments.remove, share: arguments.share, copy: arguments.copy)
            }))
        }
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
    
    let links = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessChatLinks(id: context.peerId))
    
    actionsDisposable.add(context.engine.accountData.refreshBusinessChatLinks().startStrict())
    
    actionsDisposable.add(links.start(next: { result in
        updateState { current in
            var current = current
            current.links = result?.links.map { $0.stateLink } ?? []
            return current
        }
        
    }))
    
    let editName:(State.Link, ChatCustomLinkContent?)->Void = { link, contents in
        showModal(with: BusinessLinkRenameController(context: context, name: link.name, callback: { updated in
            updateState { current in
                var current = current
                if let index = current.links.firstIndex(where: { $0.link == link.link }) {
                    current.links[index].name = updated
                }
                return current
            }
            
            guard let currentLink = stateValue.with ({ $0.links.first(where: { $0.link == link.link }) }) else {
                return
            }
            contents?.name = currentLink.name ?? ""
            _ = context.engine.accountData.editBusinessChatLink(url: currentLink.link, message: currentLink.text.inputText, entities: currentLink.text.messageTextEntities(), title: currentLink.name).startStandalone()

        }), for: context.window)}
    
    let open:(State.Link)->Void = { link in
        let contents: ChatCustomLinkContent = ChatCustomLinkContent(link: link.link, name: link.name ?? "", text: link.text)

        contents.editName = { [weak contents] in
            editName(stateValue.with { $0.links.first(where: { $0.link == link.link }) } ?? link, contents)
        }
        contents.saveText = { input in
            let currentLink = stateValue.with { $0.links.first(where: { $0.link == link.link }) }
            if let currentLink, currentLink.text != input {
                updateState { current in
                    var current = current
                    if let index = current.links.firstIndex(where: { $0.link == link.link }) {
                        current.links[index].text = .init(inputText: input.inputText, selectionRange: input.inputText.length ..< input.inputText.length, attributes: input.attributes)
                    }
                    return current
                }
                guard let currentLink = stateValue.with ({ $0.links.first(where: { $0.link == link.link }) }) else {
                    return
                }
                _ = context.engine.accountData.editBusinessChatLink(url: currentLink.link, message: currentLink.text.inputText, entities: currentLink.text.messageTextEntities(), title: currentLink.name).startStandalone()
                showModalText(for: context.window, text: strings().businessLinksTooltipSaved)
            }
            
        }
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(context.peerId), mode: .customLink(contents: contents), initialAction: .inputText(text: contents.text, behavior: .automatic)))
    }
    
    let share:(State.Link)->Void = { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link.link)), for: context.window)
    }
    

    let arguments = Arguments(context: context, shareMy: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, add: {
        
        let limit = context.appConfiguration.getGeneralValue("business_chat_links_limit", orElse: 5)
        
        if stateValue.with({$0.links.count < limit}) {
            _ = showModalProgress(signal: context.engine.accountData.createBusinessChatLink(message: "", entities: [], title: nil), for: context.window).startStandalone(next: { result in
                let link = result.stateLink
                updateState { current in
                    var current = current
                    current.links.append(link)
                    return current
                }
                open(link)
            })
        } else {
            showModalText(for: context.window, text: strings().premiumLimitReached)
        }
        
    }, open: open, editName: { link in
        editName(link, nil)
    }, remove: { link in
        verifyAlert(for: context.window, information: strings().businessLinksConfirmRemove, successHandler: { _ in
            updateState { current in
                var current = current
                current.links.removeAll(where: { $0.link == link.link })
                return current
            }
            _ = context.engine.accountData.deleteBusinessChatLink(url: link.link).startStandalone()

        })
    }, share: share, copy: { link in
        copyToClipboard(link.link)
        showModalText(for: context.window, text: strings().shareLinkCopied)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessLinksTitle, removeAfterDisappear: false, hasDone: false, identifier: "business_links")
    
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
    

    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.name), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().businessLinksNamePlaceholder, filter: { $0 }, limit: 32))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessLinksNameInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
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
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessLinksNameTitle)
    
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


