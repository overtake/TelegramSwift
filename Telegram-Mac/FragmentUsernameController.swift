//
//  FragmentUsernameController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var price: Int
    var username: String
    var peer: EnginePeer
}

private final class RowItem : GeneralRowItem {
    let peer: EnginePeer
    let context: AccountContext
    let price: Int
    let username: String
    let headerLayout: TextViewLayout
    let infoLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, context: AccountContext, price: Int, username: String) {
        self.peer = peer
        self.context = context
        self.price = price
        self.username = username
        
        let headerText = "[@\(username)]() is a collectible\nusername that belongs to"
        let attr = parseMarkdownIntoAttributedString(headerText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                
            }))
        }))
        
        let infoText = "The **@lean** username was acquired on\nFragment on 1 Mar 2024 for \(clown)** 6000** (~$15200).\n\n[Copy Link]()"
        let infoAttr = parseMarkdownIntoAttributedString(infoText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.title), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                
            }))
        })).mutableCopy() as! NSMutableAttributedString
                
        infoAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.brilliant_static.file), for: clown)
        infoAttr.detectBoldColorInString(with: .medium(.text))
        
        self.headerLayout = .init(attr, alignment: .center)
        self.headerLayout.measure(width: initialSize.width - 40)
        
        
        self.infoLayout = .init(infoAttr, alignment: .center)
        self.infoLayout.measure(width: initialSize.width - 40)

        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 70
        height += 20
        height += headerLayout.layoutSize.height
        height += 20
        height += 30
        height += 20
        height += infoLayout.layoutSize.height
        return height
    }
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView: GeneralContainableRowView {
    
    private class PeerView : Control {
        private let avatar = AvatarControl(font: .avatar(12))
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatar)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            avatar.setFrameSize(NSMakeSize(30, 30))
            scaleOnClick = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ peer: EnginePeer, context: AccountContext, presentation: TelegramPresentationTheme, maxWidth: CGFloat) {
            self.avatar.setPeer(account: context.account, peer: peer._asPeer())
            
            let layout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: presentation.colors.text, font: .medium(.text)))
            layout.measure(width: maxWidth - 40)
            textView.update(layout)
            self.backgroundColor = presentation.colors.listBackground
            
            self.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + avatar.frame.width + 10, 30))
            
            self.layer?.cornerRadius = frame.height / 2
        }
        
        override func layout() {
            super.layout()
            textView.centerY(x: avatar.frame.maxX + 10)
        }
    }

    private let peerView: PeerView = .init(frame: .zero)
    private let iconView = View(frame: NSMakeRect(0, 0, 70, 70))
    private let stickerView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 60, 60))
    private let headerView = TextView()
    private let infoView = InteractiveTextView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(peerView)
        addSubview(headerView)
        addSubview(iconView)
        addSubview(infoView)
        iconView.addSubview(stickerView)
        headerView.isSelectable = false
        iconView.layer?.cornerRadius = iconView.frame.height / 2
        
        infoView.textView.userInteractionEnabled = true
        infoView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        iconView.centerX(y: 0)
        stickerView.center()
        headerView.centerX(y: stickerView.frame.maxY + 20)
        peerView.centerX(y: headerView.frame.maxY + 20)
        infoView.centerX(y: peerView.frame.maxY + 20)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? RowItem else {
            return
        }
        infoView.set(text: item.infoLayout, context: item.context)
        headerView.update(item.headerLayout)
        peerView.update(item.peer, context: item.context, presentation: theme, maxWidth: item.blockWidth)
        iconView.backgroundColor = theme.colors.accent
        
        stickerView.update(with: LocalAnimatedSticker.fragment_username.file, size: stickerView.frame.size, context: item.context, table: nil, parameters: LocalAnimatedSticker.fragment_username.parameters, animated: animated)
    }
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, stableId: stableId, peer: state.peer, context: arguments.context, price: state.price, username: state.username)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    return entries
}

func FragmentUsernameController(context: AccountContext, peer: EnginePeer, username: String) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(price: 6000, username: "lean", peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    var close:(()->Void)? = nil
    
    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Learn More", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, grayForeground: theme.colors.background, activeBackground: theme.colors.background, listBackground: theme.colors.background)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    return modalController
}


/*

 */


