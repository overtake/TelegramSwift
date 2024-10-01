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
import InputView

private final class PreviewRowItem : GeneralRowItem {
    let context: AccountContext
    let peer: EnginePeer
    let gift: PeerStarGift
    
    let headerLayout: TextViewLayout
    
    let presentation: TelegramPresentationTheme
    let titleLayout: TextViewLayout
    let infoLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, myPeer: EnginePeer, gift: PeerStarGift, message: Updated_ChatTextInputState, context: AccountContext, viewType: GeneralViewType) {
        self.context = context
        self.peer = peer
        self.gift = gift
        self.presentation = theme.withUpdatedChatMode(true)
        
        let titleAttr = NSMutableAttributedString()
        
        titleAttr.append(string: strings().chatServiceStarGiftFrom("\(clown_space)\(myPeer._asPeer().compactDisplayTitle)"), color: presentation.chatServiceItemTextColor, font: .medium(.header))
        titleAttr.insertEmbedded(.embeddedAvatar(myPeer), for: clown)
        
        self.titleLayout = TextViewLayout(titleAttr, alignment: .center)
        
        let infoText = NSMutableAttributedString()
        
        if !message.string.isEmpty {
            let textInputState = message.textInputState()
            let entities = textInputState.messageTextEntities()
            
            let attr = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: message.string, message: nil, context: context, fontSize: 13, openInfo: { _, _, _, _ in }, textColor: presentation.chatServiceItemTextColor, isDark: theme.colors.isDark, bubbled: true).mutableCopy() as! NSMutableAttributedString
            InlineStickerItem.apply(to: attr, associatedMedia: textInputState.inlineMedia, entities: entities, isPremium: context.isPremium)
            infoText.append(attr)
        } else {
            infoText.append(string: strings().starsGiftPreviewDisplay(strings().starListItemCountCountable(Int(gift.native.convertStars))) , color: presentation.chatServiceItemTextColor, font: .normal(.text))
        }
        
        self.infoLayout = .init(infoText, alignment: .center)
        
        
        headerLayout = .init(.initialize(string: strings().chatServicePremiumGiftSent(myPeer._asPeer().compactDisplayTitle, strings().starListItemCountCountable(Int(gift.stars))), color: presentation.chatServiceItemTextColor, font: .normal(.text)), alignment: .center)
        
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
        
//        if shouldBlurService {
//            headerLayout.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor.withAlphaComponent(1))
//        } else {
//            headerLayout.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor)
//        }
//        
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
        height += 15
        height += titleLayout.layoutSize.height
        height += 2
        height += infoLayout.layoutSize.height
        height += 10
        height += 40
        return height
    }
    
    override var hasBorder: Bool {
        return false
    }
}

private final class PreviewRowView : GeneralContainableRowView {
    private let backgroundView = BackgroundView(frame: .zero)
    private let headerView = TextView()
    private let headerVisualEffect: VisualEffect = VisualEffect(frame: .zero)

    private final class BlockView : View {
        private let sticker = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 100, 100))
        private let headerView = InteractiveTextView()
        private let textView = InteractiveTextView()
        private var visualEffect: VisualEffect?
        private var imageView: ImageView?
        
        private let button = TextButton()
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(sticker)
            addSubview(headerView)
            addSubview(textView)
            addSubview(button)
            
            textView.userInteractionEnabled = false
            
            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(item: PreviewRowItem, animated: Bool) {
            headerView.set(text: item.titleLayout, context: item.context)
            textView.set(text: item.infoLayout, context: item.context)
            
            button.userInteractionEnabled = false
            button.set(font: .medium(.text), for: .Normal)
            button.set(color: item.presentation.chatServiceItemTextColor, for: .Normal)
            button.set(background: item.shouldBlurService ? item.presentation.blurServiceColor : item.presentation.chatServiceItemColor, for: .Normal)
            button.set(text: strings().chatServiceGiftView, for: .Normal)
            button.sizeToFit(NSMakeSize(20, 14))
            button.layer?.cornerRadius = button.frame.height / 2
            
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
            
            if let availability = item.gift.native.availability {
                let current: ImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = ImageView()
                    addSubview(current)
                    self.imageView = current
                }
                
                let text: String = strings().starTransactionAvailabilityOf(1, Int(availability.total).prettyNumber)
                let color = item.presentation.chatServiceItemColor
                
                let ribbon = generateGradientTintedImage(image: NSImage(named: "GiftRibbon")?.precomposed(), colors: [color.withMultipliedBrightnessBy(1.1), color.withMultipliedBrightnessBy(0.9)], direction: .diagonal)!
                
                current.image = generateGiftBadgeBackground(background: ribbon, text: text)
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
            if let imageView {
                imageView.setFrameOrigin(frame.width - imageView.frame.width, 0)
            }

            headerView.centerX(y: sticker.frame.maxY + 10)
            textView.centerX(y: headerView.frame.maxY + 2)
            button.centerX(y: textView.frame.maxY + 10)
        }
    }
    
    private let blockView = BlockView(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(headerVisualEffect)
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
        
        headerVisualEffect.bgColor = item.presentation.blurServiceColor
        
        headerView.update(item.headerLayout)
        blockView.update(item: item, animated: animated)
        backgroundView.backgroundMode = item.presentation.backgroundMode
    }
  
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? PreviewRowItem else {
            return
        }
    
        transition.updateFrame(view: backgroundView, frame: containerView.bounds)
        transition.updateFrame(view: headerView, frame: headerView.centerFrameX(y: 15))
        transition.updateFrame(view: headerVisualEffect, frame: headerView.frame.insetBy(dx: -10, dy: -5))
        transition.updateFrame(view: headerVisualEffect, frame: headerView.frame.insetBy(dx: -10, dy: -5))

        headerVisualEffect.layer?.cornerRadius = headerVisualEffect.frame.height / 2
        
        transition.updateFrame(view: blockView, frame: containerView.bounds.focusX(NSMakeSize(200, item.blockHeight), y: headerView.frame.maxY + 15))
        
    }
    
}

private final class Arguments {
    let context: AccountContext
    let toggleAnonymous: ()->Void
    let updateState:(Updated_ChatTextInputState)->Void
    init(context: AccountContext, toggleAnonymous: @escaping()->Void, updateState:@escaping(Updated_ChatTextInputState)->Void) {
        self.context = context
        self.toggleAnonymous = toggleAnonymous
        self.updateState = updateState
    }
}

private struct State : Equatable {
    var peer: EnginePeer
    var myPeer: EnginePeer
    var option: PeerStarGift
    var isAnonymous: Bool = false
    var textState: Updated_ChatTextInputState
    var starsState: StarsContext.State?
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().starsGiftPreviewCustomize), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PreviewRowItem(initialSize, stableId: stableId, peer: state.peer, myPeer: state.myPeer, gift: state.option, message: state.textState, context: arguments.context, viewType: .firstItem)
    }))
    
    
    let maxTextLength: Int32 = arguments.context.appConfiguration.getGeneralValue("stargifts_message_length_max", orElse: 256)
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state.textState), comparable: nil, item: { initialSize, stableId in
        return InputTextDataRowItem(initialSize, stableId: stableId, context: arguments.context, state: state.textState, viewType: .lastItem, placeholder: nil, inputPlaceholder: strings().starsGiftPreviewMessagePlaceholder, filter: { text in
            var text = text
            while text.contains("\n\n\n") {
                text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            }
            
            if !text.isEmpty {
                while text.range(of: "\n")?.lowerBound == text.startIndex {
                    text = String(text[text.index(after: text.startIndex)...])
                }
            }
            return text
        }, updateState: arguments.updateState, limit: maxTextLength, hasEmoji: true)
    }))
    index += 1
    
  
//    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.message), error: nil, identifier: _id_input, mode: .plain, data: .init(viewType: .lastItem), placeholder: nil, inputPlaceholder: "Enter Message", filter: { $0 }, limit: 140))
    
    // entries
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_anonymous, data: .init(name: strings().starsGiftPreviewHideMyName, color: theme.colors.text, type: .switchable(state.isAnonymous), viewType: .singleItem, action: arguments.toggleAnonymous)))
    
    let name = state.peer._asPeer().compactDisplayTitle
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().starsGiftPreviewHideMyNameInfo(name, name)), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PreviewStarGiftController(context: AccountContext, option: PeerStarGift, peer: EnginePeer) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: peer, myPeer: .init(context.myPeer!), option: option, textState: .init())
    
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
    
    actionsDisposable.add(context.starsContext.state.startStrict(next: { state in
        updateState { current in
            var current = current
            current.starsState = state
            return current
        }
    }))

    let arguments = Arguments(context: context, toggleAnonymous: {
        updateState { current in
            var current = current
            current.isAnonymous = !current.isAnonymous
            return current
        }
    }, updateState: { state in
        updateState { current in
            var current = current
            current.textState = state
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().starGiftPreviewTitle)
    
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        
        let state = stateValue.with { $0 }
        
        guard let starsState = state.starsState else {
            return .none
        }
        
        if starsState.balance < state.option.stars {
            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: state.option.stars)), for: window)
            return .none
        }
        
        let source: BotPaymentInvoiceSource = .starGift(hideName: state.isAnonymous, peerId: state.peer.id, giftId: state.option.native.id, text: state.textState.string, entities: state.textState.textInputState().messageTextEntities())
        
        let paymentForm = context.engine.payments.fetchBotPaymentForm(source: source, themeParams: nil) |> mapToSignal {
            return context.engine.payments.sendStarsPaymentForm(formId: $0.id, source: source) |> mapError { _ in
                return .generic
            }
        }
        
        _ = showModalProgress(signal: paymentForm, for: context.window).start(next: { result in
            switch result {
            case let .done(receiptMessageId, _):
                PlayConfetti(for: window, stars: true)
                closeAllModals(window: window)
                context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peer.id)))
            default:
                break
                
            }
        }, error: { error in
            var bp = 0
            bp += 1
        })
        
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().starsGiftPreviewSend(strings().starListItemCountCountable(Int(option.stars))), accept: { [weak controller] in
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



