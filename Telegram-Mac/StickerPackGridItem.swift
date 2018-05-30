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
    
    let account: Account
    let file: TelegramMediaFile
    let selected: () -> Void
    let send:(TelegramMediaFile) -> Void
    init(account: Account, file: TelegramMediaFile, send:@escaping(TelegramMediaFile) -> Void,  selected: @escaping () -> Void) {
        self.account = account
        self.file = file
        self.send = send
        self.selected = selected
        
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode) -> GridItemNode {
        let node = StickerGridItemView(gridNode)
        node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
            self?.send(file)
            }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
        node.setup(account: self.account, file: self.file, packInfo: nil)
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerGridItemView else {
            assertionFailure()
            return
        }
        node.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: {_ in}, sendSticker: { [weak self] file in
            self?.send(file)
        }, previewStickerSet: {_ in}, addStickerSet: {_ in}, showStickerPack: {_ in})
        
        node.setup(account: self.account, file: self.file, packInfo: nil)
        node.selected = self.selected
    }
}

