//
//  ViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import AppKit
import ColorPalette

public final class BackgroundGradientView : View {
    public var values:(top: NSColor?, bottom: NSColor?, rotation: Int32?)? {
        didSet {
            needsDisplay = true
        }
    }
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        noWayToRemoveFromSuperview = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override public var isFlipped: Bool {
        return false
    }
    
    override public func layout() {
        super.layout()
        let values = self.values
        self.values = values
    }
    
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let values = self.values {
            
            let colors = Array([values.top, values.bottom].compactMap { $0?.cgColor }.reversed())
            
            guard !colors.isEmpty else {
                return
            }
            
            let gradientColors = colors as CFArray
            
            let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
            
            var locations: [CGFloat] = []
            for i in 0 ..< colors.count {
                locations.append(delta * CGFloat(i))
            }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
            
            ctx.saveGState()
            ctx.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
            ctx.rotate(by: CGFloat(values.rotation ?? 0) * CGFloat.pi / -180.0)
            ctx.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: frame.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
        
    }
}


open class BackgroundView: View {
    
    private final class TileControl {
        private var superlayer: CALayer?
        private let main: CALayer
        private var tile: NSImage? = nil
        private var shouldTile: Bool = false
        private var tileLayers:[CALayer] = []
        
        init(main: CALayer) {
            self.main = main
            tileLayers.append(main)
        }
        
        func set(superlayer: CALayer?, tile: NSImage?, shouldTile: Bool) {
            self.superlayer = superlayer
            self.shouldTile = shouldTile
            self.tile = tile
        }
        
        var validLayout: CGRect? = nil
        
        func update(frame: NSRect, transition: ContainedViewLayoutTransition) {
            
            
            var rects:[CGRect] = []
            var frame = frame
            frame.size.height = max(500, frame.height)
            
            if let superlayer = superlayer {
                if let tile = tile {
                    let size = tile.size
                    let tileSize = size.aspectFitted(frame.size)
                    if shouldTile {
                        if tileSize.width < frame.width {
                            while rects.reduce(CGFloat(0), { $0 + $1.width }) < frame.width {
                                let width = rects.reduce(CGFloat(0), { $0 + $1.width })
                                rects.append(CGRect(origin: .init(x: width, y: (frame.height - tileSize.height) / 2), size: tileSize))
                            }
                        } else {
                            rects.append(frame.focus(size.aspectFilled(frame.size)))
                        }
                    } else {
                        rects.append(frame.focus(size.aspectFilled(frame.size)))
                    }
                    
                    while self.tileLayers.count > rects.count {
                        self.tileLayers.removeLast().removeFromSuperlayer()
                    }
                    while self.tileLayers.count < rects.count {
                        let layer = SimpleLayer()
//                        layer.disableActions()
                        self.tileLayers.append(layer)
                    }
                    
                    for (i, layer) in tileLayers.enumerated() {
                        layer.compositingFilter = main.compositingFilter
                        layer.backgroundColor = main.backgroundColor
                        layer.contents = main.contents
                        layer.opacity = main.opacity
//                        layer.contentsGravity = .resize

                        transition.updateFrame(layer: layer, frame: rects[i])
                        superlayer.addSublayer(layer)
                    }
                } else {
                    while tileLayers.count > 1 {
                        tileLayers.removeLast().removeFromSuperlayer()
                    }
                    superlayer.addSublayer(main)
                    transition.updateFrame(layer: main, frame: frame)
                }
            } else {
                while tileLayers.count > 1 {
                    tileLayers.removeLast().removeFromSuperlayer()
                }
                main.removeFromSuperlayer()
            }
        }
    }
    

    
    deinit {
    }
    
    private let imageView: SimpleLayer = SimpleLayer()
    private var backgroundView: NSView?
    
    public var useSharedAnimationPhase: Bool = true
    public var checkDarkPattern: Bool = true

    private let container: View = View()
    
    private var tileControl: TileControl
    
    public required init(frame frameRect: NSRect) {
        tileControl = TileControl(main: imageView)
        super.init(frame: frameRect)
//        imageView.disableActions()
        imageView.frame = frameRect.size.bounds
//        container.addSubview(imageView)
        autoresizesSubviews = false
        imageView.contentsGravity = .resize
        self.addSubview(container)
    }
    

    var contentViews: [NSView] {
        return self.subviews
    }

    
    open override func change(size: NSSize, animated: Bool, _ save: Bool = true, removeOnCompletion: Bool = true, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion: ((Bool) -> Void)? = nil) {
        super.change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
    }
    
    override init() {
        fatalError("not supported")
    }
    
    open override func layout() {
        super.layout()
        _customHandler?.layout?(self)
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    public func doAction() {
        if let backgroundView = backgroundView as? AnimatedGradientBackgroundView {
            backgroundView.animateEvent(transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
    }
    
    open override var isFlipped: Bool {
        return true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open var backgroundMode:TableBackgroundMode = .plain {
        didSet {
            if oldValue != backgroundMode {
//                CATransaction.begin()
//                CATransaction.setDisableActions(true)
                tileControl.validLayout = nil
                var backgroundView: NSView? = nil
                switch backgroundMode {
                case let .background(image, intensity, colors, rotation):
                    imageView.backgroundColor = .clear
                    imageView.contents = image
                    let colors = colors?.map { $0.withAlphaComponent(1) }


                    var shouldTile = false
                    if let colors = colors, !colors.isEmpty {
                        
                        shouldTile = true
                        let intense = Float((abs(intensity ?? 50))) / 100.0
                        
                        let invertPattern = presentation.colors.isDark && checkDarkPattern
                        if invertPattern {
                            self.imageView.compositingFilter = nil
                            imageView.opacity = 1.0
                        } else {
                            self.imageView.compositingFilter = "softLightBlendMode"
                            imageView.opacity = intense
                        }

                        if colors.count > 2 {
                            if let bg = self.backgroundView as? AnimatedGradientBackgroundView {
                                backgroundView = bg
                                bg.updateColors(colors: colors)
                            } else {
                                backgroundView = AnimatedGradientBackgroundView(colors: colors, useSharedAnimationPhase: useSharedAnimationPhase)
                                backgroundView?.frame = bounds
                            }
                        } else {
                            if let bg = self.backgroundView as? BackgroundGradientView {
                                backgroundView = bg
                            } else {
                                let bg = BackgroundGradientView(frame: bounds)
                                backgroundView = bg
                            }
                            (backgroundView as? BackgroundGradientView)?.values = (top: colors.first, bottom: colors.last, rotation: rotation)
                        }
                    } else {
                        imageView.opacity = 1
                        imageView.compositingFilter = nil
                    }
                    if let bg = backgroundView as? AnimatedGradientBackgroundView {
                        tileControl.set(superlayer: bg.contentView.layer, tile: image, shouldTile: shouldTile)
                    } else if let bg = backgroundView as? BackgroundGradientView {
                        tileControl.set(superlayer: bg.layer, tile: image, shouldTile: shouldTile)
                    } else {
                        tileControl.set(superlayer: container.layer, tile: image, shouldTile: shouldTile)
                    }
                case let .color(color):
                    imageView.backgroundColor = color.withAlphaComponent(1.0).cgColor
                    imageView.compositingFilter = nil
                    imageView.contents = nil
                    imageView.opacity = 1
                    tileControl.set(superlayer: container.layer!, tile: nil, shouldTile: false)
                case let .gradient(colors, rotation):
                    let colors = colors.map { $0.withAlphaComponent(1) }
                    imageView.contents = nil
                    imageView.backgroundColor = .clear
                    imageView.opacity = 1
                    imageView.compositingFilter = nil
                    imageView.removeFromSuperlayer()
                    tileControl.set(superlayer: nil, tile: nil, shouldTile: false)
                    if colors.count > 2 {
                        if let bg = self.backgroundView as? AnimatedGradientBackgroundView {
                            backgroundView = bg
                            bg.updateColors(colors: colors)
                        } else {
                            backgroundView = AnimatedGradientBackgroundView(colors: colors, useSharedAnimationPhase: useSharedAnimationPhase)
                            backgroundView?.frame = bounds
                        }
                    } else {
                        if let bg = self.backgroundView as? BackgroundGradientView {
                            backgroundView = bg
                        } else {
                            let bg = BackgroundGradientView(frame: bounds)
                            backgroundView = bg
                        }
                        (backgroundView as? BackgroundGradientView)?.values = (top: colors.first, bottom: colors.last, rotation: rotation)
                    }
                default:
                    imageView.backgroundColor = presentation.colors.background.cgColor
                    imageView.contents = nil
                    imageView.compositingFilter = nil
                    imageView.opacity = 1
                    imageView.removeFromSuperlayer()
                    tileControl.set(superlayer: nil, tile: nil, shouldTile: false)
                }
                
                tileControl.update(frame: bounds, transition: .immediate)
                
                if let backgroundView = backgroundView {
                    self.backgroundView?.removeFromSuperview()
                    self.backgroundView = backgroundView
                    container.addSubview(backgroundView)
                } else {
                    self.backgroundView?.removeFromSuperview()
                    self.backgroundView = nil
                }
            }
//            CATransaction.commit()
        }
    }
    
    open func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: imageView, frame: size.bounds)
        transition.updateFrame(view: container, frame: size.bounds)
        tileControl.update(frame: size.bounds, transition: transition)
        if let backgroundView = backgroundView {
            transition.updateFrame(view: backgroundView, frame: size.bounds)
            if let backgroundView = backgroundView as? AnimatedGradientBackgroundView {
                backgroundView.updateLayout(size: size, transition: transition)
            }
        }
    }
    private(set) var isCopy: Bool = false
    override open func copy() -> Any {
        let view = BackgroundView(frame: self.frame)
        view.isCopy = true
        view.backgroundMode = self.backgroundMode
        view.useSharedAnimationPhase = true
        view.updateLayout(size: view.frame.size, transition: .immediate)
        return view
    }
    
    open func copy(_ backgroundMode: TableBackgroundMode?) -> BackgroundView {
        let view = BackgroundView(frame: self.frame)
        view.isCopy = true
        view.backgroundMode = backgroundMode ?? self.backgroundMode
        view.useSharedAnimationPhase = true
        view.updateLayout(size: view.frame.size, transition: .immediate)
        return view
    }
}



class ControllerToasterView : Control {
    
    private weak var toaster:ControllerToaster?
    private let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        self.autoresizingMask = [.width]
        self.border = [.Bottom]
        updateLocalizationAndTheme(theme: presentation)
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.background
        self.textView.backgroundColor = theme.colors.background
    }
   
    
    func update(with toaster:ControllerToaster) {
        self.toaster = toaster
    }
    
    override func layout() {
        super.layout()
        if let toaster = toaster {
            toaster.text.measure(width: frame.width - 40)
            textView.update(toaster.text)
            textView.center()
        }
        self.setNeedsDisplayLayer()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class ControllerToaster {
    let text:TextViewLayout
    var view:ControllerToasterView?
    let disposable:MetaDisposable = MetaDisposable()
    private let action:(()->Void)?
    private var height:CGFloat {
        return max(30, self.text.layoutSize.height + 10)
    }
    public init(text:NSAttributedString, action:(()->Void)? = nil) {
        self.action = action
        self.text = TextViewLayout(text, maximumNumberOfLines: 3, truncationType: .middle, alignment: .center)
    }
    
    public init(text:String, action:(()->Void)? = nil) {
        self.action = action
        self.text = TextViewLayout(NSAttributedString.initialize(string: text, color: presentation.colors.text, font: .medium(.text)), maximumNumberOfLines: 3, truncationType: .middle, alignment: .center)
    }
    
    func show(for controller:ViewController, timeout:Double, animated:Bool) {
        assert(view == nil)
        text.measure(width: controller.frame.width - 40)
        view = ControllerToasterView(frame: NSMakeRect(0, 0, controller.frame.width, height))
        view?.update(with: self)
        
        if let action = self.action {
            view?.set(handler: { [weak self] _ in
                action()
                self?.hide(true)
            }, for: .Click)
        }
        
        controller.addSubview(view!)
        
        if animated {
            view?.layer?.animatePosition(from: NSMakePoint(0, -height - controller.bar.height), to: NSZeroPoint, duration: 0.2)
        }
        
        let signal:Signal<Void,Void> = .single(Void()) |> delay(timeout, queue: Queue.mainQueue())
        disposable.set(signal.start(next:{ [weak self] in
            self?.hide(true)
        }))
    }
    
    func hide(_ animated:Bool) {
        if animated {
            view?.layer?.animatePosition(from: NSZeroPoint, to: NSMakePoint(0, -height), duration: 0.2, removeOnCompletion:false, completion:{ [weak self] (completed) in
                self?.view?.removeFromSuperview()
                self?.view = nil
            })
        } else {
            view?.removeFromSuperview()
            view = nil
            disposable.dispose()
        }
    }
    
    deinit {
        let view = self.view
        view?.removeFromSuperview()
        disposable.dispose()
    }
    
}

open class ViewController : NSObject {
    
    
    public struct StakeSettings {
        
        
        public let keepLeft: CGFloat
        public let straightMove: Bool
        public let keepIn: Bool
        public let keepTop: ()->CGFloat
        public var isCustom: Bool {
            if keepLeft > 0 {
                return true
            }
            if straightMove {
                return true
            }
            if keepIn {
                return true
            }
            if keepTop() > 0 {
                return true
            }
            return false
        }
        
        public init(keepLeft: CGFloat, keepTop: @escaping()->CGFloat, straightMove: Bool, keepIn: Bool) {
            self.keepLeft = keepLeft
            self.straightMove = straightMove
            self.keepIn = keepIn
            self.keepTop = keepTop
        }
        
        public static var `default`: StakeSettings {
            return .init(keepLeft: 0, keepTop: { 0 }, straightMove: false, keepIn: false)
        }
    }
    
    
    
    fileprivate var _view:NSView?
    public var _frameRect:NSRect
    
    private var toaster:ControllerToaster?
    
    public var atomicSize:Atomic<NSSize> = Atomic(value:NSZeroSize)
    
    public var onDeinit: (()->Void)? = nil
    
    weak open var navigationController:NavigationViewController? {
        didSet {
            if navigationController != oldValue {
                updateNavigation(navigationController)
            }
        }
    }
    
    open func swapNavigationBar(leftView: BarView?, centerView: BarView?, rightView: BarView?, animation: NavigationBarSwapAnimation) {
        self.navigationController?.swapNavigationBar(leftView: leftView, centerView: centerView, rightView: rightView, animation: animation)
    }
    
    public var noticeResizeWhenLoaded: Bool = true
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration: 0.4, function:CAMediaTimingFunctionName.spring)
    public var bar:NavigationBarStyle = NavigationBarStyle(height:50)
    
    public var leftBarView:BarView!
    public var centerBarView:TitledBarView!
    public var rightBarView:BarView!
    
    public var popover:Popover?
    open var modal:Modal?
    
    open var barHeight: CGFloat {
        return bar.height
    }
    
    open var barPresentation: ControlStyle {
        return navigationButtonStyle
    }
    
    var widthOnDisappear: CGFloat? = nil
    
    public var ableToNextController:(ViewController, @escaping(ViewController, Bool)->Void)->Void = { controller, f in
        f(controller, true)
    }
    
    private let _ready = Promise<Bool>()
    open var ready: Promise<Bool> {
        return self._ready
    }
    public var didSetReady:Bool = false
    
    public let isKeyWindow:Promise<Bool> = Promise(false)
    
    open var view:NSView {
        get {
            if(_view == nil) {
                loadView();
            }
            
            return _view!;
        }
       
    }
    
    open var redirectUserInterfaceCalls: Bool {
        return false
    }
    
    public var backgroundColor: NSColor {
        set {
            self.view.background = newValue
        }
        get {
            return self.view.background
        }
    }
    
    open var enableBack:Bool {
        return false
    }
    
    open var isAutoclosePopover: Bool {
        return true
    }
    
    open var isOnScreen: Bool {
        return self.navigationController?.controller == self && !hasModals()
    }
    
    open func executeReturn() -> Void {
        self.navigationController?.back()
    }
    
    open func updateNavigation(_ navigation:NavigationViewController?) {
        
    }
    
    open var rightSwipeController: ViewController? {
        return nil
    }
    
    open func navigationWillChangeController() {
        
    }
    
    open var sidebar:ViewController? {
        return nil
    }
    
    open var sidebarWidth:CGFloat {
        return 350
    }
    
    open var supportSwipes: Bool {
        return true
    }
    
    public let internalId:Int = Int(arc4random());
    
    public override init() {
        _frameRect = NSZeroRect
        super.init()
    }
    
    public init(frame frameRect:NSRect) {
        _frameRect = frameRect;
    }
    
    open func readyOnce() -> Void {
        if !didSetReady {
            didSetReady = true
            ready.set(.single(true))
        }
    }
    
    open func updateLocalizationAndTheme(theme: PresentationTheme) {
        (view as? AppearanceViewProtocol)?.updateLocalizationAndTheme(theme: theme)
      //  self.navigationController?.updateLocalizationAndTheme(theme: theme)
    }
    
    open func loadView() -> Void {
        if(_view == nil) {
            
            leftBarView = getLeftBarViewOnce()
            centerBarView = getCenterBarViewOnce()
            rightBarView = getRightBarViewOnce()
            
            let vz = viewClass() as! NSView.Type
            _view = vz.init(frame: _frameRect);
            _view?.autoresizingMask = [.width,.height]
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)
            viewDidLoad()
        }
    }
    
    open func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        return {}
    }
    

    
    open func requestUpdateBackBar() {
        if isLoaded(), let leftBarView = leftBarView as? BackNavigationBar {
            leftBarView.requestUpdate()
        }
        self.leftBarView.style = barPresentation
    }
    
    open func requestUpdateCenterBar() {
        setCenterTitle(defaultBarTitle)
        setCenterStatus(defaultBarStatus)
        self.centerBarView.style = barPresentation
    }
    open func requestUpdateRightBar() {
        self.rightBarView.style = barPresentation
    }
    
    
    open func dismiss() {
        if navigationController?.controller == self {
            navigationController?.back()
        } 
    }
    

    
    @objc func viewFrameChanged(_ notification:Notification) {
        if atomicSize.with({ $0 != frame.size}) {
            viewDidResized(frame.size)
        }
    }
    public private(set) var bgMode: TableBackgroundMode?
    
    open func updateBackgroundColor(_ backgroundMode: TableBackgroundMode) {
        self.bgMode = backgroundMode
        switch backgroundMode {
        case .background, .gradient:
            backgroundColor = .clear
        case let .color(color):
            backgroundColor = color
        default:
            backgroundColor = presentation.colors.background
        }
    }
    
    open func updateController() {
        
    }
    
    open func viewDidResized(_ size:NSSize) {
        _ = atomicSize.swap(size)
    }
    
    open func draggingExited() {
        
    }
    open func draggingEntered() {
        
    }
    
    open func focusSearch(animated: Bool, text: String? = nil) {
        
    }
    
    open func invokeNavigationBack() -> Bool {
        return true
    }
    
    open func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        if isLoaded() {
            transition.updateFrame(view: self.view, frame: frame)
        }
    }
    
    open func getLeftBarViewOnce() -> BarView {
        return enableBack ? BackNavigationBar(self) : BarView(controller: self)
    }
    
    open var defaultBarTitle:String {
        return localizedString(self.className)
    }
    open var defaultBarStatus:String? {
        return nil
    }

    
    open func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(controller: self, .initialize(string: defaultBarTitle, color: barPresentation.textColor, font: .medium(.title)))
    }
    
    open func setCenterTitle(_ text:String) {
        self.centerBarView.text = .initialize(string: text, color: barPresentation.textColor, font: .medium(.title))
    }
    open func setCenterStatus(_ text: String?) {
        if let text = text {
            self.centerBarView.status = .initialize(string: text, color: barPresentation.grayTextColor, font: .normal(.text))
        } else {
            self.centerBarView.status = nil
        }
    }
    open func getRightBarViewOnce() -> BarView {
        return BarView(controller: self)
    }
    
    open var abolishWhenNavigationSame: Bool {
        return false
    }
    
    open func viewClass() ->AnyClass {
        return View.self
    }
    
    open func draggingItems(for pasteboard:NSPasteboard) -> [DragItem] {
        return []
    }
    
    public func loadViewIfNeeded(_ frame:NSRect = NSZeroRect) -> Void {
        
         guard _view != nil else {
            if !NSIsEmptyRect(frame) {
                _frameRect = frame
            }
            self.loadView()
            
            return
        }
    }
    
    open func viewDidLoad() -> Void {
        if noticeResizeWhenLoaded {
            viewDidResized(view.frame.size)
        }
    }
    
    
    
    open func viewWillAppear(_ animated:Bool) -> Void {
        
    }
    
    open func viewDidChangedNavigationLayout(_ state: SplitViewState) -> Void {
        
    }
    open func setToNextController(_ controller: ViewController, style: ViewControllerStyle) {
        
    }
    open func setToPreviousController(_ controller: ViewController, style: ViewControllerStyle) {
        
    }
    open var stake: StakeSettings {
        return .default
    }
    open weak var tied: ViewController?
    
    open func updateSwipingState(_ state: SwipeState, controller: ViewController, isPrevious: Bool) -> Void {
        
    }
    
    deinit {
        self.window?.removeObserver(for: self)
        self.window?.removeAllHandlers(for: self)
        NotificationCenter.default.removeObserver(self)
        assertOnMainThread()
        self.onDeinit?()
    }
    
    
    open func viewWillDisappear(_ animated:Bool) -> Void {
        if #available(OSX 10.12.2, *) {
            window?.touchBar = nil
        }
        widthOnDisappear = frame.width
        //assert(self.window != nil)
        if canBecomeResponder {
            self.window?.removeObserver(for: self)
        }
        if hasNextResponder {
            self.window?.remove(object: self, for: .Tab)
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        isKeyWindow.set(.single(false))
    }
    
    public func isLoaded() -> Bool {
        return _view != nil
    }
    
    open func viewDidAppear(_ animated:Bool) -> Void {
        //assert(self.window != nil)
        if #available(OSX 10.12.2, *) {
           // DispatchQueue.main.async { [weak self] in
                self.window?.touchBar = self.window?.makeTouchBar()
          //  }
        }
        if hasNextResponder {
            self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
                guard let `self` = self else {return .rejected}
                
                _ = self.window?.makeFirstResponder(self.nextResponder())
                
                return .invoked
            }, with: self, for: .Tab, priority: responderPriority)
        }
        
        if canBecomeResponder {
            self.window?.set(responder: {[weak self] () -> NSResponder? in
                return self?.firstResponder()
            }, with: self, priority: responderPriority)
            
            if let become = becomeFirstResponder(), become == true {
                self.window?.applyResponderIfNeeded()
            } else {
                _ = self.window?.makeFirstResponder(self.window?.firstResponder)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        if let window = window {
            isKeyWindow.set(.single(window.isKeyWindow))
        }
        
        func findTableView(in view: NSView) -> Void {
            for subview in view.subviews {
                if subview is NSTableView {
                    if !subview.inLiveResize {
                        subview.viewDidEndLiveResize()
                    }
                } else if !subview.subviews.isEmpty {
                    findTableView(in: subview)
                }
            }
        }
        if let widthOnDisappear = widthOnDisappear, frame.width != widthOnDisappear {
            findTableView(in: view)
        }
    }
    
    
    
    @objc open func windowDidBecomeKey() {
        isKeyWindow.set(.single(true))
    }
    
    @objc open func windowDidResignKey() {
        isKeyWindow.set(.single(false))
    }
    
    open var canBecomeResponder: Bool {
        return true
    }
    
    open var removeAfterDisapper:Bool {
        return false
    }
    
    open func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    open func backKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift), let textView = window?.firstResponder as? TextView, let layout = textView.textLayout, layout.selectedRange.range.max != 0 {
            _ = layout.selectPrevChar()
            textView.needsDisplay = true
            return .invoked
        }
        return .rejected
    }
    
    open func nextKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift), let textView = window?.firstResponder as? TextView, let layout = textView.textLayout, layout.selectedRange.range.max != 0 {
            _ = layout.selectNextChar()
            textView.needsDisplay = true
            return .invoked
        }
        return .invokeNext
    }
    
    open func returnKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    open func didRemovedFromStack() -> Void {
        
    }
    
    open func viewDidDisappear(_ animated:Bool) -> Void {
        
    }
    
    open func scrollup(force: Bool = false) {
        
    }
    
    open func becomeFirstResponder() -> Bool? {

        return false
    }
    
    open var window:Window? {
        return _view?.window as? Window
    }
    
    open func firstResponder() -> NSResponder? {
        return nil
    }
    
    open func nextResponder() -> NSResponder? {
        return nil
    }
    
    open var hasNextResponder: Bool {
        return false
    }
    
    open var responderPriority:HandlerPriority {
        return .low
    }
    
    
    
    public var frame:NSRect {
        get {
            return isLoaded() ? self.view.frame : _frameRect
        }
        set {
            self.view.frame = newValue
        }
    }
    public var bounds:NSRect {
        return isLoaded() ? self.view.bounds : NSMakeRect(0, 0, _frameRect.width, _frameRect.height - bar.height)
    }
    
    open var isOpaque: Bool {
        return true
    }
    
    func removeBackgroundCap() {
        for subview in view.subviews.reversed() {
            if let subview = subview as? BackgroundView, subview.isCopy {
                subview.removeFromSuperview()
            }
        }
    }
    
    public func addSubview(_ subview:NSView) -> Void {
        self.view.addSubview(subview)
    }
    
    
    
    public func removeFromSuperview() ->Void {
        if isLoaded() {
            self.view.removeFromSuperview()
        }
    }
    
    
    open func backSettings() -> (String,CGImage?) {
        return (localizedString("Navigation.back"),#imageLiteral(resourceName: "Icon_NavigationBack").precomposed(barPresentation.foregroundColor))
    }
    
    open var popoverClass:AnyClass {
        return Popover.self
    }
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, static: Bool = false) -> Void {
        if popover == nil {
            self.popover = (self.popoverClass as! Popover.Type).init(controller: self, static: `static`, animationMode: .classic)
        }
        
        if let popover = popover {
            popover.show(for: control, edge: edge, inset: inset)
        }
    }
    
    open func closePopover() -> Void {
        self.popover?.hide()
    }
    
    open func invokeNavigation(action:NavigationModalAction) {
        _ = (self.ready.get() |> take(1) |> deliverOnMainQueue).start(next: { (ready) in
            action.close()
        })
    }
    
    public func removeToaster() {
        if let toaster = self.toaster {
            toaster.hide(true)
        }
    }
    
    public func show(toaster:ControllerToaster, for delay:Double = 3.0, animated:Bool = true) {
        assert(isLoaded())
        if let toaster = self.toaster {
            toaster.hide(true)
        }
        
        self.toaster = toaster
        toaster.show(for: self, timeout: delay, animated: animated)
        
    }
}


open class GenericViewController<T> : ViewController where T:NSView {
    public var genericView:T {
        return super.view as! T
    }
    
    open override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        genericView.background = presentation.colors.background
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override open func loadView() -> Void {
        if(_view == nil) {
            
            leftBarView = getLeftBarViewOnce()
            centerBarView = getCenterBarViewOnce()
            rightBarView = getRightBarViewOnce()

            
            _view = initializer()
            _view?.wantsLayer = true
            _view?.autoresizingMask = [.width,.height]
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)
        }
        viewDidLoad()
    }
    
    public var initializationRect: NSRect {
        return NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width - self.stake.keepLeft, _frameRect.height - bar.height)
    }
    

    open func initializer() -> T {
        let vz = T.self as NSView.Type
        //controller.bar.height
        return vz.init(frame: initializationRect) as! T
    }
    
}

public struct ModalHeaderData {
    public let title: String?
    public let subtitle: String?
    public let image: CGImage?
    public let handler: (()-> Void)?
    public let contextMenu:(()->[ContextMenuItem])?
    public init(title: String? = nil, subtitle: String? = nil, image: CGImage? = nil, handler: (()->Void)? = nil, contextMenu:(()->[ContextMenuItem])? = nil) {
        self.title = title
        self.image = image
        self.subtitle = subtitle
        self.handler = handler
        self.contextMenu = contextMenu
    }
}

public protocol ModalControllerHelper {
    var modalInteractions:ModalInteractions? { get }
}

open class ModalViewController : ViewController, ModalControllerHelper {
    
    public struct Theme {
        let text: NSColor
        let grayText: NSColor
        let background: NSColor
        let border: NSColor
        let accent: NSColor
        let grayForeground: NSColor
        let activeBackground: NSColor
        let activeBorder: NSColor
        let listBackground: NSColor
        public init(text: NSColor = presentation.colors.text, grayText: NSColor = presentation.colors.grayText, background: NSColor = .clear, border: NSColor = presentation.colors.border, accent: NSColor = presentation.colors.accent, grayForeground: NSColor = presentation.colors.grayForeground, activeBackground: NSColor = presentation.colors.background, activeBorder: NSColor = presentation.colors.border, listBackground: NSColor = presentation.colors.listBackground) {
            self.text = text
            self.grayText = grayText
            self.background = background
            self.border = border
            self.accent = accent
            self.grayForeground = grayForeground
            self.activeBackground = activeBackground
            self.activeBorder = activeBorder
            self.listBackground = listBackground
        }
        public init(presentation: PresentationTheme) {
            self.text = presentation.colors.text
            self.grayText = presentation.colors.grayText
            self.background = presentation.colors.background
            self.border = presentation.colors.border
            self.accent = presentation.colors.accent
            self.grayForeground = presentation.colors.grayForeground
            self.activeBackground = presentation.colors.background
            self.activeBorder = presentation.colors.border
            self.listBackground = presentation.colors.listBackground
        }
    }
    
    open var modalTheme:Theme {
        return Theme()
    }
    
    open var hasBorder: Bool {
        return true
    }
    
    open var closable:Bool {
        return true
    }
    
    // use this only for modal progress. This is made specially for nsvisualeffect support.
    open var contentBelowBackground: Bool {
        return false
    }
    
    open var shouldCloseAllTheSameModals: Bool {
        return true
    }
    
    
    open var hasOwnTouchbar: Bool {
        return true
    }
    
    open var background:NSColor {
        return NSColor(0x000000, 0.6)
    }
    
    open func didResizeView(_ size: NSSize, animated: Bool) -> Void {
        
    }
    
    open var isVisualEffectBackground: Bool {
        return false
    }
    open var isVisualEffectContainer: Bool {
        return false
    }
    
    open var isFullScreen:Bool {
        return false
    }
    
    open var cornerRadius: CGFloat {
        return 10
    }
    
    open var redirectMouseAfterClosing: Bool {
        return false
    }
    
    open var containerBackground: NSColor {
        return presentation.colors.background
    }
    open var headerBackground: NSColor {
        return presentation.colors.background
    }
    open var headerBorderColor: NSColor {
        return presentation.colors.border
    }
    
    open var dynamicSize:Bool {
        return false
    }
    
    open override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    open func measure(size:NSSize) {
        
    }
    
    open var modalInteractions:ModalInteractions? {
        return nil
    }
    open var modalHeader: (left:ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return nil
    }
    
    open override var responderPriority: HandlerPriority {
        return .modal
    }
    
    open override func firstResponder() -> NSResponder? {
        return self.view
    }
    
    open func close(animationType: ModalAnimationCloseBehaviour = .common) {
        modal?.close(animationType: animationType)
    }
    
    open var handleEvents:Bool {
        return true
    }
    
    open var handleAllEvents: Bool {
        return true
    }
    
    override open func loadView() -> Void {
        if(_view == nil) {
            
            _view = initializer()
            _view?.autoresizingMask = [.width,.height]
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)
        }
        viewDidLoad()
    }
    
    open func initializer() -> NSView {
        let vz = viewClass() as! NSView.Type
        return vz.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height));
    }

}

open class ModalController : ModalViewController {
    public let controller: NavigationViewController
    public init(_ controller: NavigationViewController) {
        self.controller = controller
        super.init(frame: controller._frameRect)
    }

    open override var handleEvents: Bool {
        return true
    }
    
    open override var modalInteractions: ModalInteractions? {
        return (self.controller.controller as? ModalControllerHelper)?.modalInteractions
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        self.controller.viewWillAppear(animated)
    }
    open override func viewWillDisappear(_ animated: Bool) {
        self.controller.viewWillDisappear(animated)
    }
    open override func viewDidAppear(_ animated: Bool) {
        self.controller.viewDidAppear(animated)
    }
    open override func viewDidDisappear(_ animated: Bool) {
        self.controller.viewDidDisappear(animated)
    }
    open override func firstResponder() -> NSResponder? {
        return controller.controller.firstResponder()
    }
    
    open override func returnKeyAction() -> KeyHandlerResult {
        return controller.controller.returnKeyAction()
    }
    
    open override func escapeKeyAction() -> KeyHandlerResult {
        return controller.controller.escapeKeyAction()
    }

    
    open override var hasNextResponder: Bool {
        return true
    }
    
    open override func nextResponder() -> NSResponder? {
        return controller.controller.nextResponder()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        ready.set(controller.controller.ready.get())
    }
    
    open override func becomeFirstResponder() -> Bool? {
        return nil
    }
    
    
    open override func loadView() {
        self._view = controller.view
        NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: _view!)
        
        _ = atomicSize.swap(_view!.frame.size)
        viewDidLoad()
    }
}

open class TableModalViewController : ModalViewController {
    override open var dynamicSize: Bool {
        return true
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 200, genericView.listHeight)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 200, genericView.listHeight)), animated: animated)
        }
    }
    
    override open func viewClass() -> AnyClass {
        return TableView.self
    }
    
    public var genericView:TableView {
        return self.view as! TableView
    }
    

   
}


