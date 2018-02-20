//
//  ThemeGridControllerItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac


final class SettingsThemeWallpaperView: View {
    private var wallpaper: TelegramWallpaper?
    
    let imageView = TransformImageView()
    
    var pressed: (() -> Void)?
    private let label: TextView = TextView()
    override init() {
        super.init()
        backgroundColor = theme.colors.background
        layer?.borderColor = theme.colors.border.cgColor
        layer?.borderWidth = .borderSize
        addSubview(label)
        self.addSubview(self.imageView)
        
        let layout = TextViewLayout(.initialize(string: L10n.chatWallpaperEmpty, color: theme.colors.grayText, font: .normal(.title)), maximumNumberOfLines: 1)
        layout.measure(width: .greatestFiniteMagnitude)
        label.update(layout)
        label.backgroundColor = theme.colors.background
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
    
    func setWallpaper(account: Account, wallpaper: TelegramWallpaper, size: CGSize) {
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        
        if self.wallpaper != wallpaper {
            self.wallpaper = wallpaper
            switch wallpaper {
            case .builtin:
                self.label.isHidden = true
                self.imageView.isHidden = false

                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: -1), representations: [], reference: nil)
                self.imageView.setSignal(signal: cachedMedia(media: media, size: size, scale: backingScaleFactor))
                
                let scale = backingScaleFactor
                
                self.imageView.setSignal(settingsBuiltinWallpaperImage(account: account, scale: backingScaleFactor), cacheImage: { signal in
                    return cacheMedia(signal: signal, media: media, size: size, scale: scale)
                })
                
                self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: size, intrinsicInsets: NSEdgeInsets()))

                
            case let .color(color):
                self.imageView.isHidden = true
                self.label.isHidden = true
                backgroundColor = NSColor(UInt32(color))
            case let .image(representations):
                self.label.isHidden = true
                self.imageView.isHidden = false
                self.imageView.setSignal(chatAvatarGalleryPhoto(account: account, representations: representations, autoFetchFullSize: true, scale: backingScaleFactor))
                self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets()))
            case .none:
                self.label.isHidden = false
                self.imageView.isHidden = true
            default:
                break
            }
        } else if let wallpaper = self.wallpaper {
            switch wallpaper {
            case .builtin:
                self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(), boundingSize: size, intrinsicInsets: NSEdgeInsets()))
            case .color:
                break
            case let .image(representations):
                self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: largestImageRepresentation(representations)!.dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets()))
            default:
                break
            }
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}

final class ThemeGridControllerItem: GridItem {
    let account: Account
    let wallpaper: TelegramWallpaper
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    let isSelected: Bool
    init(account: Account, wallpaper: TelegramWallpaper, interaction: ThemeGridControllerInteraction, isSelected: Bool) {
        self.account = account
        self.isSelected = isSelected
        self.wallpaper = wallpaper
        self.interaction = interaction
    }
    

    func node(layout: GridNodeLayout, gridNode: GridNode) -> GridItemNode {
        let node = ThemeGridControllerItemNode(gridNode)
        node.setup(account: self.account, wallpaper: self.wallpaper, interaction: self.interaction, isSelected: isSelected)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, wallpaper: self.wallpaper, interaction: self.interaction, isSelected: self.isSelected)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperView: SettingsThemeWallpaperView
    
    private var currentState: (Account, TelegramWallpaper)?
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
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func setup(account: Account, wallpaper: TelegramWallpaper, interaction: ThemeGridControllerInteraction, isSelected: Bool) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || wallpaper != self.currentState!.1 {
            self.currentState = (account, wallpaper)
            self.needsLayout = true
        }
        imageView.isHidden = !isSelected
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let (_, wallpaper) = self.currentState {
                self.interaction?.openWallpaper(wallpaper)
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.wallpaperView.frame = bounds
        if let (account, wallpaper) = self.currentState {
            self.wallpaperView.setWallpaper(account: account, wallpaper: wallpaper, size: bounds.size)
        }
        imageView.setFrameOrigin(frame.width - imageView.frame.width - 10, 10)
    }
}
