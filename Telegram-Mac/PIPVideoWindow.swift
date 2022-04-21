//
//  PIPVideoWindow.swift
//  Telegram
//
//  Created by keepcoder on 26/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import AVKit
import SwiftSignalKit

private let pipFrameKey: String = "kPipFrameKey3"

 enum PictureInPictureControlMode {
    case normal
    case pip
}

protocol PictureInPictureControl {
    func pause()
    func play()
    func didEnter()
    func didExit()
    var view: NSView { get }
    var isPictureInPicture: Bool { get }
    
    func setMode(_ mode: PictureInPictureControlMode, animated: Bool)
}


private class PictureInpictureView : Control {
    private let _window: Window
    init(frame: NSRect, window: Window) {
        _window = window
        super.init(frame: frame)
        autoresizesSubviews = true
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseEntered(with: event)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override var window: NSWindow? {
        set {

        }
        get {
            return _window
        }
    }
}

fileprivate class ModernPictureInPictureVideoWindow: NSPanel {
    fileprivate let _window: Window
    fileprivate let control: PictureInPictureControl
    private let rect:NSRect
    private let restoreRect: NSRect
    fileprivate var forcePaused: Bool = false
    fileprivate let item: MGalleryItem
    fileprivate weak var _delegate: InteractionContentViewProtocol?
    fileprivate let _contentInteractions:ChatMediaLayoutParameters?
    fileprivate let _type: GalleryAppearType
    fileprivate let viewer: GalleryViewer
    fileprivate var eventLocalMonitor: Any?
    fileprivate var eventGlobalMonitor: Any?
    private var hideAnimated: Bool = true
    private let lookAtMessageDisposable = MetaDisposable()
    init(_ control: PictureInPictureControl, item: MGalleryItem, viewer: GalleryViewer, origin:NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
        self.viewer = viewer
        self._delegate = delegate
        self._contentInteractions = contentInteractions
        self._type = type
        self.control = control
        let minSize = control.view.frame.size.aspectFilled(NSMakeSize(250, 250))
        let size = item.notFittedSize.aspectFilled(NSMakeSize(250, 250)).aspectFilled(minSize)
        let newRect = NSMakeRect(origin.x, origin.y, size.width, size.height)
        self.rect = newRect
        self.restoreRect = NSMakeRect(origin.x, origin.y, control.view.frame.width, control.view.frame.height)
        self.item = item
        _window = Window(contentRect: newRect, styleMask: [.resizable], backing: .buffered, defer: true)
        super.init(contentRect: newRect, styleMask: [.resizable, .nonactivatingPanel], backing: .buffered, defer: true)

        //self.isOpaque = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary];

        
        
        let view = PictureInpictureView(frame: bounds, window: _window)
        self.contentView = view
        
        view.forceMouseDownCanMoveWindow = true
        
      //  self.contentView?.wantsLayer = true;
        self.contentView?.layer?.cornerRadius = 4;

        self.backgroundColor = .clear;
        control.view.frame = NSMakeRect(0, 0, newRect.width, newRect.height)
       // control.view.autoresizingMask = [.width, .height];
        

        control.view.setFrameOrigin(0, 0)
      //  contentView?.autoresizingMask = [.width, .height]
        contentView?.addSubview(control.view)
        
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            NSCursor.arrow.set()
            return .invoked
        }, with: self, for: .mouseMoved, priority: .low)
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            NSCursor.arrow.set()
            return .invoked
        }, with: self, for: .mouseEntered, priority: .low)
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            return .invoked
        }, with: self, for: .mouseExited, priority: .low)
        
        
        _window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            if event.clickCount == 2, let strongSelf = self {
                let inner = strongSelf.control.view.convert(event.locationInWindow, from: nil)                
                if NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0) == strongSelf.windowNumber, strongSelf.control.view.hitTest(inner) is MediaPlayerView {
                    strongSelf.hide()
                }
            }
            return .invoked
        }, with: self, for: .leftMouseDown, priority: .low)
        
        
        _window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            self?.findAndMoveToCorner()
            return .rejected
        }, with: self, for: .leftMouseUp, priority: .low)
        
        
        self.level = .modalPanel
        self.isMovableByWindowBackground = true

        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResized(_:)), name: NSWindow.didResizeNotification, object: self)

        
        
        eventLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
            guard let `self` = self else {return event}
            self._window.sendEvent(event)
            return event
        })
        
        eventGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp], handler: { [weak self] event in
                guard let `self` = self else {return}
                self._window.sendEvent(event)
            })


        if let message = item.entry.message {
            let messageView = item.context.account.postbox.messageView(message.id) |> deliverOnMainQueue
            lookAtMessageDisposable.set(messageView.start(next: { [weak self] view in
                if view.message == nil {
                    self?.hideAnimated = true
                    self?.hide()
                }
            }))
        }
        
        self.control.setMode(.pip, animated: true)
    }
    
    

    func hide() {
        

        
        if hideAnimated {
            contentView?._change(opacity: 0, animated: true, duration: 0.1, timingFunction: .linear)
            setFrame(NSMakeRect(frame.minX + (frame.width - 0) / 2, frame.minY + (frame.height - 0) / 2, 0, 0), display: true, animate: true)
        }
        
        orderOut(nil)
        window = nil
        _window.removeAllHandlers(for: self)
        if let monitor = eventLocalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = eventGlobalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        window = nil
        if control.isPictureInPicture {
            control.pause()
        }
    }

    func openGallery() {
        setFrame(restoreRect, display: true, animate: true)
        hideAnimated = false
        hide()
        showGalleryFromPip(item: item, gallery: self.viewer, delegate: _delegate, contentInteractions: _contentInteractions, type: _type)
    }

    deinit {
        if control.isPictureInPicture {
            control.pause()
        }
        self.control.setMode(.normal, animated: true)
        NotificationCenter.default.removeObserver(self)
        lookAtMessageDisposable.dispose()
    }

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        return 0.2
    }

    @objc func windowDidResized(_ notification: Notification) {
    
    }

    private func findAndMoveToCorner() {
        if let screen = self.screen {
            let rect = screen.frame.offsetBy(dx: -screen.visibleFrame.minX, dy: -screen.visibleFrame.minY)
            
            let point = self.frame.offsetBy(dx: -screen.visibleFrame.minX, dy: -screen.visibleFrame.minY)
            
            var options:BorderType = []
            
            if point.maxX > rect.width && point.minX < rect.width {
                options.insert(.Right)
            }
            
            if point.minX < 0 {
                options.insert(.Left)
            }
            
            if point.minY < 0 {
                options.insert(.Bottom)
            }
            
            
            var newFrame = self.frame
            
            if options.contains(.Right) {
                newFrame.origin.x = screen.visibleFrame.maxX - newFrame.width - 30
            }
            if options.contains(.Bottom) {
                newFrame.origin.y = screen.visibleFrame.minY + 30
            }
            if options.contains(.Left) {
                newFrame.origin.x = screen.visibleFrame.minX + 30
            }
            setFrame(newFrame, display: true, animate: true)

            
//            switch alignment {
//            case .topLeft:
//                setFrame(NSMakeRect(30, 30, self.frame.width, self.frame.height), display: true, animate: true)
//            case .topRight:
//                setFrame(NSMakeRect(frame.width - self.frame.width - 30, 30, self.frame.width, self.frame.height), display: true, animate: true)
//            case .bottomLeft:
//                setFrame(NSMakeRect(30, frame.height - self.frame.height - 30, self.frame.width, self.frame.height), display: true, animate: true)
//            case .bottomRight:
//                setFrame(NSMakeRect(frame.width - self.frame.width - 30, frame.height - self.frame.height - 30, self.frame.width, self.frame.height), display: true, animate: true)
//            }
        }
    }
    

    override var isResizable: Bool {
        return true
    }
    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: flag, animate: animateFlag)
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        if let screen = NSScreen.main {
            let savedRect: NSRect = NSMakeRect(0, 0, screen.frame.width * 0.3, screen.frame.width * 0.3)
            let convert_s = self.rect.size.aspectFilled(NSMakeSize(min(savedRect.width, 250), min(savedRect.height, 250)))
            self.aspectRatio = self.rect.size.fitted(NSMakeSize(savedRect.width, savedRect.height))
            self.minSize = self.rect.size.aspectFitted(NSMakeSize(savedRect.width, savedRect.height)).aspectFilled(NSMakeSize(250, 250))
            
            let frame = NSScreen.main?.frame ?? NSMakeRect(0, 0, 1920, 1080)
            
            self.maxSize = self.rect.size.aspectFitted(frame.size)

            self.setFrame(NSMakeRect(screen.frame.maxX - convert_s.width - 30, screen.frame.maxY - convert_s.height - 50, convert_s.width, convert_s.height), display: true, animate: true)
           
        }
    }


}



private var window: NSWindow?


var hasPictureInPicture: Bool {
    return window != nil
}

func showPipVideo(control: PictureInPictureControl, viewer: GalleryViewer, item: MGalleryItem, origin: NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
    closePipVideo()
    window = ModernPictureInPictureVideoWindow(control, item: item, viewer: viewer, origin: origin, delegate: delegate, contentInteractions: contentInteractions, type: type)
    window?.makeKeyAndOrderFront(nil)
}


func exitPictureInPicture() {
    if let window = window as? ModernPictureInPictureVideoWindow {
        window.openGallery()
    }
}

func pausepip() {
    if let window = window as? ModernPictureInPictureVideoWindow {
        window.control.pause()
        window.forcePaused = true
    }
}

func playPipIfNeeded() {
    if let window = window as? ModernPictureInPictureVideoWindow, window.forcePaused {
        window.control.play()
    }
}



func closePipVideo() {
    if let window = window as? ModernPictureInPictureVideoWindow {
        window.hide()
        window.control.pause()
    }
    window = nil
    
}
