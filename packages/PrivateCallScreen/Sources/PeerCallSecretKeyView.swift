//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 11.02.2024.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import AppKit

fileprivate func generateSecretKey(_ emoji: NSAttributedString) -> Signal<CGImage?, NoError> {
    return Signal { subscriber in
        
        
        
        let node = TextNode.layoutText(maybeNode: nil, emoji, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)

        if node.0.size == .zero {
            subscriber.putCompletion()
            return EmptyDisposable
        }

        let image = generateImage(node.0.size, scale: System.backingScale, rotatedContext: { size, ctx in
            ctx.clear(size.bounds)
            node.1.draw(size.bounds, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
            
        })
        
        subscriber.putNext(image)
        subscriber.putCompletion()
        
        return ActionDisposable {
            
        }
    } |> runOn(.concurrentBackgroundQueue())
}




final class SecretKeyView : Control, CallViewUpdater {
    
    private let disposable = MetaDisposable()
    
    private let secretView: SimpleLayer = SimpleLayer()
    
    private var state: PeerCallState?
    private var arguments: Arguments?
    private var secretKey: String?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer = secretView
        
        scaleOnClick = true
        
        self.layer?.contentsGravity = .resizeAspect
        
        set(handler: { [weak self] _ in
            self?.arguments?.toggleSecretKey()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.state = state
        self.arguments = arguments
        
        let previousKey = self.secretKey
        self.secretKey = state.secretKey
        
        if previousKey != secretKey, let secretKey = secretKey {
            let signal = generateSecretKey(.initialize(string: secretKey, font: .normal(50))) |> deliverOnMainQueue
            disposable.set(signal.startStandalone(next: { [weak self] image in
                self?.secretView.contents = image
            }))
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
    }
    
    deinit {
        disposable.dispose()
    }
    
}
