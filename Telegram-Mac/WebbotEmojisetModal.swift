//
//  WebbotEmojisetModal.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.11.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//


/*
 Со 193 слоя. Показывает пользователю попап с предложением установить эмоджи custom_emoji_id в качестве статуса. Если передано опциональное поле expiration_date, статус будет установлен до этой даты. expiration_date – время в unixtime. Если дата указана некорректно или некорректно указан идентификатор эмоджи, клиент должен вызвать событие emoji_status_failed. Если все параметры верны, пользователю показывается попап с подтверждением. После успешной установки статуса вызывается событие emoji_status_set. Если во время установки произошла ошибка, или пользователь закрыл попап, не установив статус, то нужно отправить событие emoji_status_failed. Если у пользователя нет премиума, предлагается все равно показывать попап с предложением установить статус от бота, а при согласии – показывать экран, что нужен премиум.
 */

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class HeaderItem : GeneralRowItem {
    fileprivate let state: State
    fileprivate let context: AccountContext
    fileprivate let header: TextViewLayout
    fileprivate let info: TextViewLayout
    fileprivate let close: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, state: State, context: AccountContext, close: @escaping()->Void) {
        self.state = state
        self.close = close
        self.context = context
        self.header = .init(.initialize(string: strings().webappSetEmojiHeader, color: theme.colors.text, font: .medium(.header)), alignment: .center)
        self.info = .init(.initialize(string: strings().webappSetEmojiInfo(state.peer._asPeer().displayTitle), color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 20 + 100 + info.layoutSize.height + 5 + header.layoutSize.height + 15 + 20 + 15
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        info.measure(width: width - 40)
        header.measure(width: width - 40)
        
        return true

    }
}

private final class HeaderView: GeneralRowView {
    
    private final class PeerView: Control {
        private let avatarView = AvatarControl(font: .avatar(10))
        private let nameView: TextView = TextView()
        private var stickerView: InlineStickerView?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatarView)
            addSubview(nameView)
            
            nameView.userInteractionEnabled = false
            
            self.avatarView.setFrameSize(NSMakeSize(20, 20))
            
            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(_ peer: EnginePeer, _ context: AccountContext, file: TelegramMediaFile, maxWidth: CGFloat) {
            self.avatarView.setPeer(account: context.account, peer: peer._asPeer())
            
            let nameLayout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
            nameLayout.measure(width: maxWidth)
            
            nameView.update(nameLayout)
            
            if stickerView == nil {
                let current: InlineStickerView = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: file.fileId.id, file: file, emoji: ""), size: NSMakeSize(18, 18))
                addSubview(current)
                self.stickerView = current
            }
            
            setFrameSize(NSMakeSize(avatarView.frame.width + 10 + nameLayout.layoutSize.width + 20 + 10, 20))
            
            self.background = theme.colors.grayForeground
        }
        
        override func layout() {
            super.layout()
            nameView.centerY(x: self.avatarView.frame.maxX + 10)
            stickerView?.centerY(x: self.nameView.frame.maxX + 10)
        }
    }
    
    private var stickerView: InlineStickerView?
    private let textView: TextView = TextView()
    private let infoText: TextView = TextView()
    private let dismiss = ImageButton()
    
    private let peerView: PeerView = .init(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(infoText)
        addSubview(peerView)
        addSubview(dismiss)
        
        textView.userInteractionEnabled = false
        infoText.userInteractionEnabled = false
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
     required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        dismiss.setSingle(handler: {  [weak item] _ in
            item?.close()
        }, for: .Click)
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        peerView.set(.init(item.context.myPeer!), item.context, file: item.state.file, maxWidth: item.width - 40)
        
        infoText.update(item.info)
        textView.update(item.header)
        
        if stickerView == nil {
            let current: InlineStickerView = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: item.state.file.fileId.id, file: item.state.file, emoji: ""), size: NSMakeSize(100, 100))
            addSubview(current)
            self.stickerView = current
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let stickerView {
            stickerView.centerX(y: 20)
            textView.centerX(y: stickerView.frame.maxY)
            infoText.centerX(y: textView.frame.maxY + 5)
            peerView.centerX(y: infoText.frame.maxY + 15)
            dismiss.setFrameOrigin(NSMakePoint(15, 15))
        }
    }
}

private final class Arguments {
    let context: AccountContext
    let close:()->Void
    init(context: AccountContext, close:@escaping()->Void) {
        self.context = context
        self.close = close
    }
}

private struct State : Equatable {
    let peer: EnginePeer
    let file: TelegramMediaFile
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
//  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, state: state, context: arguments.context, close: arguments.close)
    }))
    
    // entries
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}
 enum EmojiSetResultStatus {
    case success
    case fail
}

func WebbotEmojisetModal(context: AccountContext, bot: EnginePeer, file: TelegramMediaFile, expirationDate: Int32?, completed:@escaping(EmojiSetResultStatus)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    var status: EmojiSetResultStatus = .fail
    
    var close:(()->Void)? = nil

    let initialState = State(peer: bot, file: file)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, close: {
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        completed(status)
    }
    
    controller.validateData = { _ in
        
        if context.isPremium {
            let file = stateValue.with { $0.file }
            context.reactions.setStatus(file, peer: context.myPeer!, timestamp: context.timestamp, timeout: expirationDate, fromRect: nil, handleInteractive: false)

            status = .success
            close?()
        } else {
            prem(with: PremiumBoardingController(context: context), for: window)
        }
       
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Confirm", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        return .init(listBackground: theme.colors.background)
    })
    
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



