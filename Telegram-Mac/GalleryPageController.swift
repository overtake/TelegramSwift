//
//  GalleryPageController.swift
//  TelegramMac
//
//  Created by keepcoder on 14/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import AVFoundation
import AVKit
import TelegramCoreMac
import PostboxMac
fileprivate class GMagnifyView : MagnifyView  {
    private let progressView: RadialProgressView = RadialProgressView()
    fileprivate let statusDisposable = MetaDisposable()
    
    var minX:CGFloat {
        if contentView.frame.minX > 0 {
            return frame.minX + contentView.frame.minX
        }
        return frame.minX
    }
    
    func updateStatus(_ status: Signal<MediaResourceStatus, Void>) {
        statusDisposable.set((status |> deliverOnMainQueue).start(next: { [weak self] status in
            self?.updateProgress(status)
        }))
    }
    private func updateProgress(_ status: MediaResourceStatus) {
        progressView.isHidden = true
        switch status {
        case let .Fetching(_, progress):
            progressView.state = .ImpossibleFetching(progress: progress, force: false)
            progressView.isHidden = false
        case .Local:
            progressView.state = .Play
        case .Remote:
            progressView.state = .Remote
            progressView.isHidden = false
        }
        
        progressView.userInteractionEnabled = status != .Local
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    private let fillFrame:(GMagnifyView)->NSRect
    
    init(_ contentView: NSView, contentSize: NSSize, fillFrame:@escaping(GMagnifyView)->NSRect) {
        self.fillFrame = fillFrame
        super.init(contentView, contentSize: contentSize)
        addSubview(progressView)
        progressView.isHidden = true
        progressView.center()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        progressView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class GalleryPageView : NSView {
    init() {
        super.init(frame:NSZeroRect)
        //self.wantsLayer = true
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class GalleryPageController : NSObject, NSPageControllerDelegate {

    private let controller:NSPageController = NSPageController()
    private let ioDisposabe:MetaDisposable = MetaDisposable()
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
    init(frame:NSRect, contentInset:NSEdgeInsets, interactions:GalleryInteractions, window:Window, reversed: Bool) {
        self.contentInset = contentInset
        self.window = window
        self.reversed = reversed
        thumbsControl = GalleryThumbsControl(interactions: interactions)

        super.init()
        
        indexDisposable.set((selectedIndex.get()).start(next: { [weak self] index in
            guard let `self` = self else {return}
            
            self.thumbsControl.layoutItems(with: self.items, selectedIndex: index, animated: true)
        }))
        
        cache.countLimit = 10
        captionView.isSelectable = false
        captionView.userInteractionEnabled = false
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let view = self?.controller.selectedViewController?.view as? GMagnifyView, let window = view.window {
                
                let point = window.mouseLocationOutsideOfEventStream                
                if point.x < view.minX && !view.mouseInContent && view.magnify == 1.0 {
                    _ = interactions.previous()
                } else if view.mouseInContent && view.magnify == 1.0 {
                    _ = interactions.next()
                } else {
                    let hitTestView = window.contentView?.hitTest(point)
                    if hitTestView is GalleryBackgroundView || view.contentView == hitTestView?.subviews.first {
                        _ = interactions.dismiss()

                    } else {
                        return .invokeNext
                    }
                }
                
            }
            return .invoked
        }, with: self, for: .leftMouseUp)
        
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
            self?.autohideCaptionDisposable.set(nil)
            if self?.lockedTransition == false {
                self?.captionView.change(opacity: 1.0)
                self?.configureCaptionAutohide()
            }
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
        autohideCaptionDisposable.set((Signal<Void, Void>.single(Void()) |> delay(view?.mouseInContent == true ? 5.0 : 1.5, queue: Queue.mainQueue())).start(next: { [weak self] in
            self?.captionView.change(opacity: 0)
        }))
    }
    
    var items: [MGalleryItem] {
        return controller.arrangedObjects.map {$0 as! MGalleryItem}
    }
    
    func merge(with transition:UpdateTransition<MGalleryItem>) -> Bool {
        queuedTransitions.append(transition)
        return enqueueTransitions()
    }
    
    var isFullScreen: Bool {
        if let view = controller.selectedViewController?.view as? MagnifyView {
            if view.contentView.frame.size == window.frame.size {
                return true
            }
        }
        return false
    }
    
    func exitFullScreen() {
        if let view = controller.selectedViewController?.view as? MagnifyView {
            if let view = view.contentView as? AVPlayerView {

                let controls = view.subviews.last?.subviews.last
                if let view = controls?.subviews.first?.subviews.last?.subviews.first?.subviews.last?.subviews.last?.subviews.last {
                    if let view = view as? NSButton {
                        view.performClick(self)
                    }
                }
            }
        }
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
                    let item = items[rdx]
                    identifiers.removeValue(forKey: item.identifier)
                    items.remove(at: rdx)                    
                }
                for (idx,item) in transition.inserted {
                    let item = searchItem(item.stableId) ?? item
                    identifiers[item.identifier] = item
                    items.insert(item, at: idx)
                }
                for (idx,item) in transition.updated {
                    let item = searchItem(item.stableId) ?? item
                    identifiers[item.identifier] = item
                    items[idx] = item
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
                self.thumbsControl.layoutItems(with: self.items, selectedIndex: controller.selectedIndex, animated: animated)
            }
            
            

            return items.isEmpty
        }
        return false
    }
    
    func next() {
        if !lockedTransition {
            let item = self.item(at: min(controller.selectedIndex + 1, controller.arrangedObjects.count - 1))
            item.size.set(.single(item.pagerSize))
            item.request()
            navigationDisposable.set((item.image.get() |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let `self` = self else {return}
                if let index = self.items.index(of: item) {
                    self.set(index: index, animated: false)
                }
            }))
        }
    }
    
    func prev() {
        if !lockedTransition {
            let item = self.item(at: max(controller.selectedIndex - 1, 0))
            item.size.set(.single(item.pagerSize))
            item.request()
            navigationDisposable.set((item.image.get() |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let `self` = self else {return}
                if let index = self.items.index(of: item) {
                    self.set(index: index, animated: false)
                }
            }))
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
                }
                pageControllerDidEndLiveTransition(controller, force:true)
                currentController = controller.selectedViewController

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
            item.size.set(view.smartUpdater.get())
        }
    }
    
    
    func pageControllerWillStartLiveTransition(_ pageController: NSPageController) {
        lockedTransition = true
        captionView.change(opacity: 0)
        startIndex = pageController.selectedIndex
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
            if  let controllerView = pageController.selectedViewController?.view as? MagnifyView, previousView != controllerView || force {
                let item = self.item(at: startIndex)
                item.appear(for: controllerView.contentView)
                controllerView.frame = view.focus(contentFrame.size, inset:contentInset)
                magnifyDisposable.set(controllerView.magnifyUpdater.get().start(next: { [weak self] value in
                    self?.captionView.isHidden = value > 1.0
                }))
                
            }
        }
        
        let item = self.item(at: pageController.selectedIndex)
        if let caption = item.caption {
            captionView.update(caption)
            captionView.backgroundColor = .blackTransparent
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
        if let view = pageController.view as? MagnifyView {
            window.makeFirstResponder(view)
        }
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
            let magnify = GMagnifyView(view, contentSize:item.sizeValue, fillFrame: { [weak self] view in
                guard let `self` = self else {return NSZeroRect}
                
                return self.view.focus(self.contentFrame.size, inset: self.contentInset)
            })
            controller.view = magnify
            magnify.updateStatus(item.status)
            cache.setObject(controller, forKey: identifier as AnyObject)
            item.request()
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
    
    func animateIn( from:@escaping(AnyHashable)->NSView?, completion:(()->Void)? = nil, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil) ->Void {
        
        
        captionView.change(opacity: 0, animated: false)
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = self.selectedItem {
            lockedTransition = true
            if let oldView = from(item.stableId), let oldWindow = oldView.window {
                selectedView.isHidden = true
                
                ioDisposabe.set((item.image.get() |> take(1)).start(next: { [weak self, weak selectedView] image in
                    
                    if let view = self?.view, let contentInset = self?.contentInset, let contentFrame = self?.contentFrame {
                        let newRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset:contentInset)
                        let oldRect = oldWindow.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                        
                        selectedView?.contentSize = item.sizeValue.fitted(contentFrame.size)
                        if let _ = image, let strongSelf = self {
                            self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 0, newAlphaTo:1, oldAlphaFrom: 1, oldAlphaTo:0, contents: image, oldView: oldView, completion: { [weak strongSelf] in
                                selectedView?.isHidden = false
                                strongSelf?.lockedTransition = false
                                strongSelf?.captionView.change(opacity: 1.0)
                            }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
                        } else {
                            selectedView?.isHidden = false
                            self?.lockedTransition = false
                        }
                    }
                    
                    
                    completion?()

                }))
            } else {
                ioDisposabe.set((item.image.get() |> take(1)).start(next: { [weak self, weak selectedView] image in
                    if let selectedView = selectedView {
                        selectedView.swapView(selectedView.contentView)
                        self?.lockedTransition = false
                        if let completion = completion {
                            completion()
                            self?.window.applyResponderIfNeeded()
                        }
                    }
                    
                }))
            }
        }
    }
    
    func animate(oldRect:NSRect, newRect:NSRect, newAlphaFrom:CGFloat, newAlphaTo:CGFloat, oldAlphaFrom:CGFloat, oldAlphaTo:CGFloat, contents:CGImage?, oldView:NSView, completion:@escaping ()->Void, stableId: AnyHashable, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil) {
        
        lockedTransition = true
        
        
        let view = self.view
        
        let newView:NSView = NSView(frame: NSMakeRect(oldRect.minX, oldRect.minY, newRect.width, newRect.height))
        newView.wantsLayer = true
        newView.layer?.opacity = Float(newAlphaFrom) + 0.5
        newView.layer?.contents = contents
        newView.layer?.backgroundColor = theme.colors.transparentBackground.cgColor
        
        
        let copyView = oldView.copy() as! NSView
        addAccesoryOnCopiedView?((stableId, copyView))

        copyView.frame = NSMakeRect(oldRect.minX, oldRect.minY, oldAlphaFrom == 0 ? newRect.width : oldRect.width, oldAlphaFrom == 0 ? newRect.height : oldRect.height)
        copyView.wantsLayer = true
        copyView.layer?.opacity = Float(oldAlphaFrom)
        view.addSubview(newView)
        view.addSubview(copyView)
        

        
        CATransaction.begin()
        
        let duration:Double = 0.25
        

        
        
        newView._change(pos: newRect.origin, animated: true, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        newView._change(opacity: newAlphaTo, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        
        
        newView.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        newView.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)

        
        copyView._change(pos: newRect.origin, animated: true, false, removeOnCompletion: false, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        copyView.layer?.animateScaleX(from: oldAlphaFrom == 0 ? oldRect.width / newRect.width : 1, to: oldAlphaFrom != 0 ? newRect.width / oldRect.width : 1, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        copyView.layer?.animateScaleY(from: oldAlphaFrom == 0 ? oldRect.height / newRect.height : 1, to: oldAlphaFrom != 0 ? newRect.height / oldRect.height : 1, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        
        
        //.animateBounds(from: NSMakeRect(0, 0, oldRect.width, oldRect.height), to: NSMakeRect(0, 0, newRect.width, newRect.height), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)

     //   copyView._change(size: newRect.size, animated: true, false, removeOnCompletion: false, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        copyView._change(opacity: oldAlphaTo, duration: duration, timingFunction: kCAMediaTimingFunctionSpring) { [weak self] _ in
            completion()
            self?.lockedTransition = false
            if let strongSelf = self {
                newView.removeFromSuperview()
                copyView.removeFromSuperview()
                Queue.mainQueue().after(0.3, { [weak strongSelf] in
                    if let view = strongSelf?.controller.selectedViewController?.view as? MagnifyView {
                        strongSelf?.window.makeFirstResponder(view.contentView)
                    }
                })
            }
        }
        CATransaction.commit()


    }
    
    func animateOut( to:@escaping(AnyHashable)->NSView?, completion:(((Bool, AnyHashable?))->Void)? = nil, addAccesoryOnCopiedView:(((AnyHashable?, NSView))->Void)? = nil) ->Void {
        
        lockedTransition = true
        
        
        captionView.change(opacity: 0, animated: true)
        
        if let selectedView = controller.selectedViewController?.view as? MagnifyView, let item = selectedItem {
            selectedView.isHidden = true
            item.disappear(for: selectedView.contentView)
            if let oldView = to(item.stableId), let window = oldView.window {
                let newRect = window.convertToScreen(oldView.convert(oldView.bounds, to: nil))
                let oldRect = view.focus(item.sizeValue.fitted(contentFrame.size), inset:contentInset)
                
                ioDisposabe.set((item.image.get() |> take(1)).start(next: { [weak self] (image) in
                    self?.animate(oldRect: oldRect, newRect: newRect, newAlphaFrom: 1, newAlphaTo:0, oldAlphaFrom: 0, oldAlphaTo: 1, contents: image, oldView: oldView, completion: {
                        completion?((true, item.stableId))
                    }, stableId: item.stableId, addAccesoryOnCopiedView: addAccesoryOnCopiedView)
                }))

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
    }

}

