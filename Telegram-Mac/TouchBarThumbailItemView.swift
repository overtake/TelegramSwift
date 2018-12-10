//
//  TouchBarThumbailItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit

@available(OSX 10.12.2, *)
class TouchBarStickerItemView: NSScrubberItemView {
    
    private let imageView: TransformImageView = TransformImageView()
    
    private let spinner: NSProgressIndicator
    required override init(frame frameRect: NSRect) {
       
        spinner = NSProgressIndicator()
        
        super.init(frame: frameRect)
        
        spinner.isIndeterminate = true
        spinner.style = .spinning
        spinner.sizeToFit()
        spinner.frame = bounds.insetBy(dx: (bounds.width - spinner.frame.width)/2, dy: (bounds.height - spinner.frame.height)/2)
        spinner.isHidden = true
        spinner.controlSize = .small
        spinner.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        spinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxXMargin]
        
        subviews = [imageView, spinner]
    }
    
    func update(account: Account, file: TelegramMediaFile) {
        let dimensions = file.dimensions ?? frame.size
        let imageSize = NSMakeSize(30, 30)
        imageView.setSignal(chatMessageSticker(account: account, fileReference: FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file), type: .thumb, scale: backingScaleFactor))
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize:dimensions.aspectFitted(imageSize), boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
        imageView.set(arguments: arguments)
        imageView.setFrameSize(imageSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
       // layer?.backgroundColor = NSColor.controlColor.cgColor
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        spinner.sizeToFit()
        spinner.frame = bounds.insetBy(dx: (bounds.width - spinner.frame.width)/2, dy: (bounds.height - spinner.frame.height)/2)
    }
}
