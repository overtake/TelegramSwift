//
//  GridNode.swift
//  TGUIKit
//
//  Created by keepcoder on 23/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public protocol GridListItem {
    var section: GridSection? { get }
    func node(layout: GridNodeLayout, gridNode:GridNode) -> GridItemNode
    func update(node: GridItemNode)
}



open class GridItemNode: ImageButton {
    
    open var stableId:AnyHashable {
        return 0
    }
    
    public private(set) weak var grid:GridNode?
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    public init(_ grid:GridNode) {
        super.init()
        self.grid = grid
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}

public protocol GridSection {
    var height: CGFloat { get }
    var hashValue: Int { get }
    
    func isEqual(to: GridSection) -> Bool
    func node() -> View
}

public struct GridNodeInsertItem {
    public let index: Int
    public let item: GridListItem
    public let previousIndex: Int?
    
    public init(index: Int, item: GridListItem, previousIndex: Int?) {
        self.index = index
        self.item = item
        self.previousIndex = previousIndex
    }
}

public struct GridNodeUpdateItem {
    public let index: Int
    public let item: GridListItem
    
    public init(index: Int, item: GridListItem) {
        self.index = index
        self.item = item
    }
}

public enum GridNodeStationaryItems {
    case none
    case all
    case indices(Set<Int>)
}

public enum GridNodeScrollToItemPosition {
    case top
    case bottom
    case center
}


public enum GridNodePreviousItemsTransitionDirectionHint {
    case up
    case down
}

public struct GridNodeScrollToItem {
    public let index: Int
    public let position: GridNodeScrollToItemPosition
    public let transition: ContainedViewLayoutTransition
    public let directionHint: GridNodePreviousItemsTransitionDirectionHint
    public let adjustForSection: Bool
    public let adjustForTopInset: Bool
    
    public init(index: Int, position: GridNodeScrollToItemPosition, transition: ContainedViewLayoutTransition, directionHint: GridNodePreviousItemsTransitionDirectionHint, adjustForSection: Bool, adjustForTopInset: Bool = false) {
        self.index = index
        self.position = position
        self.transition = transition
        self.directionHint = directionHint
        self.adjustForSection = adjustForSection
        self.adjustForTopInset = adjustForTopInset
    }
}

private struct GridNodePresentationLayoutTransition {
    let layout: GridNodePresentationLayout
    let directionHint: GridNodePreviousItemsTransitionDirectionHint
    let transition: ContainedViewLayoutTransition
}

public struct GridNodeLayout: Equatable {
    public let size: CGSize
    public let insets: EdgeInsets
    public let preloadSize: CGFloat
    
    
    fileprivate let _itemSize:CGSize
    public var itemSize: CGSize {
        let s = floorToScreenPixels(size.width/floor(size.width/_itemSize.width))
        return NSMakeSize(s, s)
    }
    
    public init(size: CGSize, insets: EdgeInsets, preloadSize: CGFloat, itemSize: CGSize) {
        self.size = size
        self.insets = insets
        self.preloadSize = preloadSize
        _itemSize = itemSize
    }
    
    public static func ==(lhs: GridNodeLayout, rhs: GridNodeLayout) -> Bool {
        return lhs.size.equalTo(rhs.size) && lhs.preloadSize.isEqual(to: rhs.preloadSize) && lhs.itemSize.equalTo(rhs.itemSize)
    }
}

public struct GridNodeUpdateLayout {
    public let layout: GridNodeLayout
    public let transition: ContainedViewLayoutTransition
    
    public init(layout: GridNodeLayout, transition: ContainedViewLayoutTransition) {
        self.layout = layout
        self.transition = transition
    }
}

private struct WrappedGridItemNode: Hashable {
    let node: View
    
    var hashValue: Int {
        return node.hashValue
    }
    
    static func ==(lhs: WrappedGridItemNode, rhs: WrappedGridItemNode) -> Bool {
        return lhs.node === rhs.node
    }
}

public struct GridNodeTransaction {
    public let deleteItems: [Int]
    public let insertItems: [GridNodeInsertItem]
    public let updateItems: [GridNodeUpdateItem]
    public let scrollToItem: GridNodeScrollToItem?
    public let updateLayout: GridNodeUpdateLayout?
    public let stationaryItems: GridNodeStationaryItems
    public let updateFirstIndexInSectionOffset: Int?
    
    public init(deleteItems: [Int], insertItems: [GridNodeInsertItem], updateItems: [GridNodeUpdateItem], scrollToItem: GridNodeScrollToItem?, updateLayout: GridNodeUpdateLayout?, stationaryItems: GridNodeStationaryItems, updateFirstIndexInSectionOffset: Int?) {
        self.deleteItems = deleteItems
        self.insertItems = insertItems
        self.updateItems = updateItems
        self.scrollToItem = scrollToItem
        self.updateLayout = updateLayout
        self.stationaryItems = stationaryItems
        self.updateFirstIndexInSectionOffset = updateFirstIndexInSectionOffset
    }
}

private struct GridNodePresentationItem {
    let index: Int
    let frame: CGRect
}

private struct GridNodePresentationLayout {
    let layout: GridNodeLayout
    let contentOffset: CGPoint
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
    let sections: [GridNodePresentationSection]
    let stationarySection: GridNodePresentationSection?
}


private struct GridNodePresentationSection {
    let section: GridSection
    let frame: CGRect
}

private final class GridNodeItemLayout {
    let contentSize: CGSize
    let items: [GridNodePresentationItem]
    let sections: [GridNodePresentationSection]
    
    init(contentSize: CGSize, items: [GridNodePresentationItem], sections: [GridNodePresentationSection]) {
        self.contentSize = contentSize
        self.items = items
        self.sections = sections
    }
}

public struct GridNodeDisplayedItemRange: Equatable {
    public let loadedRange: Range<Int>?
    public let visibleRange: Range<Int>?
    
    public static func ==(lhs: GridNodeDisplayedItemRange, rhs: GridNodeDisplayedItemRange) -> Bool {
        return lhs.loadedRange == rhs.loadedRange && lhs.visibleRange == rhs.visibleRange
    }
}


public struct GridNodeVisibleItems {
    public let top: (Int, GridListItem)?
    public let bottom: (Int, GridListItem)?
    public let topVisible: (Int, GridListItem)?
    public let bottomVisible: (Int, GridListItem)?
    public let topSectionVisible: GridSection?
    public let count: Int
}

private struct WrappedGridSection: Hashable {
    let section: GridSection
    
    init(_ section: GridSection) {
        self.section = section
    }
    
    var hashValue: Int {
        return self.section.hashValue
    }
    
    static func ==(lhs: WrappedGridSection, rhs: WrappedGridSection) -> Bool {
        return lhs.section.isEqual(to: rhs.section)
    }
}


open class GridNode: ScrollView, InteractionContentViewProtocol {
    
    private var document:View
    
    
    private var gridLayout = GridNodeLayout(size: CGSize(), insets: EdgeInsets(), preloadSize: 0.0, itemSize: CGSize())
    private var firstIndexInSectionOffset: Int = 0
    private var items: [GridListItem] = []
    private var itemNodes: [Int: GridItemNode] = [:]
    private var sectionNodes: [WrappedGridSection: View] = [:]
    private var itemLayout = GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
    private var stationarySection:(WrappedGridSection?, View?)
    
    private var applyingContentOffset = false
    
    public var visibleItemsUpdated: ((GridNodeVisibleItems) -> Void)?

    public override init(frame frameRect: NSRect) {
        document = View(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        
        deltaCorner = 45
        self.autoresizesSubviews = true;
        self.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewHeightSizable]
        
        self.hasVerticalScroller = true
        
        self.documentView = document

    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func contentInteractionView(for stableId: AnyHashable) -> NSView? {
        for (_, node) in itemNodes {
            if node.stableId == stableId {
                return node
            }
        }
        return nil;
    }
    
    public func transaction(_ transaction: GridNodeTransaction, completion: (GridNodeDisplayedItemRange) -> Void) {
        if transaction.deleteItems.isEmpty && transaction.insertItems.isEmpty && transaction.scrollToItem == nil && transaction.updateItems.isEmpty && (transaction.updateLayout == nil || transaction.updateLayout!.layout == self.gridLayout && (transaction.updateFirstIndexInSectionOffset == nil || transaction.updateFirstIndexInSectionOffset == self.firstIndexInSectionOffset)) {
            completion(self.displayedItemRange())
            return
        }
        
        if let updateFirstIndexInSectionOffset = transaction.updateFirstIndexInSectionOffset {
            self.firstIndexInSectionOffset = updateFirstIndexInSectionOffset
        }
        
        if let updateLayout = transaction.updateLayout {
            self.gridLayout = updateLayout.layout
        }
        
        for updatedItem in transaction.updateItems {
            //self.items[updatedItem.index] = updatedItem.item
            if let itemNode = self.itemNodes[updatedItem.index] {
                updatedItem.item.update(node: itemNode)
            }
        }
        
        var removedNodes: [GridItemNode] = []
        
        if !transaction.deleteItems.isEmpty || !transaction.insertItems.isEmpty {
            let deleteItems = transaction.deleteItems.sorted()
            
            for deleteItemIndex in deleteItems.reversed() {
                self.items.remove(at: deleteItemIndex)
                if let itemNode = self.itemNodes[deleteItemIndex] {
                    removedNodes.append(itemNode)
                    self.removeItemNodeWithIndex(deleteItemIndex, removeNode: false)
                } else {
                    self.removeItemNodeWithIndex(deleteItemIndex, removeNode: true)
                }
            }
            
            var remappedDeletionItemNodes: [Int: GridItemNode] = [:]
            
            for (index, itemNode) in self.itemNodes {
                var indexOffset = 0
                for deleteIndex in deleteItems {
                    if deleteIndex < index {
                        indexOffset += 1
                    } else {
                        break
                    }
                }
                
                remappedDeletionItemNodes[index - indexOffset] = itemNode
            }
            
            let insertItems = transaction.insertItems.sorted(by: { $0.index < $1.index })
            if self.items.count == 0 && !insertItems.isEmpty {
                if insertItems[0].index != 0 {
                    fatalError("transaction: invalid insert into empty list")
                }
            }
            
            for insertedItem in insertItems {
                self.items.insert(insertedItem.item, at: insertedItem.index)
            }
            
            var remappedInsertionItemNodes: [Int: GridItemNode] = [:]
            
            let sortedInsertItems = transaction.insertItems.sorted(by: { $0.index < $1.index })
            
            for (index, itemNode) in remappedDeletionItemNodes {
                var indexOffset = 0
                for insertedItem in sortedInsertItems {
                    if insertedItem.index <= index + indexOffset {
                        indexOffset += 1
                    }
                }
                
                remappedInsertionItemNodes[index + indexOffset] = itemNode
            }

            
            self.itemNodes = remappedInsertionItemNodes
        }
        
        let previousLayoutWasEmpty = self.itemLayout.items.isEmpty
        
        self.itemLayout = self.generateItemLayout()
        
        let generatedScrollToItem: GridNodeScrollToItem?
        if let scrollToItem = transaction.scrollToItem {
            generatedScrollToItem = scrollToItem
        } else if previousLayoutWasEmpty {
            generatedScrollToItem = GridNodeScrollToItem(index: 0, position: .top, transition: .immediate, directionHint: .up, adjustForSection: true)
        } else {
            generatedScrollToItem = nil
        }
        
        self.applyPresentaionLayoutTransition(self.generatePresentationLayoutTransition(stationaryItems: transaction.stationaryItems, scrollToItem: generatedScrollToItem), removedNodes: removedNodes)
        
        completion(self.displayedItemRange())
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
            let clipView = self.contentView
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NSViewBoundsDidChange, object: clipView, queue: nil, using: { [weak self] notification  in
                if let strongSelf = self {
                    if !strongSelf.applyingContentOffset {
                         strongSelf.applyPresentaionLayoutTransition(strongSelf.generatePresentationLayoutTransition(), removedNodes: [])
                    }
                }
                
            })
        } else {
            NotificationCenter.default.removeObserver(self)
        }
    }

    
    
    public func scrollViewDidScroll(_ scrollView: ScrollView) {
        
    }
    
    private func displayedItemRange() -> GridNodeDisplayedItemRange {
        var minIndex: Int?
        var maxIndex: Int?
        for index in self.itemNodes.keys {
            if minIndex == nil || minIndex! > index {
                minIndex = index
            }
            if maxIndex == nil || maxIndex! < index {
                maxIndex = index
            }
        }
        
        if let minIndex = minIndex, let maxIndex = maxIndex {
            return GridNodeDisplayedItemRange(loadedRange: minIndex ..< maxIndex, visibleRange: minIndex ..< maxIndex)
        } else {
            return GridNodeDisplayedItemRange(loadedRange: nil, visibleRange: nil)
        }
    }
    
    private func generateItemLayout() -> GridNodeItemLayout {
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) && !self.items.isEmpty {
            var contentSize = CGSize(width: gridLayout.size.width, height: 0.0)
            var items: [GridNodePresentationItem] = []
            var sections: [GridNodePresentationSection] = []
            
            var incrementedCurrentRow = false
            var nextItemOrigin = CGPoint(x: 0.0, y: 0.0)
            var index = 0
            var previousSection: GridSection?
            for item in self.items {
                let section = item.section
                var keepSection = true
                if let previousSection = previousSection, let section = section {
                    keepSection = previousSection.isEqual(to: section)
                } else if (previousSection != nil) != (section != nil) {
                    keepSection = false
                }
                
                if !keepSection {
                    if incrementedCurrentRow {
                        nextItemOrigin.x = 0.0
                        nextItemOrigin.y += gridLayout.itemSize.height
                        incrementedCurrentRow = false
                    }
                    
                    if let section = section {
                        sections.append(GridNodePresentationSection(section: section, frame: CGRect(origin: CGPoint(x: 0.0, y: nextItemOrigin.y), size: CGSize(width: gridLayout.size.width, height: section.height))))
                        nextItemOrigin.y += section.height
                        contentSize.height += section.height
                    }
                }
                previousSection = section
                
                if !incrementedCurrentRow {
                    incrementedCurrentRow = true
                    contentSize.height += gridLayout.itemSize.height
                }
                
                if index == 0 {
                    let itemsInRow = Int(gridLayout.size.width) / Int(gridLayout.itemSize.width)
                    let normalizedIndexOffset = self.firstIndexInSectionOffset % itemsInRow
                    nextItemOrigin.x += gridLayout.itemSize.width * CGFloat(normalizedIndexOffset)
                }
                
                items.append(GridNodePresentationItem(index: index, frame: CGRect(origin: nextItemOrigin, size: gridLayout.itemSize)))
                index += 1
                
                nextItemOrigin.x += gridLayout.itemSize.width
                if nextItemOrigin.x + gridLayout.itemSize.width > gridLayout.size.width {
                    nextItemOrigin.x = 0.0
                    nextItemOrigin.y += gridLayout.itemSize.height
                    incrementedCurrentRow = false
                }
            }
            
            return GridNodeItemLayout(contentSize: contentSize, items: items, sections: sections)
        } else {
            return GridNodeItemLayout(contentSize: CGSize(), items: [], sections: [])
        }
    }
    
    private func generatePresentationLayoutTransition(stationaryItems: GridNodeStationaryItems = .none, scrollToItem: GridNodeScrollToItem? = nil) -> GridNodePresentationLayoutTransition {
        if CGFloat(0.0).isLess(than: gridLayout.size.width) && CGFloat(0.0).isLess(than: gridLayout.size.height) && !self.itemLayout.items.isEmpty {
            var transitionDirectionHint: GridNodePreviousItemsTransitionDirectionHint = .up
            var transition: ContainedViewLayoutTransition = .immediate
            let contentOffset: CGPoint
            switch stationaryItems {
            case .none:
                if let scrollToItem = scrollToItem {
                    let itemFrame = self.itemLayout.items[scrollToItem.index]
                    
                    var additionalOffset: CGFloat = 0.0
                    if scrollToItem.adjustForSection {
                        var adjustForSection: GridSection?
                        if scrollToItem.index == 0 {
                            if let itemSection = self.items[scrollToItem.index].section {
                                adjustForSection = itemSection
                            }
                        } else {
                            let itemSection = self.items[scrollToItem.index].section
                            let previousSection = self.items[scrollToItem.index - 1].section
                            if let itemSection = itemSection, let previousSection = previousSection {
                                if !itemSection.isEqual(to: previousSection) {
                                    adjustForSection = itemSection
                                }
                            } else if let itemSection = itemSection {
                                adjustForSection = itemSection
                            }
                        }
                        
                        if let adjustForSection = adjustForSection {
                            additionalOffset = -adjustForSection.height
                        }
                    }
                    
                    let displayHeight = max(0.0, self.gridLayout.size.height - self.gridLayout.insets.top - self.gridLayout.insets.bottom)
                    var verticalOffset: CGFloat
                    
                    switch scrollToItem.position {
                    case .top:
                        verticalOffset = itemFrame.frame.minY + additionalOffset
                    case .center:
                        verticalOffset = floor(itemFrame.frame.minY + itemFrame.frame.size.height / 2.0 - displayHeight / 2.0 - self.gridLayout.insets.top) + additionalOffset
                    case .bottom:
                        verticalOffset = itemFrame.frame.maxY - displayHeight + additionalOffset
                    }
                    
                    if verticalOffset > self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height {
                        verticalOffset = self.itemLayout.contentSize.height + self.gridLayout.insets.bottom - self.gridLayout.size.height
                    }
                    if verticalOffset < -self.gridLayout.insets.top {
                        verticalOffset = -self.gridLayout.insets.top
                    }
                    
                    transitionDirectionHint = scrollToItem.directionHint
                    transition = scrollToItem.transition
                    
                    contentOffset = CGPoint(x: 0.0, y: verticalOffset)
                } else {
                    contentOffset = self.documentOffset
                }
            case let .indices(stationaryItemIndices):
                var selectedContentOffset: CGPoint?
                for (index, itemNode) in self.itemNodes {
                    if stationaryItemIndices.contains(index) {
                  //      let currentScreenOffset = itemNode.frame.origin.y - self.documentOffset.y
                        selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + documentOffset.y)
                        break
                    }
                }
                
                if let selectedContentOffset = selectedContentOffset {
                    contentOffset = selectedContentOffset
                } else {
                    contentOffset = self.documentOffset
                }
            case .all:
                var selectedContentOffset: CGPoint?
                for (index, itemNode) in self.itemNodes {
                   // let currentScreenOffset = itemNode.frame.origin.y - self.documentOffset.y
                    selectedContentOffset = CGPoint(x: 0.0, y: self.itemLayout.items[index].frame.origin.y - itemNode.frame.origin.y + documentOffset.y)
                    break
                }
                
                if let selectedContentOffset = selectedContentOffset {
                    contentOffset = selectedContentOffset
                } else {
                    contentOffset = self.documentOffset
                }
            }
            
            let lowerDisplayBound = contentOffset.y - self.gridLayout.preloadSize
            let upperDisplayBound = contentOffset.y + self.gridLayout.size.height + self.gridLayout.preloadSize
            
            var presentationItems: [GridNodePresentationItem] = []
            for item in self.itemLayout.items {
                if item.frame.origin.y < lowerDisplayBound {
                    continue
                }
                if item.frame.origin.y + item.frame.size.height > upperDisplayBound {
                    break
                }
                presentationItems.append(item)
            }
            
            var presentationSections: [GridNodePresentationSection] = []
            for section in self.itemLayout.sections {
                if section.frame.origin.y < lowerDisplayBound {
                    continue
                }
                if section.frame.origin.y + section.frame.size.height > upperDisplayBound {
                    break
                }
                presentationSections.append(section)
            }
            
           
            
            var stationary:GridNodePresentationSection?
            for section in self.itemLayout.sections.reversed() {
                if section.frame.minY <= contentOffset.y {
                    stationary = GridNodePresentationSection(section: section.section, frame: NSMakeRect(0, contentOffset.y, section.frame.width, section.frame.height))
                    break
                }
               
            }
            
            
            return GridNodePresentationLayoutTransition(layout: GridNodePresentationLayout(layout: self.gridLayout, contentOffset: contentOffset, contentSize: self.itemLayout.contentSize, items: presentationItems, sections: presentationSections, stationarySection:stationary), directionHint: transitionDirectionHint, transition: transition)
        } else {
            return GridNodePresentationLayoutTransition(layout: GridNodePresentationLayout(layout: self.gridLayout, contentOffset: CGPoint(), contentSize: self.itemLayout.contentSize, items: [], sections: [], stationarySection:nil), directionHint: .up, transition: .immediate)
        }
    }
    
    
    private func applyPresentaionLayoutTransition(_ presentationLayoutTransition: GridNodePresentationLayoutTransition, removedNodes: [GridItemNode]) {
        var previousItemFrames: ([WrappedGridItemNode: CGRect])?
        switch presentationLayoutTransition.transition {
        case .animated:
            var itemFrames: [WrappedGridItemNode: CGRect] = [:]
            let contentOffset = self.documentOffset
            for (_, itemNode) in self.itemNodes {
                itemFrames[WrappedGridItemNode(node: itemNode)] = itemNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            for (_, sectionNode) in self.sectionNodes {
                itemFrames[WrappedGridItemNode(node: sectionNode)] = sectionNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            for itemNode in removedNodes {
                itemFrames[WrappedGridItemNode(node: itemNode)] = itemNode.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
            }
            previousItemFrames = itemFrames
        case .immediate:
            break
        }
        
        applyingContentOffset = true
        self.documentView?.setFrameSize(presentationLayoutTransition.layout.contentSize)
        if !documentOffset.equalTo(presentationLayoutTransition.layout.contentOffset) {
            self.clipView.bounds = NSMakeRect(presentationLayoutTransition.layout.contentOffset.x, presentationLayoutTransition.layout.contentOffset.y, clipView.bounds.width, clipView.bounds.height)
            self.reflectScrolledClipView(self.clipView)
        }
        applyingContentOffset = false
        
        var existingItemIndices = Set<Int>()
        for item in presentationLayoutTransition.layout.items {
            existingItemIndices.insert(item.index)
            
            if let itemNode = self.itemNodes[item.index] {
                itemNode.frame = item.frame
            } else {
                let itemNode = self.items[item.index].node(layout: presentationLayoutTransition.layout.layout, gridNode:self)
                itemNode.frame = item.frame
                self.addItemNode(index: item.index, itemNode: itemNode)
            }
        }
        
        var existingSections = Set<WrappedGridSection>()
        for section in presentationLayoutTransition.layout.sections {
            let wrappedSection = WrappedGridSection(section.section)
            existingSections.insert(wrappedSection)
            
            if let sectionNode = self.sectionNodes[wrappedSection] {
                sectionNode.frame = section.frame
            } else {
                let sectionNode = section.section.node()
                sectionNode.frame = section.frame
                self.addSectionNode(section: wrappedSection, sectionNode: sectionNode)
            }
        }
        
        if let stationarySection = presentationLayoutTransition.layout.stationarySection {
            if self.stationarySection.0 == WrappedGridSection(stationarySection.section) {
                var updated:Bool = false
                for section in presentationLayoutTransition.layout.sections {
                    if section.frame.minY > clipView.bounds.minY {
                        let difference = section.frame.minY - clipView.bounds.minY
                        if difference > 0 && difference < section.frame.height {
                            self.stationarySection.1?.frame = NSMakeRect(stationarySection.frame.minX, stationarySection.frame.minY - (stationarySection.frame.height - difference), stationarySection.frame.width, stationarySection.frame.height)
                            updated = true
                            break
                        }
                    }
                }
                if !updated {
                    self.stationarySection.1?.frame = stationarySection.frame
                }
            } else {
                removeStationarySectionNode()
                let stationary = stationarySection.section.node()
                stationary.border = [.Bottom]
                stationary.layer?.zPosition = 1000
                stationary.frame = NSMakeRect(0, 0, stationarySection.frame.width, stationarySection.frame.height)
                addStationarySectionNode(stationarySection, view:stationary)

            }
           
        } else {
            removeStationarySectionNode()
        }
        
        if let previousItemFrames = previousItemFrames, case let .animated(duration, curve) = presentationLayoutTransition.transition {
            let contentOffset = presentationLayoutTransition.layout.contentOffset
            
            var offset: CGFloat?
            for (index, itemNode) in self.itemNodes {
                if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)], existingItemIndices.contains(index) {
                    let currentFrame = itemNode.frame.offsetBy(dx: 0.0, dy: -presentationLayoutTransition.layout.contentOffset.y)
                    offset = previousFrame.origin.y - currentFrame.origin.y
                    break
                }
            }
            
            if offset == nil {
                var previousUpperBound: CGFloat?
                var previousLowerBound: CGFloat?
                for (_, frame) in previousItemFrames {
                    if previousUpperBound == nil || previousUpperBound! > frame.minY {
                        previousUpperBound = frame.minY
                    }
                    if previousLowerBound == nil || previousLowerBound! < frame.maxY {
                        previousLowerBound = frame.maxY
                    }
                }
                
                var updatedUpperBound: CGFloat?
                var updatedLowerBound: CGFloat?
                for item in presentationLayoutTransition.layout.items {
                    let frame = item.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
                    if updatedUpperBound == nil || updatedUpperBound! > frame.minY {
                        updatedUpperBound = frame.minY
                    }
                    if updatedLowerBound == nil || updatedLowerBound! < frame.maxY {
                        updatedLowerBound = frame.maxY
                    }
                }
                for section in presentationLayoutTransition.layout.sections {
                    let frame = section.frame.offsetBy(dx: 0.0, dy: -contentOffset.y)
                    if updatedUpperBound == nil || updatedUpperBound! > frame.minY {
                        updatedUpperBound = frame.minY
                    }
                    if updatedLowerBound == nil || updatedLowerBound! < frame.maxY {
                        updatedLowerBound = frame.maxY
                    }
                }
                
                if let updatedUpperBound = updatedUpperBound, let updatedLowerBound = updatedLowerBound {
                    switch presentationLayoutTransition.directionHint {
                    case .up:
                        offset = -(updatedLowerBound - (previousUpperBound ?? 0.0))
                    case .down:
                        offset = -(updatedUpperBound - (previousLowerBound ?? presentationLayoutTransition.layout.layout.size.height))
                    }
                }
            }
            
            if let offset = offset {
                let timingFunction: String
                switch curve {
                case .easeInOut:
                    timingFunction = kCAMediaTimingFunctionEaseInEaseOut
                case .spring:
                    timingFunction = kCAMediaTimingFunctionSpring
                }
                
                for (index, itemNode) in self.itemNodes where existingItemIndices.contains(index) {
                    itemNode.layer?.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                }
                for (wrappedSection, sectionNode) in self.sectionNodes where existingSections.contains(wrappedSection) {
                  //  let position = sectionNode.layer?.position
                    sectionNode.layer?.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                }
                
                for index in self.itemNodes.keys {
                    if !existingItemIndices.contains(index) {
                        let itemNode = self.itemNodes[index]!
                        if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                            self.removeItemNodeWithIndex(index, removeNode: false)
                            let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                            itemNode.layer?.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y), to: CGPoint(x: position.x, y: position.y + contentOffset.y - offset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak itemNode] _ in
                                itemNode?.removeFromSuperview()
                            })
                        } else {
                            self.removeItemNodeWithIndex(index, removeNode: true)
                        }
                    }
                }
                
                for itemNode in removedNodes {
                    if let previousFrame = previousItemFrames[WrappedGridItemNode(node: itemNode)] {
                        let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                        itemNode.layer?.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y), to: CGPoint(x: position.x, y: position.y + contentOffset.y - offset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak itemNode] _ in
                            itemNode?.removeFromSuperview()
                        })
                    } else {
                        itemNode.removeFromSuperview()
                    }
                }
                
                for wrappedSection in self.sectionNodes.keys {
                    if !existingSections.contains(wrappedSection) {
                        let sectionNode = self.sectionNodes[wrappedSection]!
                        if let previousFrame = previousItemFrames[WrappedGridItemNode(node: sectionNode)] {
                            self.removeSectionNodeWithSection(wrappedSection, removeNode: false)
                            let position = CGPoint(x: previousFrame.midX, y: previousFrame.midY)
                            sectionNode.layer?.animatePosition(from: CGPoint(x: position.x, y: position.y + contentOffset.y), to: CGPoint(x: position.x, y: position.y + contentOffset.y - offset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak sectionNode] _ in
                                sectionNode?.removeFromSuperview()
                            })
                        } else {
                            self.removeSectionNodeWithSection(wrappedSection, removeNode: true)
                        }
                    }
                }
            } else {
                for index in self.itemNodes.keys {
                    if !existingItemIndices.contains(index) {
                        self.removeItemNodeWithIndex(index)
                    }
                }
                
                for wrappedSection in self.sectionNodes.keys {
                    if !existingSections.contains(wrappedSection) {
                        self.removeSectionNodeWithSection(wrappedSection)
                    }
                }
                
                for itemNode in removedNodes {
                    itemNode.removeFromSuperview()
                }
            }
        } else {
            for index in self.itemNodes.keys {
                if !existingItemIndices.contains(index) {
                    self.removeItemNodeWithIndex(index)
                }
            }
            
            for wrappedSection in self.sectionNodes.keys {
                if !existingSections.contains(wrappedSection) {
                    self.removeSectionNodeWithSection(wrappedSection)
                }
            }
            
            for itemNode in removedNodes {
                itemNode.removeFromSuperview()
            }
        }
        
        if let visibleItemsUpdated = self.visibleItemsUpdated {
            if presentationLayoutTransition.layout.items.count != 0 {
                let topIndex = presentationLayoutTransition.layout.items.first!.index
                let bottomIndex = presentationLayoutTransition.layout.items.last!.index
                
                var topVisible: (Int, GridListItem) = (topIndex, self.items[topIndex])
                let bottomVisible: (Int, GridListItem) = (bottomIndex, self.items[bottomIndex])
                
                let lowerDisplayBound = presentationLayoutTransition.layout.contentOffset.y
              //  let upperDisplayBound = presentationLayoutTransition.layout.contentOffset.y + self.gridLayout.size.height
                
                for item in presentationLayoutTransition.layout.items {
                    if lowerDisplayBound.isLess(than: item.frame.maxY) {
                        topVisible = (item.index, self.items[item.index])
                        break
                    }
                }
                
                var topSectionVisible: GridSection?
                for section in presentationLayoutTransition.layout.sections {
                    if lowerDisplayBound.isLess(than: section.frame.maxY) {
                        if self.itemLayout.items[topVisible.0].frame.minY > section.frame.minY {
                            topSectionVisible = section.section
                        }
                        break
                    }
                }
                
                visibleItemsUpdated(GridNodeVisibleItems(top: (topIndex, self.items[topIndex]), bottom: (bottomIndex, self.items[bottomIndex]), topVisible: topVisible, bottomVisible: bottomVisible, topSectionVisible: topSectionVisible, count: self.items.count))
            } else {
                visibleItemsUpdated(GridNodeVisibleItems(top: nil, bottom: nil, topVisible: nil, bottomVisible: nil, topSectionVisible: nil, count: self.items.count))
            }
        }
    }
    
    private func addItemNode(index: Int, itemNode: GridItemNode) {
        assert(self.itemNodes[index] == nil)
        self.itemNodes[index] = itemNode
        if itemNode.superview == nil {
            self.documentView?.addSubview(itemNode)
        }
    }
    
    
    private func addSectionNode(section: WrappedGridSection, sectionNode: View) {
        assert(self.sectionNodes[section] == nil)
        self.sectionNodes[section] = sectionNode
        if sectionNode.superview == nil {
            document.addSubview(sectionNode)
        }
    }
    
    private func addStationarySectionNode(_ stationarySection: GridNodePresentationSection, view:View) {
        self.stationarySection = (WrappedGridSection(stationarySection.section),view)
        if view.superview == nil {
            document.addSubview(view)
        }
    }
    
    private func removeStationarySectionNode() {
        stationarySection.1?.removeFromSuperview()
        stationarySection = (nil,nil)
    }
    
    private func removeSectionNodeWithSection(_ section: WrappedGridSection, removeNode: Bool = true) {
        if let sectionNode = self.sectionNodes.removeValue(forKey: section) {
            if removeNode {
                sectionNode.removeFromSuperview()
            }
        }
    }
    

    
    private func removeItemNodeWithIndex(_ index: Int, removeNode: Bool = true) {
        if let itemNode = self.itemNodes.removeValue(forKey: index) {
            if removeNode {
                itemNode.removeFromSuperview()
            }
        }
    }
    
    open override func layout() {
        super.layout()
        gridLayout = GridNodeLayout(size: frame.size, insets: gridLayout.insets, preloadSize: gridLayout.preloadSize, itemSize: gridLayout._itemSize)
        self.itemLayout = generateItemLayout()
        applyPresentaionLayoutTransition(generatePresentationLayoutTransition(), removedNodes: [])
    }
    

    public func removeAllItems() ->Void {
        self.items.removeAll()
        self.itemLayout = generateItemLayout()
        
        applyPresentaionLayoutTransition(generatePresentationLayoutTransition(), removedNodes: [])
    }
    
    public func forEachItemNode(_ f: (GridItemNode) -> Void) {
        for (_, node) in self.itemNodes {
            f(node)
        }
    }
}
