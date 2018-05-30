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

class SuccessModalController : ModalViewController {
    private var imageView:ImageView?
    override var background: NSColor {
        return .clear
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func loadView() {
        super.loadView()
        
        imageView = ImageView()
        imageView?.image = icon
        imageView?.sizeToFit()
        
        view.background = presentation.colors.grayBackground.withAlphaComponent(0.86)
        view.addSubview(imageView!)
        imageView!.center()
        
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
    
    private let icon: CGImage
    
    init(_ icon: CGImage) {
        self.icon = icon
        super.init(frame:NSMakeRect(0,0,80,80))
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

public func showModalSuccess(for window: Window, icon: CGImage, delay _delay: Double) -> Signal<Void, Void> {
    
    let modal = SuccessModalController(icon)
    
    return Signal<Void, Void>({ _ -> Disposable in
        showModal(with: modal, for: window)
        return ActionDisposable {
            modal.close()
        }
    }) |> timeout(_delay, queue: Queue.mainQueue(), alternate: Signal<Void, Void>({ _ -> Disposable in
        modal.close()
        return EmptyDisposable
    }))
}
