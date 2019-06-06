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
    private let addButton: TitleButton = TitleButton()
    init(collectionInfo: StickerGridSection) {
        self.collectionInfo = collectionInfo
        self.textView.userInteractionEnabled = false
        addButton.disableActions()
        
        super.init()
        addSubview(textView)
        switch collectionInfo.packInfo {
        case let .pack(_, installed):
            if !installed {
                addSubview(addButton)
            }
        default:
            break
        }
        addButton.set(handler: { _ in
            if let reference = collectionInfo.reference {
                collectionInfo.inputInteraction.addStickerSet(reference)
            }
        }, for: .Click)
        updateLocalizationAndTheme()
    }
    override func updateLocalizationAndTheme() {
        backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        let textLayout = TextViewLayout(.initialize(string: collectionInfo.packInfo.title.fixed.uppercased(), color: theme.colors.grayText, font: .medium(.title)), constrainedWidth: 300, maximumNumberOfLines: 1, truncationType: .end)
        textLayout.measure()
        textView.update(textLayout)
        
        if addButton.superview != nil {
            addButton.set(font: .normal(.text), for: .Normal)
            addButton.set(color: theme.colors.blueUI, for: .Normal)
            addButton.set(color: .white, for: .Highlight)
            addButton.set(background: theme.colors.background, for: .Normal)
            addButton.set(background: theme.colors.blueUI, for: .Highlight)
            
            addButton.set(text: L10n.stickersSearchAdd, for: .Normal)
            _ = addButton.sizeToFit(NSZeroSize, NSMakeSize(50, 20), thatFit: true)
            addButton.layer?.borderWidth = .borderSize
            addButton.layer?.borderColor = theme.colors.blueUI.cgColor
            addButton.layer?.cornerRadius = .cornerRadius
        }
    
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x:10)
        addButton.centerY(x: frame.width - addButton.frame.width - 10)
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
    
    let context: AccountContext
    let index: ChatMediaInputGridIndex
    let file: TelegramMediaFile
    let selected: () -> Void
    let inputNodeInteraction: EStickersInteraction
    let collectionId:ChatMediaGridCollectionStableId
    let section: GridSection?
    let packInfo: ChatMediaGridPackHeaderInfo
    init(context: AccountContext, collectionId: ChatMediaGridCollectionStableId, packInfo: ChatMediaGridPackHeaderInfo, index: ChatMediaInputGridIndex, file: TelegramMediaFile, inputNodeInteraction: EStickersInteraction, selected: @escaping () -> Void) {
        self.context = context
        self.index = index
        self.file = file
        self.collectionId = collectionId
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        self.packInfo = packInfo
        
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
        if index.packIndex.collectionIndex >= 0 {
            self.section = StickerGridSection(collectionId: collectionId, packInfo: packInfo, inputInteraction: inputNodeInteraction, reference:  reference)
        } else if index.packIndex.collectionIndex <= -2 {
            
            self.section = StickerGridSection(collectionId: collectionId, packInfo: ChatMediaGridPackHeaderInfo.pack(StickerPackCollectionInfo(id: index.packIndex.collectionId, flags: [], accessHash: 0, title: file.stickerText ?? "", shortName: "", thumbnail: nil, hash: 0, count: 0), true), inputInteraction: inputNodeInteraction, reference:  nil)
        } else {
            self.section = nil
        }
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode, cachedNode: GridItemNode?) -> GridItemNode {
        let node = cachedNode as? StickerGridItemView ?? StickerGridItemView(gridNode)
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(context: self.context, file: self.file, collectionId: self.collectionId, packInfo: packInfo)
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerGridItemView else {
            assertionFailure()
            return
        }
        node.setup(context: self.context, file: self.file, collectionId: self.collectionId, packInfo: packInfo)
        node.selected = self.selected
    }
}

let eStickerSize:NSSize = NSMakeSize(60, 60)



final class StickerGridItemView: GridItemNode, ModalPreviewRowViewProtocol {
    private var currentState: (AccountContext, TelegramMediaFile, CGSize, ChatMediaGridCollectionStableId?, ChatMediaGridPackHeaderInfo?)?
    
    
    private let imageView: TransformImageView = TransformImageView()
    
    func fileAtPoint(_ point: NSPoint) -> QuickPreviewMedia? {
        if let currentState = currentState {
            let reference = currentState.1.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: currentState.1.stickerReference!, media: currentState.1) : FileMediaReference.standalone(media: currentState.1)
            return .file(reference, StickerPreviewModalView.self)
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
        addSubview(imageView)

        
        set(handler: { [weak self] (control) in
            if let window = self?.window as? Window, let currentState = self?.currentState, let grid = self?.grid {
                _ = startModalPreviewHandle(grid, window: window, context: currentState.0)
            }
        }, for: .LongMouseDown)
        set(handler: { [weak self] _ in
            self?.click()
        }, for: .SingleClick)
//        set(background: theme.colors.background, for: .Normal)
    }
    
    private func click() {
        if mouseInside() || imageView._mouseInside() {
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
    
    func setup(context: AccountContext, file: TelegramMediaFile, collectionId: ChatMediaGridCollectionStableId? = nil, packInfo: ChatMediaGridPackHeaderInfo?) {
        if let dimensions = file.dimensions {

            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: eStickerSize, boundingSize: eStickerSize, intrinsicInsets: NSEdgeInsets())
            imageView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor))
            imageView.setSignal(chatMessageSticker(postbox: context.account.postbox, file: file, small: false, scale: backingScaleFactor, fetched: true), cacheImage: { image -> Signal<Void, NoError> in
                return cacheMedia(signal: image, media: file, arguments: arguments, scale: System.backingScale)
            })

           // stickerFetchedDisposable.set(fileInteractiveFetched(account: context.account, fileReference: file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)).start())
            
            let imageSize = dimensions.aspectFitted(eStickerSize)
            imageView.set(arguments: arguments)

            imageView.setFrameSize(imageSize)
            currentState = (context, file, dimensions, collectionId, packInfo)
        }
    }
    
    
}
