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
import SyncCore
import Postbox

fileprivate class GMagnifyView : MagnifyView  {
    private var progressView: RadialProgressView?

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
    
    func updateStatus(_ status: Signal<MediaResourceStatus, NoError>) {
        statusDisposable.set((status |> deliverOnMainQueue).start(next: { [weak self] status in
            self?.updateProgress(status)
        }))
    }
    private func updateProgress(_ status: MediaResourceStatus) {
        
        switch status {
        case let .Fetching(_, progress):
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
        self.canDrawSubviewsIntoLayer = true
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class GalleryPageController : NSObject, NSPageControllerDelegate {

    private let controller:NSPageController = NSPageController()
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
    private let captionView: TextView = TextView()
    private let window:Window
    private let autohideCaptionDisposable = MetaDisposable()
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

        
        indexDisposable.set((selectedIndex.get()).start(next: { [weak self] index in
            guard let `self` = self else {return}
            
            let transition = self.thumbsControl.layoutItems(with: self.items, selectedIndex: index, animated: true)
            self.transitionCallFunc?(transition, self.selectedItem)
        }))
        
        cache.countLimit = 10
        captionView.isSelectable = false
        captionView.userInteractionEnabled = true
        
        var dragged: NSPoint? = nil
        
        window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self, !hasModals(self.window) else {return .rejected}
            
            if let view = self.controller.selectedViewController?.view as? GMagnifyView {
                if let view = view.contentView as? SVideoView, view.insideControls {
                    dragged = nil
                    return .invokeNext
                }
                
            }
            
            if let _dragged = dragged {
                let difference = NSMakePoint(abs(_dragged.x - event.locationInWindow.x), abs(_dragged.y - event.locationInWindow.y))
                if difference.x >= 10 || difference.y >= 10 {
                    dragged = nil
                    return .invoked
                }
            }
            dragged = nil
            
            let point = self.controller.view.convert(event.locationInWindow, from: nil)
            
            if NSPointInRect(point, self.captionView.frame), self.captionView.layer?.opacity != 0, let captionLayout = self.captionView.layout, captionLayout.link(at: self.captionView.convert(event.locationInWindow, from: nil)) != nil {
                self.captionView.mouseUp(with: event)
                return .invoked
            } else if self.captionView.mouseInside() {
                return .invoked
            }
            if let view = self.controller.selectedViewController?.view as? GMagnifyView, let window = view.window as? Window, self.controller.view._mouseInside() {
                guard event.locationInWindow.x > 80 && event.locationInWindow.x < window.frame.width - 80 else {
                    view.mouseUp(with: event)
                    return .invoked
                }
                
                if let view = view.contentView as? SVideoView, view.insideControls {
                    return .rejected
                }
                if hasPictureInPicture {
                    return .rejected
                }
                
                _ = interactions.dismiss()
                return .invoked
            }
            return .invokeNext
        }, with: self, for: .leftMouseUp)
        
    
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
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.autohideCaptionDisposable.set(nil)
            if self.lockedTransition == false {
                self.captionView.change(opacity: 1.0)
                self.configureCaptionAutohide()
            }
            (self.controller.selectedViewController?.view as? GMagnifyView)?.hideOrShowControls(hasPrev: self.hasPrev, hasNext: self.hasNext, animated: true)
            return .rejected
        }, with: self, for: .mouseMoved)
        
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let view = self?.controller.selectedViewController?.view as? GMagnifyView, let window = view.window {
                
                let point = window.mouseLocationOutsideOfEventStream
                let hitTestView = window.contentView?.hitTest(point)
                if view.contentView == hitTestView {
                    if let event = NSApp.currentEvent, let menu = interactions.contextMenu() {
                        NSMenu.popUpContextMenu(menu, with: event, for: view)
                    }
                } else {
                    return .invokeNext
                }
                
            }
            return .invoked
        }, with: self, for: .rightMouseUp)
        
        controller.view = view
        controller.view.frame = frame
        controller.delegate = self
        controller.transitionStyle = .horizontalStrip
    }
    
    private func configureCaptionAutohide() {
        let view = controller.selectedViewController?.view as? MagnifyView
        captionView.removeFromSuperview()
        controller.view.addSubview(captionView)
        autohideCaptionDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(view?.mouseInContent == true ? 5.0 : 1.5, queue: Queue.mainQueue())).start(next: { [weak self] in
            self?.captionView.change(opacity: 0)
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
                
                let searchItem:(AnyHashable)->MGalleryItem? = { stableId in
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
                        items.remove(at: rdx)
                    }
                }
                for (idx,item) in transition.inserted {
                    let item = searchItem(item.stableId) ?? item
                    identifiers[item.identifier] = item
                    items.insert(item, at: min(idx, items.count))
                }
                for (idx,item) in transition.updated {
                    let item = searchItem(item.stableId) ?? item
                    identifiers[item.identifier] = item
                    if idx < items.count {
                        items[idx] = item
                    }
                }
                queuedTransitions.removeFirst()
            }
            
            items = reversed ? items.reversed() : items
            
            if self.items != items {
                
                if items.count > 0 {
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
                    }
                    //pageControllerDidEndLiveTransition(controller, force: true)
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
            let item = self.item(at: min(controller.selectedIndex + 1, controller.arrangedObjects.count - 1))
            item.request()
            
            if let index = self.items.firstIndex(of: item) {
                self.set(index: index, animated: false)
            }
        }
    }
    
    func prev() {
        if !lockedTransition {
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
                if controller.selectedIndex != index {
                    controller.selectedIndex = index
                    pageControllerDidEndLiveTransition(controller, force:true)
                } else if currentController == nil {
                    selectedIndex.set(index)
                }
                currentController = controller.selectedViewController
                
            }
            
            if items.count > 1, hasInited {
                items[min(max(self.controller.selectedIndex - 1, 0), items.count - 1)].request()
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
            
            
            item.view.set(.single(view.contentView))
            smartUpdaterDisposable.set(view.smartUpdaterValue.start(next: { size in
                item.size.set(.single(size))
            }))
            
        }
    }
    
    
    func pageControllerWillStartLiveTransition(_ pageController: NSPageController) {
        lockedTransition = true
        captionView.change(opacity: 0)
        startIndex = pageController.selectedIndex
        if items.count > 1 {
            items[min(max(pageController.selectedIndex - 1, 0), items.count - 1)].request()
            items[min(max(pageController.selectedIndex + 1, 0), items.count - 1)].request()
        }
    }
    
    func pageControllerDidEndLiveTransition(_ pageController: NSPageController, force:Bool) {
        let previousView = currentController?.view as? MagnifyView
        
        captionView.change(opacity: 0, animated: captionView.superview != nil, completion: { [weak captionView] completed in
            if completed {
                captionView?.removeFromSuperview()
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
                let item = self.item(at: startIndex)
                if hasInited {
                    item.appear(for: controllerView.contentView)
                    
                }
                controllerView.frame = view.focus(contentFrame.size, inset:contentInset)
                magnifyDisposable.set(controllerView.magnifyUpdater.get().start(next: { [weak self] value in
                    self?.captionView.isHidden = value > 1.0
                }))
                
            }
        }
        
        let item = self.item(at: pageController.selectedIndex)
        if let caption = item.caption {
            captionView.update(caption)
            captionView.backgroundColor = NSColor.black.withAlphaComponent(0.5)
            captionView.disableBackgroundDrawing = true
            captionView.setFrameSize(captionView.frame.size.width + 10, captionView.frame.size.height + 8)
            captionView.layer?.cornerRadius = .cornerRadius
            
            view.addSubview(captionView)
            captionView.change(opacity: 1.0)
            captionView.centerX(y: 90)
        } else {
            captionView.update(nil)
        }
        
        configureCaptionAutohide()
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
            view.wantsLayer = true
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
                _ = self?.interactions.dismiss()
            })
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
    
    func animateIn( from:@escaping(AnyHashable)->NSView?, completion:(()->Void)? = nil, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil, addVideoTimebase:(((AnyHashable, NSView))->Void)? = nil) ->Void {
        
        window.contentView?.addSubview(_prev)
        window.contentView?.addSubview(_next)
        captionView.change(opacity: 0, animated: false)
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = self.selectedItem {
            item.request()
            lockedTransition = true
            if let oldView = from(item.stableId), let oldWindow = oldView.window {
                selectedView.isHidden = true
                
                ioDisposabe.set((item.image.get() |> take(1) |> timeout(0.7, queue: Queue.mainQueue(), alternate: .single(.image(nil)))).start(next: { [weak self, weak oldView, weak selectedView] value in
                    
                    if let view = self?.view, let contentInset = self?.contentInset, let contentFrame = self?.contentFrame, let oldView = oldView {
                        let newRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset:contentInset)
                        let oldRect = oldWindow.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                        
                        selectedView?.contentSize = item.sizeValue.fitted(contentFrame.size)
                        if value.hasValue, let strongSelf = self {
                            self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 0, newAlphaTo:1, oldAlphaFrom: 1, oldAlphaTo:0, contents: value, oldView: oldView, completion: { [weak strongSelf, weak selectedView] in
                                selectedView?.isHidden = false
                                strongSelf?.lockedTransition = false
                                strongSelf?.captionView.change(opacity: 1.0)
                                strongSelf?.hasInited = true
                                strongSelf?.selectedItem?.appear(for: selectedView?.contentView)
                            }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
                        } else {
                            selectedView?.isHidden = false
                            self?.hasInited = true
                            self?.lockedTransition = false
                            self?.selectedItem?.appear(for: selectedView?.contentView)

                        }
                        if let selectedView = selectedView {
                            addVideoTimebase?((item.stableId, selectedView.contentView))
                        }
                    }
                    
                    
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
        case let .image(contents):
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
        
        
        captionView.change(opacity: 0, animated: true)
        
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = selectedItem {
            selectedView.isHidden = true
            item.disappear(for: selectedView.contentView)
            if let oldView = to(item.stableId), let window = oldView.window {
                let newRect = window.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                let oldRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset:contentInset)
                
                ioDisposabe.set((item.image.get() |> take(1) |> timeout(0.1, queue: Queue.mainQueue(), alternate: .single(.image(nil)))).start(next: { [weak self] value in
                    self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 1, newAlphaTo:0, oldAlphaFrom: 0, oldAlphaTo: 1, contents: value, oldView: oldView, completion: {
                        completion?((true, item.stableId))
                    }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
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
    
    deinit {
        window.removeAllHandlers(for: self)
        ioDisposabe.dispose()
        navigationDisposable.dispose()
        autohideCaptionDisposable.dispose()
        magnifyDisposable.dispose()
        indexDisposable.dispose()
        smartUpdaterDisposable.dispose()
        cache.removeAllObjects()
    }

}

