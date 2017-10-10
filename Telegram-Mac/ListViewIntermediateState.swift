//
//  ListViewIntermediateState.swift
//  Telegram
//
//  Created by keepcoder on 19/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import SwiftSignalKitMac

public enum ListViewCenterScrollPositionOverflow {
    case Top
    case Bottom
}

public enum ListViewScrollPosition: Equatable {
    case Top
    case Bottom
    case Center(ListViewCenterScrollPositionOverflow)
}

public func ==(lhs: ListViewScrollPosition, rhs: ListViewScrollPosition) -> Bool {
    switch lhs {
    case .Top:
        switch rhs {
        case .Top:
            return true
        default:
            return false
        }
    case .Bottom:
        switch rhs {
        case .Bottom:
            return true
        default:
            return false
        }
    case let .Center(lhsOverflow):
        switch rhs {
        case let .Center(rhsOverflow) where lhsOverflow == rhsOverflow:
            return true
        default:
            return false
        }
    }
}

public enum ListViewScrollToItemDirectionHint {
    case Up
    case Down
}

public enum ListViewAnimationCurve {
    case Spring(duration: Double)
    case Default
}

public struct ListViewScrollToItem {
    public let index: Int
    public let position: ListViewScrollPosition
    public let animated: Bool
    public let curve: ListViewAnimationCurve
    public let directionHint: ListViewScrollToItemDirectionHint
    
    public init(index: Int, position: ListViewScrollPosition, animated: Bool, curve: ListViewAnimationCurve, directionHint: ListViewScrollToItemDirectionHint) {
        self.index = index
        self.position = position
        self.animated = animated
        self.curve = curve
        self.directionHint = directionHint
    }
}

public enum ListViewItemOperationDirectionHint {
    case Up
    case Down
}

public struct ListViewDeleteItem {
    public let index: Int
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.directionHint = directionHint
    }
}

public struct ListViewInsertItem {
    public let index: Int
    public let previousIndex: Int?
    public let item: ListViewItem
    public let directionHint: ListViewItemOperationDirectionHint?
    public let forceAnimateInsertion: Bool
    
    public init(index: Int, previousIndex: Int?, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?, forceAnimateInsertion: Bool = false) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
        self.directionHint = directionHint
        self.forceAnimateInsertion = forceAnimateInsertion
    }
}

public struct ListViewUpdateItem {
    public let index: Int
    public let previousIndex: Int
    public let item: ListViewItem
    public let directionHint: ListViewItemOperationDirectionHint?
    
    public init(index: Int, previousIndex: Int, item: ListViewItem, directionHint: ListViewItemOperationDirectionHint?) {
        self.index = index
        self.previousIndex = previousIndex
        self.item = item
        self.directionHint = directionHint
    }
}

public struct ListViewDeleteAndInsertOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let AnimateInsertion = ListViewDeleteAndInsertOptions(rawValue: 1)
    public static let AnimateAlpha = ListViewDeleteAndInsertOptions(rawValue: 2)
    public static let LowLatency = ListViewDeleteAndInsertOptions(rawValue: 4)
    public static let Synchronous = ListViewDeleteAndInsertOptions(rawValue: 8)
    public static let RequestItemInsertionAnimations = ListViewDeleteAndInsertOptions(rawValue: 16)
    public static let AnimateTopItemPosition = ListViewDeleteAndInsertOptions(rawValue: 32)
    public static let PreferSynchronousDrawing = ListViewDeleteAndInsertOptions(rawValue: 64)
    public static let PreferSynchronousResourceLoading = ListViewDeleteAndInsertOptions(rawValue: 128)
}


public struct ListViewItemRange: Equatable {
    public let firstIndex: Int
    public let lastIndex: Int
}

public func ==(lhs: ListViewItemRange, rhs: ListViewItemRange) -> Bool {
    return lhs.firstIndex == rhs.firstIndex && lhs.lastIndex == rhs.lastIndex
}

public struct ListViewDisplayedItemRange: Equatable {
    public let loadedRange: ListViewItemRange?
    public let visibleRange: ListViewItemRange?
}

public func ==(lhs: ListViewDisplayedItemRange, rhs: ListViewDisplayedItemRange) -> Bool {
    return lhs.loadedRange == rhs.loadedRange && lhs.visibleRange == rhs.visibleRange
}

struct IndexRange {
    let first: Int
    let last: Int
    
    func contains(_ index: Int) -> Bool {
        return index >= first && index <= last
    }
    
    var empty: Bool {
        return first > last
    }
}

struct OffsetRanges {
    var offsets: [(IndexRange, CGFloat)] = []
    
    mutating func append(_ other: OffsetRanges) {
        self.offsets.append(contentsOf: other.offsets)
    }
    
    mutating func offset(_ indexRange: IndexRange, offset: CGFloat) {
        self.offsets.append((indexRange, offset))
    }
    
    func offsetForIndex(_ index: Int) -> CGFloat {
        var result: CGFloat = 0.0
        for offset in self.offsets {
            if offset.0.contains(index) {
                result += offset.1
            }
        }
        return result
    }
}

func binarySearch(_ inputArr: [Int], searchItem: Int) -> Int? {
    var lowerIndex = 0;
    var upperIndex = inputArr.count - 1
    
    if lowerIndex > upperIndex {
        return nil
    }
    
    while (true) {
        let currentIndex = (lowerIndex + upperIndex) / 2
        if (inputArr[currentIndex] == searchItem) {
            return currentIndex
        } else if (lowerIndex > upperIndex) {
            return nil
        } else {
            if (inputArr[currentIndex] > searchItem) {
                upperIndex = currentIndex - 1
            } else {
                lowerIndex = currentIndex + 1
            }
        }
    }
}

struct TransactionState {
    let visibleSize: CGSize
    let items: [ListViewItem]
}



enum ListViewInsertionOffsetDirection {
    case Up
    case Down
    
    init(_ hint: ListViewItemOperationDirectionHint) {
        switch hint {
        case .Up:
            self = .Up
        case .Down:
            self = .Down
        }
    }
    
    func inverted() -> ListViewInsertionOffsetDirection {
        switch self {
        case .Up:
            return .Down
        case .Down:
            return .Up
        }
    }
}

struct ListViewInsertionPoint {
    let index: Int
    let point: CGPoint
    let direction: ListViewInsertionOffsetDirection
}

public protocol ListViewItem {
    
}

public struct ListViewUpdateSizeAndInsets {
    public let size: CGSize
    public let insets: NSEdgeInsets
    public let duration: Double
    public let curve: ListViewAnimationCurve
    
    public init(size: CGSize, insets: NSEdgeInsets, duration: Double, curve: ListViewAnimationCurve) {
        self.size = size
        self.insets = insets
        self.duration = duration
        self.curve = curve
    }
}
