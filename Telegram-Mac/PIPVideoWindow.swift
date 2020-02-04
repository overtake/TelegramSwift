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

fileprivate class PIPVideoWindow: NSPanel {
    fileprivate let playerView: VideoPlayerView
    private let rect:NSRect
    private let close:ImageButton = ImageButton()
    private let gallery:ImageButton = ImageButton()
    fileprivate var forcePaused: Bool = false
    fileprivate let item: MGalleryItem
    fileprivate weak var _delegate: InteractionContentViewProtocol?
    fileprivate let _contentInteractions:ChatMediaLayoutParameters?
    fileprivate let _type: GalleryAppearType
    fileprivate let viewer: GalleryViewer
    private var hideAnimated: Bool = true
    init(_ player: VideoPlayerView, item: MGalleryItem, viewer: GalleryViewer, origin:NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
        self.viewer = viewer
        self._delegate = delegate
        self._contentInteractions = contentInteractions
        self._type = type
        player.isPip = true
        self.playerView = player
        self.rect = NSMakeRect(origin.x, origin.y, player.frame.width, player.frame.height)
        self.item = item
        super.init(contentRect: rect, styleMask: [.closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: true)
        
        
        close.autohighlight = false
        close.set(image: #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(NSColor.white.withAlphaComponent(0.9)), for: .Normal)
       
        close.set(handler: { [weak self] _ in
            self?.hide()
        }, for: .Click)
        
        close.setFrameSize(40,40)
        
        close.layer?.cornerRadius = 20
        close.style = ControlStyle(backgroundColor: .blackTransparent, highlightColor: .grayIcon)
        close.layer?.opacity = 0.8
        
        
        gallery.autohighlight = false
        gallery.set(image: #imageLiteral(resourceName: "Icon_PipOff").precomposed(NSColor.white.withAlphaComponent(0.9)), for: .Normal)
        
        gallery.set(handler: { [weak self] _ in
            self?.openGallery()
        }, for: .Click)
        
        gallery.setFrameSize(40,40)
        
        gallery.layer?.cornerRadius = 20
        gallery.style = ControlStyle(backgroundColor: .blackTransparent, highlightColor: .grayIcon)
        gallery.layer?.opacity = 0.8
        

        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary];
        
        self.contentView?.wantsLayer = true;
        self.contentView?.layer?.cornerRadius = 4;
        
        self.contentView?.layer?.backgroundColor = NSColor.random.cgColor;
        self.backgroundColor = .clear;
        
        player.autoresizingMask = [.width, .height];
        
        player.setFrameOrigin(0,0)
        player.controlsStyle = .minimal
        self.contentView?.addSubview(player)
        
        self.contentView?.addSubview(close)
        self.contentView?.addSubview(gallery)


       
        self.level = .screenSaver
        self.isMovableByWindowBackground = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResized(_:)), name: NSWindow.didResizeNotification, object: self)

        
    }

    
    func hide() {
        playerView.isPip = false
        
        if hideAnimated {
            contentView?._change(opacity: 0, animated: true, duration: 0.1, timingFunction: .linear)
            setFrame(NSMakeRect(frame.minX + (frame.width - 0) / 2, frame.minY + (frame.height - 0) / 2, 0, 0), display: true, animate: true)
        }
        orderOut(nil)
        window = nil
    }
    
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        window = nil
        if playerView.controlsStyle != .floating {
            playerView.player?.pause()
        }
    }
    
    func openGallery() {
        close.change(opacity: 0, removeOnCompletion: false) { [weak close] completed in
            close?.removeFromSuperview()
        }
        gallery.change(opacity: 0, removeOnCompletion: false) { [weak gallery] completed in
            gallery?.removeFromSuperview()
        }
        playerView.controlsStyle = .floating
        setFrame(rect, display: true, animate: true)
        hideAnimated = false
        hide()
        showGalleryFromPip(item: item, gallery: self.viewer, delegate: _delegate, contentInteractions: _contentInteractions, type: _type)
    }
    
    deinit {
        if playerView.controlsStyle != .floating {
            playerView.player?.pause()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        return 0.2
    }
    
    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
    }


    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        close.change(opacity: 1, animated: true)
        gallery.change(opacity: 1, animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        close.change(opacity: 0, animated: true)
        gallery.change(opacity: 0, animated: true)
    }
    
    @objc func windowDidResized(_ notification: Notification) {
        let closePoint = NSMakePoint(10, frame.height - 50)
        let openPoint = NSMakePoint(closePoint.x + close.frame.width + 10, frame.height - 50)
        self.close.setFrameOrigin(closePoint)
        self.gallery.setFrameOrigin(openPoint)
        
    }
    
    override var isResizable: Bool {
        return true
    }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        
        
        Queue.mainQueue().justDispatch {
            if let screen = NSScreen.main {
                let savedRect: NSRect = NSMakeRect(0, 0, screen.frame.width * 0.3, screen.frame.width * 0.3)
                
                let convert_s = self.playerView.frame.size.fitted(NSMakeSize(savedRect.width, savedRect.height))
                self.aspectRatio = convert_s
                self.minSize = convert_s.aspectFilled(NSMakeSize(100, 100))
                let closePoint = NSMakePoint(10, convert_s.height - 50)
                let openPoint = NSMakePoint(closePoint.x + self.close.frame.width + 10, convert_s.height - 50)
                
                self.close.change(pos: closePoint, animated: false)
                self.gallery.change(pos: openPoint, animated: false)
                self.setFrame(NSMakeRect(screen.frame.maxX - convert_s.width - 30, screen.frame.maxY - convert_s.height - 50, convert_s.width, convert_s.height), display: true, animate: true)
                
            }
        }
    }
    

}

protocol PictureInPictureControl {
    func pause()
    func play()
    func didEnter()
    func didExit()
    var view: NSView { get }
    var isPictureInPicture: Bool { get }
}


private class PictureInpictureView : Control {
    private let _window: Window
    init(frame: NSRect, window: Window) {
        _window = window
        super.init(frame: frame)
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
    
    init(_ control: PictureInPictureControl, item: MGalleryItem, viewer: GalleryViewer, origin:NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
        self.viewer = viewer
        self._delegate = delegate
        self._contentInteractions = contentInteractions
        self._type = type
        self.control = control
        
      //  let difference = NSMakeSize(item.notFittedSize.width - item.sizeValue.width, item.notFittedSize.height - item.sizeValue.height)
        
        let newRect = NSMakeRect(origin.x, origin.y, item.notFittedSize.aspectFitted(control.view.frame.size).width, item.notFittedSize.aspectFitted(control.view.frame.size).height)
        self.rect = newRect //NSMakeRect(origin.x, origin.y, control.view.frame.width, control.view.frame.height)
        self.restoreRect = NSMakeRect(origin.x, origin.y, control.view.frame.width, control.view.frame.height)
        self.item = item
        _window = Window(contentRect: control.view.bounds, styleMask: [.resizable], backing: .buffered, defer: true)
        super.init(contentRect: newRect, styleMask: [.resizable, .nonactivatingPanel], backing: .buffered, defer: true)

        //self.isOpaque = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary];

        
        self.contentView = PictureInpictureView.init(frame: bounds, window: _window)
        
      //  self.contentView?.wantsLayer = true;
        self.contentView?.layer?.cornerRadius = 4;

        self.backgroundColor = .clear;
        control.view.frame = NSMakeRect(0, 0, newRect.width, newRect.height)
       // control.view.autoresizingMask = [.width, .height];
        

        control.view.setFrameOrigin(0, 0)
      //  contentView?.autoresizingMask = [.width, .height]
        contentView?.addSubview(control.view)
        
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            
            return .invoked
        }, with: self, for: .mouseMoved, priority: .low)
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            return .invoked
        }, with: self, for: .mouseEntered, priority: .low)
        
        _window.set(mouseHandler: { event -> KeyHandlerResult in
            return .invoked
        }, with: self, for: .mouseExited, priority: .low)
        
        
        _window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            if event.clickCount == 2, let strongSelf = self {
                let inner = strongSelf.control.view.convert(event.locationInWindow, from: nil)
                if NSPointInRect(event.locationInWindow, strongSelf.bounds), strongSelf.control.view.hitTest(inner) is MediaPlayerView {
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
        NotificationCenter.default.removeObserver(self)
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
            let convert_s = self.rect.size.fitted(NSMakeSize(savedRect.width, savedRect.height))
            self.aspectRatio = self.rect.size.fitted(NSMakeSize(savedRect.width, savedRect.height))
            self.minSize = self.rect.size.fitted(NSMakeSize(savedRect.width, savedRect.height)).aspectFilled(NSMakeSize(250, 250))
            
            let frame = NSScreen.main?.frame ?? NSMakeRect(0, 0, 1920, 1080)
            
            self.maxSize = self.rect.size.fitted(NSMakeSize(savedRect.width, savedRect.height)).aspectFilled(NSMakeSize(frame.width / 3, frame.height / 3))

            
            self.setFrame(NSMakeRect(screen.frame.maxX - convert_s.width - 30, screen.frame.maxY - convert_s.height - 50, convert_s.width, convert_s.height), display: true, animate: true)
           
        }
    }


}



private var window: NSWindow?


var hasPictureInPicture: Bool {
    return window != nil
}

func showLegacyPipVideo(_ playerView:VideoPlayerView, viewer: GalleryViewer, item: MGalleryItem, origin: NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
    closePipVideo()
    window = PIPVideoWindow(playerView, item: item, viewer: viewer, origin: origin, delegate: delegate, contentInteractions: contentInteractions, type: type)
    window?.makeKeyAndOrderFront(nil)
}

func showPipVideo(control: PictureInPictureControl, viewer: GalleryViewer, item: MGalleryItem, origin: NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
    closePipVideo()
    window = ModernPictureInPictureVideoWindow(control, item: item, viewer: viewer, origin: origin, delegate: delegate, contentInteractions: contentInteractions, type: type)
    window?.makeKeyAndOrderFront(nil)
}


func exitPictureInPicture() {
    if let window = window as? PIPVideoWindow {
        window.openGallery()
    } else if let window = window as? ModernPictureInPictureVideoWindow {
        window.openGallery()
    }
}

func pausepip() {
    if let window = window as? PIPVideoWindow {
        window.playerView.player?.pause()
        window.forcePaused = true
    } else if let window = window as? ModernPictureInPictureVideoWindow {
        window.control.pause()
        window.forcePaused = true
    }

}

func playPipIfNeeded() {
    if let window = window as? PIPVideoWindow, window.forcePaused {
        window.playerView.player?.play()
    } else if let window = window as? ModernPictureInPictureVideoWindow, window.forcePaused {
        window.control.play()
    }
}



func closePipVideo() {
    if let window = window as? PIPVideoWindow {
        window.hide()
        window.playerView.player?.pause()
    } else if let window = window as? ModernPictureInPictureVideoWindow {
        window.hide()
        window.control.pause()
    }
    window = nil
    
}
