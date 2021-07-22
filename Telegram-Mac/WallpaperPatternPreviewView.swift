//
//  WallpaperPatternPreview.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class WallpaperPatternView : Control {
    private var backgroundView: BackgroundView?
    let imageView = TransformImageView()
    let checkbox: ImageView = ImageView()
    private let emptyTextView = TextView()
    fileprivate(set) var pattern: Wallpaper?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        addSubview(imageView)
        addSubview(checkbox)
        checkbox.image = theme.icons.chatGroupToggleSelected
        checkbox.sizeToFit()
        self.layer?.cornerRadius = .cornerRadius

        emptyTextView.userInteractionEnabled = false
        emptyTextView.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        emptyTextView.center()
        checkbox.setFrameOrigin(NSMakePoint(frame.width - checkbox.frame.width - 5, 5))
        backgroundView?.frame = bounds
    }
    
    func update(with pattern: Wallpaper?, isSelected: Bool, account: Account, colors: [NSColor], rotation: Int32?) {
        checkbox.isHidden = !isSelected
        self.pattern = pattern
        

        let layout = TextViewLayout(.initialize(string: L10n.chatWPPatternNone, color: colors.first!.brightnessAdjustedColor, font: .normal(.title)))
        layout.measure(width: 80)
        emptyTextView.update(layout)
        
        if let pattern = pattern {
            
            self.backgroundView?.removeFromSuperview()
            self.backgroundView = nil
            
            emptyTextView.isHidden = true
            imageView.isHidden = false
            
            let emptyColor: TransformImageEmptyColor
            if colors.count > 1 {
                let colors = colors.map {
                    return $0.withAlphaComponent($0.alpha == 0 ? 0.5 : $0.alpha)
                }
                emptyColor = .gradient(colors: colors, intensity: colors.first!.alpha, rotation: nil)
            } else if let color = colors.first {
                emptyColor = .color(color)
            } else {
                emptyColor = .color(NSColor(rgb: 0xd6e2ee, alpha: 0.5))
            }
            
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: pattern.dimensions.aspectFilled(NSMakeSize(300, 300)), boundingSize: bounds.size, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor))
            switch pattern {
            case let .file(_, file, _, _):
                var representations:[TelegramMediaImageRepresentation] = []
                if let dimensions = file.dimensions {
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                } else {
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 300, height: 300), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                }
                imageView.setSignal(chatWallpaper(account: account, representations: representations, file: file, mode: .thumbnail, isPattern: true, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false, drawPatternOnly: false), animate: false, synchronousLoad: false)
            default:
                break
            }
        } else {
            emptyTextView.isHidden = false
            imageView.isHidden = true
            if self.backgroundView == nil {
                let bg = BackgroundView(frame: bounds)
                self.backgroundView = bg
                addSubview(bg, positioned: .above, relativeTo: imageView)
            }
            if colors.count > 1 {
                backgroundView?.backgroundMode = .gradient(colors: colors, rotation: rotation)
            } else {
                backgroundView?.backgroundMode = .color(color: colors[0])
            }
        }
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
