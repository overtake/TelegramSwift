//
//  StarGift_Nft_Controller.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.12.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore



private final class RowItem : GeneralRowItem {
    
    struct Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        let width: CGFloat
        init(image: CGImage, header: TextViewLayout, text: TextViewLayout, width: CGFloat) {
            self.image = image
            self.header = header
            self.text = text
            self.width = width
            self.header.measure(width: width - 40)
            self.text.measure(width: width - 40)
        }
        var size: NSSize {
            return NSMakeSize(width, header.layoutSize.height + 5 + text.layoutSize.height)
        }
    }
    let context: AccountContext
    
    let options: [Option]
    fileprivate let toggleName: ()->Void
    fileprivate let nameEnabled: Bool
    fileprivate let nameEnabledLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, nameEnabled: Bool, toggleName: @escaping()->Void) {
        self.context = context
        self.toggleName = toggleName
        self.nameEnabled = nameEnabled
        var options:[Option] = []
        
        //TODOLANG
        nameEnabledLayout = .init(.initialize(string: "Add sender's name and comment", color: theme.colors.grayText, font: .normal(.text)))
                
        
        options.append(.init(image: NSImage(resource: .iconStarInfoLock).precomposed(theme.colors.accent), header: .init(.initialize(string:  "Unique", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Get a unique number, model, backdrop and symbol for your gift.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconStarInfoLock).precomposed(theme.colors.accent), header: .init(.initialize(string:  "Transferable", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().starsPromoOption3Info, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        options.append(.init(image: NSImage(resource: .iconStarInfoCash).precomposed(theme.colors.accent), header: .init(.initialize(string:  "Tradable", color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: "Sell or auction your gift on third-party NFT marketplaces.", color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        self.options = options
        
        self.nameEnabledLayout.measure(width: initialSize.width - 80)

        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        for option in options {
            height += option.size.height
            height += 20
        }
        
        height += 20
        
        return height
    }
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView: GeneralContainableRowView {
    
    final class OptionView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let infoView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(titleView)
            addSubview(infoView)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            infoView.isSelectable = false
        }
        
        func update(option: RowItem.Option) {
            self.titleView.update(option.header)
            self.infoView.update(option.text)
            self.imageView.image = option.image
            self.imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            titleView.setFrameOrigin(NSMakePoint(40, 0))
            infoView.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
        }
 
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
        
    private let nameToggle: SelectingControl = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
    private let nameView: TextView = TextView()
    private let nameControl = Control()
    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(optionsView)
        nameControl.addSubview(nameToggle)
        nameControl.addSubview(nameView)
        addSubview(nameControl)
        
        nameToggle.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        
        
        optionsView.centerX(y: 0)
                
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 20
        }
        
        nameControl.frame = NSMakeRect(0, frame.height - 22, nameToggle.frame.width + nameView.frame.width + 10, 22)

        
        nameToggle.setFrameOrigin(NSMakePoint(0, 0))
        nameView.setFrameOrigin(NSMakePoint(nameToggle.frame.maxX + 10, 2))
        
        
        nameControl.centerX()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? RowItem else {
            return
        }
                     
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: .zero))
        }
        
        var optionsSize = NSMakeSize(0, 0)
        for (i, option) in item.options.enumerated() {
            let view = optionsView.subviews[i] as! OptionView
            view.update(option: option)
            view.setFrameSize(option.size)
            optionsSize = NSMakeSize(max(option.width, optionsSize.width), option.size.height + optionsSize.height)
            if i != item.options.count - 1 {
                optionsSize.height += 20
            }
        }
        
        optionsView.setFrameSize(optionsSize)
        
        nameView.update(item.nameEnabledLayout)
        nameToggle.set(selected: item.nameEnabled, animated: animated)
        
        nameControl.setSingle(handler: { [weak item] _ in
            item?.toggleName()
        }, for: .Click)
        needsLayout = true
    }
}




private final class HeaderItem : GeneralRowItem {
    fileprivate let gift: TelegramMediaFile
    fileprivate let context: AccountContext
    fileprivate let title: TextViewLayout
    fileprivate let info: TextViewLayout
    fileprivate let dismiss:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, gift: TelegramMediaFile, context: AccountContext, dismiss: @escaping()->Void) {
        self.gift = gift
        self.dismiss = dismiss
        self.context = context
        
        //TODOLANG
        self.title = .init(.initialize(string: "Upgrade Gift", color: .white, font: .medium(18)))
        self.info = .init(.initialize(string: "Turn your gift into a unique collectible that you can transfer or auction.", color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)), alignment: .center)

        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 40)
        self.info.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        
        height += 30
        height += 100
        height += 20
        
        height += title.layoutSize.height
        height += 5
        height += info.layoutSize.height
        height += 10
        return height
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    
    var backgroundGradient: [NSColor] {
        if let nameColor = context.myPeer?.nameColor {
            let colors = context.peerNameColors.getProfile(nameColor)
            return [colors.main, colors.secondary ?? colors.main].compactMap { $0 }
        } else {
            return [NSColor(0xffffff, 0)]
        }
    }
}

private final class HeaderView : GeneralRowView {
    private let textView = TextView()
    private let infoView = TextView()
    private let dismiss = ImageButton()
    private let giftView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 100, 100))
    private let emoji: PeerInfoSpawnEmojiView = .init(frame: NSMakeRect(0, 0, 180, 180))
    private let backgroundView = PeerInfoBackgroundView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(emoji)
        addSubview(giftView)
        addSubview(textView)
        addSubview(infoView)
        addSubview(dismiss)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = item as? HeaderItem else {
            return
        }
        self.backgroundView.gradient = item.backgroundGradient
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        dismiss.set(image: NSImage(resource: .iconChatSearchCancel).precomposed(.white), for: .Normal)
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.dismiss()
        }, for: .Click)
        
        
        let color: NSColor
        if let nameColor = item.context.myPeer?.nameColor {
            color = item.context.peerNameColors.getProfile(nameColor).main
        } else {
            color = theme.colors.text
        }
        
        emoji.set(fileId: item.context.myPeer!.emojiStatus!.fileId, color: color.withAlphaComponent(0.3), context: item.context, animated: animated)
        
        giftView.update(with: item.gift, size: giftView.frame.size, context: item.context, table: item.table, animated: animated)
                
        textView.update(item.title)
        infoView.update(item.info)
        
        backgroundView.backgroundColor = .blackTransparent

        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        emoji.frame = focus(NSMakeSize(180, 180))
        giftView.centerX(y: 30)
        infoView.centerX(y: frame.height - infoView.frame.height - 10)
        textView.centerX(y: infoView.frame.minY - textView.frame.height - 5)
        backgroundView.frame = bounds
        dismiss.setFrameOrigin(NSMakePoint(10, 10))


    }
}

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let toggleName:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void, toggleName:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.toggleName = toggleName
    }
}

private struct State : Equatable {
    var nameEnabled: Bool = true
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, gift: LocalAnimatedSticker.duck_empty.file, context: arguments.context, dismiss: arguments.dismiss)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("row"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, stableId: stableId, context: arguments.context, nameEnabled: state.nameEnabled, toggleName: arguments.toggleName)
    }))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func StarGift_Nft_Controller(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    var close:(()->Void)? = nil
    
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

    let arguments = Arguments(context: context, dismiss:{
        close?()
    }, toggleName: {
        updateState { current in
            var current = current
            current.nameEnabled = !current.nameEnabled
            return current
        }
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
    }

    let modalInteractions = ModalInteractions(acceptTitle: "PAY", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    modalController._hasBorder = false
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}



