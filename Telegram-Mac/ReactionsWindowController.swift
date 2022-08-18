//
//  ReactionsWindowController.swift
//  Telegram
//
//  Created by Mike Renoir on 16.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox

private var reactions: ReactionsWindowController?

final class ReactionsWindowController : NSObject {
    
    
    private class V : View {
        private let visualView: NSVisualEffectView
        private let contentView: NSView
        init(_ content: NSView) {
            
            
            self.contentView = content
            self.visualView = NSVisualEffectView(frame: content.bounds)
            super.init(frame: content.bounds)
            if #available(macOS 11.0, *) {
                addSubview(visualView)
            }
            addSubview(contentView)


            self.visualView.wantsLayer = true
            self.visualView.state = .active
            self.visualView.blendingMode = .behindWindow
            self.visualView.autoresizingMask = []
            self.autoresizesSubviews = false
            
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 8
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = NSMakeSize(0, 0)
            self.shadow = shadow
            
            self.layer?.isOpaque = false
            self.layer?.shouldRasterize = true
            self.layer?.rasterizationScale = System.backingScale
            
            self.layer?.cornerRadius = 20
            contentView.layer?.cornerRadius = 20
            self.visualView.layer?.cornerRadius = 20
            
        }
        
        override func layout() {
            super.layout()
            self.contentView.frame = bounds
            self.visualView.frame = bounds
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    
    private let emojies: EmojiesController
    private let context: AccountContext
    
    private var panel: Window?
    
    private var keyDisposable: Disposable?
    
    private func makeView(_ content: NSView, _ initialView: NSView, _ initialRect: NSRect, animated: Bool) -> (Window, V) {
        
        let v = V(content)
        
        let panel = Window(contentRect: NSMakeRect(initialRect.minX - 12 - 20, initialRect.maxY - 320 + (46 + 10) - 3, 390, 340), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        panel._canBecomeMain = false
        panel._canBecomeKey = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        
        let contentView = View(frame: .zero)
        panel.contentView = contentView
        
        contentView.backgroundColor = .clear
        contentView.flip = false
        contentView.layer?.isOpaque = false
        
        
        v.frame = v.frame.offsetBy(dx: 20, dy: 20)
        contentView.addSubview(v)
        
//        initialView.frame = NSMakeRect(12 + v.frame.minX, v.frame.maxY - (46 + 10) - 40 + 3, initialView.frame.width, initialView.frame.height)
//        initialView.background = theme.colors.background
        
        
//        contentView.addSubview(initialView)
        
        return (panel, v)
        
    }
    
    init(_ context: AccountContext, message: Message) {
        self.context = context
        self.emojies = .init(context, mode: .reactions)
        self.emojies.loadViewIfNeeded()
        super.init()
        
        let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
        
        interactions.sendAnimatedEmoji = { [weak self] sticker in
            let value: MessageReaction.Reaction
            if let bundle = sticker.file.stickerText {
                value = .builtin(bundle)
            } else {
                value = .custom(sticker.file.fileId.id)
            }
            let isSelected = message.reactionsAttribute?.reactions.contains(where: { $0.value == value && $0.isSelected }) == true
            context.reactions.react(message.id, value: isSelected ? nil : value, file: sticker.file, checkPrem: false)
            self?.close(animated: true)
            
        }
        emojies.update(with: interactions, chatInteraction: .init(chatLocation: .peer(context.peerId), context: context))

    }
    
    func show(_ initialView: NSView, animated: Bool = true) {
        reactions?.panel?.orderOut(nil)
        
        reactions = self
//        initialView.layer?.removeAllAnimations()
        
        assert(initialView.window != nil)
        let ready = emojies.ready.get() |> take(1)
        _ = ready.start(next: { [weak self] _ in
            self?.ready(initialView, animated: animated)
        })
    }
    
    private func ready(_ initialView: NSView, animated: Bool) {
        
        
        let initialScreenRect = initialView.window!.convertToScreen(initialView.convert(initialView.bounds, to: nil))
        
        self.emojies.view.frame = self.emojies.view.bounds
        let (panel, view) = makeView(self.emojies.view, initialView, initialScreenRect, animated: animated)
        
        panel.makeKeyAndOrderFront(nil)
        
        panel.order(.below, relativeTo: initialView.window!.windowNumber)
        
        self.panel = panel
        
        let anchor = NSMakePoint(view.frame.width / 2, view.frame.height - (46 + 10))
        
        
//
//        view.layer?.animateBounds(from: .zero, to: view.bounds, duration: 2.0)
//
//        view.layer?.animatePosition(from: initialView.frame.origin, to: view.frame.origin, duration: 2.0)

        view.layer?.animateScaleSpringFrom(anchor: anchor, from: initialView.frame.width / view.frame.width, to: 1, duration: 0.3, bounce: false)
        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)

//        initialView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak initialView] _ in
//            initialView?.removeFromSuperview()
//        })
        
        panel.set(handler: { [weak self] _ in
            self?.close(animated: true)
            return .invoked
        }, with: self, for: .Escape, priority: .supreme)
        
        panel.set(handler: { [weak self] _ in
            self?.close(animated: true)
            return .invoked
        }, with: self, for: .Escape, priority: .supreme)
        
        panel.set(mouseHandler: { [weak view, weak self] _ in
            if view?.mouseInside() == false {
                self?.close(animated: true)
            }
            return .rejected
        }, with: self, for: .leftMouseDown)
        
        var isInteracted: Bool = false

        
        context.window.set(mouseHandler: { event in
            isInteracted = true
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .supreme)
        
        context.window.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close(animated: true)
            }
            let was = isInteracted
            isInteracted = true
            return !was ? .rejected : .invoked
        }, with: self, for: .leftMouseUp, priority: .supreme)

        context.window.set(mouseHandler: { event in
            isInteracted = true
            return .rejected
        }, with: self, for: .rightMouseDown, priority: .supreme)

        context.window.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close(animated: true)
            }
            let was = isInteracted
            isInteracted = true
            return !was ? .rejected : .invoked
        }, with: self, for: .rightMouseUp, priority: .supreme)
        
        var skippedFirst: Bool = false
        
        self.keyDisposable = context.window.keyWindowUpdater.start(next: { [weak self] value in
            if !value && skippedFirst {
                self?.close()
            }
            skippedFirst = true
        })
        
    }
    
    private func close(animated: Bool = false) {
        
        context.window.removeAllHandlers(for: self)
        panel?.removeAllHandlers(for: self)
        
        var panel: Window? = self.panel
        if animated {
            panel?.contentView?.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                panel?.orderOut(nil)
                panel = nil
            })
        } else {
            self.panel?.orderOut(nil)
        }
        reactions = nil
    }
}
