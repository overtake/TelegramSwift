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
import TelegramMedia
import SwiftSignalKit
import Postbox

final class ContextMediaArguments {
    let sendResult: (ChatContextResultCollection?, ChatContextResult, NSView) -> Void
    let menuItems: (TelegramMediaFile, NSView) -> Signal<[ContextMenuItem], NoError>
    let openMessage: (Message) -> Void
    let messageMenuItems: (Message, NSView) -> Signal<[ContextMenuItem], NoError>

    init(sendResult: @escaping(ChatContextResultCollection?, ChatContextResult, NSView) -> Void = { _, _, _ in }, menuItems: @escaping(TelegramMediaFile, NSView) -> Signal<[ContextMenuItem], NoError> = { _, _ in return .single([]) }, openMessage: @escaping(Message) -> Void = { _ in }, messageMenuItems:@escaping (Message, NSView) -> Signal<[ContextMenuItem], NoError> = { _, _ in return .single([]) }) {
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
    let collection: ChatContextResultCollection?
    private let _stableId: AnyHashable?
    override var stableId: AnyHashable {
        if let _stableId = _stableId {
            return _stableId
        } else {
            return _index
        }
    }
    
    init(_ initialSize: NSSize, _ result:InputMediaContextRow, _ index:Int64, _ context: AccountContext, _ arguments: ContextMediaArguments, collection: ChatContextResultCollection? = nil, stableId: AnyHashable? = nil) {
        self.result = result
        self.arguments = arguments
        self._index = index
        self.context = context
        self.collection = collection
        self._stableId = stableId
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
            startModalPreviewHandle(table, window: window, context: item.context)
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
                case let .gif(_, file):
                    return (.file(file, GifPreviewModalView.self), self.subviews[i])
                case let .sticker(_, file):
                    let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
                    if file.isAnimatedSticker || file.isWebm {
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
    
    override var backdorColor: NSColor {
        return .clear
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
                case let .gif(_, file):
                    let view: GIFContainerView
                    let index = subviews.firstIndex(where: { $0 is GIFContainerView })
                    if let index = index {
                        view = subviews.remove(at: index) as! GIFContainerView
                    } else {
                        view = GIFContainerView()
                    }
                    
                    var effectiveFile = file
                    
                    if let preview = file.media.videoThumbnails.first {
                        
                        let file = effectiveFile.media.withUpdatedResource(preview.resource)

                        switch effectiveFile {
                        case let .message(message, _):
                            effectiveFile = FileMediaReference.message(message: message, media: file)
                        case .standalone:
                            effectiveFile = FileMediaReference.standalone(media: file)
                        case .savedGif:
                            effectiveFile = FileMediaReference.savedGif(media: file)
                        case let .stickerPack(stickerPack, _):
                            effectiveFile = FileMediaReference.stickerPack(stickerPack: stickerPack, media: file)
                        case let .webPage(webPage, _):
                            effectiveFile = FileMediaReference.webPage(webPage: webPage, media: file)
                        case let .avatarList(peer: reference, media: media):
                            effectiveFile = FileMediaReference.avatarList(peer: reference, media: media)
                        case let .attachBot(peer, media):
                            effectiveFile = FileMediaReference.attachBot(peer: peer, media: media)
                        case let .customEmoji(media):
                            effectiveFile = FileMediaReference.customEmoji(media: media)
                        case let .story(peer, id, _):
                            effectiveFile = FileMediaReference.story(peer: peer, id: id, media: file)
                        }
                        
                    }
                    let signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: effectiveFile, scale: backingScaleFactor)
                    

                    view.update(with: effectiveFile, size: NSMakeSize(item.result.sizes[i].width, item.height), viewSize: item.result.sizes[i], context: item.context, table: item.table, iconSignal: signal)
                    
                    view.userInteractionEnabled = false
                    container = view
                case let .sticker(_, file):
                    if file.isAnimatedSticker {
                        let view: MediaAnimatedStickerView
                        let index = subviews.firstIndex(where: { $0 is MediaAnimatedStickerView})
                        if let index = index {
                            view = subviews.remove(at: index) as! MediaAnimatedStickerView
                        } else {
                            view = MediaAnimatedStickerView(frame: NSZeroRect)
                        }
                        view.backgroundColor = .clear
                        let size = NSMakeSize(round(item.result.sizes[i].width), round(item.result.sizes[i].height))
                        view.update(with: file, size: size, context: item.context, parent: nil, table: item.table, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
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
                        
                        view.setSignal(chatMessageSticker(postbox: item.context.account.postbox, file: stickerPackFileReference(file), small: true, scale: backingScaleFactor, fetched: true))
                        let imageSize = item.result.sizes[i].aspectFitted(NSMakeSize(item.height, item.height - 8))
                        view.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets()))
                        
                        view.setFrameSize(imageSize)
                        container = view
                    }
                    
                case let .photo(data):
                    let view: TransformImageView
                    let index = subviews.firstIndex(where: { $0 is TransformImageView})
                    if let index = index {
                        view = subviews.remove(at: index) as! TransformImageView
                    } else {
                        view = TransformImageView()
                    }
                    let imageSize = item.result.sizes[i]
                    let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: data.representationForDisplayAtSize(.init(imageSize))?.dimensions.size ?? imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
                    
                    view.setSignal(signal: cachedMedia(media: data, arguments: arguments, scale: backingScaleFactor), clearInstantly: true)

                    if !view.isFullyLoaded {
                        view.setSignal(chatWebpageSnippetPhoto(account: item.context.account, imageReference: ImageMediaReference.standalone(media: data), scale: backingScaleFactor, small:false), clearInstantly: true, cacheImage: { result in
                            cacheMedia(result, media: data, arguments: arguments, scale: System.backingScale)
                        })
                    }
                    
                    
                    _ = chatMessagePhotoInteractiveFetched(account: item.context.account, imageReference: ImageMediaReference.standalone(media: data)).start()
                    
                    view.set(arguments: arguments)
                    view.setFrameSize(imageSize)
                    view.center()
                    container = view
                }
                
                container.setFrameOrigin(inset, 0)
                container.background = .clear
                addSubview(container)
                inset += item.result.sizes[i].width
            }
            assert(self.subviews.count == item.result.entries.count)
//            NSLog("entries: \(item.result.entries.count), rowIndex: \(item.index)")
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
                    item.arguments.sendResult(item.collection, item.result.results[index], self.subviews[index])
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let drawn = subviews.reduce(0, { (acc, view) -> CGFloat in
            return acc + view.frame.width
        })
        if drawn < frame.width {
            dif = 2
            var inset:CGFloat = dif
            for subview in subviews {
                subview.setFrameOrigin(inset, 0)
                subview.frame = CGRect(origin: CGPoint(x: inset, y: 0), size: subview.frame.size).insetBy(dx: 1, dy: 1)
                inset += subview.frame.width + dif
            }
        }
    }
    
   
    
    
}
