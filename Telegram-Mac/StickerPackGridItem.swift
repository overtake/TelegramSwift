//
//  StickerPackGridItem.swift
//  Telegram
//
//  Created by keepcoder on 27/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

final class StickerPackGridItem: GridItem {

    
    var section:GridSection? {
        return nil
    }
    
    let context: AccountContext
    let file: TelegramMediaFile
    let selected: () -> Void
    let send:(TelegramMediaFile, NSView) -> Void
    init(context: AccountContext, file: TelegramMediaFile, send:@escaping(TelegramMediaFile, NSView) -> Void,  selected: @escaping () -> Void) {
        self.context = context
        self.file = file
        self.send = send
        self.selected = selected
        
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode, cachedNode: GridItemNode?) -> GridItemNode {
        if self.file.isAnimatedSticker {
            let node = AnimatedStickerGridItemView(gridNode)
            node.sendFile = { [weak self] file, view in
                self?.send(file, view)
            }
            node.setup(context: self.context, file: self.file)
            node.selected = self.selected
            return node
        } else {
            let node = StickerGridItemView(gridNode)
            node.sendFile = { [weak self] file, view in
                self?.send(file, view)
            }
            node.setup(context: self.context, file: self.file)
            node.selected = self.selected
            return node
        }
    }
    
    func update(node: GridItemNode) {
        
        if let node = node as? StickerGridItemView {
            node.setup(context: self.context, file: self.file)
            node.selected = self.selected
        } else if let node = node as? AnimatedStickerGridItemView {
            node.setup(context: self.context, file: self.file)
            node.selected = self.selected
        }
        
    }
}



final class AnimatedStickerGridItemView: GridItemNode, ModalPreviewRowViewProtocol {
    private var currentState: (AccountContext, TelegramMediaFile, CGSize)?
    
    private let view: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)

    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let currentState = currentState {
            let reference = currentState.1.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: currentState.1.stickerReference!, media: currentState.1) : FileMediaReference.standalone(media: currentState.1)
            return (.file(reference, AnimatedStickerPreviewModalView.self), view)
        }
        return nil
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var sendFile: ((TelegramMediaFile, NSView)->Void)?
    var selected: (() -> Void)?
    
    override init(_ grid:GridNode) {
        super.init(grid)
        
        //backgroundColor = .random
        //layer?.cornerRadius = .cornerRadius
        addSubview(view)
        view.userInteractionEnabled = false
        
        set(handler: { [weak self] (control) in
            if let window = self?.window as? Window, let currentState = self?.currentState, let grid = self?.grid {
                _ = startModalPreviewHandle(grid, window: window, context: currentState.0)
            }
        }, for: .LongMouseDown)
        
        set(handler: { [weak self] _ in
            self?.click()
        }, for: .SingleClick)
    }
    
    private func click() {
        if mouseInside() || view._mouseInside() {
            if let (_, file, _) = currentState {
                 sendFile?(file, self)
            }
        }
    }
    
    override func layout() {
        view.center()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
   
    
    func setup(context: AccountContext, file: TelegramMediaFile) {
        let size = NSMakeSize(60, 60)
        self.currentState = (context, file, size)
        view.update(with: file, size: size, context: context, parent: nil, table: nil, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
    }
    
    
}




final class StickerGridItemView: GridItemNode, ModalPreviewRowViewProtocol {
    private var currentState: (AccountContext, TelegramMediaFile, CGSize)?
    
    
    private let imageView: TransformImageView = TransformImageView()
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let currentState = currentState {
            let reference = currentState.1.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: currentState.1.stickerReference!, media: currentState.1) : FileMediaReference.standalone(media: currentState.1)
            return (.file(reference, StickerPreviewModalView.self), imageView)
        }
        return nil
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var sendFile: ((TelegramMediaFile, NSView)->Void)?
    var selected: (() -> Void)?
    
    override init(_ grid:GridNode) {
        super.init(grid)
        
        //backgroundColor = .random
        //layer?.cornerRadius = .cornerRadius
        addSubview(imageView)
        
        
        set(handler: { [weak self] (control) in
            if let window = self?.window as? Window, let currentState = self?.currentState, let grid = self?.grid {
                _ = startModalPreviewHandle(grid, window: window, context: currentState.0)
            }
        }, for: .LongMouseDown)
        set(handler: { [weak self] _ in
            self?.click()
        }, for: .SingleClick)
    }
    
    private func click() {
        if mouseInside() || imageView._mouseInside() {
            if let (_, file, _) = currentState {
                self.sendFile?(file, self)
            }
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        imageView.center()
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    func setup(context: AccountContext, file: TelegramMediaFile) {
        if let dimensions = file.dimensions?.size {
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(60, 60), boundingSize: NSMakeSize(60, 60), intrinsicInsets: NSEdgeInsets())
            imageView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor))
            imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: file, small: false, scale: backingScaleFactor, fetched: true), cacheImage: { result in
                cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
            })
            
            let imageSize = dimensions.aspectFitted(NSMakeSize(60, 60))
            imageView.set(arguments: arguments)
            
            imageView.setFrameSize(imageSize)
            currentState = (context, file, dimensions)
        }
    }
    
    
}
