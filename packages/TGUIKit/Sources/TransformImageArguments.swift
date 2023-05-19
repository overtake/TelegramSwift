//
//  TransformImageView.swift
//  TGUIKit
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa




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
    
    public var corner:CGFloat {
        switch self {
        case let .Corner(corner):
            return corner
        default:
            return 0
        }
    }
}

public func ==(lhs: ImageCorner, rhs: ImageCorner) -> Bool {
    switch lhs {
    case let .Corner(lhsRadius):
        switch rhs {
        case let .Corner(rhsRadius) where abs(lhsRadius - rhsRadius) < CGFloat.ulpOfOne:
            return true
        default:
            return false
        }
    case let .Tail(lhsRadius):
        switch rhs {
        case let .Tail(rhsRadius) where abs(lhsRadius - rhsRadius) < CGFloat.ulpOfOne:
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
    
    public var extendedEdges: NSEdgeInsets {
        let left = self.bottomLeft.extendedInsets.width
        let right = self.bottomRight.extendedInsets.width
        
        return NSEdgeInsets(top: 0.0, left: left, bottom: 0.0, right: right)
    }
}

public func ==(lhs: ImageCorners, rhs: ImageCorners) -> Bool {
    return lhs.topLeft == rhs.topLeft && lhs.topRight == rhs.topRight && lhs.bottomLeft == rhs.bottomLeft && lhs.bottomRight == rhs.bottomRight
}

public enum TransformImageResizeMode : Hashable {
    case fill(NSColor)
    case blurBackground
    case none
    case fillTransparent
    case imageColor(NSColor)
}

public enum TransformImageEmptyColor : Equatable, Hashable {
    case color(NSColor)
    case fill(NSColor)
    case gradient(colors: [NSColor], intensity: CGFloat, rotation: Int32?)
}

public struct TransformImageArguments: Equatable, Hashable {
    public let corners: ImageCorners
    
    public let imageSize: NSSize
    public let boundingSize: NSSize
    public let intrinsicInsets: NSEdgeInsets
    public let resizeMode: TransformImageResizeMode
    public let emptyColor: TransformImageEmptyColor?
    public let scale: CGFloat
    public let mirror: Bool
    public let someObject: Int
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(imageSize.width)
        hasher.combine(imageSize.height)
        hasher.combine(boundingSize.height)
        hasher.combine(boundingSize.width)
        hasher.combine(scale)
        hasher.combine(mirror)
        hasher.combine(someObject)
        if let emptyColor = emptyColor {
            hasher.combine(emptyColor)
        }
        hasher.combine(resizeMode)
        
        hasher.combine(intrinsicInsets.top)
        hasher.combine(intrinsicInsets.left)
        hasher.combine(intrinsicInsets.right)
        hasher.combine(intrinsicInsets.bottom)

    }
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: max(self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, 1), height: max(self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom, 1))
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height);
    }
    
    public var insets: NSEdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return NSEdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
    
    public init(corners:ImageCorners, imageSize:NSSize, boundingSize:NSSize, intrinsicInsets:NSEdgeInsets, resizeMode: TransformImageResizeMode = .none, emptyColor: TransformImageEmptyColor? = nil, scale: CGFloat = System.backingScale, someObject: Int = 0, mirror: Bool = false) {
        self.corners = corners
        let min = corners.topLeft.corner + corners.topRight.corner
        self.imageSize = NSMakeSize(max(imageSize.width, min), max(imageSize.height, min))
        self.boundingSize = NSMakeSize(max(boundingSize.width, min), max(boundingSize.height, min))
        self.intrinsicInsets = intrinsicInsets
        self.resizeMode = resizeMode
        self.emptyColor = emptyColor
        self.scale = scale
        self.someObject = someObject
        self.mirror = mirror
    }
}

public func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
    return lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners && lhs.emptyColor == rhs.emptyColor && lhs.scale == rhs.scale && lhs.someObject == rhs.someObject && lhs.mirror == rhs.mirror
}



