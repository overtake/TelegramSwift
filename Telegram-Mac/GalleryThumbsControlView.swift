//
//  GalleryThumsControllerView.swift
//  Telegram
//
//  Created by keepcoder on 10/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

class GalleryThumbContainer : View {
    
    fileprivate let imageView: TransformImageView = TransformImageView()
    init(_ item: MGalleryItem) {
        super.init(frame: NSZeroRect)
        
        var signal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        var size: NSSize?
        if let item = item as? MGalleryPhotoItem {
           signal = chatMessagePhotoThumbnail(account: item.account, photo: item.media, scale: backingScaleFactor)
            size = item.media.representations.first?.dimensions
        } else if let item = item as? MGalleryGIFItem {
            signal = chatMessageImageFile(account: item.account, file: item.media, scale: backingScaleFactor)
            size = item.media.videoSize
        } else if let item = item as? MGalleryVideoItem {
            signal = chatMessageImageFile(account: item.account, file: item.media, scale: backingScaleFactor)
            size = item.media.videoSize
        }
        
        if let signal = signal, let size = size {
            imageView.setSignal(signal)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: NSMakeSize(50, 50), intrinsicInsets: NSEdgeInsets())
            imageView.set(arguments: arguments)
        }
        imageView.setFrameSize(50, 50)
        addSubview(imageView)
        
        layer?.cornerRadius = .cornerRadius
        layer?.borderWidth = .borderSize
        layer?.borderColor = NSColor.white.cgColor
    }
    
    override func layout() {
        imageView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}

class GalleryThumbsControlView: View {

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    func makeItems(items: [MGalleryItem], animated: Bool) {
        removeAllSubviews()
        
        for item in items {
            let view = GalleryThumbContainer(item)
            addSubview(view)
        }
    }
    
    func layoutItems(selectedIndex: Int? = nil, animated: Bool) {
        let minWidth: CGFloat = 20
        let difSize = NSMakeSize(frame.height, frame.height)
        let index = CGFloat(selectedIndex ?? 0)
        let startCenter: CGFloat = focus(difSize).minX
        
        var x:CGFloat = startCenter - index * minWidth
        
        let duration: Double = 0.4
        
        for i in 0 ..< subviews.count {
            let view = subviews[i] as! GalleryThumbContainer
            let size = selectedIndex == i ? difSize : NSMakeSize(minWidth, frame.height)
            view._change(size: size, animated: animated, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            
            let f = view.focus(view.imageView.frame.size)
            view.imageView._change(pos: f.origin, animated: animated, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            
            view._change(pos: NSMakePoint(x, 0), animated: animated, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            x += size.width + 3
        }
    }
    
}
