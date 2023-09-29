//
//  GiftLinkModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 26.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



private final class GiftLinkStarRowItem : GeneralRowItem {
    
    init(_ initialSize: NSSize, stableId: AnyHashable) {
        super.init(initialSize, height: 100, stableId: stableId)
    }
    override func viewClass() -> AnyClass {
        return GiftLinkStarRowView.self
    }
}

private final class GiftLinkStarRowView : TableRowView {
    private let scene: PremiumStarSceneView = PremiumStarSceneView(frame: NSMakeRect(0, 0, 300, 150))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scene)
        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        
        self.layer?.masksToBounds = false
    }
    
    override func layout() {
        super.layout()
        scene.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
}



private final class Arguments {
    let context: AccountContext
    let copyLink:(String)->Void
    let execute:(String)->Void
    init(context: AccountContext, copyLink:@escaping(String)->Void, execute:@escaping(String)->Void) {
        self.context = context
        self.copyLink = copyLink
        self.execute = execute
    }
}

private struct State : Equatable {
    var info: PremiumGiftCodeInfo
    var fromPeer: PeerEquatable?
    var toPeer: PeerEquatable?
    
    
    func canUse(_ accountPeerId: PeerId) -> Bool {
        if info.usedDate == nil {
            if info.toPeerId == nil || accountPeerId == info.toPeerId {
                return true
            }
        }
        return false
    }
    var link: String {
        return "t.me/giftcode/\(info.slug)"
    }
    
    func rows(_ arguments: Arguments) -> [InputDataTableBasedItem.Row] {
        var rows: [InputDataTableBasedItem.Row] = []
        
        
        
       
        
       
        
        if let fromPeer = fromPeer?.peer {
            
            let from: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(fromPeer.displayTitle)](\(fromPeer.id.toInt64()))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), alwaysStaticItems: true)
            
            from.interactions.processURL = { inapplink in
                if let inapplink = inapplink as? String {
                    arguments.execute(inapplink)
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: "From", color: theme.colors.text, font: .normal(.text))), right: .init(name: from, leftView: { previous in
                let control: AvatarControl
                if let previous = previous as? AvatarControl {
                    control = previous
                } else {
                    control = AvatarControl(font: .avatar(6))
                }
                control.setFrameSize(NSMakeSize(20, 20))
                control.setPeer(account: arguments.context.account, peer: fromPeer)
                return control
            })))
        }
        
        
        if let toPeer = self.toPeer?.peer {
            let to: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(toPeer.displayTitle)](\(toPeer.id.toInt64()))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), alwaysStaticItems: true)
            
            
            to.interactions.processURL = { inapplink in
                if let inapplink = inapplink as? String {
                    arguments.execute(inapplink)
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: "To", color: theme.colors.text, font: .normal(.text))), right: .init(name: to, leftView: { previous in
                let control: AvatarControl
                if let previous = previous as? AvatarControl {
                    control = previous
                } else {
                    control = AvatarControl(font: .avatar(6))
                }
                control.setFrameSize(NSMakeSize(20, 20))
                control.setPeer(account: arguments.context.account, peer: toPeer)
                return control
            })))
        }
        
        let duration: String = info.months == 12 ? "Telegram Premium 1 Year" : "Telegram Premium for \(info.months) months"

        rows.append(.init(left: .init(.initialize(string: "Gift", color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: duration, color: theme.colors.text, font: .normal(.text)), alwaysStaticItems: true), leftView: nil)))

        let reasonText: String
        if info.isGiveaway {
            reasonText = "Giveaway"
        } else {
            reasonText = "Gift"
        }
        
        rows.append(.init(left: .init(.initialize(string: "Reason", color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: reasonText, color: theme.colors.text, font: .normal(.text)), alwaysStaticItems: true), leftView: nil)))

        rows.append(.init(left: .init(.initialize(string: "Date", color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: info.date), color: theme.colors.text, font: .normal(.text)), alwaysStaticItems: true), leftView: nil)))

        
        return rows
    }
}

private let _id_star = InputDataIdentifier("_id_star")
private let _id_rows = InputDataIdentifier("_id_rows")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_star, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GiftLinkStarRowItem(initialSize, stableId: stableId)
    }))
    index += 1
    
    let headerText: String
    if state.info.usedDate == nil {
        headerText = "This link allows you to activate a **Telegram Premium** subscription."
    } else {
        headerText = "This link was used to activate a **Telegram Premium** subscription."
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(headerText), data: .init(color: theme.colors.text, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("link"), equatable: InputDataEquatable(state.link), comparable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: state.link, font: .normal(.text), insets: NSEdgeInsets(left: 20, right: 20), rightAction: .init(image: theme.icons.fast_copy_link, action: {
            arguments.copyLink(state.link)
        }), singleLine: true)
    }))
    index += 1
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_rows, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return InputDataTableBasedItem(initialSize, stableId: stableId, viewType: .singleItem, rows: state.rows(arguments))
    }))
    index += 1
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    if let usedDate = state.info.usedDate {
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("This link was used on \(stringForFullDate(timestamp: usedDate)).", linkHandler:arguments.execute), data: .init(color: theme.colors.text, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
        index += 1
    } else {
        if state.toPeer?.peer == nil {
            entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("You can also send this [link](share) to a friend as a gift.", linkHandler:arguments.execute), data: .init(color: theme.colors.text, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
            index += 1
        }
    }
    
    
    return entries
}

func GiftLinkModalController(context: AccountContext, info: PremiumGiftCodeInfo) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(info: info)
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, copyLink: { link in
        showModalText(for: context.window, text: strings().shareLinkCopied)
        copyToClipboard(link)
    }, execute: { link in
        if link == "share" {
            showModal(with: ShareModalController(ShareLinkObject(context, link: stateValue.with { $0.link })), for: context.window)
        } else if let id = Int64(link) {
            let peerId = PeerId(id)
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
            close?()
        }
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Gift Link")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Use Link", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone({ button in
            let canUse = stateValue.with { $0.canUse(context.peerId) }
            let text: String
            if canUse {
                text = "Use Link"
            } else {
                text = strings().modalOK
            }
            button.set(text: text, for: .Normal)
        })
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    controller.validateData = { _ in
        let canUse = stateValue.with { $0.canUse(context.peerId) }
        if canUse {
            _ = context.engine.payments.applyPremiumGiftCode(slug: info.slug).start()
            PlayConfetti(for: context.window)
            showModalText(for: context.window, text: "You successfully activated gift link.")
            close?()
        } else {
            close?()
        }
        return .none
    }
   
    
    getController = { [weak controller] in
        return controller
    }
    
    let fromPeer: Signal<TelegramEngine.EngineData.Item.Peer.Peer.Result, NoError> = context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: info.fromPeerId)
    )
    let toPeer: Signal<TelegramEngine.EngineData.Item.Peer.Peer.Result, NoError>
    
    if let toPeerId = info.toPeerId {
        toPeer = context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: toPeerId)
        )
    } else {
        toPeer = .single(Optional(nil))
    }
    
    actionsDisposable.add(combineLatest(toPeer, fromPeer).start(next: { toPeer, fromPeer in
        updateState { current in
            var current = current
            current.fromPeer = .init(fromPeer?._asPeer())
            current.toPeer = .init(toPeer?._asPeer())
            return current
        }
    }))
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*
 
 */



