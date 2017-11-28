//
//  StickerGridItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 23/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

final class StickerGridSection: GridSection {
    let collectionId: ChatMediaGridCollectionStableId
    let height: CGFloat = 30
    let reference:StickerPackReference?
    let packInfo: ChatMediaGridPackHeaderInfo
    let inputInteraction:EStickersInteraction
    var hashValue: Int {
        return self.collectionId.hashValue
    }
    
    init(collectionId: ChatMediaGridCollectionStableId, packInfo: ChatMediaGridPackHeaderInfo, inputInteraction: EStickersInteraction, reference: StickerPackReference?) {
        self.packInfo = packInfo
        self.collectionId = collectionId
        self.reference = reference
        self.inputInteraction = inputInteraction
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? StickerGridSection {
            return self.collectionId == to.collectionId
        } else {
            return false
        }
    }
    
    func node() -> View {
        return StickerGridSectionNode(collectionInfo: self)
    }
}


final class StickerGridSectionNode: View {
    var textView:TextView = TextView()
    private let collectionInfo:StickerGridSection
    init(collectionInfo: StickerGridSection) {
        self.collectionInfo = collectionInfo
        self.textView.userInteractionEnabled = false
        super.init()
        addSubview(textView)
        updateLocalizationAndTheme()
    }
    override func updateLocalizationAndTheme() {
        backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        let textLayout = TextViewLayout(.initialize(string: collectionInfo.packInfo.title.uppercased(), color: theme.colors.grayText, font: .medium(.title)), constrainedWidth: 300, maximumNumberOfLines: 1, truncationType: .end)
        textLayout.measure()
        textView.update(textLayout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x:10)
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() && event.clickCount == 1, let reference = collectionInfo.reference {
            self.collectionInfo.inputInteraction.previewStickerSet(reference)
        }
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

final class StickerGridItem: GridItem {
    
    let account: Account
    let index: ChatMediaInputGridIndex
    let file: TelegramMediaFile
    let selected: () -> Void
    let inputNodeInteraction: EStickersInteraction
    let collectionId:ChatMediaGridCollectionStableId
    let section: GridSection?
    
    init(account: Account, collectionId: ChatMediaGridCollectionStableId, packInfo: ChatMediaGridPackHeaderInfo, index: ChatMediaInputGridIndex, file: TelegramMediaFile, inputNodeInteraction: EStickersInteraction, selected: @escaping () -> Void) {
        self.account = account
        self.index = index
        self.file = file
        self.collectionId = collectionId
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        
        
        let reference: StickerPackReference?
        switch packInfo {
        case .recent:
            reference = nil
        case .pack:
            reference = file.stickerReference
        case .saved:
            reference = nil
        case .speficicPack:
            reference = file.stickerReference
        }
        if collectionId != .saved {
            self.section = StickerGridSection(collectionId: collectionId, packInfo: packInfo, inputInteraction: inputNodeInteraction, reference:  reference)
        } else {
            self.section = nil
        }
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode) -> GridItemNode {
        let node = StickerGridItemView(gridNode)
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, file: self.file, collectionId: self.collectionId)
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerGridItemView else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, file: self.file, collectionId: self.collectionId)
        node.selected = self.selected
    }
}

let eStickerSize:NSSize = NSMakeSize(80, 80)



final class StickerGridItemView: GridItemNode, StickerPreviewRowViewProtocol {
    private var currentState: (Account, TelegramMediaFile, CGSize, ChatMediaGridCollectionStableId?)?
    
    
    private let imageView: TransformImageView
    
    func fileAtPoint(_ point: NSPoint) -> TelegramMediaFile? {
        return currentState?.1
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        if let currentState = currentState, let state = currentState.3 {
            let menu = NSMenu()
            let file = currentState.1
            if state == .recent {
                if let reference = file.stickerReference, case let .id(id, _) = reference {
                    menu.addItem(ContextMenuItem(tr(.contextViewStickerSet), handler: { [weak self] in
                        self?.inputNodeInteraction?.navigateToCollectionId(.pack(ItemCollectionId.init(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)))
                    }))
                }
            } else if state == .saved, let mediaId = file.id {
                menu.addItem(ContextMenuItem(tr(.contextRemoveFaveSticker), handler: {
                    _ = removeSavedSticker(postbox: currentState.0.postbox, mediaId: mediaId).start()
                }))
            }
            
            return menu
        }
        return nil
    }
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var inputNodeInteraction: EStickersInteraction?
    var selected: (() -> Void)?
    
    override init(_ grid:GridNode) {
        imageView = TransformImageView()
        super.init(grid)
        layer?.cornerRadius = .cornerRadius
        self.autohighlight = false
        
        set(handler: { [weak self] _ in
            if let (_, file, _, _) = self?.currentState {
                self?.inputNodeInteraction?.sendSticker(file)
            }
            }, for: .Click)
        
        
        set(handler: { [weak self] (control) in
            if let window = self?.window as? Window, let currentState = self?.currentState, let grid = self?.grid {
                _ = startStickerPreviewHandle(grid, window: window, account: currentState.0)
            }
            }, for: .LongMouseDown)
        set(background: theme.colors.background, for: .Normal)
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
    
    func setup(account: Account, file: TelegramMediaFile, collectionId: ChatMediaGridCollectionStableId? = nil) {
        if let dimensions = file.dimensions {
            addSubview(imageView)
            
            set(image: theme.icons.stickerBackgroundActive, for: .Highlight)
            set(image: theme.icons.stickerBackground, for: .Normal)
            set(background: theme.colors.background, for: .Normal)
            set(background: theme.colors.background, for: .Hover)
            
            imageView.setSignal( chatMessageSticker(account: account, file: file, type: .small, scale: backingScaleFactor))
            stickerFetchedDisposable.set(fileInteractiveFetched(account: account, file: file).start())
            
            let imageSize = dimensions.aspectFitted(eStickerSize)
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: eStickerSize, intrinsicInsets: NSEdgeInsets()))
            
            imageView.setFrameSize(imageSize)
            currentState = (account, file, dimensions, collectionId)
            return
        }
        imageView.removeFromSuperview()
    }
    
    
}
