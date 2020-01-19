//
//  UndoTooltipController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore



 final class UndoTooltipControl : NSObject {
    var current: UndoTooltipController?
    private let disposable = MetaDisposable()
    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init()
        
        let invocation: (NSEvent)-> KeyHandlerResult = { [weak self] _ in
            self?.hideCurrentIfNeeded()
            return .rejected
        }
        
        self.context.window.set(mouseHandler: invocation, with: self, for: .leftMouseUp, priority: .supreme)
        self.context.window.set(mouseHandler: invocation, with: self, for: .rightMouseUp, priority: .supreme)
        self.context.window.set(mouseHandler: invocation, with: self, for: .rightMouseDown, priority: .supreme)
        
        
        self.context.window.set(handler: { [weak self] in
            self?.hideCurrentIfNeeded()
            return .rejected
        }, with: self, for: .All, priority: .supreme)
    }
    
    var getYInset:()->CGFloat = { return 10 } {
        didSet {
            self.current?.getYInset = self.getYInset
        }
    }
    
    func add(controller: ViewController) {
        let context = self.context
        if self.current == nil {
            let new = UndoTooltipController(context, controller: controller, undoManager: context.chatUndoManager)
            new.getYInset = self.getYInset
            new.show()
            
            self.current = new
            
            new.view.layer?.animatePosition(from: NSMakePoint(new.view.frame.minX, new.view.frame.maxY), to: new.view.frame.origin, duration: 0.25, timingFunction: .spring)
            new.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .spring)
        }
        disposable.set((Signal<Never, NoError>.complete() |> delay(5.0, queue: .mainQueue())).start(completed: { [weak self] in
            self?.hideCurrentIfNeeded()
        }))
    }
    
    private func hideCurrentIfNeeded(animated: Bool = true) {
        if let current = self.current {
            self.current = nil
            if !current.cancelled {
                context.chatUndoManager.invokeAll()
            }
            let view = current.view
            if animated {
                view.layer?.animatePosition(from: view.frame.origin, to: NSMakePoint(view.frame.minX, view.frame.maxY), duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
                view._change(opacity: 0, duration: 0.25, timingFunction: .spring, completion: { [weak view] completed in
                    view?.removeFromSuperview()
                })
            } else {
                view.removeFromSuperview()
            }
        }
    }
    
    deinit {
        disposable.dispose()
        context.window.removeAllHandlers(for: self)
    }
}


final class UndoTooltipView : NSVisualEffectView, AppearanceViewProtocol {
    private let progress = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, lineWidth: 2, clockwise: false), twist: false, size: NSMakeSize(20, 20))
    private let textView: TextView = TextView()
    private var undoButton: TitleButton = TitleButton()
    
    private let manager: ChatUndoManager
    private let disposable = MetaDisposable()
    private var didSetReady: Bool = false
    private var timer: SwiftSignalKit.Timer?
    private var progressValue: Double = 0.0
    private var secondsUntilFinish: Int = 0
    private let durationContainer: View = View(frame: NSMakeRect(0, 0, 18, 18))

    
    init(frame frameRect: NSRect, undoManager: ChatUndoManager, undo: @escaping()->Void) {
        self.manager = undoManager
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.blendingMode = .withinWindow
        self.material = .dark
        
        addSubview(progress)
        addSubview(undoButton)
        addSubview(durationContainer)
        addSubview(textView)
        
        self.layer?.cornerRadius = 10.0
        
        
        
        undoButton.set(font: .medium(.title), for: .Normal)
        undoButton.direction = .right
        undoButton.autohighlight = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.disableBackgroundDrawing = true
 
        progress.state = .ImpossibleFetching(progress: 0, force: true)
        
        updateDuration(value: 5, animated: false)
        
        disposable.set((manager.allStatuses() |> deliverOnMainQueue).start(next: { [weak self] statuses in
            self?.update(statuses: statuses)
        }))
        
        undoButton.set(handler: { _ in
            undo()
        }, for: .Down)
    }
    
    var removeAnimationForNextTransition: Bool = true
    
    private func updateProgress(force: Bool) {
        progress.state = .ImpossibleFetching(progress: Float(progressValue), force: force)
    }
    private func updateDuration(value: Int, animated: Bool) {
        if self.secondsUntilFinish != value {
            let reversed: Bool = self.secondsUntilFinish < value
            self.self.secondsUntilFinish = value
            
            let textView = TextView()
            let layout = TextViewLayout.init(.initialize(string: "\(value)", color: .white, font: .medium(12)))
            layout.measure(width: .greatestFiniteMagnitude)
            
            
            if animated {
                for view in durationContainer.subviews {
                    textView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
                    view._change(pos: NSMakePoint(view.frame.minX, reversed ? -view.frame.height : durationContainer.frame.height), animated: true, removeOnCompletion: false, duration: 0.2, completion: { [weak view] completed in
                        view?.removeFromSuperview()
                    })
                }
            } else {
                durationContainer.removeAllSubviews()
            }
            
            textView.update(layout)
            durationContainer.addSubview(textView)
            textView.center()
            
            if animated {
                textView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                textView.layer?.animatePosition(from: NSMakePoint(textView.frame.minX, reversed ? durationContainer.frame.height : -textView.frame.height), to: textView.frame.origin, duration: 0.2)
            }
        }
        
    }
    
    private func update(statuses: ChatUndoStatuses) {
        if statuses.hasProcessingActions {
            
            let newValue = 1.0 - min(1.0, max(0, statuses.secondsUntilFinish / statuses.maximumDuration))
            
            let removeAnimationForNextTransition = self.removeAnimationForNextTransition
            self.removeAnimationForNextTransition = false
            
            
            timer?.invalidate()
            
            
            timer = SwiftSignalKit.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
                self?.progressValue = 1.0 - min(1.0, max(0, statuses.secondsUntilFinish / statuses.maximumDuration))
                self?.updateDuration(value: Int(round(max(1, statuses.secondsUntilFinish))), animated: true)
                self?.updateProgress(force: true)
                }, queue: Queue.mainQueue())
            
            if progressValue > newValue {
                delay(0.2, closure: { [weak self] in
                    self?.timer?.start()
                })
            } else {
                timer?.start()
            }
            
            let layout = TextViewLayout(.initialize(string: statuses.activeDescription, color: .white, font: .medium(.text)), maximumNumberOfLines: 10)
            textView.update(layout)
            
            progressValue = min(max(newValue, 0), 1.0)
            updateProgress(force: false)
            updateDuration(value: Int(round(max(1, statuses.secondsUntilFinish))), animated: !removeAnimationForNextTransition)
            
        } else {
            timer?.invalidate()
            timer = nil
        }
        
        needsLayout = true
    }
    
    deinit {
        timer?.invalidate()
        disposable.dispose()
    }
    
    func updateLocalizationAndTheme(theme: PresentationTheme) {
        
        self.progress.theme = RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, lineWidth: 2, clockwise: false)
        
        let attributed = textView.layout?.attributedString.mutableCopy() as? NSMutableAttributedString
        if let attributed = attributed {
            attributed.addAttribute(.foregroundColor, value: NSColor.white, range: attributed.range)
            self.textView.update(TextViewLayout(attributed, maximumNumberOfLines: 1))
        }
        undoButton.set(text: L10n.chatUndoManagerUndo, for: .Normal)
        undoButton.set(color: .white, for: .Normal)
        
        _ = undoButton.sizeToFit()
    }
    
    
    override var isFlipped: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        progress.centerY(x: 18)
        undoButton.centerY(x: frame.width - undoButton.frame.width - 10)
        durationContainer.centerY(x: progress.frame.minX + 1, addition: -1)
        
        if let layout = textView.layout {
            layout.measure(width: frame.width - (progress.frame.maxX + 8) - undoButton.frame.width - 10)
            textView.update(layout)
        }
        textView.centerY(x: progress.frame.maxX + 8, addition: -1)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class UndoTooltipController: TelegramGenericViewController<UndoTooltipView> {
    private let undoManager: ChatUndoManager
    private weak var controller: ViewController?
    private(set) var cancelled: Bool = false
    init(_ context: AccountContext, controller: ViewController, undoManager: ChatUndoManager) {
        self.undoManager = undoManager
        self.controller = controller
        super.init(context)
        self.bar = .init(height: 0)
        self._frameRect = NSMakeRect(0, 0, min(controller.frame.width - 20, 330), 40)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    override func initializer() -> UndoTooltipView {
        return UndoTooltipView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), undoManager: undoManager, undo: { [weak self] in
            if let `self` = self {
                self.undoManager.cancelAll()
                self.cancelled = true
            }
        })
    }
    
    
    func show() {
        
        guard let controller = controller else { return }
        loadViewIfNeeded()
        controller.view.addSubview(self.view)
        self.parentFrameDidChange(Notification(name: Notification.Name("")))
        NotificationCenter.default.addObserver(self, selector: #selector(parentFrameDidChange(_:)), name: NSView.frameDidChangeNotification, object: controller.view)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        genericView.updateLocalizationAndTheme(theme: theme)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    var getYInset:()->CGFloat = { return 10 }
    
    @objc private func parentFrameDidChange(_ notification:Notification) {
        
        guard let controller = controller else { return }
        
        self.view.isHidden = controller.frame.width < 100
        self.view.frame = NSMakeRect(0, 0, min(controller.frame.width - 20, 330), self.frame.height)
        
        self.view.centerX(y: controller.frame.height - self.frame.height - self.getYInset())
    }
    
}
