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
    let sendResult: (ChatContextResult, NSView) -> Void
    let menuItems: (TelegramMediaFile) -> Signal<[ContextMenuItem], NoError>
    
    init(sendResult: @escaping(ChatContextResult, NSView) -> Void, menuItems: @escaping(TelegramMediaFile) -> Signal<[ContextMenuItem], NoError> = { _ in return .single([]) }) {
        self.sendResult = sendResult
        self.menuItems = menuItems
    }
}

class ContextMediaRowItem: TableRowItem {

    
    let result:InputMediaContextRow
    private let _index:Int64
    let context: AccountContext
    let arguments: ContextMediaArguments
    override var stableId: AnyHashable {
        return Int64(_index)
    }
    
    init(_ initialSize: NSSize, _ result:InputMediaContextRow, _ index:Int64, _ context: AccountContext, _ arguments: ContextMediaArguments) {
        self.result = result
        self.arguments = arguments
        self._index = index
        self.context = context
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
    
    func previewMediaIfPossible() -> Bool {
        if let item = self.item as? ContextMediaRowItem, let table = item.table, let window = window as? Window {
            _ = startModalPreviewHandle(table, window: window, context: item.context)
        }
        return true
    }
    
    override func forceClick(in location: NSPoint) {
        if mouseInside() == true {
            let result = previewMediaIfPossible()
            if !result {
                super.forceClick(in: location)
            }
        } else {
            super.forceClick(in: location)
        }
        
    }
    
    func fileAtPoint(_ point: NSPoint) -> QuickPreviewMedia? {
        guard let item = item as? ContextMediaRowItem else {return nil}
        for i in 0 ..< self.subviews.count {
            if NSPointInRect(point, self.subviews[i].frame) {
                switch item.result.entries[i] {
                case let .gif(data):
                    return .file(data.file, GifPreviewModalView.self)
                case let .sticker(_, file):
                    let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
                    if file.isAnimatedSticker {
                        return .file(reference, AnimatedStickerPreviewModalView.self)
                    } else {
                        return .file(reference, StickerPreviewModalView.self)
                    }
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
                    let signal:Signal<ImageDataTransformation, NoError> =  chatMessageVideo(postbox: item.context.account.postbox, fileReference: data.file, scale: backingScaleFactor)
                    
                    view.set(handler: { [weak item] control in
                        if let item = item {
                            item.arguments.sendResult(item.result.results[i], control)
                        }
                    }, for: .Click)
                    
                    view.update(with: data.file.resourceReference(data.file.media.resource) , size: NSMakeSize(item.result.sizes[i].width, item.height - 2), viewSize: item.result.sizes[i], file: data.file.media, context: item.context, table: item.table, iconSignal: signal)
                    if i != (item.result.entries.count - 1) {
                        let layer = View()
                        layer.frame = NSMakeRect(view.frame.width - 2.0, 0, 2.0, view.frame.height)
                        layer.background = theme.colors.background
                        view.addSubview(layer)
                    }
                    container = view
                case let .sticker(data):
                    if data.file.isAnimatedSticker {
                        let view = ChatMediaAnimatedStickerView(frame: NSZeroRect)
                        let size = NSMakeSize(round(item.result.sizes[i].width), round(item.result.sizes[i].height))
                        view.update(with: data.file, size: size, context: item.context, parent: nil, table: item.table, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
                        view.userInteractionEnabled = false
                        container = view
                    } else {
                        let view = TransformImageView()
                        view.setSignal(chatMessageSticker(postbox: item.context.account.postbox, file: data.file, small: true, scale: backingScaleFactor, fetched: true))
                        let imageSize = item.result.sizes[i].aspectFitted(NSMakeSize(item.height, item.height - 8))
                        view.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets()))
                        
                        view.setFrameSize(imageSize)
                        container = view
                    }
                    
                case let .photo(data):
                    let view = View()
                    let imageView = TransformImageView()
                    imageView.setSignal(chatWebpageSnippetPhoto(account: item.context.account, imageReference: ImageMediaReference.standalone(media: data), scale: backingScaleFactor, small:false))
                    _ = chatMessagePhotoInteractiveFetched(account: item.context.account, imageReference: ImageMediaReference.standalone(media: data)).start()
                    
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
                    item.arguments.sendResult(item.result.results[i], self.subviews[i])
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
