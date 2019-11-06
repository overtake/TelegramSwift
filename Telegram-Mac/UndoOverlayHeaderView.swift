//
//  UndoOverlayHeaderView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


class UndoOverlayHeaderView: NavigationHeaderView {
    private let progress = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, lineWidth: 2, clockwise: false), twist: false, size: NSMakeSize(20, 20))
    private let manager: ChatUndoManager
    private let disposable = MetaDisposable()
    private var didSetReady: Bool = false
    private var timer: SwiftSignalKit.Timer?
    private var progressValue: Double = 0.0
    private var secondsUntilFinish: Int = 0
    private let undoButton = TitleButton()
    private let textView = TextView()
    private let durationContainer: View = View(frame: NSMakeRect(0, 0, 18, 18))
    init(_ header: NavigationHeader, manager: ChatUndoManager) {
        self.manager = manager
        super.init(header)
        addSubview(progress)
        addSubview(undoButton)
        addSubview(durationContainer)
        addSubview(textView)
        undoButton.set(font: .medium(.title), for: .Normal)
        undoButton.direction = .right
        undoButton.autohighlight = false
        border = [.Bottom]
        progress.state = .ImpossibleFetching(progress: 0, force: true)
        
        updateDuration(value: 5, animated: false)
        
        disposable.set((manager.allStatuses() |> deliverOnMainQueue).start(next: { [weak self] statuses in
            self?.update(statuses: statuses)
        }))
        
        
        undoButton.set(handler: { [weak self] _ in
            self?.manager.cancelAll()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
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
            let layout = TextViewLayout.init(.initialize(string: "\(value)", color: theme.colors.text, font: .medium(12)))
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
            
            let layout = TextViewLayout(.initialize(string: statuses.activeDescription, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 10)
            textView.update(layout)
            
            progressValue = min(max(newValue, 0), 1.0)
            updateProgress(force: false)
            updateDuration(value: Int(round(max(1, statuses.secondsUntilFinish))), animated: !removeAnimationForNextTransition)
            
        } else {
            timer?.invalidate()
            timer = nil
        }
        
        
        if !didSetReady {
            self.ready.set(.single(true))
            didSetReady = true
        }
        
        needsLayout = true
    }
    
    deinit {
        timer?.invalidate()
        disposable.dispose()
    }
    
    override func layout() {
        super.layout()
        progress.centerY(x: 28)
        undoButton.centerY(x: frame.width - undoButton.frame.width - 20)
        durationContainer.centerY(x: progress.frame.minX + 1, addition: -1)
        
        if let layout = textView.layout {
            layout.measure(width: frame.width - (progress.frame.maxX + 18) - undoButton.frame.width - 20)
            textView.update(layout)
        }
        textView.centerY(x: progress.frame.maxX + 18, addition: -1)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        
        self.progress.theme = RadialProgressTheme(backgroundColor: .clear, foregroundColor: theme.colors.text, lineWidth: 2, clockwise: false)
        
        let attributed = textView.layout?.attributedString.mutableCopy() as? NSMutableAttributedString
        if let attributed = attributed {
            attributed.addAttribute(.foregroundColor, value: theme.colors.text, range: attributed.range)
            self.textView.update(TextViewLayout(attributed, maximumNumberOfLines: 10))
        }
        
        self.borderColor = theme.colors.border
        
        undoButton.set(text: L10n.chatUndoManagerUndo, for: .Normal)
        undoButton.set(image: theme.icons.chatUndoAction, for: .Normal)
        undoButton.set(color: theme.colors.accent, for: .Normal)
        
        _ = undoButton.sizeToFit()
        backgroundColor = theme.colors.background

        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
