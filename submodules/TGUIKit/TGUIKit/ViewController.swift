//
//  ViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit



open class BackgroundView: ImageView {
    private let gradient = CAGradientLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        gradient.actions = [:]
        
        self.layer = gradient
        self.layer?.disableActions()
        self.layer?.contentsGravity = .resizeAspectFill
        
    }
    open override var isFlipped: Bool {
        return true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open var backgroundMode:TableBackgroundMode = .plain {
        didSet {
            switch backgroundMode {
            case let .background(image):
                layer?.backgroundColor = .clear
                layer?.contents = image
                gradient.colors = nil
            case let .color(color):
                layer?.backgroundColor = color.cgColor
                layer?.contents = nil
                gradient.colors = nil
            case let .gradient(top, bottom):
                gradient.colors = [top.cgColor, bottom.cgColor]
                layer?.contents = nil
            default:
                gradient.colors = nil
                layer?.backgroundColor = presentation.colors.background.cgColor
                layer?.contents = nil
            }
        }
    }
    
    override open func copy() -> Any {
        let view = BackgroundView(frame: self.bounds)
        view.backgroundMode = self.backgroundMode
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
        view?.layer?.animatePosition(from: NSZeroPoint, to: NSMakePoint(0, -height), duration: 0.2, removeOnCompletion:false, completion:{ (completed) in
            view?.removeFromSuperview()
        })
        disposable.dispose()
    }
    
}

open class ViewController : NSObject {
    fileprivate var _view:NSView?
    public var _frameRect:NSRect
    
    private var toaster:ControllerToaster?
    
    public var atomicSize:Atomic<NSSize> = Atomic(value:NSZeroSize)
    
    weak open var navigationController:NavigationViewController? {
        didSet {
            if navigationController != oldValue {
                updateNavigation(navigationController)
            }
        }
    }
    
    public var noticeResizeWhenLoaded: Bool = true
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.3, function:CAMediaTimingFunctionName.spring)
    public var bar:NavigationBarStyle = NavigationBarStyle(height:50)
    
    public var leftBarView:BarView!
    public var centerBarView:TitledBarView!
    public var rightBarView:BarView!
    
    public var popover:Popover?
    open  var modal:Modal?
    
    
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
    
    public private(set) var internalId:Int = 0;
    
    public override init() {
        _frameRect = NSZeroRect
        self.internalId = Int(arc4random());
        super.init()
    }
    
    public init(frame frameRect:NSRect) {
        _frameRect = frameRect;
        self.internalId = Int(arc4random());
    }
    
    open func readyOnce() -> Void {
        if !didSetReady {
            didSetReady = true
            ready.set(.single(true))
        }
    }
    
    open func updateLocalizationAndTheme(theme: PresentationTheme) {
        (view as? AppearanceViewProtocol)?.updateLocalizationAndTheme(theme: theme)
        self.navigationController?.updateLocalizationAndTheme(theme: theme)
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
        }
    }
    
    open func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        return {}
    }
    
    open func navigationUndoHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        return {}
    }
    
    @available(OSX 10.12.2, *)
    open func makeTouchBar() -> NSTouchBar? {
        return nil//window?.firstResponder?.makeTouchBar()
    }
    
    @available(OSX 10.12.2, *)
    @objc public var touchBar: NSTouchBar? {
        return window?.touchBar
    }
    @available(OSX 10.12.2, *)
    open func layoutTouchBar() {
        
    }
    
    
    open func requestUpdateBackBar() {
        if isLoaded(), let leftBarView = leftBarView as? BackNavigationBar {
            leftBarView.requestUpdate()
        }
        self.leftBarView.style = navigationButtonStyle
    }
    
    open func requestUpdateCenterBar() {
        setCenterTitle(defaultBarTitle)
    }
    
    open func dismiss() {
        if navigationController?.controller == self {
            navigationController?.back()
        } 
    }
    
    open func requestUpdateRightBar() {
        (self.rightBarView as? TextButtonBarView)?.style = navigationButtonStyle
        self.rightBarView.style = navigationButtonStyle
    }
    
    
    @objc func viewFrameChanged(_ notification:Notification) {
        if atomicSize.with({ $0 != frame.size}) {
            viewDidResized(frame.size)
        }
    }
    
    public func updateBackgroundColor(_ backgroundMode: TableBackgroundMode) {
        switch backgroundMode {
        case .background:
            (self.view.layer as? CAGradientLayer)?.colors = nil
            backgroundColor = .clear
        case let .gradient(top, bottom):
            if let layer = self.view.layer as? CAGradientLayer {
                layer.colors = [top.cgColor, bottom.cgColor]
            } else {
                backgroundColor = top.blended(withFraction: 0.5, of: bottom)!
            }
        case let .color(color):
            (self.view.layer as? CAGradientLayer)?.colors = nil
            backgroundColor = color
        default:
            (self.view.layer as? CAGradientLayer)?.colors = nil
            backgroundColor = presentation.colors.background
        }
    }
    
    open func viewDidResized(_ size:NSSize) {
        _ = atomicSize.swap(size)
    }
    
    open func draggingExited() {
        
    }
    open func draggingEntered() {
        
    }
    
    open func focusSearch(animated: Bool) {
        
    }
    
    open func invokeNavigationBack() -> Bool {
        return true
    }
    
    open func getLeftBarViewOnce() -> BarView {
        return enableBack ? BackNavigationBar(self) : BarView(controller: self)
    }
    
    open var defaultBarTitle:String {
        return localizedString(self.className)
    }
    
    open func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(controller: self, .initialize(string: defaultBarTitle, color: presentation.colors.text, font: .medium(.title)))
    }
    
    public func setCenterTitle(_ text:String) {
        self.centerBarView.text = .initialize(string: text, color: presentation.colors.text, font: .medium(.title))
    }
    
    open func getRightBarViewOnce() -> BarView {
        return BarView(controller: self)
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
    
    deinit {
        self.window?.removeObserver(for: self)
        window?.removeAllHandlers(for: self)
        NotificationCenter.default.removeObserver(self)
        assertOnMainThread()
    }
    
    open func viewWillDisappear(_ animated:Bool) -> Void {
        if #available(OSX 10.12.2, *) {
            window?.touchBar = nil
        }
        //assert(self.window != nil)
        if canBecomeResponder {
            self.window?.removeObserver(for: self)
        }
        if haveNextResponder {
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
        if haveNextResponder {
            self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
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
    }
    
    
    
    @objc open func windowDidBecomeKey() {
        isKeyWindow.set(.single(true))
        if #available(OSX 10.12.2, *) {
            window?.touchBar = window?.makeTouchBar()
        }
    }
    
    @objc open func windowDidResignKey() {
        isKeyWindow.set(.single(false))
        if #available(OSX 10.12.2, *) {
            window?.touchBar = nil
        }
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
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift), let textView = window?.firstResponder as? TextView, let layout = textView.layout, layout.selectedRange.range.max != 0 {
            _ = layout.selectPrevChar()
            textView.needsDisplay = true
            return .invoked
        }
        return .rejected
    }
    
    open func nextKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift), let textView = window?.firstResponder as? TextView, let layout = textView.layout, layout.selectedRange.range.max != 0 {
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
    
    open func scrollup() {
        
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
    
    open var haveNextResponder: Bool {
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
            if subview is BackgroundView {
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
        return (localizedString("Navigation.back"),#imageLiteral(resourceName: "Icon_NavigationBack").precomposed(presentation.colors.accentIcon))
    }
    
    open var popoverClass:AnyClass {
        return Popover.self
    }
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, static: Bool = false) -> Void {
        if popover == nil {
            self.popover = (self.popoverClass as! Popover.Type).init(controller: self, static: `static`)
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
    
    

    open func initializer() -> T {
        let vz = T.self as NSView.Type
        //controller.bar.height
        return vz.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height)) as! T
    }
    
}

public struct ModalHeaderData {
    public let title: String?
    public let subtitle: String?
    public let image: CGImage?
    public let handler: (()-> Void)?
    public init(title: String? = nil, subtitle: String? = nil, image: CGImage? = nil, handler: (()->Void)? = nil) {
        self.title = title
        self.image = image
        self.subtitle = subtitle
        self.handler = handler
    }
}

open class ModalViewController : ViewController {
    
    open var closable:Bool {
        return true
    }
    
    // use this only for modal progress. This is made specially for nsvisualeffect support.
    open var contentBelowBackground: Bool {
        return false
    }
    
    private var temporaryTouchBar: Any?
    
    @available(OSX 10.12.2, *)
    open override func makeTouchBar() -> NSTouchBar? {
        guard let modal = modal, let interactions = modal.interactions else {
            if temporaryTouchBar == nil {
                temporaryTouchBar = NSTouchBar()
            }
            return temporaryTouchBar as? NSTouchBar
        }
        if temporaryTouchBar == nil {
            temporaryTouchBar = ModalTouchBar(interactions, modal: modal)
        }
        return temporaryTouchBar as? NSTouchBar
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
    
    open var isFullScreen:Bool {
        return false
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
    private let controller: NavigationViewController
    public init(_ controller: NavigationViewController) {
        self.controller = controller
        super.init(frame: controller._frameRect)
    }
    
    open override var handleEvents: Bool {
        return true
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
    
    open override var haveNextResponder: Bool {
        return true
    }
    
    open override func nextResponder() -> NSResponder? {
        return controller.controller.nextResponder()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        ready.set(controller.controller.ready.get())
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
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 120, genericView.listHeight)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 120, genericView.listHeight)), animated: animated)
        }
    }
    
    override open func viewClass() -> AnyClass {
        return TableView.self
    }
    
    public var genericView:TableView {
        return self.view as! TableView
    }
    

   
}


