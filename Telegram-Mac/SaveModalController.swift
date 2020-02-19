//
//  SaveModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit


private final class SaveModalView : NSVisualEffectView {
    private let imageView:MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let textView: TextView = TextView()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        self.wantsLayer = true
        self.layer?.cornerRadius = 10.0
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        self.material = presentation.colors.isDark ? .dark : .light
        self.blendingMode = .withinWindow
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        
        if !textView.isHidden {
            imageView.centerX(y: 0)
            textView.centerX(y: imageView.frame.maxY - 15)
        } else {
            imageView.centerX(y: 0)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(animation: LocalAnimatedSticker, size: NSSize, context: AccountContext, text: TextViewLayout?) {
        imageView.update(with: animation.file, size: size, context: context, parent: nil, table: nil, parameters: animation.parameters, animated: false, positionFlags: nil, approximateSynchronousValue: false)
        textView.isSelectable = false
        textView.isHidden = text == nil
        textView.update(text)
        needsLayout = true
    }
}

class SaveModalController : ModalViewController {
    override var background: NSColor {
        return .clear
    }
    
    override var contentBelowBackground: Bool {
        return true
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return SaveModalView.self
    }
    private var genericView: SaveModalView {
        return self.view as! SaveModalView
    }
    
    override var redirectMouseAfterClosing: Bool {
        return true
    }
    
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.update(animation: self.animation, size: NSMakeSize(200, 150), context: self.context, text: self.text)
        readyOnce()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private let animation: LocalAnimatedSticker
    private let text: TextViewLayout?
    private let context: AccountContext
    init(_ animation: LocalAnimatedSticker, context: AccountContext, text: TextViewLayout? = nil) {
        self.animation = animation
        self.text = text
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 200, 200))
        self.bar = .init(height: 0)
    }
}



func showSaveModal(for window: Window, context: AccountContext, animation: LocalAnimatedSticker, text: TextViewLayout? = nil, delay _delay: Double) -> Signal<Void, NoError> {
    
    let modal = SaveModalController(animation, context: context, text: text)
    
    return Signal<Void, NoError>({ _ -> Disposable in
        showModal(with: modal, for: window, animationType: .scaleCenter)
        return ActionDisposable {
            modal.close()
        }
    }) |> timeout(_delay, queue: Queue.mainQueue(), alternate: Signal<Void, NoError>({ _ -> Disposable in
        modal.close()
        return EmptyDisposable
    }))
}
