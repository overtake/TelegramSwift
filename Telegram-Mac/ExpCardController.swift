//
//  ExpCardController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

private final class ExpCardNavigationButton : Control {
    
    
    enum Direction {
        case left
        case right
    }
    
    private let textView = TextView()
    private let imageView = ImageView()
    private let view = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
        view.addSubview(textView)
        view.addSubview(imageView)
        imageView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        self.layer?.cornerRadius = 16
        scaleOnClick = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let theme = theme as! TelegramPresentationTheme
        self.background = theme.chatServiceItemColor
    }
    
    private var direction: Direction?

    func setup(_ text: String, image: CGImage, direction: Direction) {
        self.direction = direction
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.chatServiceItemTextColor, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        
        imageView.image = image
        imageView.sizeToFit()
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func layout() {
        super.layout()
        
        view.setFrameSize(NSMakeSize(textView.frame.width + 4 + imageView.frame.width, frame.height))
        view.center()
        
        if let direction = direction {
            switch direction {
            case .left:
                imageView.centerY(x: 0)
                textView.centerY(x: imageView.frame.maxX + 4)
            case .right:
                textView.centerY(x: 0)
                imageView.centerY(x: textView.frame.maxX + 4)
            }
        }
    }
    
    func size() -> NSSize {
        return NSMakeSize(28 + textView.frame.width + 4 + imageView.frame.width, 32)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ExpCardListView: View {
    
    enum PresentMode {
        case immidiate
        case leftToRight
        case rightToLeft
        
        var animated: Bool {
            return self != .immidiate
        }
    }
    
    private let documentView = View()
    
    private var controller: ViewController?
    
    private var prev: ExpCardNavigationButton?
    private var next: ExpCardNavigationButton?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(documentView)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var _next:(()->Void)?
    var _prev:(()->Void)?

    
    func present(controller: ViewController, hasNext: Bool, hasPrev: Bool, mode: PresentMode) {
        let previous = self.controller
        self.controller = controller
        
        let duration: Double = 0.5
        
        if let previous = previous {
            if mode.animated {
                previous.view._change(opacity: 0, duration: duration, timingFunction: .spring, completion: { [weak previous] completed in
                    if completed {
                        previous?.removeFromSuperview()
                    }
                })
            } else {
                previous.removeFromSuperview()
            }
        }
        
        documentView.addSubview(controller.view)
        controller.view.centerX(y: 0)

        controller.view._change(opacity: 1, animated: mode.animated, duration: duration, timingFunction: .spring)
        if mode.animated {
            let to = controller.view.frame.origin
            let from: NSPoint
            switch mode {
            case .leftToRight:
                from = NSMakePoint(to.x - 50, to.y)
            case .rightToLeft:
                from = NSMakePoint(to.x + 50, to.y)
            default:
                from = to
            }
            controller.view.layer?.animatePosition(from: from, to: to, duration: duration, timingFunction: .spring)
        }
        
        if hasPrev {
            if self.prev == nil {
                self.prev = .init(frame: .zero)
                if let prev = prev {
                    addSubview(prev)
                }
                self.prev?.set(handler: { [weak self] _ in
                    self?._prev?()
                }, for: .SingleClick)
            }
        } else if let prev = self.prev {
            prev.userInteractionEnabled = false
            performSubviewRemoval(prev, animated: mode.animated)
            self.prev = nil
        }
        if hasNext {
            if self.next == nil {
                self.next = .init(frame: .zero)
                if let next = next {
                    addSubview(next)
                }
                self.next?.set(handler: { [weak self] _ in
                    self?._next?()
                }, for: .SingleClick)
            }
        } else if let next = self.next {
            next.userInteractionEnabled = false
            performSubviewRemoval(next, animated: mode.animated)
            self.next = nil
        }
        updateLocalizationAndTheme(theme: theme)
        
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        backgroundColor = .clear
        documentView.backgroundColor = .clear
        
        let theme = theme as! TelegramPresentationTheme
        
        if let prev = prev {
            prev.setup(L10n.emptyChatNavigationPrev, image: theme.emptyChatNavigationPrev, direction: .left)
            prev.setFrameSize(prev.size())
        }
        if let next = next {
            next.setup(L10n.emptyChatNavigationNext, image: theme.emptyChatNavigationNext, direction: .right)
            next.setFrameSize(next.size())
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        documentView.frame = NSMakeRect(0, 0, frame.width, 320)
        
        guard let controller = controller else {
            return
        }
        controller.view.centerX(y: 0)
        
        if let prev = prev {
            prev.setFrameOrigin(NSMakePoint(controller.frame.minX, documentView.frame.maxY + 10))
        }
        if let next = next {
            next.setFrameOrigin(NSMakePoint(controller.frame.maxX - next.frame.width, documentView.frame.maxY + 10))
        }
    }
}

final class ExpCardController : TelegramGenericViewController<ExpCardListView> {
    
    private var controllers:[ViewController] = []
    
    private var selected: Int = 0
    
    override init(_ context: AccountContext) {
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    private func loadController(_ controller: ViewController) {
        controller._frameRect = NSMakeRect(0, 0, 320, 320)
        controller.bar = .init(height: 0)
        controller.loadViewIfNeeded()
    }
    
    private func presentSelected(_ mode: ExpCardListView.PresentMode) {
        let controller = controllers[selected]
        loadController(controller)
        genericView.present(controller: controller, hasNext: controllers.count - 1 > selected, hasPrev: selected > 0, mode: mode)
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        if prev() {
            return .invoked
        }
        return .rejected
    }
    override func nextKeyAction() -> KeyHandlerResult {
        if next() {
            return .invoked
        }
        return .rejected
    }
    
    @discardableResult private func next() -> Bool {
        if selected < controllers.count - 1 {
            selected += 1
            presentSelected(.rightToLeft)
            return true
        }
        return false
    }
    @discardableResult private func prev() -> Bool {
        if selected > 0 {
            selected -= 1
            presentSelected(.leftToRight)
            return true
        }
        return false
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controllers.append(ExpCardAppearanceController(context))
        controllers.append(ExpCardStorageController(context))
        controllers.append(ExpCardStickersController(context))

        let current = controllers[selected]
        
        loadController(current)
        
        ready.set(current.ready.get())
        
        genericView.present(controller: current, hasNext: controllers.count - 1 > selected, hasPrev: selected > 0, mode: .immidiate)
        
        genericView._next = { [weak self] in
            self?.next()
        }
        genericView._prev = { [weak self] in
            self?.prev()
        }
    }
}
