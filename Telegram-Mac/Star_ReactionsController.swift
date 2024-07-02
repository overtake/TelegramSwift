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
    fileprivate let context: AccountContext
    fileprivate let state: State
    fileprivate let close:()->Void
    fileprivate let updateValue:(Int64)->Void
    
    fileprivate let balanceLayout: TextViewLayout
    fileprivate let headerLayout: TextViewLayout
    fileprivate let info: TextViewLayout

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: State, viewType: GeneralViewType, updateValue:@escaping(Int64)->Void, action:@escaping()->Void, close:@escaping()->Void) {
        self.context = context
        self.state = state
        self.close = close
        self.updateValue = updateValue
        let balanceAttr = NSMutableAttributedString()
        balanceAttr.append(string: strings().starPurchaseBalance("\(clown)\(state.myBalance)"), color: theme.colors.text, font: .normal(.text))
        balanceAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file, playPolicy: .onceEnd), for: clown)
        
        self.balanceLayout = .init(balanceAttr, alignment: .right)
        
        //TODOLANG
        self.headerLayout = .init(.initialize(string: "React with Stars", color: theme.colors.text, font: .medium(.title)), alignment: .center)
        
        
        let attr = NSMutableAttributedString()
        attr.append(string: "Choose how many stars you want to send to **MeowArts** to support this post.", color: theme.colors.text, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        self.info = .init(attr, alignment: .center)
        
        
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
        return 50 + (48 + 12) + 10 + 30 + info.layoutSize.height + 10 + 40 + 10 + 10
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

private final class SliderView : Control {
    let dotLayer = View(frame: NSMakeRect(0, 0, 28, 28))
    private let backgroundLayer = SimpleLayer()
    private let foregroundLayer = SimpleGradientLayer()
    
    private var progress: CGFloat = 0.0
    
    var updateProgress:((CGFloat)->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        dotLayer.backgroundColor = theme.colors.background
        dotLayer.layer?.cornerRadius = dotLayer.frame.width / 2.0
        
        self.layer?.cornerRadius = 15
        
        self.layer?.addSublayer(backgroundLayer)
        self.layer?.addSublayer(foregroundLayer)
        self.addSubview(dotLayer)
        
        backgroundLayer.backgroundColor = NSColor.random.cgColor

        
        foregroundLayer.colors = [NSColor(0xFFAC04), NSColor(0xFFCA35)].map { $0.cgColor }
        foregroundLayer.startPoint = NSMakePoint(0, 0.5)
        foregroundLayer.endPoint = NSMakePoint(1, 0.2)

        
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
        if let current = self.window?.mouseLocationOutsideOfEventStream {
            let width = self.frame.width - dotLayer.frame.width / 2
            let newValue = self.convert(current, from: nil)
            let percent = max(0, min(1, newValue.x / width))
                        
            self.updateProgress?(percent)
        }
    }
    
    override func layout() {
        super.layout()
        foregroundLayer.frame = bounds
        backgroundLayer.frame = bounds
        dotLayer.frame = NSMakeRect(1, 1, 28, 28)
        
        dotLayer.frame = NSMakeRect(max(1, min(1 + floor((frame.width - dotLayer.frame.width - 1) * progress), frame.width - dotLayer.frame.width - 1)), 1, dotLayer.frame.width, dotLayer.frame.height)
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
        
        foregroundLayer.colors = [NSColor(0xFFAC04), NSColor(0xFFCA35)].map { $0.cgColor }
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
            let view = InlineStickerView(account: context.account, file: LocalAnimatedSticker.star_currency.file, size: NSMakeSize(30, 30), getColors: { _ in
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
                item.updateValue(Int64(ceil(progress * 100)))
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

        let size = badgeView.update(item.state.count, max: 100, context: item.context)
        
        transition.updateFrame(view: self.badgeView, frame: self.focus(size))
        badgeView.updateLayout(size: size, transition: transition)
        
        info.set(text: item.info, context: item.context)
        
        sliderView.update(count: item.state.count, minValue: 1, maxValue: 100)
                
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        balance.set(text: item.balanceLayout, context: item.context)
        header.set(text: item.headerLayout, context: item.context)
        
        accept.update(item, animated: animated)
        accept.setFrameSize(NSMakeSize(frame.width - 20, 40))
        
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
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("By sending Stars you agree to the [Terms of Service](https://telegram.org).", linkHandler: { link in
    }), data: .init(color: theme.colors.grayText, viewType: .textBottomItem, fontSize: 12, centerViewAlignment: true, alignment: .center, linkColor: theme.colors.link)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h2"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
    
    return entries
}

func Star_ReactionsController(context: AccountContext) -> InputDataModalController {

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

    let arguments = Arguments(context: context, dismiss: {
        
    }, react: {
        updateState { current in
            var current = current
            current.count += 1
            return current
        }
    }, updateValue: { value in
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




