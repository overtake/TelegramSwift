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
import Postbox

final class TransferUniqueGiftHeaderItem : GeneralRowItem {
    fileprivate let gift: StarGift.UniqueGift
    fileprivate let toPeer: EnginePeer
    fileprivate let context: AccountContext
    fileprivate let layout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, gift: StarGift.UniqueGift, toPeer: EnginePeer, context: AccountContext) {
        self.gift = gift
        self.toPeer = toPeer
        self.context = context
        self.layout = TextViewLayout(.initialize(string: strings().giftTransferConfirmationTitle, color: theme.colors.text, font: .medium(.title)))
        layout.measure(width: .greatestFiniteMagnitude)
        super.init(initialSize, height: 120, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return TransferHeaderView.self
    }
}

private final class TransferHeaderView : GeneralRowView {
    private let avatar = AvatarControl(font: .avatar(18))
    private let giftView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 70, 70))
    private let chevron: ImageView = ImageView()
    private let container = View()
    private let textView = TextView()
    
    private let transferContainer = View()
    
    private let emoji: PeerInfoSpawnEmojiView = .init(frame: NSMakeRect(0, 0, 180, 180))
    private let backgroundView = PeerInfoBackgroundView(frame: .zero)

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        transferContainer.addSubview(backgroundView)
        transferContainer.addSubview(emoji)
        transferContainer.addSubview(giftView)
        
        transferContainer.backgroundColor = .random
        
        transferContainer.layer?.cornerRadius = 10
        transferContainer.setFrameSize(NSMakeSize(70, 70))
        
        container.addSubview(transferContainer)
        container.addSubview(chevron)
        container.addSubview(avatar)

        addSubview(textView)
        
        chevron.image = NSImage(resource: .iconAffiliateChevron).precomposed(theme.colors.grayIcon.withAlphaComponent(0.8))
        chevron.sizeToFit()
        giftView.setFrameSize(NSMakeSize(60, 60))
        avatar.setFrameSize(NSMakeSize(70, 70))
        addSubview(container)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? TransferUniqueGiftHeaderItem else {
            return
        }
        
        textView.update(item.layout)
        
        container.setFrameSize(NSMakeSize(transferContainer.frame.width + avatar.frame.width + 45, 70))
        avatar.setPeer(account: item.context.account, peer: item.toPeer._asPeer())
        giftView.update(with: item.gift.file!, size: giftView.frame.size, context: item.context, table: item.table, animated: animated)
        
        emoji.set(fileId: item.gift.pattern!.fileId.id, color: item.gift.patternColor!.withAlphaComponent(0.3), context: item.context, animated: animated)
        
        self.backgroundView.gradient = item.gift.backdrop!
        
    }
    
    override func layout() {
        super.layout()
        container.centerX(y: 15)
        transferContainer.centerY(x: 0)
        avatar.centerY(x: container.frame.width - avatar.frame.width)
        
        self.backgroundView.frame = transferContainer.bounds
        self.emoji.frame = transferContainer.bounds
        
        chevron.center()
        chevron.setFrameOrigin(NSMakePoint(chevron.frame.minX + 5, chevron.frame.minY))
        textView.centerX(y: frame.height - textView.frame.height)
    }
}

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
    fileprivate var nameEnabledLayout: TextViewLayout?
    fileprivate let isPreview: Bool
    
    fileprivate let transaction: StarsContext.State.Transaction?
    
    
    let hasToggle: Bool
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: StarsContext.State.Transaction?, nameEnabled: Bool, isPreview: Bool, toggleName: @escaping()->Void) {
        self.context = context
        self.toggleName = toggleName
        self.isPreview = isPreview
        self.nameEnabled = nameEnabled
        self.transaction = transaction
        var options:[Option] = []
        
        
        var hasToggle: Bool {
            if isPreview {
                return false
            } else if let _ = transaction {
                return true
            }
            return true
        }
        
        self.hasToggle = hasToggle
        
        if hasToggle {
            nameEnabledLayout = .init(.initialize(string: transaction?.title == nil || transaction?.title?.isEmpty == true ? strings().giftUpgradeAddName : strings().giftUpgradeAddNameAndComment, color: theme.colors.grayText, font: .normal(.text)))
        } else {
            nameEnabledLayout = nil
        }
                
        
        options.append(.init(image: NSImage(resource: .iconNFTUnique).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().giftUpgradeUniqueTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: isPreview ? strings().giftUpgradeUniqueIncludeDescription : strings().giftUpgradeUniqueDescription, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconNFTTransferable).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().giftUpgradeTransferableTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: isPreview ? strings().giftUpgradeTransferableIncludeDescription : strings().giftUpgradeTransferableDescription, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        options.append(.init(image: NSImage(resource: .iconNFTTradable).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().giftUpgradeTradableTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: isPreview ? strings().giftUpgradeUniqueIncludeDescription : strings().giftUpgradeUniqueDescription, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        self.options = options
        
        self.nameEnabledLayout?.measure(width: initialSize.width - 80)

        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        for option in options {
            height += option.size.height
            height += 20
        }
        
        if hasToggle {
            height += 20
        }
        
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
        return theme.colors.background
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
        
        nameControl.isHidden = item.isPreview
        
        nameView.update(item.nameEnabledLayout)
        nameToggle.set(selected: item.nameEnabled, animated: animated)
        
        nameControl.setSingle(handler: { [weak item] _ in
            item?.toggleName()
        }, for: .Click)
        needsLayout = true
    }
    
}




private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let title: TextViewLayout
    fileprivate let info: TextViewLayout
    fileprivate let dismiss:()->Void
    fileprivate let attributes: [StarGift.UniqueGift.Attribute]
    
    fileprivate var patterns:[TelegramMediaFile] = []
    fileprivate var backdrops:[StarGift.UniqueGift.Attribute] = []
    fileprivate var models:[StarGift.UniqueGift.Attribute] = []

    private var patternIndex: Int = 0
    private var backdropIndex: Int = 0
    private var modelIndex: Int = 0
    
    private let converted: Bool
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, dismiss: @escaping()->Void, state: State, attributes: [StarGift.UniqueGift.Attribute], source: StarGiftNftSource) {
        self.dismiss = dismiss
        self.context = context
        self.attributes = attributes
        self.converted = state.converted
        
        self.patterns = attributes.compactMap { attribute in
            switch attribute {
            case let .pattern(_, file, _):
                return file
            default:
                return nil
            }
        }
        
        self.backdrops = attributes.compactMap { attribute in
            switch attribute {
            case .backdrop:
                return attribute
            default:
                return nil
            }
        }
        
        self.models = attributes.compactMap { attribute in
            switch attribute {
            case .model:
                return attribute
            default:
                return nil
            }
        }
        
        self.title = .init(.initialize(string: state.headerTitle, color: .white, font: .medium(18)))
        self.info = .init(.initialize(string: state.headerInfo, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)), alignment: .center)

        for model in models {
            switch model {
            case let .model(_, file, _):
                _ = freeMediaFileInteractiveFetched(context: context, fileReference: .standalone(media: file)).start()
            default:
                break
            }
        }
        
        
        super.init(initialSize, stableId: stableId)
    }
    
    func makeNextPattern() {
        if !converted {
            patternIndex = Int.random(in: 0..<patterns.count)
            backdropIndex = Int.random(in: 0..<backdrops.count)
            modelIndex = Int.random(in: 0..<models.count)
        }
        
    }
    
    var model: TelegramMediaFile {
        switch self.models[self.modelIndex] {
        case let .model(_, file, _):
            return file
        default:
            fatalError()
        }
    }
    var pattern: TelegramMediaFile {
        return self.patterns[self.patternIndex]
    }
    
    var patternColor: NSColor {
        let value = self.backdrops[self.backdropIndex]
        switch value {
        case let .backdrop(_, _, _, patternColor, _, _):
            return NSColor.init(UInt32(patternColor))
        default:
            fatalError()
        }
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
        switch self.backdrops[self.backdropIndex] {
        case let .backdrop(_, inner, outer, _, _, _):
            return [NSColor(UInt32(inner)), NSColor(UInt32(outer))]
        default:
            fatalError()
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
    
    private var timer: SwiftSignalKit.Timer?
    
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
        
        
        let update:()->Void = { [weak self] in
            guard let self else {
                return
            }
            self.emoji.set(fileId: item.pattern.fileId.id, color: item.patternColor.withAlphaComponent(0.3), context: item.context, animated: animated)
            self.backgroundView.gradient = item.backgroundGradient
            self.giftView.update(with: item.model, size: giftView.frame.size, context: item.context, table: item.table, animated: animated)
        }
        
        self.timer = .init(timeout: 2.5, repeat: true, completion: {
            item.makeNextPattern()
            update()
        }, queue: .mainQueue())
        
        self.timer?.start()
        update()
        
                
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
    let transfer:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void, toggleName:@escaping()->Void, transfer:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.toggleName = toggleName
        self.transfer = transfer
    }
}

private struct State : Equatable {
    var source: StarGiftNftSource
    var gift: StarGift
    var transaction: StarsContext.State.Transaction?
    var nameEnabled: Bool = true
    var converted: Bool = false
    var convertedGift: ProfileGiftsContext.State.StarGift?
    var upgradeForm: BotPaymentForm?
    
    var attributes: [StarGift.UniqueGift.Attribute]
    
    var starsState: StarsContext.State?

    
    var okText: String {
        switch source {
        case .preview:
            return strings().modalOK
        case .upgrade:
            if converted {
                return strings().modalOK
            } else {
                if upgradeForm == nil {
                    return strings().giftUpgradeConfirm
                } else if let upgradeStars = gift.generic?.upgradeStars {
                    return strings().giftUpgradePay(strings().starListItemCountCountable(Int(upgradeStars)))
                } else {
                    return strings().modalOK
                }
            }
        }
    }
    
    var headerTitle: String {
        switch source {
        case .preview:
            return strings().giftUpgradeIncludeTitle
        default:
            if let unique = gift.unique {
                return unique.title
            } else {
                return strings().giftUpgradeTitle
            }
        }
    }
    var headerInfo: String {
        switch source {
        case .preview(let peer, _):
            return strings().giftUpgradeIncludeDescription(peer._asPeer().displayTitle)
        default:
            if let unique = gift.unique {
                return strings().starTransactionGiftCollectible("#\(unique.number)")
            } else {
                return strings().giftUpgradeDescription
            }
        }
    }
    
    var closeOnOk: Bool {
        switch source {
        case .preview:
            return true
        default:
            return converted
        }
    }
    
    var isPreview: Bool {
        switch source {
        case .preview:
            return true
        default:
            return false
        }
    }
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, dismiss: arguments.dismiss, state: state, attributes: state.attributes, source: state.source)
    }))
    
    entries.append(.sectionId(sectionId, type: .legacy))
    sectionId += 1
            
    if state.converted {
        var rows: [InputDataTableBasedItem.Row] = []
        
        let myPeer = arguments.context.myPeer!
        
        let ownerText: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(myPeer.displayTitle)]()", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })), maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        ownerText.interactions.processURL = { url in
            if let url = url as? String {
               
            }
        }
        
        rows.append(.init(left: .init(.initialize(string: strings().giftUniqueOwner, color: theme.colors.text, font: .normal(.text))), right: .init(name: ownerText, leftView: { previous in
            let control: AvatarControl
            if let previous = previous as? AvatarControl {
                control = previous
            } else {
                control = AvatarControl(font: .avatar(6))
            }
            control.setFrameSize(NSMakeSize(20, 20))
            control.setPeer(account: arguments.context.account, peer: myPeer)
            return control
        }, badge: .init(text: strings().giftUniqueTransfer, callback: arguments.transfer))))
        
        switch state.gift {
        case let .unique(gift):
            for attr in gift.attributes {
                switch attr {
                case .model(let name, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueModel, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 100).string)%", callback: {}))))
                case .pattern(let name, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueSymbol, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 100).string)%", callback: {}))))
                case .backdrop(let name, _, _, _, _, let rarity):
                    rows.append(.init(left: .init(.initialize(string: strings().giftUniqueBackdrop, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 100).string)%", callback: {}))))
                default:
                    break
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionAvailability, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: strings().starTransactionGiftUpgradeIssued(Int(gift.availability.issued).formattedWithSeparator, Int(gift.availability.total).formattedWithSeparator), color: theme.colors.text, font: .normal(.text))))))

            
        default:
            break
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("attributes"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return InputDataTableBasedItem(initialSize, stableId: stableId, viewType: .singleItem, rows: rows, context: arguments.context)
        }))
        
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("row"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return RowItem(initialSize, stableId: stableId, context: arguments.context, transaction: state.transaction, nameEnabled: state.nameEnabled, isPreview: state.isPreview, toggleName: arguments.toggleName)
        }))
        
        // entries
        
        entries.append(.sectionId(sectionId, type: .legacy))
        sectionId += 1
    }
    
    
    return entries
}

enum StarGiftNftSource : Equatable {
    case preview(EnginePeer, [StarGift.UniqueGift.Attribute])
    case upgrade(EnginePeer, [StarGift.UniqueGift.Attribute], MessageId)
    
    var attributes: [StarGift.UniqueGift.Attribute] {
        switch self {
        case let .preview(_, attributes):
            return attributes
        case let .upgrade(_, attributes, _):
            return attributes
        }
    }
}

func StarGift_Nft_Controller(context: AccountContext, gift: StarGift, source: StarGiftNftSource, transaction: StarsContext.State.Transaction? = nil) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    let initialState = State(source: source, gift: gift, transaction: transaction, attributes: source.attributes)
    
    var close:(()->Void)? = nil
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    actionsDisposable.add(context.starsContext.state.startStrict(next: { state in
        updateState { current in
            var current = current
            current.starsState = state
            return current
        }
    }))
    
    
    switch source {
    case let .upgrade(_, _, messageId):
        actionsDisposable.add(context.engine.payments.fetchBotPaymentForm(source: .starGiftUpgrade(keepOriginalInfo: false, messageId: messageId), themeParams: nil).start(next: { form in
            updateState { current in
                var current = current
                current.upgradeForm = form
                return current
            }
        }, error: { _ in
            
        }))
    default:
        break
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
    }, transfer: {
        
        let state = stateValue.with { $0 }
        
        var additionalItem: SelectPeers_AdditionTopItem?
        
        
        if let convertedGift = state.convertedGift, let canExportDate = convertedGift.canExportDate {
            additionalItem = .init(title: strings().giftTransferSendViaBlockchain, color: theme.colors.text, icon: NSImage(resource: .iconSendViaTon).precomposed(), callback: {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                if currentTime > canExportDate {
                    showModalText(for: window, text: strings().updateAppUpdateTelegram)
                } else {
                    let delta = canExportDate - currentTime
                    let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                    alert(for: window, header: strings().giftTransferUnlockPendingTitle, info: strings().giftTransferUnlockPendingText(strings().timerDaysCountable(Int(days))))
                }
            })
        }
        
        _ = selectModalPeers(window: window, context: context, title: strings().giftTransferTitle, behavior: SelectChatsBehavior(settings: [.excludeBots, .contacts, .remote], limit: 1, additionTopItem: additionalItem)).start(next: { peerIds in
            if let peerId = peerIds.first {
                let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
                
                _ = peer.startStandalone(next: { peer in
                    if let peer {
                                                
                        let info: String
                        let ok: String
                        
                        guard let convertedGift = state.convertedGift, let messageId = convertedGift.messageId, let unique = convertedGift.gift.unique else {
                            return
                        }
                        
                        if let convertStars = convertedGift.convertStars, let starsState = state.starsState, starsState.balance.value < convertStars {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: convertStars)), for: window)
                            return
                        }
                        
                        if let stars = convertedGift.convertStars, stars > 0 {
                            info = strings().giftTransferConfirmationText("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(stars)))
                            ok = strings().giftTransferConfirmationTransfer + " " + strings().starListItemCountCountable(Int(stars))
                        } else {
                            info = strings().giftTransferConfirmationTextFree("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle)
                            ok = strings().giftTransferConfirmationTransferFree
                        }
                
                        let data = ModalAlertData(title: nil, info: info, description: nil, ok: ok, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                            return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: peer, context: context)
                        }))
                        
                        showModalAlert(for: window, data: data, completion: { result in
                            _ = context.engine.payments.transferStarGift(prepaid: convertedGift.convertStars == nil, messageId: messageId, peerId: peerId).startStandalone()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                            close?()
                            context.bindings.rootNavigation().push(ChatController.init(context: context, chatLocation: .peer(messageId.peerId)))
                        })
                    }
                })
            }
            
        })
                                
      
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        
        let state = stateValue.with { $0 }
        let closeOnOk = stateValue.with { $0.closeOnOk }
        
        guard let starsState = state.starsState else {
            return .none
        }
        
        switch source {
        case .preview:
            close?()
        case let .upgrade(_, _, messageId):
            
            if let upgradeStars = gift.generic?.upgradeStars, starsState.balance.value < upgradeStars {
                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: upgradeStars)), for: window)
                return .none
            }
            
            let signal = context.engine.payments.upgradeStarGift(formId: state.upgradeForm?.id, messageId: messageId, keepOriginalInfo: state.nameEnabled) |> deliverOnMainQueue
            
            _ = showModalProgress(signal: signal, for: window).startStandalone(next: { converted in
                updateState { current in
                    var current = current
                    current.gift = converted.gift
                    current.convertedGift = converted
                    current.converted = true
                    switch converted.gift {
                    case let .unique(gift):
                        current.attributes = gift.attributes
                    default:
                        break
                    }
                    return current
                }
                PlayConfetti(for: window)
            }, error: { error in
                switch error {
                case .generic:
                    showModalText(for: window, text: strings().unknownError)
                }
            })
        }
       
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle:  "", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, listBackground: theme.colors.background)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    modalController._hasBorder = false
    

    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone { button in
            let converted = stateValue.with({ $0.converted })
            button.set(text: stateValue.with { $0.okText }, for: .Normal)
        }
    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}



