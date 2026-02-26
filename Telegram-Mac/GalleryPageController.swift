//
//  GalleryPageController.swift
//  TelegramMac
//
//  Created by keepcoder on 14/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import AVFoundation
import AVKit
import TelegramCore
import TextRecognizing
import Postbox

fileprivate class PublicPhotoView : Control {
    private let avatar: AvatarControl = AvatarControl(font: .avatar(10))
    private let textView = TextView()
    override init() {
        let layout = TextViewLayout(.initialize(string: strings().galleryPublicPhoto, color: .white, font: .normal(.text)))
        layout.measure(width: .greatestFiniteMagnitude)

        super.init(frame: NSMakeSize(layout.layoutSize.width + 30 + 10 + 10, 30).bounds)
        avatar.setFrameSize(NSMakeSize(20, 20))
        addSubview(avatar)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        textView.update(layout)
        self.backgroundColor = .blackTransparent
        self.layer?.cornerRadius = frame.height / 2
        self.scaleOnClick = true
        avatar.userInteractionEnabled = false
        
    }
    
    override func layout() {
        super.layout()
        avatar.centerY(x: 5)
        textView.centerY(x: avatar.frame.maxX + 10)
    }
    
    func update(context: AccountContext, image: TelegramMediaImage, peer: TelegramUser) {
        avatar.setPeer(account: context.account, peer: peer.withUpdatedPhoto(image.representations))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


fileprivate class GMagnifyView : MagnifyView  {
    private var progressView: RadialProgressView?

    private var recognitionView: NSView?
    var recognition: GalleryRecognition? {
        didSet {
            self.recognitionView?.removeFromSuperview()
            if let recognition = recognition {
                self.recognitionView = recognition.view
                self.addSubview(recognition.view)
            }
        }
    }
    
    override func layout() {
        super.layout()
        recognitionView?.frame = contentView.frame
    }
    
    fileprivate let statusDisposable = MetaDisposable()
    
    var minX:CGFloat {
        if contentView.frame.minX > 0 {
            return frame.minX + contentView.frame.minX
        }
        return frame.minX
    }
    
    override var isOpaque: Bool {
        return true
    }
    
    override func scrollWheel(with event: NSEvent) {
        if magnify == 1.0 {
            superview?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    func updateStatus(_ status: Signal<MediaResourceStatus, NoError>) {
        statusDisposable.set((status |> deliverOnMainQueue).start(next: { [weak self] status in
            self?.updateProgress(status)
        }))
    }
    private func updateProgress(_ status: MediaResourceStatus) {
        
        switch status {
        case let .Fetching(_, progress), let .Paused(progress):
            if self.progressView == nil {
                self.progressView = RadialProgressView()
                self.addSubview(self.progressView!)
                self.progressView!.center()
            }
            progressView?.state = .ImpossibleFetching(progress: progress, force: false)
        case .Local:

            if let progressView = self.progressView {
                progressView.state = .ImpossibleFetching(progress: 1, force: false)
                self.progressView = nil
                progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] complete in
                    if complete {
                        progressView?.removeFromSuperview()
                    }
                })
            }
        case .Remote:
            if self.progressView == nil {
                self.progressView = RadialProgressView()
                self.addSubview(self.progressView!)
                self.progressView!.center()
            }
            progressView?.state = .Remote
        }
        
        progressView?.userInteractionEnabled = status != .Local
    }
    
    override func mouseInside() -> Bool {
        return super.mouseInside()
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    private let fillFrame:(GMagnifyView)->NSRect
    private let prevAction:()->Void
    private let nextAction:()->Void
    private let hasPrev:()->Bool
    private let hasNext:()->Bool
    private let dismiss:()->Void
    private let prev: Control
    private let next: Control
    init(_ contentView: NSView, contentSize: NSSize, prev: Control, next: Control, fillFrame:@escaping(GMagnifyView)->NSRect, prevAction: @escaping()->Void, nextAction:@escaping()->Void, hasPrev: @escaping()->Bool, hasNext:@escaping()->Bool, dismiss:@escaping()->Void) {
        self.fillFrame = fillFrame
        self.prevAction = prevAction
        self.nextAction = nextAction
        self.prev = prev
        self.next = next
        self.hasPrev = hasPrev
        self.hasNext = hasNext
        self.dismiss = dismiss
        super.init(contentView, contentSize: contentSize)
        prev.alphaValue = 0
        next.alphaValue = 0
    }
    
    override var contentSize: NSSize {
        didSet {
            if frame.origin != NSZeroPoint {
                self.frame = fillFrame(self)
            }
        }
    }
    
    
    override func mouseUp(with theEvent: NSEvent) {
        let point = convert(theEvent.locationInWindow, from: nil)

        if point.x > frame.width - 80 && self.hasNext() {
            nextAction()
        } else if point.x < 80 && self.hasPrev() {
            prevAction()
        } else if let recognition = recognition, recognition.hasSelectedText {
            return
        } else {
            dismiss()
        }
    }
    
    func hideOrShowControls(hasPrev: Bool, hasNext: Bool, animated: Bool) {
        guard let window = window as? Window else {return}
        
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        (animated ? prev.animator() : prev).alphaValue = point.x > 80 || !hasPrev ? 0 : 1
        (animated ? next.animator() : next).alphaValue = point.x < frame.width - 80 || !hasNext ? 0 : 1
    }
    
    override func add(magnify: CGFloat, for location: NSPoint, animated: Bool) {
        super.add(magnify: magnify, for: location, animated: animated)
        if self.magnify != 1 {
            recognition?.cancelSelection()
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        progressView?.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class GalleryPageView : NSView {
    init() {
        super.init(frame:NSZeroRect)
        self.wantsLayer = true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private final class PageController : NSPageController {
    
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
    }
}

class GalleryPageController : NSObject, NSPageControllerDelegate {

    private let controller:PageController = PageController()
    private let ioDisposabe:MetaDisposable = MetaDisposable()
    private let smartUpdaterDisposable = MetaDisposable()
    private var identifiers:[NSPageController.ObjectIdentifier:MGalleryItem] = [:]
    private var cache:NSCache<AnyObject, NSViewController> = NSCache()
    private var queuedTransitions:[UpdateTransition<MGalleryItem>] = []
    let contentInset:NSEdgeInsets
    private(set) var lockedTransition:Bool = false {
        didSet {
            if !lockedTransition {
                _ = enqueueTransitions()
            }
        }
    }
    private var startIndex:Int = -1
    let view:GalleryPageView = GalleryPageView()
    private let textView: FoldingTextView = FoldingTextView(frame: .zero)
    private var publicPhotoView: PublicPhotoView?
    private var adButton: TextButton?
    private let textContainer = View()
    private let textScrollView = ScrollView()
    private let window:Window
    private let autohideTextDisposable = MetaDisposable()
    private let magnifyDisposable = MetaDisposable()
    let selectedIndex:ValuePromise<Int> = ValuePromise(ignoreRepeated: false)
    let thumbsControl: GalleryThumbsControl
    private let indexDisposable = MetaDisposable()
    fileprivate let reversed: Bool
    private let navigationDisposable = MetaDisposable()
    private let _prev: ImageButton = ImageButton()
    private let _next: ImageButton = ImageButton()
    
    private var hasInited: Bool = false
    
    var selectedItemChanged: ((@escaping(MGalleryItem) -> Void)->Void)!
    var transition: ((@escaping(UpdateTransition<MGalleryItem>, MGalleryItem?) -> Void) -> Void)!

    private var transitionCallFunc: ((UpdateTransition<MGalleryItem>, MGalleryItem?) -> Void)?
    private var selectedItemCallFunc: ((MGalleryItem) -> Void)?
    private let interactions: GalleryInteractions
    init(frame:NSRect, contentInset:NSEdgeInsets, interactions:GalleryInteractions, window:Window, reversed: Bool) {
        self.contentInset = contentInset
        self.window = window
        self.reversed = reversed
        thumbsControl = GalleryThumbsControl(interactions: interactions)
        self.interactions = interactions
        super.init()
        
        self.selectedItemChanged = { [weak self] selectedItemCallFunc in
            self?.selectedItemCallFunc = selectedItemCallFunc
        }
        
        self.transition = { [weak self] transitionCallFunc in
            self?.transitionCallFunc = transitionCallFunc
        }
        
        _prev.animates = true
        _next.animates = true
        
        _prev.autohighlight = false
        _next.autohighlight = false
        _prev.set(image: theme.icons.galleryPrev, for: .Normal)
        _next.set(image: theme.icons.galleryNext, for: .Normal)
        
        _prev.set(background: .clear, for: .Normal)
        _next.set(background: .clear, for: .Normal)

        
        _prev.frame = NSMakeRect(0, 0, 60, frame.height)
        _next.frame = NSMakeRect(frame.width - 60, 0, 60, frame.height)
        
        _next.userInteractionEnabled = false
        _prev.userInteractionEnabled = false

        textContainer.addSubview(textView)
        textScrollView.documentView = textContainer
        
        textScrollView.applyExternalScroll = { [weak self] event in
            self?.adjustTextWith(event)
            return true
        }
        
        indexDisposable.set((selectedIndex.get()).start(next: { [weak self] index in
            guard let `self` = self else {return}
            
            let transition = self.thumbsControl.layoutItems(with: self.items, selectedIndex: index, animated: true)
            self.transitionCallFunc?(transition, self.selectedItem)
        }))
        
        cache.countLimit = 10
        textView.textSelectable = false
        textView.userInteractionEnabled = true
        
        var dragged: NSPoint? = nil
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self, !hasModals(self.window) else {return .rejected}
            
            guard let view = self.controller.selectedViewController?.view as? GMagnifyView else {
                return .rejected
            }
            
            if let view = view.contentView as? SVideoView, view.insideControls {
                dragged = nil
                return .invokeNext
            }
            
            if let _dragged = dragged {
                let difference = NSMakePoint(abs(_dragged.x - event.locationInWindow.x), abs(_dragged.y - event.locationInWindow.y))
                if difference.x >= 10 || difference.y >= 10 {
                    dragged = nil
                    if let recognition = view.recognition, recognition.hasRecognition {
                        return .invokeNext
                    } else {
                        return .invoked
                    }
                }
            }
            dragged = nil
            
            let point = self.controller.view.convert(event.locationInWindow, from: nil)
            let hitTestView = self.window.contentView?.hitTest(event.locationInWindow)

            if let textView = hitTestView as? TextView {
                textView.mouseUp(with: event)
                return .invoked
            } else if self.textView.mouseInside() {
                return .invoked
            } else if let view = self.publicPhotoView, NSPointInRect(point, view.frame) {
                return .invokeNext
            } else if let view = self.adButton, NSPointInRect(point, view.frame) {
                return .invokeNext
            }
            if let window = view.window as? Window, self.controller.view._mouseInside() {
                guard event.locationInWindow.x > 80 && event.locationInWindow.x < window.frame.width - 80 else {
                    view.mouseUp(with: event)
                    return .invoked
                }
                
                if let recognition = view.recognition {
                    if recognition.hasSelectedText {
                        recognition.cancelSelection()
                        return .invoked
                    }
                }
                
                if hitTestView is Control && hitTestView != view.recognition?.view {
                    return .rejected
                }
                
                if let view = view.contentView as? SVideoView, view.insideControls {
                    return .rejected
                }
                
                
                
                if hasPictureInPicture {
                    return .rejected
                }
                
                _ = interactions.dismiss(event)
                return .invoked
            } else if hitTestView is GalleryModernControlsView {
                _ = interactions.dismiss(event)
                return .invoked
            }
            return .invokeNext
        }, with: self, for: .leftMouseUp)
        
        
        window.set(mouseHandler: { event -> KeyHandlerResult in
            dragged = nil
            return .rejected
        }, with: self, for: .leftMouseDown)
    
        window.set(mouseHandler: { event -> KeyHandlerResult in
            guard dragged == nil else {return .rejected}
            dragged = event.locationInWindow
            return .rejected
        }, with: self, for: .leftMouseDragged)
        
        window.set(responder: { [weak self] () -> NSResponder? in
            return self?.controller.selectedViewController?.view
        }, with: self, priority: .high)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self {
                if strongSelf.lockedTransition {
                    return .invoked
                } else {
                    return .invokeNext
                }
            }
            return .invoked
        }, with: self, for: .scrollWheel)
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let view = self.controller.selectedViewController?.view as? MagnifyView

            if let view = view {
                let point = view.convert(event.locationInWindow, from: nil)
                
                var points:[NSPoint] = []
                
                points.append(NSMakePoint(self.textScrollView.frame.minX, self.textScrollView.frame.minY))
                
                points.append(NSMakePoint(self.textScrollView.frame.maxX, self.textScrollView.frame.minY))

                points.append(NSMakePoint(self.textScrollView.frame.maxX, self.textScrollView.frame.maxY))

                points.append(NSMakePoint(self.textScrollView.frame.minX, self.textScrollView.frame.maxY))

                points.append(NSMakePoint(self.textScrollView.frame.midX, self.textScrollView.frame.midY))

                
                var min_dst = point.distance(p2: points[0])
                for i in 1 ..< points.count {
                    let dst = point.distance(p2: points[i])
                    if dst < min_dst {
                        min_dst = dst
                    }
                }
                
                let max_dst: CGFloat = max(150, self.textScrollView.frame.height)
                
                if min_dst < max_dst {
                    self.autohideTextDisposable.set(nil)
                    if self.lockedTransition == false {
                        self.textScrollView.change(opacity: 1.0)
                    }
                } else {
                    if self.lockedTransition == false {
                        self.textScrollView.change(opacity: 0.0)
                    }
                }
            }

            self.configureTextAutohide()

            
            (self.controller.selectedViewController?.view as? GMagnifyView)?.hideOrShowControls(hasPrev: self.hasPrev, hasNext: self.hasNext, animated: true)
            return .rejected
        }, with: self, for: .mouseMoved)
        
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let view = self?.controller.selectedViewController?.view as? GMagnifyView, let window = view.window {
                
                let point = window.mouseLocationOutsideOfEventStream
                let hitTestView = window.contentView?.hitTest(point)
                if view.contentView == hitTestView || hitTestView == view.recognition?.view {
                    if let event = NSApp.currentEvent, let menu = interactions.contextMenu() {
                        AppMenu.show(menu: menu, event: event, for: view)
                    }
                } else {
                    return .invokeNext
                }
                
            }
            return .invoked
        }, with: self, for: .rightMouseDown)
        
        controller.view = view
        controller.view.frame = frame
        controller.delegate = self
        controller.transitionStyle = .horizontalStrip
    }
    
    private func configureTextAutohide() {
        let view = controller.selectedViewController?.view as? MagnifyView
        if textScrollView.superview != controller.view {
            textScrollView.removeFromSuperview()
            controller.view.addSubview(textScrollView)
        }
        if let view = publicPhotoView, view.superview != nil {
            view.removeFromSuperview()
            controller.view.addSubview(view)
        }
        if let view = adButton, view.superview != nil {
            view.removeFromSuperview()
            controller.view.addSubview(view)
        }
        autohideTextDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(view?.mouseInContent == true ? 5.0 : 1.5, queue: Queue.mainQueue())).start(next: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.textScrollView.change(opacity: self.textScrollView._mouseInside() ? 1 : 0)
        }))
    }
    
    var items: [MGalleryItem] {
        return controller.arrangedObjects.map {$0 as! MGalleryItem}
    }
    
    private var afterTransaction:(()->Void)? = nil
    
    func merge(with transition:UpdateTransition<MGalleryItem>, afterTransaction:(()->Void)? = nil) -> Bool {
        queuedTransitions.append(transition)
        self.afterTransaction = afterTransaction
        return enqueueTransitions()
    }
    
    var isFullScreen: Bool {
        if let view = controller.selectedViewController?.view as? MagnifyView {
            if view.contentView.window !== window {
                return true
            }
        }
        return false
    }
    
    func exitFullScreen() {
        self.selectedItem?.toggleFullScreen()
    }
    
    func toggleFullScreen() {
        self.selectedItem?.toggleFullScreen()
    }
    
    var itemView:NSView? {
        return (controller.selectedViewController?.view as? MagnifyView)?.contentView
    }
    
    func enqueueTransitions() -> Bool {
        if !lockedTransition {
            
            let wasInited = !controller.arrangedObjects.isEmpty
            let item: MGalleryItem? = !controller.arrangedObjects.isEmpty ? self.item(at: controller.selectedIndex) : nil
            let animated = !self.items.isEmpty
            
            var items:[MGalleryItem] = controller.arrangedObjects as! [MGalleryItem]
            items = reversed ? items.reversed() : items
            while !queuedTransitions.isEmpty {
                let transition = queuedTransitions[0]
                
                let searchItem:(AnyHashable, [MGalleryItem])->MGalleryItem? = { stableId, items in
                    for item in items {
                        if item.stableId == stableId {
                            return item
                        }
                    }
                    return nil
                }
                
                for rdx in transition.deleted.reversed() {
                    if items.count > rdx {
                        let item = items[rdx]
                        identifiers.removeValue(forKey: item.identifier)
                        cache.removeObject(forKey: item.identifier as AnyObject)
                        items.remove(at: rdx)
                    }
                }
                for (idx,item) in transition.inserted {
                    let item = searchItem(item.stableId, items) ?? item
                    identifiers[item.identifier] = item
                    items.insert(item, at: min(idx, items.count))
                }
                for (idx,item) in transition.updated {
                    let item = searchItem(item.stableId, items) ?? item
                    identifiers[item.identifier] = item
                    cache.removeObject(forKey: item.identifier as AnyObject)
                    if idx < items.count {
                        items[idx] = item
                    }
                }
                queuedTransitions.removeFirst()
            }
            
            items = reversed ? items.reversed() : items
            
            if self.items != items {
                
                if items.count > 0 {
                    
                    let previousSelected = self.selectedItem
                    
                    controller.arrangedObjects = items
                    controller.completeTransition()
                    
                    if let item = item {
                        for i in 0 ..< items.count {
                            if item.identifier == items[i].identifier {
                                if controller.selectedIndex != i {
                                    controller.selectedIndex = i
                                }
                                break
                            }
                        }
                    }
                    if wasInited {
                        items[controller.selectedIndex].request(immediately: false)
                        if previousSelected != self.selectedItem {
                            self.selectedItem?.appear(for: controller.selectedViewController?.view)
                        }
                    }
                }
                if wasInited {
                    transitionCallFunc?(self.thumbsControl.layoutItems(with: self.items, selectedIndex: controller.selectedIndex, animated: animated), selectedItem)
                }
            }
            if let item = selectedItem {
                (controller.selectedViewController?.view as? GMagnifyView)?.updateStatus(item.status)
            }
            afterTransaction?()

            return items.isEmpty
        }
        return false
    }
    
    var hasNext: Bool {
        return controller.selectedIndex < controller.arrangedObjects.count - 1
    }
    var hasPrev: Bool {
        return controller.selectedIndex > 0
    }
    
    func next() {
        if !lockedTransition {
            if let item = self.selectedItem as? MGalleryVideoItem, item.isFullscreen {
                return
            }
            let item = self.item(at: min(controller.selectedIndex + 1, controller.arrangedObjects.count - 1))
            item.request()
            
            if let index = self.items.firstIndex(of: item) {
                self.set(index: index, animated: false)
            }
        }
    }
    
    func prev() {
        if !lockedTransition {
            if let item = self.selectedItem as? MGalleryVideoItem, item.isFullscreen {
                return
            }
            let item = self.item(at: max(controller.selectedIndex - 1, 0))
            item.request()
            if let index = self.items.firstIndex(of: item) {
                self.set(index: index, animated: false)
            }
        }
    }
    
    var currentIndex: Int {
        return controller.selectedIndex
    }
    
    func zoomIn() {
        if let magnigy = controller.selectedViewController?.view as? MagnifyView {
            magnigy.zoomIn()
        }
    }
    
    func zoomOut() {
        if let magnigy = controller.selectedViewController?.view as? MagnifyView {
            magnigy.zoomOut()
        }
    }
    
    private func gotoLastItem() {
        if !lockedTransition {
            if let item = self.selectedItem as? MGalleryVideoItem, item.isFullscreen {
                return
            }
            let item = self.item(at: controller.arrangedObjects.count - 1)
            item.request()
            if let index = self.items.firstIndex(of: item) {
                self.set(index: index, animated: true)
            }
        }
    }
    
    
    
    func decreaseSpeed() {
        
    }
    
    func increaseSpeed() {
        
    }
    
    
    func rotateLeft() {
        guard let item = self.selectedItem else {return}
        item.disableAnimations = true
        
        _ = (item.rotate.get() |> take(1)).start(next: { [weak item] orientation in
            if let orientation = orientation {
                switch orientation {
                case .right:
                    item?.rotate.set(.down)
                case .down:
                    item?.rotate.set(.left)
                default:
                    item?.rotate.set(nil)
                }
            } else {
                item?.rotate.set(.right)
            }
        })
    }
    
    func set(index:Int, animated:Bool) {
        
        _ = enqueueTransitions()
        
        if queuedTransitions.isEmpty {
            let controller = self.controller
            let index = min(max(0,index),controller.arrangedObjects.count - 1)
            
            if animated {
                NSAnimationContext.runAnimationGroup({ (context) in
                    controller.animator().selectedIndex = index
                }) {
                    self.pageControllerDidEndLiveTransition(controller)
                }
            } else {
                let updated = controller.selectedIndex != index
                if controller.selectedIndex != index {
                    controller.selectedIndex = index
                    pageControllerDidEndLiveTransition(controller, force: updated)
                } else if currentController == nil {
                    selectedIndex.set(index)
                    pageControllerDidEndLiveTransition(controller, force: updated)
                }
                currentController = controller.selectedViewController
            }
            
            if items.count > 1, hasInited {
                items[min(max(self.controller.selectedIndex - 1, 0), items.count - 1)].request()
                items[index].request()
                items[min(max(self.controller.selectedIndex + 1, 0), items.count - 1)].request()
            }
        } 
    }
    

    func pageController(_ pageController: NSPageController, prepare viewController: NSViewController, with object: Any?) {
        if let object = object, let view = viewController.view as? MagnifyView {
            let item = self.item(for: object)
            view.contentSize = item.sizeValue
            view.minMagnify = item.minMagnify
            view.maxMagnify = item.maxMagnify
            
        
            item.size.set(.single(item.sizeValue))
            
            item.view.set(.single(view.contentView))
            
//            smartUpdaterDisposable.set(view.smartUpdaterValue.start(next: { size in
//                item.size.set(.single(size))
//            }))
            
        }
    }
    
    
    func pageControllerWillStartLiveTransition(_ pageController: NSPageController) {
        lockedTransition = true
        textScrollView.change(opacity: 0)
        startIndex = pageController.selectedIndex
        
        if items.count > 1 {
            items[min(max(pageController.selectedIndex - 1, 0), items.count - 1)].request()
            items[min(max(pageController.selectedIndex + 1, 0), items.count - 1)].request()
        }
    }
    
    func pageControllerDidEndLiveTransition(_ pageController: NSPageController, force:Bool) {
        let previousView = currentController?.view as? MagnifyView

        textScrollView.change(opacity: 0, animated: textScrollView.superview != nil, completion: { [weak textScrollView] completed in
            if completed {
                textScrollView?.removeFromSuperview()
            }
        })
        
        
        if startIndex != pageController.selectedIndex || force {
            if startIndex != -1, startIndex <= pageController.arrangedObjects.count - 1 {
                self.item(at: startIndex).disappear(for: previousView?.contentView)
            }
            startIndex = pageController.selectedIndex
            
            

            pageController.completeTransition()
            if  let controllerView = pageController.selectedViewController?.view as? GMagnifyView, previousView != controllerView || force {
                controllerView.hideOrShowControls(hasPrev: hasPrev, hasNext: hasNext, animated: !force)
                if hasInited {
                    self.selectedItem?.appear(for: controllerView.contentView)
                }
                controllerView.frame = view.focus(contentFrame.size, inset:contentInset)
                magnifyDisposable.set(controllerView.magnifyUpdaterValue.start(next: { [weak self] value in
                    self?.textScrollView.isHidden = value > 1.0
                }))
                
            }
        }
        
        let item = self.item(at: pageController.selectedIndex)
        if let text = item.caption {
            text.measure(width: min(item.sizeValue.width + 240, min(item.pagerSize.width - 200, 600)))
            textView.update(layout: text, animated: false)
            textView.setFrameSize(text.size)
                  
            textView.revealBlockAtIndex = { [weak self] index in
                self?.toggleQuoteBlock(index)
            }
            
            controller.view.addSubview(textScrollView)
            textScrollView.setFrameSize(textView.frame.size.width + 10, min(120, textView.frame.height) + 10)
            textScrollView.centerX(y: 100)
            textScrollView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
            textScrollView.layer?.cornerRadius = .cornerRadius
            
            textContainer.frame = NSMakeRect(0, 0, textScrollView.frame.width, textView.frame.height + 10)
            textView.centerX(y: 5)

        } else {
            textScrollView.removeFromSuperview()
        }
        
        if let photo = item.publicPhoto {
            let current: PublicPhotoView
            if let view = self.publicPhotoView {
                current = view
            } else {
                current = PublicPhotoView()
                self.publicPhotoView = current
                controller.view.addSubview(current)
                current.set(handler: { [weak self] _ in
                    self?.gotoLastItem()
                }, for: .Click)
                
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            current.centerX(y: 100)
            current.update(context: item.context, image: photo.image, peer: photo.peer)
            
        } else if let view = self.publicPhotoView {
            performSubviewRemoval(view, animated: true)
            self.publicPhotoView = nil
        }
        
        if let message = item.entry.message, let adAttribute = message.adAttribute {
            let current: TextButton
            if let view = self.adButton {
                current = view
            } else {
                current = TextButton()
                self.adButton = current
                controller.view.addSubview(current)
                current.scaleOnClick = true
            }
            
            current.setSingle(handler: { [weak self] _ in
                self?.interactions.invokeAd(message.id.peerId, adAttribute)
            }, for: .Down)
            
            current.set(text: adAttribute.buttonText, for: .Normal)
            current.set(font: .medium(.text), for: .Normal)
            current.set(color: .white, for: .Normal)
            current.set(background: darkAppearance.colors.grayBackground, for: .Normal)
            current.sizeToFit(.zero, NSMakeSize(300, 40), thatFit: true)
            current.layer?.cornerRadius = 10
            
            current.centerX(y: 30)

            
        } else if let view = self.adButton {
            performSubviewRemoval(view, animated: true)
            self.adButton = nil
        }
        
        configureTextAutohide()
    }
    
    private func toggleQuoteBlock(_ index: Int) {
        if let item = self.selectedItem, let caption = item.caption {
            caption.toggle(index)
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeOut)
            
            let prevSize = self.textView.frame.size
            let newSize = caption.size

            self.textView.update(layout: caption, animated: transition.isAnimated)
            
            transition.updateFrame(view: self.textView, frame: CGRect(origin: self.textView.frame.origin, size: caption.size))
            transition.updateFrame(view: textContainer, frame: CGRect(origin: textContainer.frame.origin, size: CGSize(width: textContainer.frame.width, height: caption.size.height + 10)))
            
            let dif = newSize.height - prevSize.height
            
            var rect = textScrollView.frame.offsetBy(dx: 0, dy: dif)
            rect.size.height += dif
            transition.updateFrame(view: textScrollView, frame: rect)
        }
    }
    
    private func adjustTextWith(_ event: NSEvent) {
        var frame = textScrollView.frame
        let documentSize = textScrollView.documentSize
        let documentOffset = textScrollView.documentOffset
        
        let nextScroll:()->CGFloat = {
            return max(0, min(documentOffset.y - event.scrollingDeltaY, documentSize.height - frame.height))
        }
        if textScrollView.documentOffset.y == 0 {
            frame.size.height -= event.scrollingDeltaY

            let reach: CGFloat = 400
            
            let max_limit = min(frame.size.height, documentSize.height, reach)
            let min_limit = min(100, documentSize.height)
            frame.size.height = max(max_limit, min_limit)
            
           
            textScrollView.frame = frame
            
            if max_limit == reach, documentSize.height > reach {
                textScrollView.clipView.scroll(to: NSMakePoint(0, nextScroll()))
            }
        } else {
            textScrollView.clipView.scroll(to: NSMakePoint(0, nextScroll()))
        }
    }
    
    private var currentController:NSViewController?
    
    func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
        pageControllerDidEndLiveTransition(pageController, force:false)
        currentController = pageController.selectedViewController
      //  if let view = pageController.view as? MagnifyView {
           // window.makeFirstResponder(view)
       // }
        lockedTransition = false
    }
    
    func pageController(_ pageController: NSPageController, didTransitionTo object: Any) {
        if pageController.selectedIndex >= 0 && pageController.selectedIndex < pageController.arrangedObjects.count {
            selectedIndex.set(pageController.selectedIndex)
        }
    }
    


    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        return item(for: object).identifier
    }
    
    
    var contentFrame:NSRect {
        let rect = NSMakeRect(frame.minX + contentInset.left, frame.minY + contentInset.top, frame.width - contentInset.left - contentInset.right, frame.height - contentInset.top - contentInset.bottom)
        
        return rect
    }
    
    func pageController(_ pageController: NSPageController, frameFor object: Any?) -> NSRect {
        if let object = object {
            let item = self.item(for: object)
            let size = item.sizeValue
            
            return view.focus(size.fitted(contentFrame.size), inset:self.contentInset)
        }
        return view.bounds
    }
    
    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        if let controller = cache.object(forKey: identifier as AnyObject)   {
            return controller
        } else {
            let controller = NSViewController()
            let item = identifiers[identifier]!
            let view = item.singleView()
            
            let magnify = GMagnifyView(view, contentSize:item.sizeValue, prev: _prev, next: _next, fillFrame: { [weak self] view in
                guard let `self` = self else {return NSZeroRect}
                
                return self.view.focus(self.contentFrame.size, inset: self.contentInset)
            }, prevAction: { [weak self] in
                self?.prev()
            }, nextAction: { [weak self] in
                self?.next()
            }, hasPrev: { [weak self] in
                return self?.hasPrev ?? false
            }, hasNext: { [weak self] in
                return self?.hasNext ?? false
            }, dismiss: { [weak self] in
                if let event = NSApp.currentEvent {
                    _ = self?.interactions.dismiss(event)
                }
            })
            
            magnify.recognition = GalleryRecognition(item)
            
            item.magnify.set(magnify.magnifyUpdaterValue |> deliverOnPrepareQueue)
            controller.view = magnify
            if hasInited {
                item.request()
            }
            magnify.updateStatus(item.status)
            cache.setObject(controller, forKey: identifier as AnyObject)
            
            return controller
        }
    }
    
    
    var frame:NSRect {
        return view.frame
    }
    
    var count: Int {
        return controller.arrangedObjects.count
    }
    
    func item(for object:Any) -> MGalleryItem {
        return object as! MGalleryItem
    }
    
    func select(by item: MGalleryItem) -> Void {
        if let index = index(for: item), !lockedTransition {
            set(index: index, animated: false)
        }
    }
    
    func index(for item:MGalleryItem) -> Int? {
        for i in 0 ..< controller.arrangedObjects.count {
            if let _item = controller.arrangedObjects[i] as? MGalleryItem {
                if _item.stableId == item.stableId {
                    return i
                }
            }
        }
        return nil
    }
    
    func item(at index:Int) -> MGalleryItem {
        return controller.arrangedObjects[index] as! MGalleryItem
    }
    
    var selectedItem:MGalleryItem? {
        if controller.arrangedObjects.count > 0 {
            return controller.arrangedObjects[controller.selectedIndex] as? MGalleryItem
        }
        return nil
    }
    
    func hideVideoControls() -> Bool {
        if let item = self.selectedItem as? MGalleryVideoItem {
            return item.hideControls()
        }
        return false
    }
    
    func copySelectedText() -> Bool {
        if let view = self.controller.selectedViewController?.view as? GMagnifyView {
            if let recognition = view.recognition {
                return recognition.copySelectedText()
            }
        }
        return false
    }
    
    var selectedText: String? {
        if let view = self.controller.selectedViewController?.view as? GMagnifyView {
            if let recognition = view.recognition {
                return recognition.selectedText
            }
        }
        return nil
    }
    
    func animateIn( from:@escaping(AnyHashable)->NSView?, completion:(()->Void)? = nil, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil, addVideoTimebase:(((AnyHashable, NSView))->Void)? = nil, showBackground:(()->Void)? = nil) ->Void {
        
        window.contentView?.addSubview(_prev)
        window.contentView?.addSubview(_next)
        textScrollView.change(opacity: 0, animated: false)
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = self.selectedItem {
            item.request()
            lockedTransition = true
            if let oldView = from(item.stableId), let oldWindow = oldView.window, let oldScreen = oldWindow.screen {
                selectedView.isHidden = true
                
                ioDisposabe.set((item.image.get() |> map { $0.value } |> take(1) |> timeout(0.7, queue: Queue.mainQueue(), alternate: .single(.image(nil, nil)))).start(next: { [weak self, weak oldView, weak selectedView] value in
                    
                    
                    if let view = self?.view, let contentInset = self?.contentInset, let contentFrame = self?.contentFrame, let oldView = oldView {
                        let newRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset: contentInset)
                        var oldRect = oldWindow.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                        oldRect.origin = oldRect.origin.offsetBy(dx: -oldScreen.frame.minX, dy: -oldScreen.frame.minY)
                        selectedView?.contentSize = item.sizeValue.fitted(contentFrame.size)
                        
                        var value = value
                        
                        if value.hasValue, let strongSelf = self {
                            self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 0, newAlphaTo:1, oldAlphaFrom: 1, oldAlphaTo:0, contents: value, oldView: oldView, completion: { [weak strongSelf, weak selectedView] in
                                selectedView?.isHidden = false
//                                strongSelf?.textScrollView.change(opacity: 1.0)
                                strongSelf?.hasInited = true
                                strongSelf?.selectedItem?.appear(for: selectedView?.contentView)
                                strongSelf?.lockedTransition = false
                            }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
                        } else {
                            selectedView?.isHidden = false
                            self?.hasInited = true
                            self?.selectedItem?.appear(for: selectedView?.contentView)
                            self?.lockedTransition = false
                        }
                        if let selectedView = selectedView {
                            addVideoTimebase?((item.stableId, selectedView.contentView))
                        }
                    }
                    
                    showBackground?()

                    completion?()

                }))
            } else {
                ioDisposabe.set((item.image.get() |> take(1)).start(next: { [weak self, weak selectedView] image in
                    if let selectedView = selectedView {
                        selectedView.isHidden = false
                        selectedView.swapView(selectedView.contentView)
                        self?.lockedTransition = false
                        self?.hasInited = true
                        self?.selectedItem?.appear(for: selectedView.contentView)
                        if let completion = completion {
                            completion()
                            self?.window.applyResponderIfNeeded()
                        }
                    }
                    
                }))
            }
        }
    }
    
    func animate(oldRect:NSRect, newRect:NSRect, newAlphaFrom:CGFloat, newAlphaTo:CGFloat, oldAlphaFrom:CGFloat, oldAlphaTo:CGFloat, contents:GPreviewValue, oldView:NSView, completion:@escaping ()->Void, stableId: AnyHashable, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil) {
        
        lockedTransition = true
        
        
        let view = self.view
        
        
        let newView:NSView //

        switch contents {
        case let .image(contents, _):
            newView = NSView(frame: newRect)
            newView.wantsLayer = true
            newView.layer?.contents = contents
        case let .view(view):
            newView = view ?? NSView(frame: newRect)
            newView.frame = newRect
        }
        
        
        let copyView = oldView.copy() as! NSView
        addAccesoryOnCopiedView?((stableId, copyView))

        copyView.frame = NSMakeRect(oldRect.minX, oldRect.minY, oldAlphaFrom == 0 ? newRect.width : oldRect.width, oldAlphaFrom == 0 ? newRect.height : oldRect.height)
        copyView.wantsLayer = true
        view.addSubview(newView)
        view.addSubview(copyView)
        

        
        CATransaction.begin()
        
        let duration:Double = 0.25
        
        let timingFunction: CAMediaTimingFunctionName = .spring
        
        
        
        
        newView.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        newView.layer?.animateAlpha(from: newAlphaFrom, to: newAlphaTo, duration: duration / 2, timingFunction: timingFunction, removeOnCompletion: false)
        
        
        newView.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        newView.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)

        
        copyView.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        copyView.layer?.animateScaleX(from: oldAlphaFrom == 0 ? oldRect.width / newRect.width : 1, to: oldAlphaFrom != 0 ? newRect.width / oldRect.width : 1, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        copyView.layer?.animateScaleY(from: oldAlphaFrom == 0 ? oldRect.height / newRect.height : 1, to: oldAlphaFrom != 0 ? newRect.height / oldRect.height : 1, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)

        copyView.layer?.animateAlpha(from: oldAlphaFrom , to: oldAlphaTo, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak self, weak copyView, weak newView] _ in
            completion()
            self?.lockedTransition = false
            newView?.removeFromSuperview()
            copyView?.removeFromSuperview()
        })
        CATransaction.commit()


    }
    
    func animateOut( to:@escaping(AnyHashable)->NSView?, completion:(((Bool, AnyHashable?))->Void)? = nil, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil, addVideoTimebase:(((AnyHashable, NSView))->Void)? = nil) ->Void {
        
        lockedTransition = true
        
        
        textScrollView.change(opacity: 0, animated: true)
        
        if let view = publicPhotoView {
            performSubviewRemoval(view, animated: true)
            self.publicPhotoView = nil
        }
        if let view = adButton {
            performSubviewRemoval(view, animated: true)
            self.adButton = nil
        }
        
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = selectedItem {
            selectedView.isHidden = true
            item.disappear(for: selectedView.contentView)
            if let oldView = to(item.stableId), let window = oldView.window, let screen = window.screen {
                var newRect = window.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                newRect.origin = newRect.origin.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
                let oldRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset:contentInset)
                
                ioDisposabe.set((item.image.get() |> map { $0.value } |> take(1) |> timeout(0.1, queue: Queue.mainQueue(), alternate: .single(.image(nil, nil)))).start(next: { [weak self, weak item] value in
                    if let item = item {
                        self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 1, newAlphaTo:0, oldAlphaFrom: 0, oldAlphaTo: 1, contents: value, oldView: oldView, completion: { [weak item] in
                            if let item = item {
                                completion?((true, item.stableId))
                            }
                        }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
                    }
                }))
                
                addVideoTimebase?((item.stableId, selectedView.contentView))


            } else {
                view._change(opacity: 0, completion: { (_) in
                    completion?((false, item.stableId))
                })
            }
        } else {
            view._change(opacity: 0, completion: { (_) in
                completion?((false, nil))
            })
        }
    }
    
    var recognition: GalleryRecognition? {
        return (self.controller.selectedViewController?.view as? GMagnifyView)?.recognition
    }
    
    deinit {
        window.removeAllHandlers(for: self)
        ioDisposabe.dispose()
        navigationDisposable.dispose()
        autohideTextDisposable.dispose()
        magnifyDisposable.dispose()
        indexDisposable.dispose()
        smartUpdaterDisposable.dispose()
        cache.removeAllObjects()
    }

}

