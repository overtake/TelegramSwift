//
//  ContextMediaRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 21/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

final class ContextMediaArguments {
    let sendResult: (ChatContextResult) -> Void
    let menuItems: (TelegramMediaFile) -> Signal<[ContextMenuItem], NoError>
    
    init(sendResult: @escaping(ChatContextResult) -> Void, menuItems: @escaping(TelegramMediaFile) -> Signal<[ContextMenuItem], NoError> = { _ in return .single([]) }) {
        self.sendResult = sendResult
        self.menuItems = menuItems
    }
}

class ContextMediaRowItem: TableRowItem {

    
    let result:InputMediaContextRow
    private let _index:Int64
    let account:Account
    let arguments: ContextMediaArguments
    override var stableId: AnyHashable {
        return Int64(_index)
    }
    
    init(_ initialSize: NSSize, _ result:InputMediaContextRow, _ index:Int64, _ account:Account, _ arguments: ContextMediaArguments) {
        self.result = result
        self.arguments = arguments
        self._index = index
        self.account = account
        dif = 0
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        var height:CGFloat = 120
        for size in result.sizes {
             height = min(height, size.height)
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return ContextMediaRowView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var inset:CGFloat = 0
        var i:Int = 0
        for size in result.sizes {
            if location.x > inset && location.x < inset + size.width {
                switch result.results[i] {
                case let .internalReference(_, _, _, _, _, _, file, _):
                    if let file = file {
                        let items = arguments.menuItems(file)
                        return items
                    }
                default:
                    break
                }
                break
            }
            inset += size.width
            i += 1
        }
        return .single([])
    }
    
}

private var dif:CGFloat = 0

class ContextMediaRowView: TableRowView, ModalPreviewRowViewProtocol {
   
    
    private let stickerFetchedDisposable:MetaDisposable = MetaDisposable()
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    func fileAtPoint(_ point: NSPoint) -> FileMediaReference? {
        guard let item = item as? ContextMediaRowItem else {return nil}
        for i in 0 ..< self.subviews.count {
            if NSPointInRect(point, self.subviews[i].frame) {
                switch item.result.entries[i] {
                case let .gif(data):
                    return data.file
                default:
                    break
                }
            }
        }
        return nil
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        removeAllSubviews()
        if let item = item as? ContextMediaRowItem {
            var inset:CGFloat = 0
            for i in 0 ..< item.result.entries.count {
                let container:NSView
                switch item.result.entries[i] {
                case let .gif(data):
                    let view = GIFContainerView()
                    let signal:Signal<(TransformImageArguments) -> DrawingContext?, NoError> =  chatMessageVideo(postbox: item.account.postbox, fileReference: data.file, scale: backingScaleFactor)
                    
                    view.set(handler: { _ in
                        item.arguments.sendResult(item.result.results[i])
                    }, for: .Click)
                    
                    view.update(with: data.file.resourceReference(data.file.media.resource) , size: NSMakeSize(item.result.sizes[i].width, item.height), viewSize: item.result.sizes[i], file: data.file.media, account: item.account, table: item.table, iconSignal: signal)
                    container = view
                case let .sticker(data):
                    let view = TransformImageView()
                    //TODO
                    let reference = data.file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: data.file.stickerReference!, media: data.file) : FileMediaReference.standalone(media: data.file)
                    view.setSignal(chatMessageSticker(account: item.account, fileReference: reference, type: .small, scale: backingScaleFactor))
                    _ = fileInteractiveFetched(account: item.account, fileReference: reference).start()
                    
                    let imageSize = item.result.sizes[i].aspectFitted(NSMakeSize(item.height, item.height - 8))
                    view.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets()))
                    
                    view.setFrameSize(imageSize)
                    container = view
                case let .photo(data):
                    let view = View()
                    let imageView = TransformImageView()
                    imageView.setSignal(chatWebpageSnippetPhoto(account: item.account, imageReference: ImageMediaReference.standalone(media: data), scale: backingScaleFactor, small:false))
                    _ = chatMessagePhotoInteractiveFetched(account: item.account, imageReference: ImageMediaReference.standalone(media: data)).start()
                    
                    let imageSize = item.result.sizes[i]
                    imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets()))
                    view.layer?.borderWidth = 2.0
                    view.layer?.borderColor = theme.colors.background.cgColor
                    view.setFrameSize(NSMakeSize(imageSize.width, item.height))
                    imageView.setFrameSize(imageSize)
                    imageView.center()
                    view.addSubview(imageView)
                    container = view

                    break
                }
                container.setFrameOrigin(inset, 0)
                container.background = theme.colors.background
                addSubview(container)
                inset += item.result.sizes[i].width
            }
            
            needsLayout = true
        }
    }
    
    
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if let item = item as? ContextMediaRowItem {
            var inset:CGFloat = 0
            var i:Int = 0
            for size in item.result.sizes {
                
                if point.x > inset && point.x < inset + size.width {
                    item.arguments.sendResult(item.result.results[i])
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
    
   
    
    
}
