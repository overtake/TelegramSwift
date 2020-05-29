//
//  ContextMediaRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 21/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

final class ContextMediaArguments {
    let sendResult: (ChatContextResult, NSView) -> Void
    let menuItems: (TelegramMediaFile, NSView) -> Signal<[ContextMenuItem], NoError>
    let openMessage: (Message) -> Void
    let messageMenuItems: (Message, NSView) -> Signal<[ContextMenuItem], NoError>

    init(sendResult: @escaping(ChatContextResult, NSView) -> Void = { _, _ in }, menuItems: @escaping(TelegramMediaFile, NSView) -> Signal<[ContextMenuItem], NoError> = { _, _ in return .single([]) }, openMessage: @escaping(Message) -> Void = { _ in }, messageMenuItems:@escaping (Message, NSView) -> Signal<[ContextMenuItem], NoError> = { _, _ in return .single([]) }) {
        self.sendResult = sendResult
        self.menuItems = menuItems
        self.openMessage = openMessage
        self.messageMenuItems = messageMenuItems
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
    
    func contains(_ messageId: MessageId) -> Bool {
        if self.result.messages.contains(where: { $0.id == messageId }) {
            return true
        }
        return false
    }
    
    override func viewClass() -> AnyClass {
        return ContextMediaRowView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var inset:CGFloat = 0
        var i:Int = 0
        for size in result.sizes {
            if location.x > inset && location.x < inset + size.width {
                if !result.messages.isEmpty {
                    if let view = self.view {
                        let items = arguments.messageMenuItems(result.messages[i], view.subviews[i])
                        return items
                    }
                } else {
                    switch result.results[i] {
                    case let .internalReference(values):
                        if let file = values.file, let view = self.view {
                            let items = arguments.menuItems(file, view.subviews[i])
                            return items
                        }
                    default:
                        break
                    }
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
    private let longDisposable = MetaDisposable()
    deinit {
        stickerFetchedDisposable.dispose()
        longDisposable.dispose()
    }
    
    func previewMediaIfPossible() -> Bool {
        if let item = self.item as? ContextMediaRowItem, let table = item.table, let window = window as? Window {
            _ = startModalPreviewHandle(table, window: window, context: item.context)
        }
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let signal = Signal<NoValue, NoError>.complete() |> delay(0.2, queue: .mainQueue())
        
        let downIndex = self.index(at: convert(event.locationInWindow, to: nil))
        
        longDisposable.set(signal.start(completed: { [weak self] in
            guard let `self` = self, let window = self.window else {
                return
            }
            let nextIndex = self.index(at: self.convert(window.mouseLocationOutsideOfEventStream, to: nil))
            if nextIndex == downIndex {
                _ = self.previewMediaIfPossible()
            }
        }))
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
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        guard let item = item as? ContextMediaRowItem else {return nil}
        for i in 0 ..< self.subviews.count {
            if NSPointInRect(point, self.subviews[i].frame) {
                switch item.result.entries[i] {
                case let .gif(data):
                    return (.file(data.file, GifPreviewModalView.self), self.subviews[i])
                case let .sticker(_, file):
                    let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
                    if file.isAnimatedSticker {
                        return (.file(reference, AnimatedStickerPreviewModalView.self), self.subviews[i])
                    } else {
                        return (.file(reference, StickerPreviewModalView.self), self.subviews[i])
                    }
                default:
                    break
                }
            }
        }
        return nil
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        if let innerId = innerId.base as? MessageId {
            let view = self.subviews.first(where: {
                ($0 as? GIFContainerView)?.associatedMessageId == innerId
            })
            return view ?? self
        }
        return self
    }
    

    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)

        var subviews = self.subviews

        self.removeAllSubviews()
        
        if let item = item as? ContextMediaRowItem {
            var inset:CGFloat = 0
            for i in 0 ..< item.result.entries.count {
                let container:NSView
                switch item.result.entries[i] {
                case let .gif(data):
                    let view: GIFContainerView
                    let index = subviews.firstIndex(where: { $0 is GIFContainerView })
                    if let index = index {
                        view = subviews.remove(at: index) as! GIFContainerView
                        inner: for view in view.subviews {
                            if view.identifier == NSUserInterfaceItemIdentifier("gif-separator") {
                                view.removeFromSuperview()
                                break inner
                            }
                        }
                    } else {
                        view = GIFContainerView()
                    }
                    
                    var effectiveFile = data.file
                    
//                    let signal:Signal<ImageDataTransformation, NoError>
//                    if let preview = data.file.media.videoThumbnails.first {
//                        let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: arc4random64()), partialReference: nil, resource: preview.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [])
//
//                        switch data.file {
//                        case let .message(message, _):
//                            effectiveFile = FileMediaReference.message(message: message, media: file)
//                        case .standalone:
//                            effectiveFile = FileMediaReference.standalone(media: file)
//                        case .savedGif:
//                            effectiveFile = FileMediaReference.savedGif(media: file)
//                        case let .stickerPack(stickerPack, _):
//                            effectiveFile = FileMediaReference.stickerPack(stickerPack: stickerPack, media: file)
//                        case let .webPage(webPage, _):
//                            effectiveFile = FileMediaReference.webPage(webPage: webPage, media: file)
//                        }
//                    }
                    let signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: effectiveFile, scale: backingScaleFactor)

                    
//                    signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: data.file, scale: backingScaleFactor)

                    
                    if !item.result.messages.isEmpty {
                        view.associatedMessageId = item.result.messages[i].id
                    }
                    
                    view.update(with: effectiveFile, size: NSMakeSize(item.result.sizes[i].width, item.height - 2), viewSize: item.result.sizes[i], context: item.context, table: item.table, iconSignal: signal)
                    if i != (item.result.entries.count - 1) {
                        let layer = View()
                        layer.identifier = NSUserInterfaceItemIdentifier("gif-separator")
                        layer.frame = NSMakeRect(view.frame.width - 2.0, 0, 2.0, view.frame.height)
                        layer.background = theme.colors.background
                        view.addSubview(layer)
                    }
                    view.userInteractionEnabled = false
                    container = view
                case let .sticker(data):
                    if data.file.isAnimatedSticker {
                        let view: MediaAnimatedStickerView
                        let index = subviews.firstIndex(where: { $0 is MediaAnimatedStickerView})
                        if let index = index {
                            view = subviews.remove(at: index) as! MediaAnimatedStickerView
                        } else {
                            view = MediaAnimatedStickerView(frame: NSZeroRect)
                        }
                        let size = NSMakeSize(round(item.result.sizes[i].width), round(item.result.sizes[i].height))
                        view.update(with: data.file, size: size, context: item.context, parent: nil, table: item.table, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
                        view.userInteractionEnabled = false
                        
                        container = view
                    } else {
                        let view: TransformImageView
                        let index = subviews.firstIndex(where: { $0 is TransformImageView})
                        if let index = index {
                            view = subviews.remove(at: index) as! TransformImageView
                        } else {
                            view = TransformImageView()
                        }
                        
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
                }
                
                container.setFrameOrigin(inset, 0)
                container.background = theme.colors.background
                addSubview(container)
                inset += item.result.sizes[i].width
            }
            
            needsLayout = true
        }
    }
    
    func index(at point: NSPoint) -> Int? {
        if let _ = item as? ContextMediaRowItem {
            for (i, subview) in self.subviews.enumerated() {
                if NSPointInRect(point, subview.frame) {
                    return i
                }
            }
        }
        return nil
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        longDisposable.set(nil)
        
        if let item = item as? ContextMediaRowItem, event.clickCount == 1  {
            let point = convert(event.locationInWindow, from: nil)
            if let index = self.index(at: point) {
                if !item.result.messages.isEmpty {
                    item.arguments.openMessage(item.result.messages[index])
                } else {
                    item.arguments.sendResult(item.result.results[index], self.subviews[index])
                }
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
