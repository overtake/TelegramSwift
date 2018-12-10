//
//  ProgressModal.swift
//  TGUIKit
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
class ProgressModalController: ModalViewController {

    private var progressView:ProgressIndicator?
    override var background: NSColor {
        return .clear
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func loadView() {
        super.loadView()
   
        progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
        
        view.background = presentation.colors.grayBackground.withAlphaComponent(0.8)
        view.addSubview(progressView!)
        progressView!.center()
        
        viewDidLoad()
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
    
    override init() {
        super.init(frame:NSMakeRect(0,0,80,80))
        self.bar = .init(height: 0)
    }
    
    
}


private final class SuccessModalView : View {
    private let imageView:ImageView = ImageView()
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        
        background = presentation.colors.grayBackground.withAlphaComponent(0.86)
        addSubview(imageView)
       
        
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
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return SuccessModalView.self
    }
    private var genericView: SuccessModalView {
        return self.view as! SuccessModalView
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.updateIcon(icon: icon, text: text)
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
    
    private let icon: CGImage
    private let text: TextViewLayout?
    init(_ icon: CGImage, text: TextViewLayout? = nil) {
        self.icon = icon
        self.text = text
        super.init(frame:NSMakeRect(0, 0, text != nil ? 100 + text!.layoutSize.width : 80, text != nil ? max(icon.backingSize.height + 20, text!.layoutSize.height + 20) : 80))
        self.bar = .init(height: 0)
    }
}

public func showModalProgress<T, E>(signal:Signal<T,E>, for window:Window, disposeAfterComplete: Bool = true) -> Signal<T,E> {
    return Signal { subscriber in
        
        let signal = signal |> deliverOnMainQueue
        
        let modal = ProgressModalController()
        let beforeModal:Signal<Void,Void> = .single(Void()) |> delay(0.25, queue: Queue.mainQueue())
        
        let beforeDisposable:DisposableSet = DisposableSet()
        
        beforeDisposable.add(beforeModal.start(completed: {
            showModal(with: modal, for: window)
        }))
        
        
        
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

public func showModalSuccess(for window: Window, icon: CGImage, text: TextViewLayout? = nil, delay _delay: Double) -> Signal<Void, NoError> {
    
    let modal = SuccessModalController(icon, text: text)
    
    return Signal<Void, NoError>({ _ -> Disposable in
        showModal(with: modal, for: window)
        return ActionDisposable {
            modal.close()
        }
    }) |> timeout(_delay, queue: Queue.mainQueue(), alternate: Signal<Void, NoError>({ _ -> Disposable in
        modal.close()
        return EmptyDisposable
    }))
}
