//
//  ProgressModal.swift
//  TGUIKit
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
public class ProgressModalController<T>: ModalViewController {

    private(set) var promise:Promise<T>? = Promise()
    let afterDisposable:MetaDisposable = MetaDisposable()
    private var progressView:RadialProgressView?
    private var timer:SwiftSignalKitMac.Timer?
    private var progress:Float = 0.2
    override public var background: NSColor {
        return .clear
    }
    
    override public var containerBackground: NSColor {
        return .clear
    }
    
    override public func loadView() {
        super.loadView()
   
        progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
        progressView?.state = .ImpossibleFetching(progress: progress)
        view.backgroundColor = NSColor(0x000000,0.8)
        view.addSubview(progressView!)
        progressView?.center()
        
        viewDidLoad()
    }
    
    public override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    deinit {
        afterDisposable.dispose()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
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
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
        promise = nil
        afterDisposable.dispose()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public init(_ signal:Signal<T,Void>) {
        super.init(frame:NSMakeRect(0,0,100,100))
        
        let modified = signal |> delay(2.0, queue: Queue.mainQueue()) |> deliverOnMainQueue
        afterDisposable.set(modified.start(next: {[weak self] (result) in
            self?.promise?.set(.single(result))
        }))
    }
    
}

public func showModalProgress<T>(signal:Signal<T,Void>, for window:Window) -> Signal<T,Void> {
    let modal = ProgressModalController(signal)
    let beforeModal:Signal<Void,Void> = .single() |> delay(0.15, queue: Queue.mainQueue())
    
    let beforeDisposable:MetaDisposable = MetaDisposable()
    
    beforeDisposable.set(beforeModal.start(next: {
        showModal(with: modal, for: window)
    }))
    
    _ = modal.promise?.get().start(next: { (result) in
        beforeDisposable.dispose()
        modal.modal?.close()
    })
    
    return modal.promise!.get()
}
