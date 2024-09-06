//
//  PreviewStarGiftController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit
import SwiftSignalKit

private final class PreviewRowItem : GeneralRowItem {
    let context: AccountContext
    let peer: EnginePeer
    let gift: PeerStarGift
    
    let headerLayout: TextViewLayout
    
    let presentation: TelegramPresentationTheme
    let titleLayout: TextViewLayout
    let infoLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, myPeer: EnginePeer, gift: PeerStarGift, message: String?, context: AccountContext, viewType: GeneralViewType) {
        self.context = context
        self.peer = peer
        self.gift = gift
        self.presentation = theme.withUpdatedChatMode(true)
        
        let titleAttr = NSMutableAttributedString()
        
        //TODOLANG
        titleAttr.append(string: "Gift from  \(clown_space)\(myPeer._asPeer().compactDisplayTitle)", color: presentation.chatServiceItemTextColor, font: .medium(.header))
        titleAttr.insertEmbedded(.embeddedAvatar(myPeer), for: clown)
        
        self.titleLayout = TextViewLayout(titleAttr, alignment: .center)
        
        let infoText: String
        
        if let message, !message.isEmpty {
            infoText = message
        } else {
            infoText = "Display this gift on your page or convert it to 500 Stars."
        }
        
        self.infoLayout = .init(.initialize(string: infoText, color: presentation.chatServiceItemTextColor, font: .normal(.text)), alignment: .center)
        
        
        //TODOLANG
        headerLayout = .init(.initialize(string: "\(myPeer._asPeer().compactDisplayTitle) sent you a gift for \(gift.stars) Stars", color: presentation.chatServiceItemTextColor, font: .normal(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var shouldBlurService: Bool {
        return true
    }
    
    var isBubbled: Bool {
        return presentation.bubbled
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        headerLayout.measure(width: blockWidth - 40)
        titleLayout.measure(width: 200 - 20)
        infoLayout.measure(width: 200 - 20)
        
        if shouldBlurService {
            headerLayout.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor.withAlphaComponent(1))
        } else {
            headerLayout.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor)
        }
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PreviewRowView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += 20
        height += headerLayout.layoutSize.height
        height += blockHeight
        height += 20
        return height
    }
    
    var blockHeight: CGFloat {
        var height: CGFloat = 0
        height += 100
        height += 10
        height += titleLayout.layoutSize.height
        height += 2
        height += infoLayout.layoutSize.height
        height += 10
        return height
    }
    
    override var hasBorder: Bool {
        return false
    }
}

private final class PreviewRowView : GeneralContainableRowView {
    private let backgroundView = BackgroundView(frame: .zero)
    private let headerView = TextView()
    
    private final class BlockView : View {
        private let sticker = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 100, 100))
        private let headerView = InteractiveTextView()
        private let textView = TextView()
        private var visualEffect: VisualEffect?
        private var imageView: ImageView?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(sticker)
            addSubview(headerView)
            addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(item: PreviewRowItem, animated: Bool) {
            headerView.set(text: item.titleLayout, context: item.context)
            textView.update(item.infoLayout)
            
            let parameters = ChatAnimatedStickerMediaLayoutParameters(playPolicy: .onceEnd, media: item.gift.media)
            
            sticker.update(with: item.gift.media, size: sticker.frame.size, context: item.context, table: nil, parameters: parameters, animated: animated)
            
            if item.shouldBlurService {
                let current: VisualEffect
                if let view = self.visualEffect {
                    current = view
                } else {
                    current = VisualEffect(frame: bounds)
                    self.visualEffect = current
                    addSubview(current, positioned: .below, relativeTo: self.subviews.first)
                }
                current.bgColor = item.presentation.blurServiceColor
                
                self.backgroundColor = .clear
                
            } else {
                if let view = visualEffect {
                    performSubviewRemoval(view, animated: animated)
                    self.visualEffect = nil
                }
                self.backgroundColor = item.presentation.chatServiceItemColor
            }
            
            if item.gift.limited {
                let current: ImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current)
                    self.imageView = current
                }
                current.image = generateGiftBadgeBackground(size: NSMakeSize(66, 66), text: "1 of 1000", color: item.presentation.chatServiceItemColor, textColor: item.presentation.chatServiceItemTextColor)
                current.sizeToFit()
            } else if let view = self.imageView {
                performSubviewRemoval(view, animated: animated)
                self.imageView = nil
            }
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            sticker.centerX(y: 0)
            visualEffect?.frame = bounds
            imageView?.setFrameOrigin(67 * 2, 0)

            headerView.centerX(y: sticker.frame.maxY + 10)
            textView.centerX(y: headerView.frame.maxY + 2)
        }
    }
    
    private let blockView = BlockView(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(headerView)
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        addSubview(blockView)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PreviewRowItem else {
            return
        }
        
        headerView.update(item.headerLayout)
        blockView.update(item: item, animated: animated)
        backgroundView.backgroundMode = item.presentation.backgroundMode
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PreviewRowItem else {
            return
        }
        
        backgroundView.frame = containerView.bounds
        headerView.centerX(y: 20)
        blockView.frame = containerView.bounds.focusX(NSMakeSize(200, item.blockHeight), y: headerView.frame.maxY)
    }
    
}

private final class Arguments {
    let context: AccountContext
    let toggleAnonymous: ()->Void
    init(context: AccountContext, toggleAnonymous: @escaping()->Void) {
        self.context = context
        self.toggleAnonymous = toggleAnonymous
    }
}

private struct State : Equatable {
    var peer: EnginePeer
    var myPeer: EnginePeer
    var option: PeerStarGift
    var isAnonymous: Bool = false
    var message: String?
}

private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_input = InputDataIdentifier("_id_input")
private let _id_anonymous = InputDataIdentifier("_id_anonymous")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CUSTOMIZE YOUR GIFT"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PreviewRowItem(initialSize, stableId: stableId, peer: state.peer, myPeer: state.myPeer, gift: state.option, message: state.message, context: arguments.context, viewType: .firstItem)
    }))
  
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.message), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .lastItem), placeholder: nil, inputPlaceholder: "Enter Message", filter: { $0 }, limit: 140))
    
    // entries
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_anonymous, data: .init(name: "Hide My Name", color: theme.colors.text, type: .switchable(state.isAnonymous), viewType: .singleItem, action: arguments.toggleAnonymous)))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Hide my name and message from visitors to \(state.peer._asPeer().compactDisplayTitle)'s profile. \(state.peer._asPeer().compactDisplayTitle) will still see your name and message."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PreviewStarGiftController(context: AccountContext, option: PeerStarGift, peer: EnginePeer) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: peer, myPeer: .init(context.myPeer!), option: option)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, toggleAnonymous: {
        updateState { current in
            var current = current
            current.isAnonymous = !current.isAnonymous
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    //TODOLANG
    let controller = InputDataController(dataSignal: signal, title: "Send a Gift")
    
    controller.updateDatas = { datas in
        updateState { current in
            var current = current
            current.message = datas[_id_input]?.stringValue
            return current
        }
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Send a Gift for \(option.stars) Stars", accept: { [weak controller] in
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


/*

 */



