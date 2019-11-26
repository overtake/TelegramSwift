//
//  ProgressModal.swift
//  TGUIKit
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


private final class ProgressModalView : NSVisualEffectView {
    private let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 32, 32))
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.cornerRadius = 10.0
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        self.addSubview(self.progressView)
        self.material = presentation.colors.isDark ? .dark : .light
        self.blendingMode = .withinWindow
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSMakeSize(80, 80))
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.progressView.center()
        self.center()
    }
}

class ProgressModalController: ModalViewController {

    private var progressView:ProgressIndicator?
    override var background: NSColor {
        return .clear
    }
    
    override var contentBelowBackground: Bool {
        return true
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        disposable.dispose()
    }
    
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return ProgressModalView.self
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    deinit {
        disposable.dispose()
    }
    
    fileprivate let disposable: Disposable
    
    init(_ disposable: Disposable) {
        self.disposable = disposable
        super.init(frame:NSMakeRect(0,0,80,80))
        self.bar = .init(height: 0)
    }
    
    
}


private final class SuccessModalView : NSVisualEffectView {
    private let imageView:ImageView = ImageView()
    private let textView: TextView = TextView()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(imageView)
        self.wantsLayer = true
        self.layer?.cornerRadius = 10.0
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        self.material = presentation.colors.isDark ? .dark : .light
        self.blendingMode = .withinWindow
    }
    

    
    override func layout() {
        super.layout()
        
        if !textView.isHidden {
            imageView.centerY(x: 20)
            textView.centerY(x: imageView.frame.maxX + 20)
        } else {
            imageView.center()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateIcon(icon: CGImage, text: TextViewLayout?) {
        imageView.image = icon
        imageView.sizeToFit()
        textView.isSelectable = false
        textView.isHidden = text == nil
        textView.update(text)
        needsLayout = true
    }
}

class SuccessModalController : ModalViewController {
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
        return SuccessModalView.self
    }
    private var genericView: SuccessModalView {
        return self.view as! SuccessModalView
    }
    
    override var redirectMouseAfterClosing: Bool {
        return true
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.updateIcon(icon: icon, text: text)
        readyOnce()
    }
    
//    override var handleEvents: Bool {
//        return false
//    }
//    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private let icon: CGImage
    private let text: TextViewLayout?
    private let _backgroundColor: NSColor
    init(_ icon: CGImage, text: TextViewLayout? = nil, background: NSColor) {
        self.icon = icon
        self.text = text
        self._backgroundColor = background
        super.init(frame:NSMakeRect(0, 0, text != nil ? 100 + text!.layoutSize.width : 80, text != nil ? max(icon.backingSize.height + 20, text!.layoutSize.height + 20) : 80))
        self.bar = .init(height: 0)
    }
}

public func showModalProgress<T, E>(signal:Signal<T,E>, for window:Window, disposeAfterComplete: Bool = true) -> Signal<T,E> {
    return Signal { subscriber in
        
        var signal = signal |> deliverOnMainQueue
        let beforeDisposable:DisposableSet = DisposableSet()

        let modal = ProgressModalController(beforeDisposable)
        let beforeModal:Signal<Void,Void> = .single(Void()) |> delay(0.25, queue: Queue.mainQueue())
        
        
        beforeDisposable.add(beforeModal.start(completed: {
            showModal(with: modal, for: window, animationType: .scaleCenter)
        }))
        
        signal = signal |> afterDisposed {
            modal.close()
        }
        
        beforeDisposable.add(signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
            if disposeAfterComplete {
                beforeDisposable.dispose()
            }
            modal.close()
        }, completed: {
            subscriber.putCompletion()
            if disposeAfterComplete {
                beforeDisposable.dispose()
            }
            modal.close()
        }))
        
        return beforeDisposable
    }
}

public func showModalSuccess(for window: Window, icon: CGImage, text: TextViewLayout? = nil, background: NSColor = presentation.colors.background, delay _delay: Double) -> Signal<Void, NoError> {
    
    let modal = SuccessModalController(icon, text: text, background: background)
    
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
