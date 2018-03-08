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
import SwiftSignalKitMac

private let pipFrameKey: String = "kPipFrameKey3"

fileprivate class PIPVideoWindow: NSPanel {
    fileprivate let playerView:AVPlayerView
    private let rect:NSRect
    private let close:ImageButton = ImageButton()
    private let openGallery:ImageButton = ImageButton()
    fileprivate var forcePaused: Bool = false
    fileprivate let item: MGalleryVideoItem
    fileprivate weak var _delegate: InteractionContentViewProtocol?
    fileprivate let _contentInteractions:ChatMediaLayoutParameters?
    fileprivate let _type: GalleryAppearType
    fileprivate let viewer: GalleryViewer
    init(_ player:AVPlayerView, item: MGalleryVideoItem, viewer: GalleryViewer, origin:NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
        self.viewer = viewer
        self._delegate = delegate
        self._contentInteractions = contentInteractions
        self._type = type
        
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
        
        
        openGallery.autohighlight = false
        openGallery.set(image: #imageLiteral(resourceName: "Icon_PipOff").precomposed(NSColor.white.withAlphaComponent(0.9)), for: .Normal)
        
        openGallery.set(handler: { [weak self] _ in
            self?._openGallery()
        }, for: .Click)
        
        openGallery.setFrameSize(40,40)
        
        openGallery.layer?.cornerRadius = 20
        openGallery.style = ControlStyle(backgroundColor: .blackTransparent, highlightColor: .grayIcon)
        openGallery.layer?.opacity = 0.8
        

        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary];
        
        self.contentView?.wantsLayer = true;
        self.contentView?.layer?.cornerRadius = 4;
        
        self.contentView?.layer?.backgroundColor = NSColor.random.cgColor;
        self.backgroundColor = .clear;
        
        player.autoresizingMask = [.width, .height];
        
        player.setFrameOrigin(0,0)
        player.controlsStyle = .minimal
        player.removeFromSuperview()
        self.contentView?.addSubview(player)
        
        self.contentView?.addSubview(close)
        self.contentView?.addSubview(openGallery)

       
        self.level = .screenSaver
        self.isMovableByWindowBackground = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResized(_:)), name: NSWindow.didResizeNotification, object: self)


        
    }

    
    func hide() {
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
    
    func _openGallery() {
        close.change(opacity: 0, removeOnCompletion: false) { [weak close] completed in
            close?.removeFromSuperview()
        }
        openGallery.change(opacity: 0, removeOnCompletion: false) { [weak openGallery] completed in
            openGallery?.removeFromSuperview()
        }
        playerView.controlsStyle = .floating
        setFrame(rect, display: true, animate: true)
        hide()
        showGalleryFromPip(item: item, gallery: self.viewer, delegate: _delegate, contentInteractions: _contentInteractions, type: _type)
    }
    
    deinit {
        if playerView.controlsStyle != .floating {
            playerView.player?.pause()
        }
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
        openGallery.change(opacity: 1, animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        close.change(opacity: 0, animated: true)
        openGallery.change(opacity: 0, animated: true)
    }
    
    @objc func windowDidResized(_ notification: Notification) {
        let closePoint = NSMakePoint(10, frame.height - 50)
        let openPoint = NSMakePoint(closePoint.x + close.frame.width + 10, frame.height - 50)
        self.close.setFrameOrigin(closePoint)
        self.openGallery.setFrameOrigin(openPoint)
        
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
                self.openGallery.change(pos: openPoint, animated: false)

                self.setFrame(NSMakeRect(screen.frame.maxX - convert_s.width - 30, screen.frame.maxY - convert_s.height - 50, convert_s.width, convert_s.height), display: true, animate: true)
                

            }
        }
    }
    

}

private var window: PIPVideoWindow?

func showPipVideo(_ player:AVPlayerView, viewer: GalleryViewer, item: MGalleryVideoItem, origin: NSPoint, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType) {
    closePipVideo()
    window = PIPVideoWindow(player, item: item, viewer: viewer, origin: origin, delegate: delegate, contentInteractions: contentInteractions, type: type)
    window?.makeKeyAndOrderFront(nil)
}

func pausepip() {
    window?.playerView.player?.pause()
    window?.forcePaused = true
}

func playPipIfNeeded() {
    if let forcePaused = window?.forcePaused, forcePaused {
        window?.playerView.player?.play()
    }
}



func closePipVideo() {
    window?.hide()
    window?.playerView.player?.pause()
    window = nil
    
}
