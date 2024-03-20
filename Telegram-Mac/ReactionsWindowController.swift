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
import TelegramMedia

protocol StickerFramesCollector {
    func collect() -> [Int : LottiePlayerView]
}

private var reactions: ReactionsWindowController?

final class ReactionsWindowController : NSObject {
    
    
    private class V : View {
        private let visualView: NSVisualEffectView
        private let contentView: NSView
        private let backgroundView = View()
        private let container = View()
        private var mask: SimpleShapeLayer?
        init(_ content: NSView, theme: TelegramPresentationTheme) {
            
            
            self.contentView = content
            self.visualView = NSVisualEffectView(frame: content.bounds)
            super.init(frame: content.bounds)
            if #available(macOS 11.0, *), !isLite(.blur) {
                container.addSubview(visualView)
                backgroundView.backgroundColor = theme.colors.background.withAlphaComponent(0.7)
            } else {
                backgroundView.backgroundColor = theme.colors.background
            }
            container.addSubview(backgroundView)
            container.addSubview(contentView)

            
            addSubview(container)
            

            if !isLite(.blur) {
                self.visualView.wantsLayer = true
                self.visualView.state = .active
                self.visualView.blendingMode = .behindWindow
                self.visualView.autoresizingMask = []
                self.visualView.material = theme.colors.isDark ? .dark : .light
            }
            
            self.autoresizesSubviews = false

            
            self.layer?.isOpaque = false
            self.layer?.shouldRasterize = true
            self.layer?.rasterizationScale = System.backingScale
            
            self.layer?.cornerRadius = 20
            contentView.layer?.cornerRadius = 20
            self.visualView.layer?.cornerRadius = 20
            self.backgroundView.layer?.cornerRadius = 20
            self.container.layer?.cornerRadius = 20
            contentView.layer?.opacity = 0
        }
        
        func appearAnimated(from: NSRect, to: NSRect) {
            
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 2
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowOffset = NSMakeSize(0, 0)
            self.shadow = shadow
            
            contentView.layer?.opacity = 1
            let duration: Double = 0.35
            
            self.container.layer?.mask = nil
            self.mask = nil

            
            var offset: NSPoint = .zero
            offset.y = to.height - from.height / 2 - from.origin.y - 5
            offset.x = 10
            
            self.container.layer?.animateBounds(from: from.size.bounds.offsetBy(dx: offset.x, dy: offset.y), to: to.size.bounds, duration: duration, timingFunction: .spring)
            
            self.container.layer?.animatePosition(from: offset, to: .zero, duration: duration, timingFunction: .spring)
        }
        
        func initFake(_ from: NSRect, to: NSRect) {
            
            var offset: NSPoint = .zero
            offset.y = to.height - from.height / 2 - from.origin.y - 5
            offset.x = 10
            
            var rect = from.size.bounds.offsetBy(dx: offset.x, dy: offset.y)
            rect.size.width -= 20
            rect.size.height = 20
            
            if from.height > 60 {
                rect.size.height += (from.height - 60)
                offset.y -= (from.height - 60) / 2
            }
            
           // rect.size.height += 20

            let mask = SimpleShapeLayer()
            self.mask = mask

            let path = CGMutablePath()
            path.addRoundedRect(in: rect.size.bounds, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2)
            mask.path = path
            mask.frame = rect
            mask.cornerRadius = 20
            container.layer?.mask = mask

        }
        
        override func layout() {
            super.layout()
            self.container.frame = bounds
            self.contentView.frame = bounds
            self.visualView.frame = bounds
            self.backgroundView.frame = bounds
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
    private let overlay = OverlayControl()
    
    private var initialPlayers:[Int: LottiePlayerView] = [:]

    
    private var keyDisposable: Disposable?
    private var panelKeyDisposable: Disposable?

    private func makeView(_ content: NSView, _ initialView: NSView, _ initialRect: NSRect, animated: Bool, theme: TelegramPresentationTheme) -> (Window, V) {
        
        let v = V(content, theme: theme)
        
        var wAdd: CGFloat = 0
        var initialAdd: CGFloat = 0
        if initialView.frame.height != 60 {
            let offset = initialView.subviews[1].frame.minY - 8
            wAdd = (initialView.frame.height - 60) + offset // (18 is reaction offset y in parent)
            initialAdd = offset // (18 is reaction offset y in parent)
        }
        
        let panel = Window(contentRect: NSMakeRect(initialRect.minX - 21, initialRect.maxY - 320 + (initialRect.height + 20) - 32 + 36 - wAdd, 390, 340), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        panel._canBecomeMain = false
        panel._canBecomeKey = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.name = self.name
        
        let contentView = View(frame: .zero)
        panel.contentView = contentView
        
        contentView.backgroundColor = .clear
        contentView.flip = false
        contentView.layer?.isOpaque = false
        
        
        v.frame = v.frame.offsetBy(dx: 20, dy: 20)
        contentView.addSubview(v)
        
        initialView.frame = NSMakeRect(v.frame.minX + 1, v.frame.maxY - initialView.frame.height - (48 + 36) + initialAdd, initialView.frame.width, initialView.frame.height)
       // initialView.background = .red
//        initialView.layer?.opacity = 0.5
        initialView.removeFromSuperview()
        contentView.addSubview(initialView)
        
        return (panel, v)
        
    }

    private var onClose:(()->Void)?
    private let presentation: TelegramPresentationTheme
    private let name: String
    private var skipAppearAnimation = false
    init(_ context: AccountContext, peerId: PeerId, selectedItems: [EmojiesSectionRowItem.SelectedItem], react: @escaping(StickerPackItem, NSRect?)->Void, onClose:(()->Void)? = nil, presentation: TelegramPresentationTheme = theme, name: String = "") {
        self.context = context
        self.presentation = presentation
        self.onClose = onClose
        self.name = name
        
        self.emojies = .init(context, mode: context.peerId == peerId ? .defaultTags : .reactions, selectedItems: selectedItems, presentation: presentation)
        self.emojies.loadViewIfNeeded()
        super.init()
        
        let interactions = EntertainmentInteractions(.emoji, peerId: peerId)
        
        interactions.sendAnimatedEmoji = { [weak self] sticker, _, _, fromRect in
            react(sticker, fromRect)
            self?.close(animated: true)
        }
        emojies.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))

        
        emojies.closeCurrent = { [weak self] in
            self?.close(animated: true)
        }
        emojies.animateAppearance = { [weak self] items in
            self?.animateAppearanceItems(items, initialPlayers: self?.initialPlayers ?? [:])
        }
    }
    
    private func animateAppearanceItems(_ items: [TableRowItem], initialPlayers:[Int: LottiePlayerView]) {
        
        if skipAppearAnimation {
            return
        }
        let sections = items.compactMap {
            $0 as? EmojiesSectionRowItem
        }
        let tabs = items.compactMap {
            $0 as? StickerPackRowItem
        }
        let firstTab = items.compactMap {
            $0 as? ETabRowItem
        }
        
        let duration: Double = 0.35
        let itemDelay: Double = duration / Double(sections.count)
        var delay: Double = itemDelay
        
        firstTab.first?.animateAppearance(delay: 0.1, duration: duration, ignoreCount: 0)
        
        for tab in tabs {
            tab.animateAppearance(delay: 0.1, duration: duration, ignoreCount: 0)
        }
        
        for (i, section) in sections.enumerated() {
            section.animateAppearance(delay: delay, duration: duration, initialPlayers: i == 0 ? initialPlayers : [:])
            delay += itemDelay
        }
    }
    
    func show(_ initialView: NSView & StickerFramesCollector, animated: Bool = true) {
        reactions?.panel?.orderOut(nil)
        
        reactions = self
        
        self.ready(initialView, animated: animated)
       
    }
    
    private func ready(_ initialView: NSView & StickerFramesCollector, animated: Bool) {
        
        guard let screen = NSScreen.main else {
            return
        }
        
        let initialWindow = initialView.window!
        let initialScreenRect = initialWindow.convertToScreen(initialView.convert(initialView.bounds, to: nil))
        
                
        
        self.emojies.view.frame = self.emojies.view.bounds
        let (panel, view) = makeView(self.emojies.view, initialView, initialScreenRect, animated: animated, theme: self.presentation)
        
        panel.makeKeyAndOrderFront(nil)
        
        panel.order(.below, relativeTo: initialWindow.windowNumber)
        
        self.panel = panel
        let context = self.context
                

        panel.set(handler: { [weak self] _ in
            self?.close(animated: true)
            return .invoked
        }, with: self, for: .Escape, priority: .modal)
        
        panel.set(handler: { [weak self] _ in
            self?.close(animated: true)
            return .invoked
        }, with: self, for: .Escape, priority: .modal)
        
        panel.set(mouseHandler: { [weak view, weak self] _ in
            if view?.mouseInside() == false {
                self?.close(animated: true)
            }
            return .rejected
        }, with: self, for: .leftMouseUp)
        
        context.window.set(handler: { [weak self] _ in
            self?.close(animated: true)
            return .invoked
        }, with: self, for: .Escape, priority: .modal)
        
        var isInteracted: Bool = false

        
        context.window.set(mouseHandler: { event in
            isInteracted = true
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .modal)
        
        context.window.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close(animated: true)
            }
            let was = isInteracted
            isInteracted = true
            return !was ? .rejected : .invoked
        }, with: self, for: .leftMouseUp, priority: .modal)

        context.window.set(mouseHandler: { event in
            isInteracted = true
            return .rejected
        }, with: self, for: .rightMouseDown, priority: .modal)

        context.window.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close(animated: true)
            }
            let was = isInteracted
            isInteracted = true
            return !was ? .rejected : .invoked
        }, with: self, for: .rightMouseUp, priority: .modal)
        
        var skippedFirst: Bool = false
        
        self.keyDisposable = context.window.keyWindowUpdater.start(next: { [weak self] value in
            if !value && skippedFirst, self?.panel?._canBecomeKey == false {
                self?.close()
            }
            skippedFirst = true
        })
        
        self.panelKeyDisposable = panel.keyWindowUpdater.start(next: { [weak self] value in
            if self?.panel?.canBecomeKey == true, !value {
                DispatchQueue.main.async {
                    self?.close(animated: context.window.isKeyWindow == true)
                }
            }
        })
        
        view.initFake(initialView.frame, to: view.frame)

        overlay.frame = context.window.bounds
        context.window.contentView?.addSubview(overlay)

        
        let ready = emojies.ready.get() |> take(1)
        _ = ready.start(next: { [weak view, weak initialView, weak self] _ in
            guard let view = view, let initialView = initialView, let `self` = self else {
                return
            }
            CATransaction.begin()
            initialView.removeFromSuperview()
            CATransaction.commit()

            self.initialPlayers = initialView.collect()
            CATransaction.begin()
            view.appearAnimated(from: initialView.frame, to: view.frame)
            CATransaction.commit()
            
            if initialScreenRect.origin.y - 200 < 0, let panel = self.panel {
                self.skipAppearAnimation = true
                panel.setFrame(NSMakeRect(panel.frame.minX, panel.frame.minY + 100, panel.frame.width, panel.frame.height), display: true, animate: true)
            }
            
        })
        
    }
    
    deinit {
        panelKeyDisposable?.dispose()
        keyDisposable?.dispose()
    }
    
    private func close(animated: Bool = false) {
        
        self.onClose?()
        
        self.overlay.removeFromSuperview()
        self.context.window.removeAllHandlers(for: self)
        self.panel?.removeAllHandlers(for: self)
        AppMenu.closeAll()
        
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
