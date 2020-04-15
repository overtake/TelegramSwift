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
    init(_ initialSize: NSSize, stableId: AnyHashable, controller: PeerMediaController, viewType: GeneralViewType) {
        self.controller = controller
        listener = TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { _ in })
        super.init(initialSize, height: initialSize.height, stableId: stableId, viewType: viewType)
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    override var height: CGFloat {
     //   return 10000
        if let temporaryHeight = temporaryHeight {
            return temporaryHeight
        } else {
            return table?.frame.height ?? initialSize.height
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
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PeerMediaBlockRowItem, let table = item.table else {
            return
        }
        
        item.controller.view.frame = NSMakeRect(0, max(0, self.frame.minY - table.documentOffset.y), self.frame.width, table.frame.height)
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
        
        
        item.listener.handler = { [weak self, weak item] _ in
            guard let `self` = self, let table = item?.table, let item = item else {
                return
            }
            scrollInner = table.documentOffset.y >= self.frame.minY
            let mediaTable = (item.controller.genericView.mainView as? TableView)
            if let mediaTable = mediaTable {
                
                let offset = table.documentOffset.y - self.frame.minY
                //let maximum = mediaTable.documentSize.height - mediaTable.frame.height
                let updated = max(0, offset)//min(max(0, offset), maximum)
                if !scrollingInMediaTable, updated != mediaTable.documentOffset.y {
                    mediaTable.clipView.scroll(to: NSMakePoint(0, updated))
                }
                if scrollInner {
                    
                } else {
                    if mediaTable.documentOffset.y > 0 {
                        scrollInner = true
                    }
                }
                NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: mediaTable.clipView)
                
                if item.temporaryHeight != mediaTable.documentSize.height {
                    item.temporaryHeight = mediaTable.documentSize.height
                    table.noteHeightOfRow(item.index, false)
                }
                item.controller.view.frame = NSMakeRect(0, max(0, self.frame.minY - table.documentOffset.y), self.frame.width, table.frame.height)
            }
        }

        item.table?.addScroll(listener: item.listener)
        
        item.table?.hasVerticalScroller = false
        
        item.table?._scrollWillStartLiveScrolling = {
            scrollingInMediaTable = false
        }
        
        item.table?.addSubview(item.controller.view)
        
        item.controller.currentMainView = { [weak item, weak self] mainView, animated, updated in
            if let item = item, animated {
                if item.table?.documentOffset.y == self?.frame.minY {
                    if !updated {
                        (mainView as? TableView)?.scroll(to: .up(true))
                    }
                } else {
                    item.table?.scroll(to: .top(id: item.stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
                }
            }
            
         //   (mainView as? TableView)?.hasVerticalScroller = false
            
            (mainView as? TableView)?.applyExternalScroll = { [weak self, weak item] event in
                guard let `self` = self, let item = item else {
                    return false
                }
                if scrollInner {
                    if event.scrollingDeltaY > 0 {
                        if let tableView = item.controller.genericView.mainView as? TableView, tableView.documentOffset.y <= 0 {
                            scrollInner = false
                            item.table?.clipView.scroll(to: NSMakePoint(0, self.frame.minY))
                            item.table?.scrollWheel(with: event)
                            scrollingInMediaTable = false
                            return true
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
    }
    
}
