//
//  Star_ReactionsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit

private let gradient = [NSColor(0xFFAC04), NSColor(0xFFCA35)]

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let react:()->Void
    let updateValue:(Int64)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, react:@escaping()->Void, updateValue:@escaping(Int64)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.react = react
        self.updateValue = updateValue
    }
}

private struct State : Equatable {
    var myBalance: Int64 = 1000
    var count: Int64 = 1
}


private final class HeaderItem : GeneralRowItem {
    
    fileprivate struct Sender : Equatable {
        let titleLayout: TextViewLayout
        let amountLayout: TextViewLayout
        let peer: EnginePeer
        let amount: Int64
    }
    
    fileprivate let context: AccountContext
    fileprivate let state: State
    fileprivate let close:()->Void
    fileprivate let updateValue:(Int64)->Void
    
    let maxValue: Int64
    
    fileprivate let balanceLayout: TextViewLayout
    fileprivate let headerLayout: TextViewLayout
    fileprivate let info: TextViewLayout
    
    fileprivate var senders: [Sender] = []

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: State, viewType: GeneralViewType, updateValue:@escaping(Int64)->Void, action:@escaping()->Void, close:@escaping()->Void) {
        self.context = context
        self.state = state
        self.close = close
        self.updateValue = updateValue
        self.maxValue = Int64(context.appConfiguration.getGeneralValue("stars_paid_reaction_amount_max", orElse: 1))
        let balanceAttr = NSMutableAttributedString()
        balanceAttr.append(string: strings().starPurchaseBalance("\(clown + TINY_SPACE)\(state.myBalance)"), color: theme.colors.text, font: .normal(.text))
        balanceAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        
        self.balanceLayout = .init(balanceAttr, alignment: .right)
        
        //TODOLANG
        self.headerLayout = .init(.initialize(string: "React with Stars", color: theme.colors.text, font: .medium(.title)), alignment: .center)
        
        
        let attr = NSMutableAttributedString()
        attr.append(string: "Choose how many stars you want to send to **MeowArts** to support this post.", color: theme.colors.text, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        self.info = .init(attr, alignment: .center)
        
        for i in 0 ..< 3 {
            let peer = EnginePeer(context.myPeer!)
            let amount = Int64.random(in: 100...100000)
            
            senders.append(.init(titleLayout: .init(.initialize(string: peer._asPeer().compactDisplayTitle, color: theme.colors.text, font: .normal(.text))), amountLayout: .init(.initialize(string: "\(amount.prettyNumber)", color: .white, font: .medium(.short))), peer: peer, amount: amount))
        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action, inset: .init())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.balanceLayout.measure(width: .greatestFiniteMagnitude)

        self.headerLayout.measure(width: width - 40 - balanceLayout.layoutSize.width)
        self.info.measure(width: width - 40)
        
        
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 50 + (48 + 12) + 10 + 30 + info.layoutSize.height + 10 + 40 + 10 + 10
        
        if !senders.isEmpty {
            height += sendersHeight + 20
        }
        return height
    }
    
    var sendersHeight: CGFloat {
        return 20 + 36 + 20 + 80
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class AcceptView : Control {
    private let textView = InteractiveTextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        layer?.cornerRadius = 10
        scaleOnClick = true
        self.set(background: theme.colors.accent, for: .Normal)
        
        textView.userInteractionEnabled = false
        
    }
    
    func update(_ item: HeaderItem, animated: Bool) {
        let attr = NSMutableAttributedString()
        
        //TODOLANG
        attr.append(string: "Send \("\(XTRSTAR)\(TINY_SPACE)\(item.state.count)")", color: theme.colors.underSelectedColor, font: .medium(.text))
        attr.insertEmbedded(.embedded(name: XTR_ICON, color: theme.colors.underSelectedColor, resize: false), for: XTRSTAR)
        
        let layout = TextViewLayout(attr)
        layout.measure(width: item.width - 60)
        
        textView.set(text: layout, context: item.context)
        
        self.removeAllHandlers()
        self.set(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }
}

private final class SendersView: View {
    
    private class BadgeView : View {
        private let container: View = View()
        private let gradientLayer = SimpleGradientLayer()
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            
            container.layer?.addSublayer(gradientLayer)
            
            container.addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            //TODOLANG
            let layout = TextViewLayout(.initialize(string: "Top Senders", color: NSColor.white, font: .medium(.text)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            self.textView.update(layout)
            
            container.setFrameSize(NSMakeSize(textView.frame.width + 20, frameRect.height))
            container.layer?.cornerRadius = container.frame.height / 2
            
            gradientLayer.colors = gradient.map { $0.cgColor }
            gradientLayer.startPoint = NSMakePoint(0, 0.5)
            gradientLayer.endPoint = NSMakePoint(1, 0.5)
            
            gradientLayer.frame = container.bounds
        }
        
        override func layout() {
            super.layout()
            textView.center()
            container.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(10, frame.height / 2, container.frame.minX - 20, .borderSize))
            ctx.fill(NSMakeRect(container.frame.maxX + 10, frame.height / 2, container.frame.minX - 20, .borderSize))

        }
    }
    
    private final class PeerView : Control {
        private let avatarView = AvatarControl(font: .avatar(18))
        private let nameView = TextView()
        
        private let badgeView = View()
        private let amountView = InteractiveTextView()
        private let amountIcon = ImageView()
        private let badgeGradient = SimpleGradientLayer()
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.avatarView.setFrameSize(70, 70)
            addSubview(avatarView)
            self.badgeView.layer?.addSublayer(badgeGradient)
            self.badgeView.addSubview(amountView)
            self.badgeView.addSubview(amountIcon)
            addSubview(self.badgeView)
            addSubview(nameView)
            
            badgeGradient.colors = gradient.map { $0.cgColor }
            badgeGradient.startPoint = NSMakePoint(0, 0.5)
            badgeGradient.endPoint = NSMakePoint(1, 0.5)
            
            
            nameView.userInteractionEnabled = false
            nameView.isSelectable = false
            self.layer?.masksToBounds = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ sender: HeaderItem.Sender, context: AccountContext, animated: Bool) {
            self.avatarView.setPeer(account: context.account, peer: sender.peer._asPeer())
            
            sender.titleLayout.measure(width: frame.width + 20)
            nameView.update(sender.titleLayout)
            
            sender.amountLayout.measure(width: .greatestFiniteMagnitude)
            amountView.set(text: sender.amountLayout, context: context)
            
            badgeView.layer?.borderColor = theme.colors.background.cgColor
            badgeView.layer?.borderWidth = 2
            
            amountIcon.image = NSImage(resource: .iconPeerPremium).precomposed(NSColor.white, zoom: 0.875)
            amountIcon.sizeToFit()
            
            badgeView.setFrameSize(NSMakeSize(amountView.frame.width + 14 + amountIcon.frame.width, amountView.frame.height + 5))
            badgeView.layer?.cornerRadius = badgeView.frame.height / 2
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            nameView.centerX(y: frame.height - nameView.frame.height)
            badgeView.centerX(y: avatarView.frame.maxY - floorToScreenPixels(nameView.frame.height / 2))
            amountIcon.centerY(x: 6, addition: -1)
            amountView.centerY(x: amountIcon.frame.maxX, addition: -1)
            badgeGradient.frame = badgeView.bounds
        }
    }
    
    private let badge: BadgeView
    private let container: View
    required init(frame frameRect: NSRect) {
        badge = BadgeView(frame: NSMakeRect(0, 0, frameRect.width, 36))
        container = View(frame: NSMakeRect(0, badge.frame.height + 20, frameRect.width, 100))
        super.init(frame: frameRect)
        addSubview(badge)
        addSubview(container)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func update(_ senders: [HeaderItem.Sender], context: AccountContext, animated: Bool) {
        
        
        while container.subviews.count > senders.count {
            container.subviews.last?.removeFromSuperview()
        }
        while container.subviews.count < senders.count {
            container.addSubview(PeerView(frame: NSMakeRect(0, 0, 70, container.frame.height)))
        }
        
        for (i, sender) in senders.enumerated() {
            let view = container.subviews[i] as! PeerView
            view.update(sender, context: context, animated: animated)
        }
    }
    
    override func layout() {
        super.layout()
        
        let between = floorToScreenPixels((frame.width - container.subviewsWidthSize.width) / CGFloat(container.subviews.count + 1))
        var x: CGFloat = between
        for view in container.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width + between
        }
    }
}

private final class SliderView : Control {
    let dotLayer = View(frame: NSMakeRect(0, 0, 28, 28))
    private let foregroundLayer = SimpleGradientLayer()
    private let emptyLayer = SimpleLayer()

    private var progress: CGFloat = 0.0
    
    var updateProgress:((CGFloat)->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        dotLayer.backgroundColor = theme.colors.background
        dotLayer.layer?.cornerRadius = dotLayer.frame.width / 2.0
        
        self.layer?.cornerRadius = 15
        
        self.layer?.addSublayer(emptyLayer)
        self.layer?.addSublayer(foregroundLayer)
        self.addSubview(dotLayer)
        
        emptyLayer.backgroundColor = theme.colors.listBackground.cgColor

        
        foregroundLayer.colors = gradient.map { $0.cgColor }
        foregroundLayer.startPoint = NSMakePoint(0, 0.5)
        foregroundLayer.endPoint = NSMakePoint(1, 0.2)

        foregroundLayer.cornerRadius = frameRect.height / 2
        
        self.set(handler: { [weak self] _ in
            self?.checkAndUpdate()
        }, for: .Down)
        
        self.set(handler: { [weak self] _ in
            self?.checkAndUpdate()
        }, for: .MouseDragging)
        
        self.set(handler: { [weak self] _ in
            self?.checkAndUpdate()
        }, for: .Up)
        
        handleScrollEventOnInteractionEnabled = false
        
    }
    
    override func scrollWheel(with event: NSEvent) {
        window?.scrollWheel(with: event)
        
        var scrollPoint = NSZeroPoint
        let isInverted: Bool = System.isScrollInverted

        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
        }
        
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x -= -event.scrollingDeltaX
            } else {
                scrollPoint.x += event.scrollingDeltaX
            }
        }

        let percent = self.progress + (scrollPoint.x * (1 / 100))

        
        self.updateProgress?(min(max(0, percent), 1))
        
    }
    
    func checkAndUpdate() {
        if var current = self.window?.mouseLocationOutsideOfEventStream {
            let width = self.frame.width - dotLayer.frame.width / 2
            current.x -= dotLayer.frame.width / 2
            let newValue = self.convert(current, from: nil)
            let percent = max(0, min(1, newValue.x / width))
                        
            self.updateProgress?(percent)
        }
    }
    
    override func layout() {
        super.layout()
        
        
        emptyLayer.frame = bounds
        dotLayer.frame = NSMakeRect(1, 1, 26, 26)
        
        dotLayer.frame = NSMakeRect(max(2, min(2 + floor((frame.width - dotLayer.frame.width - 2) * progress), frame.width - dotLayer.frame.width - 2)), 2, dotLayer.frame.width, dotLayer.frame.height)
        
        foregroundLayer.frame = NSMakeRect(0, 0, dotLayer.frame.maxX + 2, frame.height)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func update(count: Int64, minValue: Int64, maxValue: Int64) {
        
        self.progress = CGFloat(max(minValue - 1, min(maxValue, count - 1))) / CGFloat(maxValue - 1)
        
        layout()
    }
}

private final class BadgeView : View {
    private let shapeLayer = SimpleShapeLayer()
    private let foregroundLayer = SimpleGradientLayer()
    private let textView = InteractiveTextView()
    private var inlineView: InlineStickerView?
    private let container = View()
    
    private(set) var tailPosition: CGFloat = 0.0
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        textView.userInteractionEnabled = false
        
        foregroundLayer.colors = gradient.map { $0.cgColor }
        foregroundLayer.startPoint = NSMakePoint(0, 0.5)
        foregroundLayer.endPoint = NSMakePoint(1, 0.2)
        foregroundLayer.mask = shapeLayer
        
        
        self.layer?.addSublayer(foregroundLayer)


        self.layer?.masksToBounds = false
        
        shapeLayer.fillColor = NSColor.red.cgColor
        shapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        container.addSubview(textView)
        addSubview(container)
        container.layer?.masksToBounds = false
    }
    
    func update(_ count: Int64, max maxValue: Int64, context: AccountContext) -> NSSize {
        
        
        if inlineView == nil {
            let view = InlineStickerView(account: context.account, file: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(30, 30), getColors: { _ in
                return [.init(keyPath: "", color: .init(0xffffff))]
            }, playPolicy: .framesCount(1), controlContent: false)
            self.inlineView = view
            container.addSubview(view)
        }
        
        let attr = NSMutableAttributedString()
        attr.append(string: "\(count)", color: NSColor.white, font: .avatar(25))
        let textLayout = TextViewLayout(attr)
        textLayout.measure(width: .greatestFiniteMagnitude)
        self.textView.set(text: textLayout, context: context)

        
        container.setFrameSize(NSMakeSize(container.subviewsWidthSize.width + 2, container.subviewsWidthSize.height))
        
        self.tailPosition = max(0, min(1, CGFloat(count) / CGFloat(maxValue)))
                
        let size = NSMakeSize(max(100, container.frame.width + 30), frame.height)
        
        
        foregroundLayer.frame = size.bounds.insetBy(dx: 0, dy: -10)
        shapeLayer.frame = foregroundLayer.frame.focus(size)
        
        shapeLayer.path = generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPosition)._cgPath
        
        return size
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: container, frame: container.centerFrameX(y: 1))

        if let inlineView {
            transition.updateFrame(view: inlineView, frame: inlineView.centerFrameY(x: 0, addition: -2))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: inlineView.frame.maxX + 2))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
     //   shapeLayer.frame = bounds
    }
}


private final class HeaderItemView : GeneralContainableRowView {
    
    private let dismiss = ImageButton()
    private let balance = InteractiveTextView()
    private let header = InteractiveTextView()
    private let info = InteractiveTextView()
    
    
    
    private let accept: AcceptView = AcceptView(frame: .zero)
    
    private let badgeView = BadgeView(frame: NSMakeRect(0, 0, 100, 48))
    private let sliderView = SliderView(frame: NSMakeRect(0, 0, 100, 30))
    
    private var sendersView: SendersView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(balance)
        addSubview(header)
        addSubview(info)
        addSubview(accept)
        
        addSubview(badgeView)
        addSubview(sliderView)
        
        sliderView.updateProgress = { [weak self] progress in
            if let item = self?.item as? HeaderItem {
                item.updateValue(Int64(ceil(progress * CGFloat(item.maxValue))))
            }
        }
        
        info.userInteractionEnabled = false
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.close()
            }
        }, for: .Click)
        
        accept.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.action()
            }
        }, for: .Click)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition = .immediate
        

        let size = badgeView.update(item.state.count, max: item.maxValue, context: item.context)
        
        transition.updateFrame(view: self.badgeView, frame: self.focus(size))
        badgeView.updateLayout(size: size, transition: transition)
        
        info.set(text: item.info, context: item.context)
        
        sliderView.update(count: item.state.count, minValue: 1, maxValue: item.maxValue)
                
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        balance.set(text: item.balanceLayout, context: item.context)
        header.set(text: item.headerLayout, context: item.context)
        
        accept.update(item, animated: animated)
        accept.setFrameSize(NSMakeSize(frame.width - 20, 40))
        
        if !item.senders.isEmpty {
            let current: SendersView
            if let view = self.sendersView {
                current = view
            } else {
                current = .init(frame: NSMakeRect(0, 0, frame.width, item.sendersHeight))
                addSubview(current)
                self.sendersView = current
            }
            current.update(item.senders, context: item.context, animated: animated)
        } else if let view = self.sendersView {
            performSubviewRemoval(view, animated: animated)
            self.sendersView = nil
        }
        
        needsLayout = true

    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - dismiss.frame.height) / 2) - 10))
        balance.setFrameOrigin(NSMakePoint(frame.width - 12 - balance.frame.width, floorToScreenPixels((50 - balance.frame.height) / 2) - 10))
                
        header.centerX(y: floorToScreenPixels((50 - header.frame.height) / 2) - 10)
        accept.centerX(y: frame.height - accept.frame.height)
        
        
        if let sendersView {
            sendersView.setFrameOrigin(NSMakePoint(0, accept.frame.minY - sendersView.frame.height - 20))
        }
        
        sliderView.frame = NSMakeRect(10, 50 + badgeView.frame.height + 10, frame.width - 20, 30)
        
        badgeView.centerX(y: 50)
        
        badgeView.setFrameOrigin(NSMakePoint(10 + sliderView.dotLayer.frame.midX - badgeView.frame.width * badgeView.tailPosition, 50))
        
        info.centerX(y: sliderView.frame.maxY + 20)

    }
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h1"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, state: state, viewType: .legacy, updateValue: arguments.updateValue, action: arguments.react, close: arguments.dismiss)
    }))
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h2"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("By sending Stars you agree to the [Terms of Service](https://telegram.org).", linkHandler: { link in
    }), data: .init(color: theme.colors.grayText, viewType: .textBottomItem, fontSize: 12, centerViewAlignment: true, alignment: .center, linkColor: theme.colors.link)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h2"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
    
    return entries
}

func Star_ReactionsController(context: AccountContext, message: Message) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
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
    context.starsContext.load(force: true)
    
    actionsDisposable.add(context.starsContext.state.start(next: { state in
        updateState { current in
            var current = current
            current.myBalance = state?.balance ?? 0
            return current
        }
    }))
    
    let react:()->Void = {
        let count = stateValue.with { Int($0.count) }
        let myBalance = stateValue.with { $0.myBalance }
        
        if let peer = message.peers[message.id.peerId] {
            if count > myBalance {
                showModal(with: Star_ListScreen(context: context, source: .purchase(.init(peer), Int64(count) - myBalance)), for: context.window)
            } else {
                context.reactions.sendStarsReaction(message.id, count: count)
                close?()
            }
        }
        
    }

    let arguments = Arguments(context: context, dismiss: {
        
    }, react: react, updateValue: { value in
        updateState { current in
            var current = current
            current.count = max(1, value)
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.validateData = { _ in
        react()
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}




