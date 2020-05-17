//
//  PeerMediaBlockRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import CoreGraphics

class PeerMediaBlockRowItem: GeneralRowItem {
    
    fileprivate var temporaryHeight: CGFloat?
    fileprivate let listener: TableScrollListener
    fileprivate let controller: PeerMediaController
    fileprivate let isMediaVisible: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, controller: PeerMediaController, isVisible: Bool, viewType: GeneralViewType) {
        self.controller = controller
        self.isMediaVisible = isVisible
        self.listener = TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { _ in })
        super.init(initialSize, height: initialSize.height, stableId: stableId, viewType: viewType)
    }
    
    deinit {
        if self.controller.isLoaded(), let table = self.table {
//            let view = self.controller.genericView
//            view.removeFromSuperview()
            
            if controller.frame.minY == 0 {
                table.scroll(to: .up(true))
                if self.controller.genericView.superview != nil {
                    controller.viewWillDisappear(true)
                    self.controller.genericView.removeFromSuperview()
                    controller.viewDidDisappear(true)
                }
            }
        }
        
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    override var height: CGFloat {
     //   return 10000
        
        if !isMediaVisible {
            return 1
        } else {
            if let temporaryHeight = temporaryHeight {
                return temporaryHeight
            } else {
                return table?.frame.height ?? initialSize.height
            }
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaBlockRowView.self
    }
}


private final class PeerMediaBlockRowView : TableRowView {
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    private func updateOrigin() {
        guard let item = item as? PeerMediaBlockRowItem, let table = item.table else {
            return
        }
        item.controller.view.frame = NSMakeRect(0, max(0, self.frame.minY - table.documentOffset.y), self.frame.width, table.frame.height)
    }
    
    override func layout() {
        super.layout()
        
        self.updateOrigin()
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        self.updateOrigin()
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview() 
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard let item = item as? PeerMediaBlockRowItem else {
            super.scrollWheel(with: event)
            return
        }
        item.controller.view.enclosingScrollView?.scrollWheel(with: event)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerMediaBlockRowItem else {
            return
        }
        item.controller.bar = .init(height: 0)
        item.controller._frameRect = bounds
        
        var scrollInner: Bool = false
        
        var scrollingInMediaTable: Bool = false
        
        
        if item.isMediaVisible {
            item.listener.handler = { [weak self, weak item] _ in
                guard let `self` = self, let table = item?.table, let item = item else {
                    return
                }
                scrollInner = table.documentOffset.y >= self.frame.minY
                let mediaTable = item.controller.genericView.mainTable
                if let mediaTable = mediaTable {
                    
                    let offset = table.documentOffset.y - self.frame.minY
                    var updated = max(0, offset)
                    if mediaTable.documentSize.height <= table.frame.height, updated > 0 {
                        updated = max(updated - 30, 0)
                    }
                    if !scrollingInMediaTable, updated != mediaTable.documentOffset.y {
                        mediaTable.clipView.scroll(to: NSMakePoint(0, updated))
                        mediaTable.reflectScrolledClipView(mediaTable.clipView)
                    }
                    if scrollInner {
                        
                    } else {
                        if mediaTable.documentOffset.y > 0 {
                            scrollInner = true
                        }
                    }
                    NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: mediaTable.clipView)
                    
                    if item.temporaryHeight != mediaTable.documentSize.height {
                        item.temporaryHeight = max(mediaTable.documentSize.height, table.frame.height)
                        table.noteHeightOfRow(item.index, false)
                    }
                    
                    let previousY = item.controller.view.frame.minY
                    
                    item.controller.view.frame = NSMakeRect(0, max(0, self.frame.minY - table.documentOffset.y), self.frame.width, table.frame.height)
                    
                    let currentY = item.controller.view.frame.minY
                    if previousY != currentY {
                        if currentY == 0, previousY != 0 {
                            item.controller.viewWillAppear(true)
                            item.controller.viewDidAppear(true)
                        } else if previousY == 0 {
                            item.controller.viewWillDisappear(true)
                            item.controller.viewDidDisappear(true)
                        }
                    }
                }
            }
            
            item.table?.addScroll(listener: item.listener)
            
            item.table?.hasVerticalScroller = false
            
            item.table?._scrollWillStartLiveScrolling = {
                scrollingInMediaTable = false
            }
        } else {
            needsLayout = true
        }
        
        if item.controller.view.superview != item.table {
            item.controller.view.removeFromSuperview()
            item.table?.addSubview(item.controller.view)
        }
        if let table = item.table {
            item.controller.genericView.change(pos: NSMakePoint(0, max(0, table.rectOf(item: item).minY - table.documentOffset.y)), animated: animated)
        }
        
        if item.isMediaVisible {
            item.controller.genericView.isHidden = false
        }
        
        item.controller.genericView.change(opacity: item.isMediaVisible ? 1 : 0, animated: animated, completion: { [weak item] _ in
            guard let item = item else {
                return
            }
            item.controller.genericView.isHidden = !item.isMediaVisible
        })
        
        if item.isMediaVisible {
            item.controller.currentMainTableView = { [weak item, weak self] mainTable, animated, updated in
                if let item = item, animated {
                    if item.table?.documentOffset.y == self?.frame.minY {
                        if !updated {
                            mainTable?.scroll(to: .up(true))
                        }
                    } else if updated {
                        item.table?.scroll(to: .top(id: item.stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
                    }
                }
                
                mainTable?.applyExternalScroll = { [weak self, weak item] event in
                    guard let `self` = self, let item = item else {
                        return false
                    }
                    if scrollInner {
                        if event.scrollingDeltaY > 0 {
                            if let tableView = item.controller.genericView.mainTable, tableView.documentOffset.y <= 0 {
                                if !item.controller.unableToHide {
                                    scrollInner = false
                                    item.table?.clipView.scroll(to: NSMakePoint(0, self.frame.minY))
                                    item.table?.scrollWheel(with: event)
                                    scrollingInMediaTable = false
                                    return true
                                }
                                
                            }
                        }
                        scrollingInMediaTable = true
                        return false
                    } else {
                        scrollingInMediaTable = false
                        item.table?.scrollWheel(with: event)
                        return true
                    }
                }
            }
        } else {
            item.controller.currentMainTableView = nil
        }
    }

    deinit {
    }
}
