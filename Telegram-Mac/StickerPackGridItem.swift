//
//  StickerPackGridItem.swift
//  Telegram
//
//  Created by keepcoder on 27/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

final class StickerPackGridItem: GridItem {

    
    var section:GridSection? {
        return nil
    }
    
    let context: AccountContext
    let file: TelegramMediaFile
    let selected: () -> Void
    let send:(TelegramMediaFile) -> Void
    init(context: AccountContext, file: TelegramMediaFile, send:@escaping(TelegramMediaFile) -> Void,  selected: @escaping () -> Void) {
        self.context = context
        self.file = file
        self.send = send
        self.selected = selected
        
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode, cachedNode: GridItemNode?) -> GridItemNode {
        if self.file.isAnimatedSticker {
            let node = AnimatedStickerGridItemView(gridNode)
            node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
                self?.send(file)
                }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
            node.setup(context: self.context, file: self.file, packInfo: nil)
            node.selected = self.selected
            return node
        } else {
            let node = StickerGridItemView(gridNode)
            node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
                self?.send(file)
                }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
            node.setup(context: self.context, file: self.file, packInfo: nil)
            node.selected = self.selected
            return node
        }
    }
    
    func update(node: GridItemNode) {
        
        if let node = node as? StickerGridItemView {
            node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
                self?.send(file)
                }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
            
            node.setup(context: self.context, file: self.file, packInfo: nil)
            node.selected = self.selected
        } else if let node = node as? AnimatedStickerGridItemView {
            node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
                self?.send(file)
            }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
            
            node.setup(context: self.context, file: self.file, packInfo: nil)
            node.selected = self.selected
        }
        
    }
}



final class AnimatedStickerGridItemView: GridItemNode, ModalPreviewRowViewProtocol {
    private var currentState: (AccountContext, TelegramMediaFile, CGSize, ChatMediaGridCollectionStableId?, ChatMediaGridPackHeaderInfo?)?
    
    private let view: ChatMediaAnimatedStickerView = ChatMediaAnimatedStickerView(frame: NSZeroRect)

    func fileAtPoint(_ point: NSPoint) -> QuickPreviewMedia? {
        if let currentState = currentState {
            let reference = currentState.1.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: currentState.1.stickerReference!, media: currentState.1) : FileMediaReference.standalone(media: currentState.1)
            return .file(reference, AnimatedStickerPreviewModalView.self)
        }
        return nil
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        if let currentState = currentState, let state = currentState.3 {
            let menu = NSMenu()
            let file = currentState.1
            if let reference = file.stickerReference{
                menu.addItem(ContextMenuItem(L10n.contextViewStickerSet, handler: { [weak self] in
                    self?.inputNodeInteraction?.showStickerPack(reference)
                }))
            }
            if let mediaId = file.id {
                if state == .saved {
                    menu.addItem(ContextMenuItem(L10n.contextRemoveFaveSticker, handler: {
                        _ = removeSavedSticker(postbox: currentState.0.account.postbox, mediaId: mediaId).start()
                    }))
                } else {
                    menu.addItem(ContextMenuItem(L10n.chatContextAddFavoriteSticker, handler: {
                        _ = addSavedSticker(postbox: currentState.0.account.postbox, network: currentState.0.account.network, file: file).start()
                    }))
                }
            }
            
            
            return menu
        }
        return nil
    }
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var inputNodeInteraction: EStickersInteraction?
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
            if let (_, file, _, _, packInfo) = currentState {
                if let packInfo = packInfo {
                    switch packInfo {
                    case let .pack(_, installed):
                        if installed {
                            inputNodeInteraction?.sendSticker(file)
                        } else if let reference = file.stickerReference {
                            inputNodeInteraction?.previewStickerSet(reference)
                        }
                    default:
                        inputNodeInteraction?.sendSticker(file)
                    }
                } else {
                    inputNodeInteraction?.sendSticker(file)
                }
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
   
    
    func setup(context: AccountContext, file: TelegramMediaFile, collectionId: ChatMediaGridCollectionStableId? = nil, packInfo: ChatMediaGridPackHeaderInfo?) {
        let size = NSMakeSize(60, 60)

        self.currentState = (context, file, size, collectionId, packInfo)
        
        
       view.update(with: file, size: size, context: context, parent: nil, table: nil, parameters: nil, animated: false, positionFlags: nil, approximateSynchronousValue: false)
    }
    
    
}
