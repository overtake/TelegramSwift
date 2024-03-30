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
import CurrencyFormat

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
    }
}

private struct State : Equatable {
    var data: FragmentItemInfoScreenInitialData
}

private final class RowItem : GeneralRowItem {
    let context: AccountContext
    let peer: EnginePeer
    let headerLayout: TextViewLayout
    let infoLayout: TextViewLayout
    let dismiss:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, context: AccountContext, info: TelegramCollectibleItemInfo, dismiss:@escaping()->Void) {
        self.peer = peer
        self.context = context
        self.dismiss = dismiss
        let headerText: String
        switch info.subject {
        case let .phoneNumber(phoneNumber):
            headerText = strings().collectibleItemInfoPhoneTitle(formatPhoneNumber(phoneNumber))
        case let .username(username):
            headerText = strings().collectibleItemInfoUsernameTitle("@\(username)")
        }
        
        let copySubject:(String)->Void = { _ in
            switch info.subject {
            case let .phoneNumber(phoneNumber):
                copyToClipboard(formatPhoneNumber(phoneNumber))
            case let .username(username):
                copyToClipboard("@\(username)")
            }
            showModalText(for: context.window, text: strings().shareLinkCopied)
        }
         
        let attr = parseMarkdownIntoAttributedString(headerText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", copySubject))
        }))
        
        let cryptoFormatted = formatCurrencyAmount(info.cryptoCurrencyAmount, currency: info.cryptoCurrency).prettyCurrencyNumber
        let currencyFormatted = formatCurrencyAmount(info.currencyAmount, currency: info.currency).prettyCurrencyNumber
        let date = stringForMediumDate(timestamp: info.purchaseDate)
        let infoText: String
        switch info.subject {
        case .username(let string):
            infoText = strings().collectibleItemInfoUsernameText(string, date, clown, cryptoFormatted, currencyFormatted)
        case .phoneNumber(let string):
            infoText = strings().collectibleItemInfoPhoneText(formatPhoneNumber(string), date, clown, cryptoFormatted, currencyFormatted)
        }
        let infoAttr = parseMarkdownIntoAttributedString(infoText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.title), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", copySubject))
        })).mutableCopy() as! NSMutableAttributedString
                
        infoAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.brilliant_static.file), for: clown)
        infoAttr.detectBoldColorInString(with: .medium(.text))
        
        self.headerLayout = .init(attr, alignment: .center)
        self.headerLayout.measure(width: initialSize.width - 40)
        
        
        self.infoLayout = .init(infoAttr, alignment: .center)
        self.infoLayout.measure(width: initialSize.width - 40)

        self.headerLayout.interactions = globalLinkExecutor
        self.infoLayout.interactions = globalLinkExecutor
        
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
    
    private let dismiss = ImageButton()

    
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
        
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        containerView.superview?.addSubview(dismiss)
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? RowItem {
                item.dismiss()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(0, 0))
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
        
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        
        stickerView.update(with: LocalAnimatedSticker.fragment.file, size: stickerView.frame.size, context: item.context, table: nil, parameters: LocalAnimatedSticker.fragment.parameters, animated: animated)
        
        needsLayout = true
    }
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let peer = state.data.peer {
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return RowItem(initialSize, stableId: stableId, peer: peer, context: arguments.context, info: state.data.collectibleItemInfo, dismiss: arguments.dismiss)
        }))
        
    }
  
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1

    
    return entries
}

func FragmentUsernameController(context: AccountContext, data: FragmentItemInfoScreenInitialData) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: data)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    var close:(()->Void)? = nil
    
    let arguments = Arguments(context: context, dismiss: {
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
    
        execute(inapp: .external(link: data.collectibleItemInfo.url, false))
        
        return .success(.custom({
            close?()
        }))
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().collectibleItemInfoButtonOpenInfo, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, grayForeground: theme.colors.background, activeBackground: theme.colors.background, listBackground: theme.colors.background)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    

    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    return modalController
}


enum FragmentItemInfoScreenSubject {
    case phoneNumber(String)
    case username(String)
}



struct FragmentItemInfoScreenInitialData : Equatable {
    
    fileprivate enum ResolvedSubject : Equatable {
        struct Username : Equatable {
            var username: String
            var info: TelegramCollectibleItemInfo
            
            init(username: String, info: TelegramCollectibleItemInfo) {
                self.username = username
                self.info = info
            }
        }
        
        struct PhoneNumber : Equatable {
            var phoneNumber: String
            var info: TelegramCollectibleItemInfo
            
            init(phoneNumber: String, info: TelegramCollectibleItemInfo) {
                self.phoneNumber = phoneNumber
                self.info = info
            }
        }
        
        case username(Username)
        case phoneNumber(PhoneNumber)
    }
       

    
    fileprivate let peer: EnginePeer?
    fileprivate let subject: ResolvedSubject

    fileprivate init(peer: EnginePeer?, subject: ResolvedSubject) {
        self.peer = peer
        self.subject = subject
    }
    
    public var collectibleItemInfo: TelegramCollectibleItemInfo {
        switch self.subject {
        case let .username(username):
            return username.info
        case let .phoneNumber(phoneNumber):
            return phoneNumber.info
        }
    }
}


func FragmentItemInitialData(context: AccountContext, peerId: EnginePeer.Id, subject: FragmentItemInfoScreenSubject) -> Signal<FragmentItemInfoScreenInitialData?, NoError> {
    switch subject {
    case let .username(username):
        return combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            ),
            context.engine.peers.getCollectibleUsernameInfo(username: username)
        )
        |> map { peer, result -> FragmentItemInfoScreenInitialData? in
            guard let result else {
                return nil
            }
            return FragmentItemInfoScreenInitialData(peer: peer, subject: .username(FragmentItemInfoScreenInitialData.ResolvedSubject.Username(
                username: username,
                info: result
            )))
        }
    case let .phoneNumber(phoneNumber):
        return combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            ),
            context.engine.peers.getCollectiblePhoneNumberInfo(phoneNumber: phoneNumber)
        )
        |> map { peer, result -> FragmentItemInfoScreenInitialData? in
            guard let result else {
                return nil
            }
            return FragmentItemInfoScreenInitialData(peer: peer, subject: .phoneNumber(FragmentItemInfoScreenInitialData.ResolvedSubject.PhoneNumber(
                phoneNumber: phoneNumber,
                info: result
            )))
        }
    }
}
