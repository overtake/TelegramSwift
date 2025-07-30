//
//  Untitled.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class LevelRowItem : GeneralRowItem {
    fileprivate let rating: TelegramStarRating
    init(_ initialSize: NSSize, stableId: AnyHashable, rating: TelegramStarRating) {
        self.rating = rating
        super.init(initialSize, height: 30 + 48, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return LevelRowView.self
    }
}

private final class LevelRowView : GeneralRowView {
    
    
    private final class BadgeView : View {
        private let shapeLayer = SimpleShapeLayer()
        private let foregroundLayer = SimpleGradientLayer()
        private let textView = InteractiveTextView()
        private let container = View()
        private let crownView = ImageView()
        
        private(set) var tailPosition: CGFloat = 0.0
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            textView.userInteractionEnabled = false
            
            foregroundLayer.colors = [theme.colors.accent, theme.colors.accent].map { $0.cgColor }
            foregroundLayer.startPoint = NSMakePoint(0, 0.5)
            foregroundLayer.endPoint = NSMakePoint(1, 0.2)
            foregroundLayer.mask = shapeLayer
            
            
            self.layer?.masksToBounds = false
            self.foregroundLayer.masksToBounds = false
            
            
            self.layer?.addSublayer(foregroundLayer)


            self.layer?.masksToBounds = false
            
            shapeLayer.fillColor = NSColor.red.cgColor
            shapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            

            
            container.addSubview(textView)
            addSubview(container)
            container.layer?.masksToBounds = false
        }
        
        func update(sliderValue: Int64, realValue: Int64, nextValue: Int64?, max maxValue: Int64) -> NSSize {
            
            
            let attr = NSMutableAttributedString()
            attr.append(string: "\(realValue.prettyNumber)", color: theme.colors.underSelectedColor, font: .medium(16))
            
            if let nextValue {
                attr.append(string: " / \(nextValue.prettyNumber)", color: theme.colors.underSelectedColor.withAlphaComponent(0.6), font: .normal(14))
            }
            let textLayout = TextViewLayout(attr)
            textLayout.measure(width: .greatestFiniteMagnitude)
            self.textView.set(text: textLayout, context: nil)

            
            container.setFrameSize(NSMakeSize(container.subviewsWidthSize.width + 2, container.subviewsWidthSize.height))
            
            self.tailPosition = max(0, min(1, CGFloat(sliderValue) / CGFloat(maxValue)))
                    
            let size = NSMakeSize(container.frame.width + 30, frame.height)
            
            
            foregroundLayer.frame = size.bounds.insetBy(dx: 0, dy: -10)
            shapeLayer.frame = foregroundLayer.frame.focus(size)
            
            shapeLayer.path = generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPosition)._cgPath
            
            return size
            
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: container, frame: container.centerFrameX(y: 1))

            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: -3))
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
         //   shapeLayer.frame = bounds
        }
    }

    private class LineView : View {
        private var rating: TelegramStarRating?
        private let limitedView = TextView()
        private let totalView = TextView()
        
        private let limitColorMask = SimpleLayer()
        private let totalColorMask = SimpleLayer()
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.layer?.cornerRadius = 10
            addSubview(limitedView)
            addSubview(totalView)
            
            self.layer?.addSublayer(self.limitColorMask)
            self.layer?.addSublayer(self.totalColorMask)
            
            limitedView.userInteractionEnabled = false
            limitedView.isSelectable = false
            
            totalView.userInteractionEnabled = false
            totalView.isSelectable = false
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            guard let rating else {
                return
            }
            
            let percent = CGFloat(rating.currentLevelStars) / CGFloat(rating.nextLevelStars ?? rating.currentLevelStars)
            
            ctx.setFillColor(theme.colors.grayForeground.cgColor)
            ctx.fill(bounds)
            
            
            ctx.setFillColor(theme.colors.accent.cgColor)
            ctx.fill(NSMakeRect(0, 0, bounds.width * percent, bounds.height))
            
        }
        
        func set(rating: TelegramStarRating) {
            self.rating = rating
            needsDisplay = true
            
            
            
            
            let limitedLayout = TextViewLayout(
                .initialize(
                    string: strings().peerRatingPreviewLevel(Int(rating.level)),
                    color: .white,
                    font: .medium(.text)
                )
            )
            limitedLayout.measure(width: .greatestFiniteMagnitude)
            self.limitedView.update(limitedLayout)
            
            
            let percent = CGFloat(rating.currentLevelStars) / CGFloat(rating.nextLevelStars ?? rating.currentLevelStars)

            let w = frame.width * percent

            limitColorMask.contents = generateImage(limitedLayout.layoutSize, contextGenerator: { size, ctx in
                let width = w - 10
                ctx.setFillColor(theme.colors.underSelectedColor.cgColor)
                ctx.fill(NSMakeRect(0, 0, width, size.height))
                
                ctx.setFillColor(theme.colors.grayIcon.cgColor)
                ctx.fill(NSMakeRect(width, 0, size.width - width, size.height))
            })
            
            limitColorMask.mask = self.limitedView.drawingLayer
            
            let nextLevel: String

            if let _ = rating.nextLevelStars {
                nextLevel = strings().peerRatingPreviewNextLevel(Int(rating.level) + 1)
            } else {
                nextLevel = ""
            }
                        
            let totalLayout = TextViewLayout(.initialize(string: nextLevel, color: .white, font: .medium(.text)))
            totalLayout.measure(width: .greatestFiniteMagnitude)
            self.totalView.update(totalLayout)
            
            totalColorMask.contents = generateImage(totalLayout.layoutSize, contextGenerator: { size, ctx in
                let minx = frame.width - 10 - size.width
                
                let width = max(0,  w - minx)
                ctx.setFillColor(theme.colors.underSelectedColor.cgColor)
                ctx.fill(NSMakeRect(0, 0, width, size.height))
                
                ctx.setFillColor(theme.colors.grayIcon.cgColor)
                ctx.fill(NSMakeRect(width, 0, size.width - width, size.height))
                
            })
            
            totalColorMask.mask = self.totalView.drawingLayer

        }
        
        override func layout() {
            super.layout()
            limitedView.centerY(x: 10)
            limitColorMask.frame = limitedView.frame
            self.totalView.centerY(x: frame.width - totalView.frame.width - 10)
            self.totalColorMask.frame = totalView.frame
        }
    }
    
    private let lineView = LineView(frame: .zero)
    private let badgeView = BadgeView(frame: NSMakeSize(100, 30).bounds)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(lineView)
        addSubview(badgeView)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LevelRowItem else {
            return
        }
        
        let rating = item.rating

        lineView.frame = NSMakeRect(20, frame.height - 30, frame.width - 40, 30)

        lineView.set(rating: item.rating)
        let size = badgeView.update(sliderValue: rating.currentLevelStars, realValue: rating.currentLevelStars, nextValue: rating.nextLevelStars, max: rating.nextLevelStars ?? rating.currentLevelStars)
        badgeView.setFrameSize(size)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? LevelRowItem else {
            return
        }
        
        let rating = item.rating
        let percent = CGFloat(rating.currentLevelStars) / CGFloat(rating.nextLevelStars ?? rating.currentLevelStars)

        let w = floorToScreenPixels(percent * (frame.width - 40))
        
        badgeView.setFrameOrigin(NSMakePoint(20 + w - badgeView.frame.width * badgeView.tailPosition, 10))

        lineView.frame = NSMakeRect(20, frame.height - 30, frame.width - 40, 30)
        
    }
    
}



private final class RowItem : GeneralRowItem {
    
    struct Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        let width: CGFloat
        let infoImage: CGImage
        init(image: CGImage, header: TextViewLayout, text: TextViewLayout, width: CGFloat, infoImage: CGImage) {
            self.image = image
            self.header = header
            self.text = text
            self.width = width
            self.infoImage = infoImage
            self.header.measure(width: width - 40)
            self.text.measure(width: width - 40)
        }
        var size: NSSize {
            return NSMakeSize(width, header.layoutSize.height + 5 + text.layoutSize.height)
        }
    }
    let context: AccountContext
    let headerLayout: TextViewLayout
    
    let options: [Option]

    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, context: AccountContext) {
        self.context = context
        
        let headerText = NSAttributedString.initialize(
            string: peer.id == context.peerId ? strings().peerRatingPreviewInfoHeaderYou : strings().peerRatingPreviewInfoHeader(peer._asPeer().compactDisplayTitle),
            color: theme.colors.text,
            font: .medium(.title)
        ).detectBold(with: .medium(.title))
        
        
                                                                                    
        self.headerLayout = .init(headerText, alignment: .center)
        self.headerLayout.measure(width: initialSize.width - 40)
                
        var options:[Option] = []
        
        
        let infoImage_1 = generateTextIcon_AccentBadge(
            text: strings().peerRatingPreviewBadgeAdded,
            bgColor: theme.colors.accent,
            textColor: theme.colors.underSelectedColor
        )

        let infoImage_2 = generateTextIcon_AccentBadge(
            text: strings().peerRatingPreviewBadgeAdded,
            bgColor: theme.colors.accent,
            textColor: theme.colors.underSelectedColor
        )

        let infoImage_3 = generateTextIcon_AccentBadge(
            text: strings().peerRatingPreviewBadgeDeducted,
            bgColor: theme.colors.grayForeground,
            textColor: theme.colors.underSelectedColor
        )

        options.append(.init(
            image: NSImage(resource: .iconChannelGift).precomposed(theme.colors.accent),
            header: .init(.initialize(
                string: strings().peerRatingPreviewTelegramHeader,
                color: theme.colors.text,
                font: .medium(.text)
            )),
            text: .init(.initialize(
                string: strings().peerRatingPreviewTelegramText("100%"),
                color: theme.colors.grayText,
                font: .normal(.text)
            ), cutout: .init(topLeft: NSMakeSize(infoImage_1.backingSize.width + 5, 20))),
            width: initialSize.width - 40,
            infoImage: infoImage_1
        ))

        options.append(.init(
            image: NSImage(resource: .iconGiftStars).precomposed(theme.colors.accent),
            header: .init(.initialize(
                string: strings().peerRatingPreviewUsersHeader,
                color: theme.colors.text,
                font: .medium(.text)
            )),
            text: .init(.initialize(
                string: strings().peerRatingPreviewUsersText("20%"),
                color: theme.colors.grayText,
                font: .normal(.text)
            ), cutout: .init(topLeft: NSMakeSize(infoImage_2.backingSize.width + 5, 20))),
            width: initialSize.width - 40,
            infoImage: infoImage_2
        ))

        options.append(.init(
            image: NSImage(resource: .iconStarRefund).precomposed(theme.colors.accent),
            header: .init(.initialize(
                string: strings().peerRatingPreviewRefundsHeader,
                color: theme.colors.text,
                font: .medium(.text)
            )),
            text: .init(.initialize(
                string: strings().peerRatingPreviewRefundsText("85%"),
                color: theme.colors.grayText,
                font: .normal(.text)
            ), cutout: .init(topLeft: NSMakeSize(infoImage_3.backingSize.width + 5, 20))),
            width: initialSize.width - 40,
            infoImage: infoImage_3
        ))

        self.options = options

        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += headerLayout.layoutSize.height
        height += 20
        for (i, option) in options.enumerated() {
            height += option.size.height
            if i != options.count - 1 {
                height += 20
            }
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
        private let infoImage = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(titleView)
            addSubview(infoView)
            addSubview(infoImage)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            infoView.userInteractionEnabled = false
            infoView.isSelectable = false
        }
        
        func update(option: RowItem.Option) {
            self.titleView.update(option.header)
            self.infoView.update(option.text)
            self.imageView.image = option.image
            self.imageView.sizeToFit()
            
            infoImage.image = option.infoImage
            infoImage.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            titleView.setFrameOrigin(NSMakePoint(40, 0))
            infoView.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
            infoImage.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
        }
 
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
        
    private let optionsView = View()
    private let headerView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        
        addSubview(optionsView)
        
        headerView.isSelectable = false
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        headerView.centerX(y: 0)
        
        optionsView.centerX(y: headerView.frame.maxY + 20)
        
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 20
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? RowItem else {
            return
        }
        
        headerView.update(item.headerLayout)

        
        
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
        
        
        needsLayout = true
    }
}


private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var rating: TelegramStarRating
    var peer: EnginePeer
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("line"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return LevelRowItem(initialSize, stableId: stableId, rating: state.rating)
    }))
    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("The rating updates in 21 days after purchases. 345 points are pending."), data: .init(color: theme.colors.listGrayText, centerViewAlignment: true, alignment: .center)))
//    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("info"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, stableId: stableId, peer: state.peer, context: arguments.context)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PeerRatingModalController(context: AccountContext, peer: Peer, rating: TelegramStarRating) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(rating: rating, peer: .init(peer))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(
        dataSignal: signal,
        title: strings().peerRatingPreviewTitle
    )
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.validateData = { _ in
        close?()
        return .none
    }
    
    let modalInteractions = ModalInteractions(
        acceptTitle: strings().peerRatingPreviewAccept,
        accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        },
        singleButton: true
    )

    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}

