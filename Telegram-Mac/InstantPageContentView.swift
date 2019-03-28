//
//  InstantPageContentView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Foundation
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit


final class InstantPageContentView : View {
    private let arguments: InstantPageItemArguments
    

    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithViews: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileView] = [:]
    var visibleItemsWithViews: [Int: InstantPageView] = [:]
    
    var currentWebEmbedHeights: [Int : CGFloat] = [:]
    var currentExpandedDetails: [Int : Bool]?
    var currentDetailsItems: [InstantPageDetailsItem] = []
    
    var requestLayoutUpdate: ((Bool) -> Void)?
    
    var currentLayout: InstantPageLayout
    let contentSize: CGSize
    let inOverlayPanel: Bool
    
    private var previousVisibleBounds: CGRect?
    
    init(arguments: InstantPageItemArguments, items: [InstantPageItem], contentSize: CGSize, inOverlayPanel: Bool = false) {
        self.arguments = arguments

        
        self.currentLayout = InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        self.contentSize = contentSize
        self.inOverlayPanel = inOverlayPanel
        
        super.init()
        
        self.updateLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func updateLayout() {
        for (_, tileView) in self.visibleTiles {
            tileView.removeFromSuperview()
        }
        self.visibleTiles.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: contentSize.width)
        
        var currentDetailsItems: [InstantPageDetailsItem] = []
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int : Int] = [:]
        
        var expandedDetails: [Int : Bool] = [:]
        
        var detailsIndex = -1
        for item in self.currentLayout.items {
            if item.wantsView {
                currentLayoutItemsWithViews.append(item)
                if let group = item.distanceThresholdGroup() {
                    let count: Int
                    if let currentCount = distanceThresholdGroupCount[Int(group)] {
                        count = currentCount
                    } else {
                        count = 0
                    }
                    distanceThresholdGroupCount[Int(group)] = count + 1
                }
                if let detailsItem = item as? InstantPageDetailsItem {
                    detailsIndex += 1
                    expandedDetails[detailsIndex] = detailsItem.initiallyExpanded
                    currentDetailsItems.append(detailsItem)
                }
            }
        }
        
        if self.currentExpandedDetails == nil {
            self.currentExpandedDetails = expandedDetails
        }
        
        self.currentLayoutTiles = currentLayoutTiles
        self.currentLayoutItemsWithViews = currentLayoutItemsWithViews
        self.currentDetailsItems = currentDetailsItems
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
    }
    
    var effectiveContentSize: CGSize {
        var contentSize = self.contentSize
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            contentSize.height += -item.frame.height + (expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight)
        }
        return contentSize
    }
    
    func isExpandedItem(_ item: InstantPageDetailsItem) -> Bool {
        if let index = self.currentDetailsItems.firstIndex(where: {$0 === item}) {
            return self.currentExpandedDetails?[index] ?? item.initiallyExpanded
        } else {
            return false
        }
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        self.previousVisibleBounds = visibleBounds
        
        CATransaction.begin()
        defer {
            CATransaction.commit()
        }
        
        var topView: View?
        let topTileView = topView
        for view in self.subviews.reversed() {
            if let view = view as? InstantPageTileView {
                topView = view
                break
            }
        }
        
        var collapseOffset: CGFloat = 0.0
        
        var itemIndex = -1
        var embedIndex = -1
        var detailsIndex = -1
        
       
        for item in self.currentLayoutItemsWithViews {
            itemIndex += 1
            if item is InstantPageWebEmbedItem {
                embedIndex += 1
            }
            if item is InstantPageDetailsItem {
                detailsIndex += 1
            }
            
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }
            
            var itemFrame = item.frame.offsetBy(dx: 0.0, dy: -collapseOffset)
            var thresholdedItemFrame = itemFrame
            thresholdedItemFrame.origin.y -= itemThreshold
            thresholdedItemFrame.size.height += itemThreshold * 2.0
            
            if let detailsItem = item as? InstantPageDetailsItem, let expanded = self.currentExpandedDetails?[detailsIndex] {
                let height = expanded ? self.effectiveSizeForDetails(detailsItem).height : detailsItem.titleHeight
                collapseOffset += itemFrame.height - height
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: height))
            }
            
            if visibleBounds.intersects(thresholdedItemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemView = self.visibleItemsWithViews[itemIndex]
                if let currentItemView = itemView {
                    if !item.matchesView(currentItemView) {
                        (currentItemView as! NSView).removeFromSuperview()
                        self.visibleItemsWithViews.removeValue(forKey: itemIndex)
                        itemView = nil
                    }
                }
                
                if itemView == nil {
                    let itemIndex = itemIndex
                    let detailsIndex = detailsIndex
                    
                    let arguments = InstantPageItemArguments(context: self.arguments.context, theme: self.arguments.theme, openMedia: self.arguments.openMedia, openPeer: self.arguments.openPeer, openUrl: self.arguments.openUrl, updateWebEmbedHeight: { _ in }, updateDetailsExpanded: { [weak self] expanded  in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }, isExpandedItem: { [weak self] item in
                        return self?.isExpandedItem(item) ?? false
                    }, effectiveRectForItem: { [weak self] item in
                        return self?.effectiveFrameForItem(item) ?? item.frame
                    })
                    
                    if let newView = item.view(arguments: arguments, currentExpandedDetails: self.currentExpandedDetails) {
                        newView.frame = itemFrame
                        self.addSubview(newView)
                        topView = newView as? View
                        self.visibleItemsWithViews[itemIndex] = newView
                        itemView = newView
                        
                        if let itemView = itemView as? InstantPageDetailsView {
                            itemView.requestLayoutUpdate = { [weak self] animated in
                                self?.requestLayoutUpdate?(animated)
                            }
                        }
                    }
                } else {
                    if (itemView as! NSView).frame != itemFrame {
                        (itemView as! NSView)._change(size: itemFrame.size, animated: animated)
                        (itemView as! NSView)._change(pos: itemFrame.origin, animated: animated)
                    } else {
                        (itemView as! NSView).needsDisplay = true
                    }
                }
                
                if let itemView = itemView as? InstantPageDetailsView {
                    itemView.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -itemView.frame.minX, dy: -itemView.frame.minY), animated: animated)
                }
            }
        }
        
        topView = topTileView
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            
            let tileFrame = effectiveFrameForTile(tile)
            var tileVisibleFrame = tileFrame
            tileVisibleFrame.origin.y -= 400.0
            tileVisibleFrame.size.height += 400.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if self.visibleTiles[tileIndex] == nil {
                    let tileView = InstantPageTileView(tile: tile, backgroundColor: .clear)
                    tileView.frame = tileFrame
                    self.addSubview(tileView)
                    topView = tileView
                    self.visibleTiles[tileIndex] = tileView
                } else {
                    if visibleTiles[tileIndex]!.frame != tileFrame {
                        
                        let view = self.visibleTiles[tileIndex]!
                        view._change(pos: tileFrame.origin, animated: animated)
                        view._change(size: tileFrame.size, animated: animated)
                    }
                }
            }
        }
        
        var removeTileIndices: [Int] = []
        for (index, tileView) in self.visibleTiles {
            if !visibleTileIndices.contains(index) {
                removeTileIndices.append(index)
                tileView.removeFromSuperview()
            }
        }
        for index in removeTileIndices {
            self.visibleTiles.removeValue(forKey: index)
        }
        
        var removeItemIndices: [Int] = []
        for (index, itemView) in self.visibleItemsWithViews {
            if !visibleItemIndices.contains(index) {
                removeItemIndices.append(index)
                (itemView as! NSView).removeFromSuperview()
            } else {
                var itemFrame = (itemView as! NSView).frame
                let itemThreshold: CGFloat = 200.0
                itemFrame.origin.y -= itemThreshold
                itemFrame.size.height += itemThreshold * 2.0
                itemView.updateIsVisible(visibleBounds.intersects(itemFrame))
            }
        }
        for index in removeItemIndices {
            self.visibleItemsWithViews.removeValue(forKey: index)
        }
        
        let subviews = self.subviews.sorted(by: {$0.frame.minY < $1.frame.minY})
        self.subviews = subviews
        self.needsLayout = true
    }
    
    private func updateWebEmbedHeight(_ index: Int, _ height: CGFloat) {
        //        let currentHeight = self.currentWebEmbedHeights[index]
        //        if height != currentHeight {
        //            if let currentHeight = currentHeight, currentHeight > height {
        //                return
        //            }
        //            self.currentWebEmbedHeights[index] = height
        //
        //            let signal: Signal<Void, NoError> = (.complete() |> delay(0.08, queue: Queue.mainQueue()))
        //            self.updateLayoutDisposable.set(signal.start(completed: { [weak self] in
        //                if let strongSelf = self {
        //                    strongSelf.updateLayout()
        //                    strongSelf.updateVisibleItems()
        //                }
        //            }))
        //        }
    }
    
    func updateDetailsExpanded(_ index: Int, _ expanded: Bool, animated: Bool = true, requestLayout: Bool = true) {
        if var currentExpandedDetails = self.currentExpandedDetails {
            currentExpandedDetails[index] = expanded
            self.currentExpandedDetails = currentExpandedDetails
        }
        self.requestLayoutUpdate?(animated)
    }
    

    
    func scrollableContentOffset(item: InstantPageScrollableItem) -> CGPoint {
        var contentOffset = CGPoint()
        for (_, itemView) in self.visibleItemsWithViews {
            if let itemView = itemView as? InstantPageScrollableView, itemView.item === item {
                contentOffset = itemView.contentOffset
                break
            }
        }
        return contentOffset
    }
    
    func viewForDetailsItem(_ item: InstantPageDetailsItem) -> InstantPageDetailsView? {
        for (_, itemView) in self.visibleItemsWithViews {
            if let detailsView = itemView as? InstantPageDetailsView, detailsView.item === item {
                return detailsView
            }
        }
        return nil
    }
    
    private func effectiveSizeForDetails(_ item: InstantPageDetailsItem) -> CGSize {
        if let view = viewForDetailsItem(item) {
            return CGSize(width: item.frame.width, height: view.effectiveContentSize.height + item.titleHeight)
        } else {
            return item.frame.size
        }
    }
    
    private func effectiveFrameForTile(_ tile: InstantPageTile) -> CGRect {
        let layoutOrigin = tile.frame.origin
        var origin = layoutOrigin
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        return CGRect(origin: origin, size: tile.frame.size)
    }
    
    func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        let layoutOrigin = item.frame.origin
        var origin = layoutOrigin
        
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        
        if let item = item as? InstantPageDetailsItem {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: height))
        } else {
            return CGRect(origin: origin, size: item.frame.size)
        }
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        for item in self.currentLayout.items {
            let itemFrame = self.effectiveFrameForItem(item)
            if itemFrame.contains(location) {
                if let item = item as? InstantPageTextItem, item.selectable {
                    return (item, CGPoint(x: itemFrame.minX - item.frame.minX, y: itemFrame.minY - item.frame.minY))
                } else if let item = item as? InstantPageScrollableItem {
                    let contentOffset = scrollableContentOffset(item: item)
                    if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY)) {
                        return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x - contentOffset.x, dy: parentOffset.y))
                    }
                } else if let item = item as? InstantPageDetailsItem {
                    for (_, itemView) in self.visibleItemsWithViews {
                        if let itemView = itemView as? InstantPageDetailsView, itemView.item === item {
                            if let (textItem, parentOffset) = itemView.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX, dy: -itemFrame.minY)) {
                                return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
}
