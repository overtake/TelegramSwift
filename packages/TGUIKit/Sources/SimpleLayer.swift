//
//  File.swift
//  
//
//  Created by Mike Renoir on 07.07.2022.
//

import Foundation
import Cocoa

public final class NullActionClass: NSObject, CAAction {
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

public let nullAction = NullActionClass()


open class SimpleShapeLayer : CAShapeLayer {
    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?
    public private(set) var isInHierarchy: Bool = false
    
    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
            self.didExitHierarchy?()
        }
        return nullAction
    }
    
    override public init() {
        super.init()
        contentsScale = System.backingScale
    }
    public init(frame frameRect: NSRect) {
        super.init()
        contentsScale = System.backingScale
        self.frame = frameRect
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class SimpleLayer: CALayer {
    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?
    public var isInHierarchy: Bool = false {
        didSet {
            if isInHierarchy {
                self.didEnterHierarchy?()
            } else {
                self.didExitHierarchy?()
            }
        }
    }
    
    public var onDraw: ((CALayer, CGContext) -> Void)?

    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
        }
        return nullAction
    }
    
    override public init() {
        super.init()
        contentsScale = System.backingScale
    }
    public init(frame frameRect: NSRect) {
        super.init()
        contentsScale = System.backingScale
        self.frame = frameRect
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        onDraw?(self, ctx)
    }
    
}



open class SimpleGradientLayer: CAGradientLayer {
    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?
    public private(set) var isInHierarchy: Bool = false
    
    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
            self.didExitHierarchy?()
        }
        return nullAction
    }
    
    override public init() {
        super.init()
        contentsScale = System.backingScale
    }
    public init(frame frameRect: NSRect) {
        super.init()
        contentsScale = System.backingScale
        self.frame = frameRect
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

open class SimpleTextLayer: CATextLayer {
    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?
    public private(set) var isInHierarchy: Bool = false
    
    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
            self.didExitHierarchy?()
        }
        return nullAction
    }
    
    override public init() {
        super.init()
        contentsScale = System.backingScale
    }
    public init(frame frameRect: NSRect) {
        super.init()
        contentsScale = System.backingScale
        self.frame = frameRect
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



