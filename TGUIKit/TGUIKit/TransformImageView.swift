//
//  TransformImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

public enum ImageCorner: Equatable {
    case Corner(CGFloat)
    case Tail(CGFloat)
    
    public var extendedInsets: CGSize {
        switch self {
        case .Tail:
            return CGSize(width: 3.0, height: 0.0)
        default:
            return CGSize()
        }
    }
}

public func ==(lhs: ImageCorner, rhs: ImageCorner) -> Bool {
    switch lhs {
    case let .Corner(lhsRadius):
        switch rhs {
        case let .Corner(rhsRadius) where abs(lhsRadius - rhsRadius) < CGFloat(FLT_EPSILON):
            return true
        default:
            return false
        }
    case let .Tail(lhsRadius):
        switch rhs {
        case let .Tail(rhsRadius) where abs(lhsRadius - rhsRadius) < CGFloat(FLT_EPSILON):
            return true
        default:
            return false
        }
    }
}

public struct ImageCorners: Equatable {
    public let topLeft: ImageCorner
    public let topRight: ImageCorner
    public let bottomLeft: ImageCorner
    public let bottomRight: ImageCorner
    
    public init(radius: CGFloat) {
        self.topLeft = .Corner(radius)
        self.topRight = .Corner(radius)
        self.bottomLeft = .Corner(radius)
        self.bottomRight = .Corner(radius)
    }
    
    public init(topLeft: ImageCorner, topRight: ImageCorner, bottomLeft: ImageCorner, bottomRight: ImageCorner) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
    
    public init() {
        self.init(topLeft: .Corner(0.0), topRight: .Corner(0.0), bottomLeft: .Corner(0.0), bottomRight: .Corner(0.0))
    }
    
    public var extendedEdges: EdgeInsets {
        let left = self.bottomLeft.extendedInsets.width
        let right = self.bottomRight.extendedInsets.width
        
        return EdgeInsets(top: 0.0, left: left, bottom: 0.0, right: right)
    }
}

public func ==(lhs: ImageCorners, rhs: ImageCorners) -> Bool {
    return lhs.topLeft == rhs.topLeft && lhs.topRight == rhs.topRight && lhs.bottomLeft == rhs.bottomLeft && lhs.bottomRight == rhs.bottomRight
}

public struct TransformImageArguments: Equatable {
    public let corners: ImageCorners
    
    public let imageSize: NSSize
    public let boundingSize: NSSize
    public let intrinsicInsets: EdgeInsets
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, height: self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom)
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height);
    }
    
    public var insets: EdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return EdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
    
    public init(corners:ImageCorners, imageSize:NSSize, boundingSize:NSSize, intrinsicInsets:EdgeInsets) {
        self.corners = corners
        self.imageSize = imageSize
        self.boundingSize = boundingSize
        self.intrinsicInsets = intrinsicInsets
    }
}

public func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
    return lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners
}

open class TransformImageView: Control {
    public var imageUpdated: (() -> Void)?
    public var alphaTransitionOnFirstUpdate = false
    private var disposable = MetaDisposable()
    public var animatesAlphaOnFirstTransition:Bool = false
    private let argumentsPromise = Promise<TransformImageArguments>()
    private var first:Bool = true
    override public init() {
        super.init()
        self.layer?.disableActions()
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.disableActions()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    open override func removeFromSuperview() {
        super.removeFromSuperview()
        self.disposable.set(nil)
    }
    
    public func setSignal(account: Account, signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, dispatchOnDisplayLink: Bool = true) {
        self.layer?.contents = nil
        let result = combineLatest(signal, argumentsPromise.get()) |> deliverOn(account.graphicsThreadPool) |> mapToThrottled { transform, arguments -> Signal<CGImage?, NoError> in
            return deferred {
                return Signal<CGImage?, NoError>.single(transform(arguments)?.generateImage())
            }
        }
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: {[weak self] next in
            
            if let strongSelf = self  {
                if strongSelf.layer?.contents == nil && strongSelf.animatesAlphaOnFirstTransition {
                    strongSelf.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                self?.layer?.contents = next
                
                if !strongSelf.first {
                    self?.layer?.animateContents()
                }
                strongSelf.first = false
            }
           
        }))
    }
    
    public func set(arguments:TransformImageArguments) ->Void {
        first = true
        argumentsPromise.set(.single(arguments))
    }
    
    override open func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        view.background = .clear
        view.layer?.frame = NSMakeRect(0, visibleRect.minY == 0 ? 0 : visibleRect.height - frame.height, frame.width,  frame.height)
        view.layer?.contents = self.layer?.contents
        view.layer?.masksToBounds = true
        view.frame = self.visibleRect
        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = System.backingScale
        return view
    }
    
    
}




/*
 if dispatchOnDisplayLink {
 displayLinkDispatcher.dispatch { [weak self] in
 if let strongSelf = self {
 if strongSelf.alphaTransitionOnFirstUpdate && strongSelf.contents == nil {
 strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
 }
 strongSelf.contents = next?.cgImage
 if let imageUpdated = strongSelf.imageUpdated {
 imageUpdated()
 }
 }
 }
 } else {
 if let strongSelf = self {
 if strongSelf.alphaTransitionOnFirstUpdate && strongSelf.contents == nil {
 strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
 }
 strongSelf.contents = next?.cgImage
 if let imageUpdated = strongSelf.imageUpdated {
 imageUpdated()
 }
 }
 }
 */
