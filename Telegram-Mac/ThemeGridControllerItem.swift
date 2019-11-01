//
//  ThemeGridControllerItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox


final class SettingsThemeWallpaperView: View {
    private var wallpaper: Wallpaper?
    let imageView = TransformImageView()
    private let fetchDisposable = MetaDisposable()
    var delete: (() -> Void)?
    private let label: TextView = TextView()
    override init() {
        super.init()
        backgroundColor = theme.chatBackground
        layer?.borderColor = theme.colors.border.cgColor
        layer?.borderWidth = .borderSize
        addSubview(label)
        self.addSubview(self.imageView)
        label.isEventLess = true
        label.userInteractionEnabled = false
        label.isSelectable = false
        let layout = TextViewLayout(.initialize(string: L10n.chatWallpaperEmpty, color: theme.colors.grayText, font: .normal(.title)), maximumNumberOfLines: 1)
        layout.measure(width: .greatestFiniteMagnitude)
        label.update(layout)
        label.backgroundColor = theme.chatBackground
    }
    
    deinit {
        fetchDisposable.dispose()
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "")
        if let wallpaper = self.wallpaper {
            switch wallpaper {
            case .file:
                menu.addItem(ContextMenuItem(L10n.messageContextDelete, handler: { [weak self] in
                    self?.delete?()
                }))
            default:
                break
            }
        }
       
        return menu
    }
    
    override func layout() {
        super.layout()
        label.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func setWallpaper(account: Account, wallpaper: Wallpaper, size: CGSize) {
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        
        
        

        
        self.wallpaper = wallpaper
        switch wallpaper {
        case .builtin:
            self.label.isHidden = true
            self.imageView.isHidden = false
            
            let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: -1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: size, intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor))
            
            
            self.imageView.setSignal(settingsBuiltinWallpaperImage(account: account, scale: backingScaleFactor), cacheImage: { [weak media] result in
                if let media = media {
                    cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                }
            })
            
            self.imageView.set(arguments: arguments)
            
            
        case let .color(color):
            self.imageView.isHidden = true
            self.label.isHidden = true
            backgroundColor = NSColor(UInt32(color))
        case let .image(representations, _):
            self.label.isHidden = true
            self.imageView.isHidden = false
            self.imageView.setSignal(chatWallpaper(account: account, representations: representations, mode: .thumbnail, autoFetchFullSize: true, scale: backingScaleFactor))
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.size.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), emptyColor: nil))
            
            fetchDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.wallpaper(resource: largestImageRepresentation(representations)!.resource)).start())
        case let .file(_, file, settings, isPattern):
            self.label.isHidden = true
            self.imageView.isHidden = false
            
            var patternColor: NSColor? = nil// = NSColor(rgb: 0xd6e2ee, alpha: 0.5)

            if isPattern {
                var patternIntensity: CGFloat = 0.5
                if let color = settings.color {
                    if let intensity = settings.intensity {
                        patternIntensity = CGFloat(intensity) / 100.0
                    }
                    patternColor = NSColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
                }
            }
            
            var representations:[TelegramMediaImageRepresentation] = []
            representations.append(contentsOf: file.previewRepresentations)
            if let dimensions = file.dimensions {
                representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource))
            }
            
            self.imageView.setSignal(chatWallpaper(account: account, representations: representations, mode: .thumbnail, autoFetchFullSize: true, scale: backingScaleFactor))
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.size.aspectFilled(isPattern ? NSMakeSize(300, 300) : size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), emptyColor: patternColor))
            
            
            fetchDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.wallpaper(resource: largestImageRepresentation(representations)!.resource)).start())
        default:
            break
        }
    }
    
}

final class ThemeGridControllerItem: GridItem {
    let account: Account
    let wallpaper: Wallpaper
    let telegramWallpaper: TelegramWallpaper?
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    let isSelected: Bool
    init(account: Account, wallpaper: Wallpaper, telegramWallpaper: TelegramWallpaper?, interaction: ThemeGridControllerInteraction, isSelected: Bool) {
        self.account = account
        self.isSelected = isSelected
        self.wallpaper = wallpaper
        self.telegramWallpaper = telegramWallpaper
        self.interaction = interaction
    }
    

    func node(layout: GridNodeLayout, gridNode: GridNode, cachedNode: GridItemNode?) -> GridItemNode {
        let node = ThemeGridControllerItemNode(gridNode)
        node.setup(account: self.account, wallpaper: self.wallpaper, telegramWallpaper: self.telegramWallpaper, interaction: self.interaction, isSelected: isSelected)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, wallpaper: self.wallpaper, telegramWallpaper: self.telegramWallpaper, interaction: self.interaction, isSelected: self.isSelected)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperView: SettingsThemeWallpaperView
    
    private var currentState: (Account, Wallpaper, TelegramWallpaper?)?
    private var interaction: ThemeGridControllerInteraction?
    private let imageView: ImageView = ImageView()
    override init(_ grid: GridNode) {
        self.wallpaperView = SettingsThemeWallpaperView()
        wallpaperView.userInteractionEnabled = false 
        
        super.init(grid)
        self.addSubview(self.wallpaperView)
        addSubview(imageView)
        imageView.image = theme.icons.chatGroupToggleSelected
        imageView.sizeToFit()
        
        wallpaperView.delete = { [weak self] in
            if let (_, wallpaper, telegramWallapper) = self?.currentState {
                if let telegramWallapper = telegramWallapper {
                    self?.interaction?.deleteWallpaper(wallpaper, telegramWallapper)
                }
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func setup(account: Account, wallpaper: Wallpaper, telegramWallpaper: TelegramWallpaper?, interaction: ThemeGridControllerInteraction, isSelected: Bool) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || wallpaper != self.currentState!.1 {
            self.currentState = (account, wallpaper, telegramWallpaper)
            self.needsLayout = true
        }
        imageView.isHidden = !isSelected
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let (_, wallpaper, telegramWallpaper) = self.currentState {
                self.interaction?.openWallpaper(wallpaper, telegramWallpaper)
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.wallpaperView.frame = bounds
        if let (account, wallpaper, _) = self.currentState {
            self.wallpaperView.setWallpaper(account: account, wallpaper: wallpaper, size: bounds.size)
        }
        imageView.setFrameOrigin(frame.width - imageView.frame.width - 10, 10)
    }
}
