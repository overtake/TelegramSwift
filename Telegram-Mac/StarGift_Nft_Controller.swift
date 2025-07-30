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
import InputView


extension StarGift.UniqueGift {
    func resellStars(_ context: AccountContext) -> CurrencyAmount? {
        let value = self.resellAmounts?.first(where: { value in
            if value.currency == .stars {
               return true
            } else {
                return false
            }
        })
        
        if let value {
            return value
        } else if let ton = self.resellAmounts?.first(where: { $0.currency == .ton}) {
            let usd_rate = context.appConfiguration.getGeneralValueDouble("ton_usd_rate", orElse: 3)
            let tons = Double(ton.amount.value) / 1_000_000_000
            let usdAmount = tons * usd_rate
            return .init(amount: .init(value: Int64(usdAmount / 0.013), nanos: 0), currency: .stars)
        } else {
            return nil
        }
    }
    
    var resell: CurrencyAmount? {
        return self.resellAmounts?.first(where: { value in
            if value.currency == (resellForTonOnly ? .ton : .stars) {
               return true
            } else {
                return false
            }
        })
    }
    
    func resell(_ currency: CurrencyAmount.Currency) -> CurrencyAmount? {
        return self.resellAmounts?.first(where: { value in
            if value.currency == currency {
               return true
            } else {
                return false
            }
        })
    }
}

final class TransferUniqueGiftHeaderItem : GeneralRowItem {
    enum TransferType : Equatable {
        case buy(onlyTon: Bool)
        case transfer
    }
    fileprivate let transferType: TransferType
    fileprivate let gift: StarGift.UniqueGift
    fileprivate let toPeer: EnginePeer
    fileprivate let context: AccountContext
    fileprivate let layout: TextViewLayout
    
    fileprivate let onlyTonLayout: TextViewLayout?
    
    fileprivate let buyForStars: TextViewLayout?
    fileprivate let buyForTon: TextViewLayout?
    
    fileprivate var buyForSelected: CurrencyAmount.Currency = .stars
    fileprivate let callback: (CurrencyAmount.Currency)->Void
    
    func toggleBuySelected() {
        switch buyForSelected {
        case .stars:
            buyForSelected = .ton
        case .ton:
            buyForSelected = .stars
        }
        callback(buyForSelected)
        self.redraw(animated: true)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable, gift: StarGift.UniqueGift, toPeer: EnginePeer, context: AccountContext, transferType: TransferType = .transfer, buyForSelected: CurrencyAmount.Currency = .stars, callback: @escaping (CurrencyAmount.Currency)->Void = { _ in }) {
        self.transferType = transferType
        self.buyForSelected = buyForSelected
        self.callback = callback
        self.gift = gift
        self.toPeer = toPeer
        self.context = context
        switch transferType {
        case .transfer:
            self.layout = TextViewLayout(
                .initialize(
                    string: toPeer.id == context.peerId
                        ? strings().giftWithdrawTitle
                        : strings().giftTransferConfirmationTitle,
                    color: theme.colors.text,
                    font: .medium(.title)
                )
            )
        case .buy:
            self.layout = TextViewLayout(
                .initialize(
                    string: strings().starGiftSellAlertTitleConfirmPayment,
                    color: theme.colors.text,
                    font: .medium(.title)
                )
            )
        }
        layout.measure(width: .greatestFiniteMagnitude)

        if case let .buy(onlyTon) = transferType {
            if onlyTon {
                self.onlyTonLayout = .init(
                    .initialize(
                        string: strings().starGiftSellAlertOnlyTon,
                        color: theme.colors.listGrayText,
                        font: .normal(.text)
                    ),
                    alignment: .center
                )
                self.onlyTonLayout?.measure(width: 200)
                
                self.buyForTon = nil
                self.buyForStars = nil
                
            } else {
                self.onlyTonLayout = nil
                
                self.buyForTon = .init(
                    .initialize(
                        string: strings().starGiftSellAlertPayInTon,
                        color: theme.colors.listGrayText,
                        font: .normal(.text)
                    ),
                    alignment: .center
                )
                self.buyForStars = .init(
                    .initialize(
                        string: strings().starGiftSellAlertPayInStars,
                        color: theme.colors.listGrayText,
                        font: .normal(.text)
                    ),
                    alignment: .center
                )
                
                self.buyForStars?.measure(width: .greatestFiniteMagnitude)
                self.buyForTon?.measure(width: .greatestFiniteMagnitude)
            }
        } else {
            self.onlyTonLayout = nil
            self.buyForTon = nil
            self.buyForStars = nil
        }

        var height: CGFloat = 120
        if let onlyTonLayout {
            height += onlyTonLayout.layoutSize.height
        } else if let _ = buyForTon {
            height += 20
        }
        
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return TransferHeaderView.self
    }
}

private final class TransferHeaderView : GeneralRowView {
    private let avatar = AvatarControl(font: .avatar(18))
    private let giftView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 40, 40))
    private let chevron: ImageView = ImageView()
    private let container = View()
    private let textView = TextView()
    private var headerTextView: TextView?
    
    private let transferContainer = View()
    
    private let emoji: PeerInfoSpawnEmojiView = .init(frame: NSMakeRect(0, 0, 180, 180))
    private let backgroundView = PeerInfoBackgroundView(frame: .zero)
    
    private var buyFor: View?
    private var buyForTon: TextView?
    private var buyForStars: TextView?

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
      
        
        transferContainer.addSubview(backgroundView)
        transferContainer.addSubview(emoji)
        transferContainer.addSubview(giftView)
        
        transferContainer.backgroundColor = .random
        
        transferContainer.layer?.cornerRadius = 10
        transferContainer.setFrameSize(NSMakeSize(60, 60))
        
        container.addSubview(transferContainer)
        container.addSubview(chevron)
        container.addSubview(avatar)

        addSubview(textView)
        
        chevron.image = NSImage(resource: .iconAffiliateChevron).precomposed(theme.colors.grayIcon.withAlphaComponent(0.8))
        chevron.sizeToFit()
        giftView.setFrameSize(NSMakeSize(50, 50))
        avatar.setFrameSize(NSMakeSize(60, 60))
        addSubview(container)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        giftView.center()
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
        
        if item.toPeer.id == item.context.peerId, item.transferType == .transfer {
            avatar.setSignal(generateEmptyPhoto(avatar.frame.size, type: .icon(colors: (top: theme.colors.listBackground, bottom: theme.colors.listBackground), icon: NSImage(resource: .iconStarTransactionRowFragment).precomposed(), iconSize: avatar.frame.size, cornerRadius: nil), bubble: false) |> map {($0, false)})
        } else {
            avatar.setPeer(account: item.context.account, peer: item.toPeer._asPeer())
        }
        giftView.update(with: item.gift.file!, size: giftView.frame.size, context: item.context, table: item.table, animated: animated)
        
        emoji.set(fileId: item.gift.pattern!.fileId.id, color: item.gift.patternColor!.withAlphaComponent(0.3), context: item.context, animated: animated)
        
        if let onlyTonLayout = item.onlyTonLayout {
            let current: TextView
            if let view = self.headerTextView {
                current = view
            } else {
                current = TextView()
                self.headerTextView = current
                self.addSubview(current)
                current.userInteractionEnabled = false
                current.isSelectable = false
                current.disableBackgroundDrawing = true
                current.isEventLess = true
            }
            current.update(onlyTonLayout)
        } else if let view = self.headerTextView {
            performSubviewRemoval(view, animated: animated)
            self.headerTextView = nil
        }
        
        if let buyForTon = item.buyForTon, let buyForStars = item.buyForStars {
            let current: View
            if let view = buyFor {
                current = view
            } else {
                current = View(frame: NSMakeRect(0, 0, frame.width, 26))
                addSubview(current)
                self.buyFor = current
            }
            
            let tonCurrent: TextView
            if let view = self.buyForTon {
                tonCurrent = view
            } else {
                tonCurrent = TextView()
                self.buyForTon = tonCurrent
                current.addSubview(tonCurrent)
                tonCurrent.isSelectable = false
                tonCurrent.scaleOnClick = true
            }
            tonCurrent.update(buyForTon)
            tonCurrent.setFrameSize(NSMakeSize(buyForTon.layoutSize.width + 20, 26))
            tonCurrent.layer?.cornerRadius = tonCurrent.frame.height / 2

            let starsCurrent: TextView
            if let view = self.buyForStars {
                starsCurrent = view
            } else {
                starsCurrent = TextView()
                self.buyForStars = starsCurrent
                current.addSubview(starsCurrent)
                starsCurrent.isSelectable = false
                starsCurrent.scaleOnClick = true
            }
            starsCurrent.update(buyForStars)
            starsCurrent.setFrameSize(NSMakeSize(buyForStars.layoutSize.width + 20, 26))
            starsCurrent.layer?.cornerRadius = starsCurrent.frame.height / 2
            
            
            starsCurrent.setSingle(handler: { [weak item, weak self] _ in
                if item?.buyForSelected != .stars {
                    item?.toggleBuySelected()
                    if let buyForTon = self?.buyForTon {
                        tooltip(for: buyForTon, text: strings().starSellTonTooltip)
                    }
                }
                
            }, for: .Click)
            
            tonCurrent.setSingle(handler: { [weak item] _ in
                if item?.buyForSelected != .ton {
                    item?.toggleBuySelected()
                }
            }, for: .Click)
            
            switch item.buyForSelected {
            case .stars:
                starsCurrent.set(background: theme.colors.listGrayText.withAlphaComponent(0.2), for: .Normal)
                tonCurrent.set(background: .clear, for: .Normal)
            case .ton:
                tonCurrent.set(background: theme.colors.listGrayText.withAlphaComponent(0.2), for: .Normal)
                starsCurrent.set(background: .clear, for: .Normal)
            }
        } else {
            if let view = self.buyFor {
                performSubviewRemoval(view, animated: animated)
                self.buyFor = nil
                self.buyForTon = nil
                self.buyForStars = nil
            }
        }
        
        self.backgroundView.gradient = item.gift.backdrop!
        
        needsLayout = true
        
        
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? TransferUniqueGiftHeaderItem else {
            return
        }
        
        
        headerTextView?.centerX(y: 0)
        
        var offset: CGFloat = 15
        
        if let headerTextView {
            offset += headerTextView.frame.height
        }
        if let buyFor {
            offset += buyFor.frame.height
        }
        
        if let buyFor {
            buyFor.frame = bounds.focusX(NSMakeSize(buyFor.subviewsWidthSize.width, 26), y: 0)
            if let buyForTon, let buyForStars {
                buyForStars.centerY(x: 0)
                buyForTon.centerY(x: buyForStars.frame.maxX)
            }
        }
        
        container.centerX(y: offset)
        transferContainer.centerY(x: 0)
        avatar.centerY(x: container.frame.width - avatar.frame.width)
        
        self.backgroundView.frame = transferContainer.bounds.offsetBy(dx: 0, dy: 0)
        self.emoji.frame = transferContainer.bounds
        
        chevron.center()
        chevron.setFrameOrigin(NSMakePoint(chevron.frame.minX + 2, chevron.frame.minY))
        textView.centerX(y: frame.height - textView.frame.height - 10)
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
    
    fileprivate let headerLayout: TextViewLayout?
    fileprivate let infoLayout: TextViewLayout?
    
    let hasToggle: Bool
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, source: StarGiftNftSource, transaction: StarsContext.State.Transaction?, nameEnabled: Bool, isPreview: Bool, toggleName: @escaping()->Void) {
        self.context = context
        self.toggleName = toggleName
        self.isPreview = isPreview
        self.nameEnabled = nameEnabled
        self.transaction = transaction
        var options:[Option] = []
        
        switch source {
        case let .previewWear(_, gift):
            headerLayout = .init(.initialize(string: strings().starNftWearTitle("\(gift.title) #\(gift.number)"), color: theme.colors.text, font: .medium(18)))
            infoLayout = .init(.initialize(string: strings().starNftWearInfo, color: theme.colors.text, font: .normal(.text)))
        default:
            headerLayout = nil
            infoLayout = nil
        }
        
        
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
        
        let title1: String
        let info1: String
        
        let title2: String
        let info2: String

        let title3: String
        let info3: String
        
        
        let image1: CGImage
        let image2: CGImage
        let image3: CGImage
        
        switch source {
        case .previewWear:
            title1 = strings().giftWearBadgeTitle
            info1 = strings().giftWearBadgeText
            
            title2 = strings().giftWearDesignTitle
            info2 = strings().giftWearDesignText

            title3 = strings().giftWearProofTitle
            info3 = strings().giftWearProofText
            
            image1 = NSImage(resource: .iconNFTRadiantBadge).precomposed(theme.colors.accent)
            image2 = NSImage(resource: .iconChannelFeatureCoverIcon).precomposed(theme.colors.accent)
            image3 = NSImage(resource: .iconNFTVerification).precomposed(theme.colors.accent)
        default:
            title1 = strings().giftUpgradeUniqueTitle
            info1 = isPreview ? strings().giftUpgradeUniqueIncludeDescription : strings().giftUpgradeUniqueDescription
            
            title2 = strings().giftUpgradeTransferableTitle
            info2 = isPreview ? strings().giftUpgradeTransferableIncludeDescription : strings().giftUpgradeTransferableDescription
            
            title3 = strings().giftUpgradeTradableTitle
            info3 = isPreview ? strings().giftUpgradeUniqueIncludeDescription : strings().giftUpgradeUniqueDescription
            
            image1 = NSImage(resource: .iconNFTUnique).precomposed(theme.colors.accent)
            image2 = NSImage(resource: .iconNFTTransferable).precomposed(theme.colors.accent)
            image3 = NSImage(resource: .iconNFTTradable).precomposed(theme.colors.accent)
        }

        
        options.append(.init(image: image1, header: .init(.initialize(string: title1, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: info1, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: image2, header: .init(.initialize(string: title2, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: info2, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        options.append(.init(image: image3, header: .init(.initialize(string: title3, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: info3, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        self.options = options
        
        self.nameEnabledLayout?.measure(width: initialSize.width - 80)

        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        infoLayout?.measure(width: width - 40)
        headerLayout?.measure(width: width - 40)
        return true
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
        
        if let infoLayout, let headerLayout {
            height += headerLayout.layoutSize.height
            height += 5
            height += infoLayout.layoutSize.height
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
    
    private var headerView: TextView?
    private var infoView: TextView?
    
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
        
        
        if let headerView, let infoView {
            headerView.centerX(y: 0)
            infoView.centerX(y: headerView.frame.maxY + 5)
        }
        
        var offset: CGFloat = 0
        if let infoView {
            offset += infoView.frame.maxY + 20
        }
        optionsView.centerX(y: offset)
                
      
        
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
        
        if let textLayout = item.headerLayout {
            let current: TextView
            if let view = self.headerView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.headerView = current
                addSubview(current)
            }
            current.update(textLayout)
        } else if let view = self.headerView {
            performSubviewRemoval(view, animated: animated)
            self.headerView = nil
        }
        
        if let textLayout = item.infoLayout {
            let current: TextView
            if let view = self.infoView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.infoView = current
                addSubview(current)
            }
            current.update(textLayout)
        } else if let view = self.infoView {
            performSubviewRemoval(view, animated: animated)
            self.infoView = nil
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
    
    
    class ActionItem {
        var title: TextViewLayout
        var image: CGImage
        var action:()->Void
        var size: NSSize = .zero
      
        
        init(title: String, image: CGImage, action: @escaping () -> Void) {
            self.title = .init(.initialize(string: title, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)))
            self.image = image
            self.action = action
        }
        
        func measure(width: CGFloat) {
            self.title.measure(width: width)
            self.size = NSMakeSize(width, 80)
        }
    }
    
    fileprivate let context: AccountContext
    fileprivate let title: TextViewLayout
    fileprivate let info: TextViewLayout
    fileprivate let arguments:Arguments
    fileprivate let attributes: [StarGift.UniqueGift.Attribute]
    fileprivate let source: StarGiftNftSource
    
    fileprivate var patterns:[TelegramMediaFile] = []
    fileprivate var backdrops:[StarGift.UniqueGift.Attribute] = []
    fileprivate var models:[StarGift.UniqueGift.Attribute] = []

    private var patternIndex: Int = 0
    private var backdropIndex: Int = 0
    private var modelIndex: Int = 0
    
    private let converted: Bool
    
    let uniqueGift: StarGift.UniqueGift?
    let state: State
    
    var actions: [ActionItem] = []
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, arguments: Arguments, state: State, attributes: [StarGift.UniqueGift.Attribute], source: StarGiftNftSource) {
        self.arguments = arguments
        self.context = context
        self.attributes = attributes
        self.converted = state.converted
        self.source = source
        self.state = state
        switch state.gift {
        case let .unique(gift):
            self.uniqueGift = gift
        default:
            self.uniqueGift = nil
        }
        
        
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
        
        switch source {
        case let .quickLook(peer, _):
            if let uniqueGift = uniqueGift, let owner = state.owner, owner.id == context.peerId || owner._asPeer().groupAccess.canManageGifts {
                actions = [.init(title: strings().starNftTransfer, image: NSImage(resource: .iconNFTTransfer).precomposed(.white), action: {
                    arguments.transfer()
                }), .init(title: state.weared ? strings().starNftTakeOff : strings().starNftWear, image: NSImage(resource: .iconNFTWear).precomposed(.white), action: {
                    arguments.toggleWear(uniqueGift)
                })]
                
                if case .starGift = state.purpose {
                    actions.append(.init(title: uniqueGift.resellStars(context) != nil ? strings().starNftUnlist : strings().starNftSell, image: NSImage(resource: (uniqueGift.resellStars(context) != nil ? .iconNftUnlist : .iconNftSell)).precomposed(.white), action: {
                        arguments.sellNft(uniqueGift, false)
                    }))
                } else {
                    actions.append(.init(title: strings().starNftShare, image: NSImage(resource: .iconNFTShare).precomposed(.white), action: {
                        arguments.shareNft(uniqueGift)
                    }))
                }
                
            }
        default:
            break
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
        case let .backdrop(_, _, _, _, patternColor, _, _):
            return NSColor.init(UInt32(patternColor))
        default:
            fatalError()
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 40)
        self.info.measure(width: width - 40)
        
        if state.author != nil {
            self.info.generateAutoBlock(backgroundColor: patternColor.withAlphaComponent(0.4))
        }
        
        for action in actions {
            action.measure(width: 120)
        }
        
       

        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        
        height += 30
        height += 100
        height += 20
        
        height += title.layoutSize.height
        height += 5
        height += 20//info.layoutSize.height
        height += 10
        
        if !actions.isEmpty {
            height += 70
        }
        
        return height
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    
    var backgroundGradient: [NSColor] {
        switch self.backdrops[self.backdropIndex] {
        case let .backdrop(_, _, inner, outer, _, _, _):
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
    private var actions: ImageButton?
    private let giftView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 100, 100))
    private let emoji: PeerInfoSpawnEmojiView = .init(frame: NSMakeRect(0, 0, 180, 180))
    private let backgroundView = PeerInfoBackgroundView(frame: .zero)
    
    private var avatarView: AvatarControl?
    
    private var ownerActions: View?
    
    class ActionView : Control {
        private let textView: TextView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            addSubview(textView)
            addSubview(imageView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(item: HeaderItem.ActionItem) {
            self.textView.update(item.title)
            self.imageView.image = item.image
            self.imageView.sizeToFit()
            
            setSingle(handler: { [weak item] _ in
                item?.action()
            }, for: .Click)
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            
            imageView.centerX(y: 5)
            textView.centerX(y: frame.height - textView.frame.height - 10)
        }
    }
    
    private var timer: SwiftSignalKit.Timer?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(emoji)
        addSubview(giftView)
        addSubview(textView)
        addSubview(infoView)
        addSubview(dismiss)
        
        infoView.isSelectable = false
        
        giftView.scaleOnClick = true
        giftView.tooltipOnclick = true

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
            item?.arguments.dismiss()
        }, for: .Click)
        
        
        
        if let uniqueGift = item.uniqueGift, !item.source.isWearing {
            let current: ImageButton
            if let view = self.actions {
                current = view
            } else {
                current = ImageButton()
                addSubview(current)
                self.actions = current
                current.autohighlight = false
                current.scaleOnClick = true
            }
            current.set(image: NSImage(resource: .iconChatActions).precomposed(.white), for: .Normal)
            current.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
            
            current.contextMenu = {
                let menu = ContextMenu()
                
                menu.addItem(ContextMenuItem(strings().contextCopy, handler: {
                    item.arguments.copyNftLink(uniqueGift)
                }, itemImage: MenuAnimation.menu_copy_link.value))
                
                menu.addItem(ContextMenuItem(strings().storyMyInputShare, handler: {
                    item.arguments.shareNft(uniqueGift)
                }, itemImage: MenuAnimation.menu_share.value))
                
                let owner = item.state.owner?._asPeer()
                
                
                
                if case let .peerId(peerId) = uniqueGift.owner, peerId == item.arguments.context.peerId || owner?.groupAccess.isCreator == true {
                    
                    if let pinnedInfo = item.state.pinnedInfo {
                        menu.addItem(ContextMenuItem(pinnedInfo.pinnedInfo ? strings().messageContextUnpin : strings().messageContextPin, handler: item.arguments.togglePin, itemImage: pinnedInfo.pinnedInfo ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value))
                    }
                                        
                    menu.addItem(ContextMenuItem(strings().giftTransferConfirmationTransferFree, handler: {
                        item.arguments.transfer()
                    }, itemImage: MenuAnimation.menu_replace.value))
                }
                return menu
            }
        }
           
        
        switch item.source {
        case let .previewWear(peer, _):
            let current: AvatarControl
            if let view = avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(18))
                current.setFrameSize(100, 100)
                self.avatarView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.setPeer(account: item.context.account, peer: peer._asPeer())
            giftView.setFrameSize(NSMakeSize(25, 25))
            if let gift = item.uniqueGift {
                giftView.appTooltip = "\(gift.title) #\(gift.number)"
                giftView.tooltipOnclick = true
            }
        default:
            if let avatarView {
                performSubviewRemoval(avatarView, animated: animated)
                self.avatarView = nil
            }
            giftView.setFrameSize(NSMakeSize(100, 100))
            giftView.appTooltip = nil
        }
        
        let update:()->Void = { [weak self] in
            guard let self else {
                return
            }
            self.emoji.set(fileId: item.pattern.fileId.id, color: item.patternColor.withAlphaComponent(0.5), context: item.context, animated: animated)
            self.backgroundView.gradient = item.backgroundGradient
            self.giftView.update(with: item.model, size: giftView.frame.size, context: item.context, table: item.table, animated: animated)
        }
        
        self.timer = .init(timeout: 2.5, repeat: true, completion: {
            item.makeNextPattern()
            update()
        }, queue: .mainQueue())
        
        self.timer?.start()
        update()
        
        if !item.actions.isEmpty {
            
            let current: View
            if let view = ownerActions {
                current = view
            } else {
                current = View()
                addSubview(current)
                self.ownerActions = current
            }
            
            while current.subviews.count > item.actions.count {
                current.subviews.removeLast()
            }
            
            while current.subviews.count < item.actions.count {
                current.addSubview(ActionView(frame: .zero))
            }
            
            for (i, action) in item.actions.enumerated() {
                let view = current.subviews[i] as! ActionView
                view.layer?.cornerRadius = 10
                view.scaleOnClick = true
                
                let textColor = item.uniqueGift?.backdrop?.first?.lightness ?? 1.0 > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)

                view.background = textColor.withAlphaComponent(0.2)
                view.set(item: action)
            }
            
        } else if let view = ownerActions {
            performSubviewRemoval(view, animated: animated)
            self.ownerActions = nil
        }
        
                
        textView.update(item.title)
        infoView.update(item.info)
        
        
        if let author = item.state.author {
            let context = item.context
            
            infoView.setSingle(handler: { [weak item] view in
                if let event = NSApp.currentEvent {
                    let data = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: author.id),
                        TelegramEngine.EngineData.Item.Peer.AboutText(id: author.id)
                    ) |> take(1) |> deliverOnMainQueue
                    
                    _ = data.start(next: { [weak view, weak item] data in
                        
                        guard let peer = data.0, let view = view else {
                            return
                        }
                        
                        var firstBlock:[ContextMenuItem] = []
                        var secondBlock:[ContextMenuItem] = []
                        let thirdBlock: [ContextMenuItem] = []
                        
                        firstBlock.append(GroupCallAvatarMenuItem(peer._asPeer(), context: context))
                        
                        firstBlock.append(ContextMenuItem(peer._asPeer().displayTitle, handler: {
                            item?.arguments.openPeer(peer, true)
                        }, itemImage: MenuAnimation.menu_open_profile.value))
                        
                        if let username = peer.addressName {
                            firstBlock.append(ContextMenuItem("\(username)", handler: {
                                item?.arguments.openPeer(peer, true)
                            }, itemImage: MenuAnimation.menu_atsign.value))
                        }
                        
                        switch data.1 {
                        case let .known(about):
                            if let about = about, !about.isEmpty {
                                firstBlock.append(ContextMenuItem(about, handler: {
                                    item?.arguments.openPeer(peer, true)
                                }, itemImage: MenuAnimation.menu_bio.value, removeTail: false, overrideWidth: 200))
                            }
                        default:
                            break
                        }
                        
                        let blocks:[[ContextMenuItem]] = [firstBlock,
                                                          secondBlock,
                                                          thirdBlock].filter { !$0.isEmpty }
                        var items: [ContextMenuItem] = []

                        for (i, block) in blocks.enumerated() {
                            if i != 0 {
                                items.append(ContextSeparatorItem())
                            }
                            items.append(contentsOf: block)
                        }
                        
                        let menu = ContextMenu()
                        
                        for item in items {
                            menu.addItem(item)
                        }
                        AppMenu.show(menu: menu, event: event, for: view)
                    })
                }
            }, for: .Click)
        } else {
            infoView.removeAllHandlers()
        }
        backgroundView.backgroundColor = .blackTransparent

        //let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        //updateLayout(size: frame.size, transition: transition)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        emoji.frame = size.bounds.focusX(NSMakeSize(180, 180), y: 30)
        
        if let ownerActions {
            ownerActions.setFrameSize(NSMakeSize(size.width, 60))
            ownerActions.centerX(y: size.height - ownerActions.frame.height - 10)
            
            infoView.centerX(y: ownerActions.frame.minY - 20 - 10)

                        
            let itemSize = (frame.width - (CGFloat(ownerActions.subviews.count + 1) * 10)) / CGFloat(ownerActions.subviews.count)
            var x: CGFloat = 10
            for subview in ownerActions.subviews {
                subview.frame = NSMakeRect(x, 0, itemSize, ownerActions.frame.height)
                x += subview.frame.width + 10
            }
        } else {
            infoView.centerX(y: size.height - 20 - 15)
        }
        
        backgroundView.offset = 30
        
        transition.updateFrame(view: backgroundView, frame: NSMakeSize(340, 278).bounds)
        backgroundView.updateLayout(size: backgroundView.frame.size, transition: transition)
        
        dismiss.setFrameOrigin(NSMakePoint(10, 10))

        if let actions {
            actions.setFrameOrigin(NSMakePoint(size.width - actions.frame.width - 10, 10))
        }
        
        if let avatarView {
            avatarView.centerX(y: 30)
            textView.centerX(y: infoView.frame.minY - textView.frame.height - 5, addition: -10)
            giftView.setFrameOrigin(NSMakePoint(textView.frame.maxX + 2, textView.frame.minY - 3))
        } else {
            giftView.centerX(y: 30)
            textView.centerX(y: infoView.frame.minY - textView.frame.height - 5)
        }
    }
    
    override func layout() {
        super.layout()
     

    }
}



private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let toggleName:()->Void
    let transfer:()->Void
    let copyNftLink:(StarGift.UniqueGift)->Void
    let shareNft:(StarGift.UniqueGift)->Void
    let sellNft:(StarGift.UniqueGift, Bool)->Void
    let toggleWear:(StarGift.UniqueGift)->Void
    let togglePin:()->Void
    let openPeer:(EnginePeer, Bool)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, toggleName:@escaping()->Void, transfer:@escaping()->Void, copyNftLink:@escaping(StarGift.UniqueGift)->Void, shareNft:@escaping(StarGift.UniqueGift)->Void, sellNft:@escaping(StarGift.UniqueGift, Bool)->Void, toggleWear:@escaping(StarGift.UniqueGift)->Void, togglePin:@escaping()->Void, openPeer:@escaping(EnginePeer, Bool)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.toggleName = toggleName
        self.transfer = transfer
        self.copyNftLink = copyNftLink
        self.shareNft = shareNft
        self.sellNft = sellNft
        self.toggleWear = toggleWear
        self.togglePin = togglePin
        self.openPeer = openPeer
    }
}

private struct State : Equatable {
    var source: StarGiftNftSource
    var gift: StarGift
    var transaction: StarsContext.State.Transaction?
    var nameEnabled: Bool = true
    var converted: Bool = false
    
    var author: EnginePeer?
    
    var purpose: Star_TransactionPurpose?
    
    var weared: Bool {
        return owner?.emojiStatus?.fileId == gift.unique?.file?.fileId.id
    }
    
    var upgradeForm: BotPaymentForm?
        
    var attributes: [StarGift.UniqueGift.Attribute]
    
    var starsState: StarsContext.State?
    var myBalance: StarsAmount?
    var myTonBalance: StarsAmount?
    var tonAddress: String? = nil
    
    var owner: EnginePeer?
    var ownerName: String?
    
    var isTonOwner: Bool = false
    
    var accountPeerId: PeerId
    
    var pinnedInfo: GiftPinnedInfo?

    func okText(_ context: AccountContext) -> String {
        switch source {
        case .preview:
            return strings().modalOK
        case let .quickLook(peer, gift):
            if let purpose {
                switch purpose {
                case let .starGift(_, _, _, _, _, savedToProfile, _, _, _, _, _, reference, _, _, _, _):
                    if let _ = reference {
                        var canManage: Bool
                        let peer = peer ?? owner
                        
                        if let peer, peer._asPeer().groupAccess.canManageGifts || peer.id == accountPeerId {
                            canManage = true
                        } else {
                            canManage = false
                        }
                        if canManage {
                            if !savedToProfile {
                                return strings().starTransactionStarGiftChannelDisplayOnMyPage
                            } else {
                                return strings().starTransactionStarGiftChannelHideFromMyPage
                            }
                        }
                    }
                default:
                    break
                }
            }
            if let resellStars = gift.resell {
                return strings().starNftBuyFor(resellStars.fullyFormatted)
            }
            return strings().modalOK
        case .previewWear:
            return strings().giftWearStart
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
        case let .previewWear(peer, _):
            return peer._asPeer().displayTitle
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
        case .previewWear:
            return strings().peerStatusOnline
        default:
            if let unique = gift.unique {
                if let author {
                    return strings().starTransactionGiftCollectible("#\(unique.number)") + " by @\(author.addressName ?? "")"
                } else {
                    return strings().starTransactionGiftCollectible("#\(unique.number)")
                }
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
        case .quickLook:
            return true
        case .previewWear:
            return true
        default:
            return false
        }
    }
}

private let _id_ton_input = InputDataIdentifier("_id_ton_input")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, arguments: arguments, state: state, attributes: state.attributes, source: state.source)
    }))
    
    let explorerUrl = arguments.context.appConfiguration.getStringValue("ton_blockchain_explorer_url", orElse: "https://tonviewer.com/")

    
    entries.append(.sectionId(sectionId, type: .legacy))
    sectionId += 1
    
    switch state.source {
    default:
        if state.converted {
            var rows: [InputDataTableBasedItem.Row] = []
            
                    
            let ownerAttr: NSAttributedString
            
            if let peer = state.owner {
                ownerAttr = parseMarkdownIntoAttributedString("[\(peer._asPeer().displayTitle)](owner)", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, contents)
                }))
            } else if let ownerName = state.ownerName {
                if state.isTonOwner {
                    ownerAttr = parseMarkdownIntoAttributedString("[\(ownerName)](\(ownerName))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, contents)
                    }))
                } else {
                    ownerAttr = .initialize(string: ownerName, color: theme.colors.text, font: .normal(.text))
                }
            } else {
                ownerAttr = .init()
            }
            
            let ownerText: TextViewLayout = .init(ownerAttr, maximumNumberOfLines: state.isTonOwner ? 3 : 1, alwaysStaticItems: true)
            
            ownerText.interactions.processURL = { url in
                if let url = url as? String, !url.isEmpty {
                    if url == "owner", let peer = state.owner {
                        arguments.openPeer(peer, false)
                    } else {
                        execute(inapp: .external(link: explorerUrl + url, false))
                    }
                }
            }
            
            let leftView:((NSView?)->NSView)?
            let rightView:((NSView?)->NSView?)?
    //        let badge: InputDataTableBasedItem.Row.Right.Badge?
            if let owner = state.owner {
                leftView = { previous in
                    let control: AvatarControl
                    if let previous = previous as? AvatarControl {
                        control = previous
                    } else {
                        control = AvatarControl(font: .avatar(6))
                    }
                    control.setFrameSize(NSMakeSize(20, 20))
                    control.setPeer(account: arguments.context.account, peer: owner._asPeer())
                    return control
                }
                if let gift = state.gift.unique, let owner = state.owner {
                    rightView = { previous in
                        let control: PremiumStatusControl? = PremiumStatusControl.control(owner._asPeer(), account: arguments.context.account, inlinePacksContext: arguments.context.inlinePacksContext, left: false, isSelected: false, cached: previous as? PremiumStatusControl, animated: false)
                        control?.userInteractionEnabled = true
                        if state.weared {
                            control?.appTooltip = strings().starNftTooltipWorn("\(gift.title) #\(gift.number)")
                        }
                        return control
                    }
                } else {
                    rightView = nil
                }
    //            if owner.id == arguments.context.peerId {
    //                badge = .init(text: strings().giftUniqueTransfer, callback: arguments.transfer)
    //            } else {
    //                badge = nil
    //            }
            } else {
                leftView = nil
                rightView = nil
    //            badge = nil
            }
            
            rows.append(.init(left: .init(.initialize(string: strings().giftUniqueOwner, color: theme.colors.text, font: .normal(.text))), right: .init(name: ownerText, leftView: leftView, rightView: rightView, badge: nil)))
            
            switch state.gift {
            case let .unique(gift):
                
                let badge: InputDataTableBasedItem.Row.Right.Badge?
                
                if let owner = state.owner, owner.id == arguments.context.peerId || owner._asPeer().groupAccess.canManageGifts {
                    badge = .init(text: strings().starNftPriceEdit, callback: {
                        arguments.sellNft(gift, true)
                    })
                } else {
                    badge = nil
                }
                
                
                if let resellStars = gift.resell, badge != nil {
                    rows.append(.init(left: .init(.initialize(string: strings().starNftPriceSale, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: "\(resellStars.formatted)", color: theme.colors.text, font: .normal(.text))), leftView: { previous in
                        let control: ImageView
                        if let previous = previous as? ImageView {
                            control = previous
                        } else {
                            control = ImageView(frame: NSMakeRect(0, 0, 20, 20))
                        }
                        if gift.resellForTonOnly {
                            control.image = NSImage(resource: .iconTonCurrency).precomposed()
                        } else {
                            control.image = NSImage(resource: .iconStarCurrency).precomposed()
                        }
                        return control
                    }, badge: badge)))
                }
                
                for attr in gift.attributes {
                    switch attr {
                    case .model(let name, _, let rarity):
                        rows.append(.init(left: .init(.initialize(string: strings().giftUniqueModel, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
                    case .pattern(let name, _, let rarity):
                        rows.append(.init(left: .init(.initialize(string: strings().giftUniqueSymbol, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
                    case .backdrop(let name, _, _, _, _, _, let rarity):
                        rows.append(.init(left: .init(.initialize(string: strings().giftUniqueBackdrop, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: name, color: theme.colors.text, font: .normal(.text))), badge: .init(text: "\((Double(rarity) / 10).string)%", callback: {}))))
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
            
            
            if let address = state.gift.unique?.giftAddress {
                entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().starGiftOnBlockchainInfo, linkHandler: { _ in
                    execute(inapp: .external(link: explorerUrl + address, false))
                }), data: .init(viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
            } else {
                if case .quickLook = state.source {
                    entries.append(.sectionId(sectionId, type: .legacy))
                    sectionId += 1
                }
                /*
                 else if state.convertedGift != nil {
                     entries.append(.sectionId(sectionId, type: .legacy))
                     sectionId += 1
                 }
                 */
            }
            
          
            
        } else {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("row"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return RowItem(initialSize, stableId: stableId, context: arguments.context, source: state.source, transaction: state.transaction, nameEnabled: state.nameEnabled, isPreview: state.isPreview, toggleName: arguments.toggleName)
            }))
            
            // entries
            
            entries.append(.sectionId(sectionId, type: .custom(10)))
            sectionId += 1
        }
        
    }
    
    return entries
}

enum StarGiftNftSource : Equatable {
    case preview(EnginePeer, [StarGift.UniqueGift.Attribute])
    case previewWear(EnginePeer, StarGift.UniqueGift)
    case upgrade(EnginePeer, [StarGift.UniqueGift.Attribute], StarGiftReference)
    case quickLook(EnginePeer?, StarGift.UniqueGift)
    var attributes: [StarGift.UniqueGift.Attribute] {
        switch self {
        case let .preview(_, attributes):
            return attributes
        case let .upgrade(_, attributes, _):
            return attributes
        case let .quickLook(_, gift):
            return gift.attributes
        case let .previewWear(_, gift):
            return gift.attributes
        }
    }
    
    var isQuickLook: Bool {
        switch self {
        case .quickLook:
            return true
        default:
            return false
        }
    }
    
    var peer: EnginePeer? {
        switch self {
        case .preview(let enginePeer, _):
            return enginePeer
        case .previewWear(let enginePeer, _):
            return enginePeer
        case .upgrade(let enginePeer, _, _):
            return enginePeer
        case .quickLook(let enginePeer, _):
            return enginePeer
        }
    }
    
    var isWearing: Bool {
        switch self {
        case .previewWear:
            return true
        default:
            return false
        }
    }
    
}

struct GiftPinnedInfo : Equatable {
    var pinnedInfo: Bool
    var reference: StarGiftReference
}

func StarGift_Nft_Controller(context: AccountContext, gift: StarGift, source: StarGiftNftSource, transaction: StarsContext.State.Transaction? = nil, purpose: Star_TransactionPurpose? = nil, giftsContext: ProfileGiftsContext? = nil, resaleContext: ResaleGiftsContext? = nil, pinnedInfo: GiftPinnedInfo? = nil, toPeerId: PeerId? = nil) -> InputDataModalController {

    
    let toPeerId = toPeerId ?? context.peerId
    
    let giftsContext = giftsContext ?? ProfileGiftsContext(account: context.account, peerId: toPeerId)
    
    let actionsDisposable = DisposableSet()
    
    let authorPeer: Signal<EnginePeer?, NoError>
    if let authorId = gift.releasedBy {
        authorPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: authorId))
    } else {
        authorPeer = .single(nil)
    }
    let initialState = State(source: source, gift: gift, transaction: transaction, converted: source.isQuickLook, purpose: purpose, attributes: source.attributes, accountPeerId: context.peerId, pinnedInfo: pinnedInfo)
    
    var close:(()->Void)? = nil
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    actionsDisposable.add(combineLatest(context.starsContext.state, context.tonContext.state, authorPeer).startStrict(next: { state, tonState, authorPeer in
        updateState { current in
            var current = current
            current.starsState = state
            current.myBalance = state?.balance
            current.myTonBalance = tonState?.balance
            current.author = authorPeer
            return current
        }
    }))
    
    actionsDisposable.add(statePromise.get().start(next: { state in
        if let unique = state.gift.unique {
            switch unique.owner {
            case let .peerId(peerId):
                actionsDisposable.add(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)).startStandalone(next: { peer in
                    updateState { current in
                        var current = current
                        current.owner = peer
                        current.ownerName = nil
                        current.isTonOwner = false
                        return current
                    }
                }))
            case let .name(name):
                updateState { current in
                    var current = current
                    current.owner = nil
                    current.ownerName = name
                    current.isTonOwner = false
                    return current
                }
            case let .address(address):
                updateState { current in
                    var current = current
                    current.owner = nil
                    current.ownerName = address
                    current.isTonOwner = true
                    return current
                }
            }
        }
    }))
    
    
    switch source {
    case let .upgrade(_, _, messageId):
        actionsDisposable.add(context.engine.payments.fetchBotPaymentForm(source: .starGiftUpgrade(keepOriginalInfo: false, reference: messageId), themeParams: nil).start(next: { form in
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
    
    actionsDisposable.add(giftsContext.state.startStrict(next: { state in
        let unique = state.gifts.first(where: { $0.gift.unique?.slug == gift.unique?.slug })
        
        if let unique = unique?.gift.unique {
            updateState { current in
                var current = current
                current.gift = .unique(unique)
                switch current.source {
                case let .quickLook(peer, _):
                    current.source = .quickLook(peer, unique)
                default:
                    break
                }
                return current
            }
        }
        
    }))
    
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
   
    
    
    let buyResellGift:(StarGift.UniqueGift, EnginePeer, BotPaymentForm, BotPaymentForm)->Void = { [weak giftsContext, weak resaleContext] gift, peer, starsForm, tonForm in
        
        let state = stateValue.with { $0 }
        
       
        let resellStars = gift.resell?.fullyFormatted ?? ""

        let amount = gift.resell?.amount ?? .zero
        
        
        var buyForSelected: CurrencyAmount.Currency = gift.resellForTonOnly ? .ton : .stars
        var modifyData:((ModalAlertData)->Void)? = nil
        
        var getData:()->ModalAlertData = { .init(info: "") }
        
        getData = {
            
            let form = buyForSelected == .stars ? starsForm : tonForm
            
            let fullAmount = form.invoice.prices.first?.amount ?? 0
            
            let resellAmount = CurrencyAmount(amount: StarsAmount.init(value: fullAmount, nanos: 0), currency: buyForSelected)
            
            let resellStars = resellAmount.fullyFormatted
            
            let infoText: String
            if peer.id == context.peerId {
                infoText = strings().starNftGiftBuyConfirmSelf(gift.title, resellStars)
            } else {
                infoText = strings().starNftGiftBuyConfirm(gift.title, resellStars, peer._asPeer().displayTitle)
            }
            
            return ModalAlertData(title: strings().starNftGiftConfirmTitle, info: infoText, description: nil, ok: strings().starNftGiftConfirmOk(resellStars), options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: gift, toPeer: peer, context: context, transferType: .buy(onlyTon: gift.resellForTonOnly), buyForSelected: buyForSelected, callback: { updated in
                    buyForSelected = updated
                    modifyData?(getData())
                })
            }))
        }
        
        
        
        showModalAlert(for: window, data: getData(), completion: { result in
            
            let myBalance: StarsAmount
            if buyForSelected == .stars {
                myBalance = state.myBalance ?? .init(value: 0, nanos: 0)
            } else {
                myBalance = state.myTonBalance ?? .init(value: 0, nanos: 0)
            }
            
            let form = buyForSelected == .stars ? starsForm : tonForm
                        
            let fullAmount = form.invoice.prices.first?.amount ?? 0
            let resellAmount = CurrencyAmount(amount: StarsAmount.init(value: fullAmount, nanos: 0), currency: buyForSelected).fullyFormatted

            if fullAmount > myBalance.value {
                if buyForSelected == .ton {
                    showModal(with: AddTonBalanceController(context: context, tonAmount: fullAmount - myBalance.value), for: window)
                } else {
                    let sourceValue: Star_ListScreenSource =  .buy(suffix: nil, amount: fullAmount)
                    showModal(with: Star_ListScreen(context: context, source: sourceValue), for: window)
                }
            } else {
                _ = showModalProgress(signal: context.engine.payments.sendStarsPaymentForm(formId: form.id, source: .starGiftResale(slug: gift.slug, toPeerId: toPeerId, ton: buyForSelected == .ton)), for: window).startStandalone(next: { result in
                    switch result {
                    case let .done(receiptMessageId, subscriptionPeerId, _):
                        PlayConfetti(for: window, stars: true)
                        context.starsContext.load(force: true)
                        context.starsSubscriptionsContext.load(force: true)
                        giftsContext?.removeStarGift(gift: .unique(gift))
                        resaleContext?.removeStarGift(gift: .unique(gift))
                        
                        let successText: String
                        if peer.id == context.peerId {
                            successText = strings().starNftGiftBuySuccessSelf(gift.title, resellAmount)
                        } else {
                            successText = strings().starNftGiftBuySuccess(gift.title, resellAmount, peer._asPeer().displayTitle)
                        }
                        showModalText(for: window, text: successText)
                        
                        close?()
                    default:
                        break
                    }
                }, error: { error in
                    let text: String
                    switch error {
                    case .alreadyPaid:
                        text = strings().checkoutErrorInvoiceAlreadyPaid
                    case .generic:
                        text = strings().unknownError
                    case .paymentFailed:
                        text = strings().checkoutErrorPaymentFailed
                    case .precheckoutFailed:
                        text = strings().checkoutErrorPrecheckoutFailed
                    case .starGiftOutOfStock:
                        text = strings().giftSoldOutError
                    case .disallowedStarGift:
                        text = strings().giftSendDisallowError
                    case .starGiftUserLimit:
                        text = strings().giftOptionsGiftBuyLimitReached
                    }
                    showModalText(for: window, text: text)
                })
            }
        }, takeNewData: { f in
            modifyData = f
        })
        
//        verifyAlert(for: window, header: strings().starNftGiftConfirmTitle, information: infoText, ok: strings().starNftGiftConfirmOk(resellStars), successHandler: { _ in
//            
//            
//        })
        
    }

    let arguments = Arguments(context: context, dismiss:{
        let state = stateValue.with { $0 }
        switch state.source {
        case let .previewWear(owner, gift):
            updateState { current in
                var current = current
                current.source = .quickLook(owner, gift)
                current.converted = true
                return current
            }
        default:
            close?()
        }
    }, toggleName: {
        updateState { current in
            var current = current
            current.nameEnabled = !current.nameEnabled
            return current
        }
    }, transfer: {
        
        let state = stateValue.with { $0 }
        
        var additionalItem: SelectPeers_AdditionTopItem?
        
        
        var canExportDate: Int32? = nil
        var transferStars: Int64? = nil
        var convertStars: Int64? = nil
        var canTransferDate: Int32? = nil
        var reference: StarGiftReference? = nil
        if case let .starGift(_, _convertStars, _, _, _, _, _, _, _, _transferStars, _canExportDate, _reference, _, _, _, _canTransferDate) = state.purpose {
            canExportDate = _canExportDate
            transferStars = _transferStars
            convertStars = _convertStars
            reference = _reference
            canTransferDate = _canTransferDate
        }
        
        if let canTransferDate, canTransferDate > context.timestamp {
            alert(for: window, header: strings().giftTransferUnavailableTitle, info: strings().giftTransferUnavailableText(stringForFullDate(timestamp: canTransferDate)))
            return
        }
        
        
        if let canExportDate = canExportDate {
            additionalItem = .init(title: strings().giftTransferSendViaBlockchain, color: theme.colors.text, icon: NSImage(resource: .iconSendViaTon).precomposed(flipVertical: true), callback: {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                if currentTime > canExportDate, let unique = state.gift.unique, let reference {
                    
                    let data = ModalAlertData(title: nil, info: strings().giftWithdrawText(unique.title + " #\(unique.number)"), description: nil, ok: strings().giftWithdrawProceed, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                        return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: .init(context.myPeer!), context: context)
                    }))
                    
                    showModalAlert(for: window, data: data, completion: { result in
                        showModal(with: InputPasswordController(context: context, title: strings().giftWithdrawTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                            return context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: value)
                            |> deliverOnMainQueue
                            |> afterNext { url in
                                execute(inapp: .external(link: url, false))
                            }
                            |> ignoreValues
                            |> mapError { error in
                                switch error {
                                case .invalidPassword:
                                    return .wrong
                                case .limitExceeded:
                                    return .custom(strings().loginFloodWait)
                                case .generic:
                                    return .generic
                                default:
                                    return .custom(strings().monetizationWithdrawErrorText)
                                }
                            }
                        }), for: context.window)                        
                    })
                    
                } else {
                    let delta = canExportDate - currentTime
                    let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                    alert(for: window, header: strings().giftTransferUnlockPendingTitle, info: strings().giftTransferUnlockPendingText(strings().timerDaysCountable(Int(days))))
                }
            })
        }
        
        _ = selectModalPeers(window: window, context: context, title: strings().giftTransferTitle, behavior: SelectChatsBehavior(settings: [.excludeBots, .contacts, .remote, .channels], limit: 1, additionTopItem: additionalItem)).start(next: { peerIds in
            if let peerId = peerIds.first {
                let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
                
                _ = peer.startStandalone(next: { peer in
                    if let peer {
                                                
                        let info: String
                        let ok: String
                        
                        guard let reference = reference, let unique = state.gift.unique else {
                            return
                        }
                        
                        if let convertStars = convertStars, let starsState = state.starsState, starsState.balance.value < convertStars {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: convertStars)), for: window)
                            return
                        }
                        
                        if let stars = transferStars, stars > 0 {
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
                            _ = giftsContext.transferStarGift(prepaid: transferStars == nil, reference: reference, peerId: peerId).startStandalone()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                            close?()
                        })
                    }
                })
            }
        })
    }, copyNftLink: { gift in
        copyToClipboard(gift.link)
        showModalText(for: window, text: strings().contextAlertCopied)
    }, shareNft: { gift in
        showModal(with: ShareModalController(ShareLinkObject(context, link: gift.link)), for: window)
    }, sellNft: { gift, updatePrice in
        
        let state = stateValue.with { $0 }
        
        if case let .starGift(_, _, _, _, _, _, _, _, _, _, _, reference, _, _, _, canResaleDate) = state.purpose {
            if let _ = gift.resellStars(context), !updatePrice, let reference {
                verifyAlert(for: window, header: strings().giftUnlistConfirmTitle, information: strings().giftUnlistConfirmText, ok: strings().giftUnlistConfirmOk, successHandler: { _ in
                    _ = showModalProgress(signal: giftsContext.updateStarGiftResellPrice(reference: reference, price: nil, id: gift.id), for: window).startStandalone()
                })
            } else if let reference {
                
                if let canResaleDate, canResaleDate > context.timestamp {
                    alert(for: window, header: strings().giftResaleUnavailableTitle, info: strings().giftResaleUnavailableText(stringForFullDate(timestamp: canResaleDate)))
                    return
                }
                
                showModal(with: sellNft(context: context, resellPrice: gift.resellAmounts, defaultCurrency: gift.resellForTonOnly ? .ton : .stars, gift: gift, callback: { value in
                    if !updatePrice {
                        verifyAlert(for: window, header: strings().giftSellConfirmTitle, information: strings().giftSellConfirmText(gift.title, value.fullyFormatted), successHandler: { _ in
                            _ = showModalProgress(signal: giftsContext.updateStarGiftResellPrice(reference: reference, price: value, id: gift.id), for: window).startStandalone(error: { error in
                                switch error {
                                case let .starGiftResellTooEarly(value):
                                    showModalText(for: window, text: strings().giftResaleUnavailableText(stringForFullDate(timestamp: value)))
                                default:
                                    break
                                }
                            }, completed: {
                                showModalText(for: window, text: strings().giftResaleSetSuccess)
                            })
                        })
                    } else {
                        _ = showModalProgress(signal: giftsContext.updateStarGiftResellPrice(reference: reference, price: value, id: gift.id), for: window).startStandalone(completed: {
                            showModalText(for: window, text: strings().giftResalePriceUpdate)
                        })
                    }
                }), for: window)
            }
        }
        
    }, toggleWear: { gift in
        
        let weared = stateValue.with { $0.weared }
        let owner = stateValue.with { $0.owner }
        

        if weared, let owner {
            context.reactions.setStatus(gift.file!, peer: owner._asPeer(), timestamp: context.timestamp, timeout: nil, fromRect: nil)
        } else if let owner {
            updateState { current in
                var current = current
                switch current.source {
                case .previewWear(_, _):
                    current.source = .quickLook(owner, gift)
                    current.converted = true
                default:
                    if current.weared {
                        current.source = .quickLook(owner, gift)
                        current.converted = true
                    } else {
                        current.source = .previewWear(owner, gift)
                        current.converted = false
                    }
                }
                return current
            }
        }
    }, togglePin: { [weak giftsContext] in
        let pinnedInfo = stateValue.with { $0.pinnedInfo }
        if let pinnedInfo {
            giftsContext?.updateStarGiftPinnedToTop(reference: pinnedInfo.reference, pinnedToTop: !pinnedInfo.pinnedInfo)
            updateState { current in
                var current = current
                current.pinnedInfo = .init(pinnedInfo: !pinnedInfo.pinnedInfo, reference: pinnedInfo.reference)
                return current
            }
            showModalText(for: window, text: !pinnedInfo.pinnedInfo ? strings().giftTooltipPinned : strings().giftTooltipUnpinned)
        }
    }, openPeer: { peer, toChat in
        close?()
        if toChat {
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peer.id)))
        } else {
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peer.id)
        }
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
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.tonAddress = data[_id_ton_input]?.stringValue
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
    
    controller.validateData = { [weak giftsContext] _ in
        
        let state = stateValue.with { $0 }
        let closeOnOk = stateValue.with { $0.closeOnOk }
        
        guard let starsState = state.starsState else {
            return .none
        }
        
        switch state.source {
        case .preview:
            close?()
        case let .quickLook(peer, gift):
            if let purpose = state.purpose {
                switch purpose {
                case let.starGift(_, _, _, _, _, savedToProfile, _, _, _, _, _, reference, _, _, _, _):
                    if let reference {
                        var canManage: Bool
                        let peer = peer ?? state.owner
                        
                        if let peer, peer._asPeer().groupAccess.canManageGifts || peer.id == context.peerId {
                            canManage = true
                        } else {
                            canManage = false
                        }
                        if canManage {
                            giftsContext?.updateStarGiftAddedToProfile(reference: reference, added: !savedToProfile)
                        }
                        close?()
                    } else if let _ = gift.resellStars(context) {
                        let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: toPeerId)) |> deliverOnMainQueue
                        
                        
                        let formAndMaybeValidatedInfo_Stars: Signal<BotPaymentForm?, BotPaymentFormRequestError>
                        if gift.resellForTonOnly {
                            formAndMaybeValidatedInfo_Stars = .single(nil)
                        } else {
                            formAndMaybeValidatedInfo_Stars = context.engine.payments.fetchBotPaymentForm(source: .starGiftResale(slug: gift.slug, toPeerId: toPeerId, ton: false), themeParams: nil)
                            |> map(Optional.init)
                        }
                        
                        
                        
                        let formAndMaybeValidatedInfo_Ton = context.engine.payments.fetchBotPaymentForm(source: .starGiftResale(slug: gift.slug, toPeerId: toPeerId, ton: true), themeParams: nil)

                        _ = showModalProgress(signal: combineLatest(signal |> castError(BotPaymentFormRequestError.self), formAndMaybeValidatedInfo_Stars, formAndMaybeValidatedInfo_Ton), for: window).start(next: { peer, starsForm, tonForm in
                            if let peer {
                                buyResellGift(gift, peer, starsForm ?? tonForm, tonForm)
                            }
                            
                        })
                    } else {
                        close?()
                    }
                default:
                    close?()
                }
            } else {
                close?()
            }
        case let .previewWear(peer, gift):
            
            let owner = stateValue.with { $0.owner }
            
            if let owner = owner?._asPeer() {
                if let channel = owner as? TelegramChannel {
                    let approximateBoostLevel = channel.approximateBoostLevel ?? 0
                    let boostNeeded = BoostSubject.wearGift.requiredLevel(context: context, group: false, configuration: .with(appConfiguration: context.appConfiguration))
                    if boostNeeded > approximateBoostLevel {
                        let signal = showModalProgress(signal: combineLatest(context.engine.peers.getChannelBoostStatus(peerId: channel.id), context.engine.peers.getMyBoostStatus()), for: window)
                        _ = signal.start(next: { stats, myStatus in
                            if let stats = stats {
                                showModal(with: BoostChannelModalController(context: context, peer: channel, boosts: stats, myStatus: myStatus, infoOnly: false, source: .wearStatus, presentation: theme), for: window)
                            }
                        })
                        return .none
                    }
                } else if !owner.isPremium {
                    showModalText(for: context.window, text: strings().giftUniqueNeedsPremium, callback: { _ in
                        prem(with: PremiumBoardingController(context: context, source: .emoji_status, openFeatures: true), for: context.window)
                    })
                    return .none
                }
            }
            updateState { current in
                var current = current
                current.source = .quickLook(peer, gift)
                current.converted = true
                return current
            }
            if let owner, owner._asPeer().isChannel {
                let _ = context.engine.peers.updatePeerStarGiftStatus(peerId: owner.id, starGift: gift, expirationDate: nil).startStandalone()
            } else {
                _ = context.engine.accountData.setStarGiftStatus(starGift: gift, expirationDate: nil).start()
            }
            PlayConfetti(for: window)
        case let .upgrade(_, _, reference):
            
            if let upgradeStars = gift.generic?.upgradeStars, starsState.balance.value < upgradeStars {
                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: upgradeStars)), for: window)
                return .none
            }
            
            let signal = context.engine.payments.upgradeStarGift(formId: state.upgradeForm?.id, reference: reference, keepOriginalInfo: state.nameEnabled) |> deliverOnMainQueue
            
            _ = showModalProgress(signal: signal, for: window).startStandalone(next: { converted in
                updateState { current in
                    var current = current
                    current.gift = converted.gift
                    
                    current.purpose = .starGift(gift: converted.gift, convertStars: converted.convertStars, text: converted.text, entities: converted.entities, nameHidden: converted.nameHidden, savedToProfile: converted.savedToProfile, converted: true, fromProfile: false, upgraded: true, transferStars: converted.transferStars, canExportDate: converted.canExportDate, reference: converted.reference, sender: nil, saverId: nil, canTransferDate: converted.canTransferDate, canResaleDate: converted.canResaleDate)
                    
                    current.converted = true
                    switch converted.gift {
                    case let .unique(gift):
                        current.source = .quickLook(nil, gift)
                        current.attributes = gift.attributes
                    default:
                        break
                    }
                    return current
                }
                PlayConfetti(for: window)
                giftsContext?.reload()
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
            button.set(text: stateValue.with { $0.okText(context) }, for: .Normal)
        }
    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}





private final class SellNftArguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState: (Updated_ChatTextInputState)->Void
    let toggleOnlyTon:()->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState: @escaping(Updated_ChatTextInputState)->Void, toggleOnlyTon:@escaping()->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        self.toggleOnlyTon = toggleOnlyTon
    }
}


private final class SellNftInputItem : GeneralRowItem {
    let inputState: Updated_ChatTextInputState
    let arguments: SellNftArguments
    let interactions: TextView_Interactions
    let currency: CurrencyAmount.Currency
    
    let usdLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, value: Int64, inputState: Updated_ChatTextInputState, currency: CurrencyAmount.Currency, arguments: SellNftArguments) {
        self.currency = currency
        self.inputState = inputState
        self.arguments = arguments
        self.interactions = arguments.interactions
        
        let usd_rate: Double
        switch currency {
        case .ton:
            usd_rate = arguments.context.appConfiguration.getGeneralValueDouble("ton_usd_rate", orElse: 3)
        case .stars:
            usd_rate = arguments.context.appConfiguration.getGeneralValueDouble("star_usd_rate", orElse: 0.013)
        }
        
        let string: String
        if value > 0 {
            string = "~$\("\((Double(value) * usd_rate))".prettyCurrencyNumberUsd)"
        } else {
            string = ""
        }
        
        self.usdLayout = .init(.initialize(string: string, color: theme.colors.grayText, font: .normal(.short)))
        self.usdLayout.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, stableId: stableId)
        
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return SellNftInputView.self
    }
}


private final class SellNftInputView : GeneralRowView {
    
    private final class Input : View {
        
        private weak var item: SellNftInputItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        private let usdView = TextView()
        private let starView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(starView)
            addSubview(inputView)
            addSubview(usdView)

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: SellNftInputItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.background
            
            let attr = NSMutableAttributedString()
            attr.append(string: clown)
            switch item.currency {
            case .stars:
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            case .ton:
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file), for: clown)
            }
            
            let layout = TextViewLayout(attr)
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.starView.set(text: layout, context: item.arguments.context)
            self.usdView.update(item.usdLayout)
            

            
            inputView.placeholder = strings().fragmentStarAmountPlaceholder
            
            inputView.context = item.arguments.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            
            let value = Int64(item.inputState.string) ?? 0
            
            let min_resale: Double
            let max_resale: Double
            
            switch item.currency {
            case .stars:
                min_resale = item.arguments.context.appConfiguration.getGeneralValueDouble("stars_stargift_resale_amount_min", orElse: 125)
                max_resale = item.arguments.context.appConfiguration.getGeneralValueDouble("stars_stargift_resale_amount_max", orElse: 100000)
            case .ton:
                min_resale = item.arguments.context.appConfiguration.getGeneralValueDouble("ton_stargift_resale_amount_min", orElse: 1) / 1_000_000_000
                max_resale = item.arguments.context.appConfiguration.getGeneralValueDouble("ton_stargift_resale_amount_max", orElse: 10000) / 1_000_000_000
            }

            inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(Double(value) < min_resale || Double(value) > max_resale ? theme.colors.redUI : theme.colors.text)
            
            
            item.interactions.filterEvent = { event in
                if let chars = event.characters {
                    return chars.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890\u{7f}")).isEmpty
                } else {
                    return false
                }
            }

            self.inputView.set(item.interactions.presentation.textInputState())

            self.inputView.interactions = item.interactions
            
            item.interactions.inputDidUpdate = { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.set(state)
                self.inputDidUpdateLayout(animated: true)
            }
            
        }
        
        
        var textWidth: CGFloat {
            return frame.width - 20
        }
        
        func textViewSize() -> (NSSize, CGFloat) {
            let w = textWidth
            let height = inputView.height(for: w)
            return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
        }
        
        private func inputDidUpdateLayout(animated: Bool) {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            let (textSize, textHeight) = textViewSize()
            
            transition.updateFrame(view: starView, frame: starView.centerFrameY(x: 10))
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: starView.frame.maxX + 10, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
            
            ContainedViewLayoutTransition.immediate.updateFrame(view: usdView, frame: usdView.centerFrameY(x: size.width - usdView.frame.width - 10))
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.arguments.updateState(state)
            
            item.redraw(animated: true)
        }
    }
    
    private let inputView = Input(frame: NSMakeRect(0, 0, 40, 40))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
    }
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SellNftInputItem else {
            return
        }
        
        self.inputView.update(item: item, animated: animated)
        
               
        self.inputView.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func shakeView() {
        inputView.shake(beep: true)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(20, 0, size.width - 40,40))
        inputView.updateLayout(size: inputView.frame.size, transition: transition)
        
    }
    override var firstResponder: NSResponder? {
        return inputView.inputView.inputView
    }
}

private struct SellNftState : Equatable {
    
    var inputState: Updated_ChatTextInputState = .init()
    
    var floorPrice: Int64?
    var currency: CurrencyAmount.Currency = .stars
    
    var value: Int64 {
        if let value = Int64(inputState.string) {
            return value
        } else {
            return 0
        }
    }
    
    func amount(comission: Double) -> StarsAmount {
        switch self.currency {
        case .stars:
            return .init(value: Int64((Double(self.value) * comission)), nanos: 0)
        case .ton:
            return .init(value: Int64((Double(self.value) * comission) * 1_000_000_000), nanos: 0)
        }
    }
}


private let _id_input = InputDataIdentifier("_id_input")
private let _id_only_ton = InputDataIdentifier("_id_only_ton")

private func sellNftEntries(_ state: SellNftState, arguments: SellNftArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().starNftSellHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return SellNftInputItem(initialSize, stableId: stableId, value: state.value, inputState: state.inputState, currency: state.currency, arguments: arguments)
    }))
    
    let comission: Double
    switch state.currency {
    case .stars:
        comission = arguments.context.appConfiguration.getGeneralValue("stars_stargift_resale_commission_permille", orElse: 800).decemial / 100.0
    case .ton:
        comission = arguments.context.appConfiguration.getGeneralValue("ton_stargift_resale_commission_permille", orElse: 800).decemial / 100.0
    }
    
    
    var text: String
    if state.value == 0 {
        text = strings().starNftSellInfo("\(comission * 100.0)%")
    } else {
        let amount: Int64

        let currency = CurrencyAmount(amount: state.amount(comission: comission), currency: state.currency)
        text = strings().starNftSellInfo(currency.fullyFormatted)
    }
    
   
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { _ in }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(
        sectionId: sectionId,
        index: index,
        value: .none,
        error: nil,
        identifier: _id_only_ton,
        data: .init(
            name: strings().starSellTonOnlyAccept,
            color: theme.colors.text,
            type: .switchable(state.currency == .ton),
            viewType: .singleItem,
            action: arguments.toggleOnlyTon
        )
    ))

    entries.append(.desc(
        sectionId: sectionId,
        index: index,
        text: .plain(strings().starSellTonDescription),
        data: .init(
            color: theme.colors.listGrayText,
            viewType: .textBottomItem
        )
    ))

    index += 1


    
    if let floorPrice = state.floorPrice {
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
        
        let text = strings().starNftSellFloor(strings().starListItemCountCountable(Int(floorPrice)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { _ in }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}



private func sellNft(context: AccountContext, resellPrice: [CurrencyAmount]?, defaultCurrency: CurrencyAmount.Currency, gift: StarGift.UniqueGift, callback:@escaping(CurrencyAmount)->Void) -> InputDataModalController {
    
    
    
    let string: String
    if let resellPrice = resellPrice {
        switch defaultCurrency {
        case .stars:
            if let currency = resellPrice.first(where: { $0.currency == .stars }) {
                string = currency.formatted.numeralFormat()
            } else {
                string = ""
            }
        case .ton:
            if let currency = resellPrice.first(where: { $0.currency == .ton }) {
                string = currency.formatted.numeralFormat()
            } else {
                string = ""
            }
        }
    } else {
        string = ""
    }
    
    
    let initialState = SellNftState(inputState: .init(inputText: .initialize(string: string)), currency: defaultCurrency)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SellNftState) -> SellNftState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    



    let actionsDisposable = DisposableSet()
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
        
    let interactions = TextView_Interactions(presentation: initialState.inputState)
    
    actionsDisposable.add(context.engine.payments.cachedStarGifts().start(next: { gifts in
        updateState { current in
            var current = current
            current.floorPrice = gifts?.first(where: { $0.generic?.title == gift.title })?.generic?.availability?.minResaleStars
            return current
        }
    }))

    let arguments = SellNftArguments(context: context, interactions: interactions, updateState: { [weak interactions] value in
        
        interactions?.update { _ in
            return value
        }
        updateState { current in
            var current = current
            current.inputState = value
            return current
        }
    }, toggleOnlyTon: {
        updateState { current in
            var current = current
            switch current.currency {
            case .ton:
                current.currency = .stars
            case .stars:
                current.currency = .ton
            }
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: sellNftEntries(state, arguments: arguments))
    }
    
    

    
    let controller = InputDataController(dataSignal: signal, title: strings().starNftSellTitle)
    
    controller.validateData = { _ in
        
        let state = stateValue.with { $0 }
        
        let min_resale: Double
        let max_resale: Double
        
        switch state.currency {
        case .stars:
            min_resale = context.appConfiguration.getGeneralValueDouble("stars_stargift_resale_amount_min", orElse: 125)
            max_resale = context.appConfiguration.getGeneralValueDouble("stars_stargift_resale_amount_max", orElse: 100000)
        case .ton:
            min_resale = context.appConfiguration.getGeneralValueDouble("ton_stargift_resale_amount_min", orElse: 1) / 1_000_000_000
            max_resale = context.appConfiguration.getGeneralValueDouble("ton_stargift_resale_amount_max", orElse: 10000) / 1_000_000_000
        }
        
        let value = state.value
        
        if Double(value) < min_resale || Double(value) > max_resale {
            return .fail(.fields([_id_input : .shake]))
        }
                
        callback(.init(amount: state.amount(comission: 1), currency: state.currency))
        close?()
        return .none
    }
        
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
   
    
    let modalInteractions = ModalInteractions(acceptTitle: resellPrice != nil ? strings().starNftSellButtonUpdate : strings().starNftSellButtonSell, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)

    
    
    actionsDisposable.add(statePromise.get().startStrict(next: { [weak modalInteractions] state in
        DispatchQueue.main.async {
            modalInteractions?.updateDone { button in
                button.isEnabled = true
            }
        }
    }))
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    
    return modalController
}
