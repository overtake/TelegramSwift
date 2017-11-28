//
//  RecentGIFRowItem.swift
//  Telegram
//
//  Created by keepcoder on 24/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

class RecentGIFRowItem: TableRowItem {
    fileprivate let entry:RecentGifRowEntry
    fileprivate let row:RecentGifRow
    fileprivate let account:Account
    fileprivate let arguments:RecentGifsArguments
    init(_ initialSize: NSSize, account:Account, entry:RecentGifRowEntry, arguments:RecentGifsArguments) {
        self.entry = entry
        self.account = account
        self.arguments = arguments
        switch entry {
        case let .gif(index: _, row: r):
            self.row = r
        }
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    
    
    override var height: CGFloat {
        var height:CGFloat = 120
        for size in row.sizes {
            height = min(height, size.height)
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return RecentGIFRowView.self
    }
    
}


private var dif:CGFloat = 0

class RecentGIFRowView: TableRowView {
    private let stickerFetchedDisposable:MetaDisposable = MetaDisposable()
    
    deinit {
        stickerFetchedDisposable.dispose()
        removeAllSubviews()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        removeAllSubviews()
        if let item = item as? RecentGIFRowItem {
            var inset:CGFloat = 0
            for i in 0 ..< item.row.entries.count {
                
                let view = GIFContainerView()
                
                view.playerInset = NSEdgeInsets(left: i == 0 ? 2 : 1, right: i == item.row.entries.count - 1 ? 2 : 1, top: i == 0 ? 2 : 1, bottom: i == item.row.entries.count - 1 ? 2 : 1)
                
                let signal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                signal = chatWebpageSnippetPhoto(account: item.account, photo: TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: item.row.results[i].previewRepresentations, reference: nil), scale: backingScaleFactor, small:true)

                
                view.update(with: item.row.results[i].resource, size: NSMakeSize(item.row.sizes[i].width, item.height), viewSize:  item.row.sizes[i] , account: item.account, table: item.table, iconSignal: signal)

                
                addSubview(view)
                view.setFrameOrigin(inset, 0)
                inset += item.row.sizes[i].width
            }
            
            needsLayout = true
        }
    }
    
    
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if let item = item as? RecentGIFRowItem {
            var inset:CGFloat = 0
            var i:Int = 0
            for size in item.row.sizes {
                
                if point.x > inset && point.x < inset + size.width {
                    item.arguments.sendGif(item.row.results[i])
                    break
                }
                inset += size.width
                i += 1
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? ContextMediaRowItem  {
            if item.result.isFilled(for: frame.width) {
                let drawn = subviews.reduce(0, { (acc, view) -> CGFloat in
                    return acc + view.frame.width
                })
                if drawn < frame.width {
                    dif = (frame.width - drawn) / CGFloat(subviews.count + 1)
                    var inset:CGFloat = dif
                    for subview in subviews {
                        subview.setFrameOrigin(inset, 0)
                        inset += (dif + subview.frame.width)
                    }
                }
            } else {
                var inset:CGFloat = dif
                for subview in subviews {
                    subview.setFrameOrigin(inset, 0)
                    inset += (dif + subview.frame.width)
                }
            }
        }
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(ContextMenuItem(tr(.contextRecentGifRemove), handler: { [weak self] in
            if let item = self?.item as? RecentGIFRowItem, let point = self?.convert(mainWindow.mouseLocationOutsideOfEventStream, from: nil) {
                var inset:CGFloat = 0
                var i:Int = 0
                for size in item.row.sizes {
                    
                    if point.x > inset && point.x < inset + size.width {
                        if let id = item.row.results[i].id {
                            _ = removeSavedGif(postbox: item.account.postbox, mediaId: id).start()
                        }
                        break
                    }
                    inset += size.width
                    i += 1
                }
            }
        }))
        
        return menu
    }
    
}
