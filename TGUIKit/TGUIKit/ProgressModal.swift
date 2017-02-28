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

    private var progressView:RadialProgressView?
    private var timer:SwiftSignalKitMac.Timer?
    private var progress:Float = 0.2
    override var background: NSColor {
        return .clear
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func loadView() {
        super.loadView()
   
        progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
        progressView?.state = .ImpossibleFetching(progress: progress)
        view.background = NSColor(0x000000,0.8)
        view.addSubview(progressView!)
        progressView?.center()
        
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
        
        
        self.timer = SwiftSignalKitMac.Timer(timeout: 0.05, repeat: true, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.progress += 0.05
                strongSelf.progressView?.state = .ImpossibleFetching(progress: strongSelf.progress)
                if strongSelf.progress >= 0.8 {
                    strongSelf.timer?.invalidate()
                }
            }
        }, queue: Queue.mainQueue())
        self.timer?.start()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override init() {
        super.init(frame:NSMakeRect(0,0,100,100))
    }
    
    
}

public func showModalProgress<T, E>(signal:Signal<T,E>, for window:Window) -> Signal<T,E> {
    return Signal { subscriber in
        
        let signal = signal |> deliverOnMainQueue
        
        let modal = ProgressModalController()
        let beforeModal:Signal<Void,Void> = .single() |> delay(0.25, queue: Queue.mainQueue())
        
        let beforeDisposable:DisposableSet = DisposableSet()
        
        beforeDisposable.add(beforeModal.start(completed: {
            showModal(with: modal, for: window)
        }))
        
        
        beforeDisposable.add(signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
            beforeDisposable.dispose()
            modal.close()
        }))
        
        return beforeDisposable
    }
    

}
