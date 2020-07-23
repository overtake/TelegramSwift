//
//  GalleryThumsControllerView.swift
//  Telegram
//
//  Created by keepcoder on 10/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

class GalleryThumbContainer : Control {
    
    fileprivate let imageView: TransformImageView = TransformImageView()
    fileprivate let overlay: View = View()
    init(_ item: MGalleryItem) {
        super.init(frame: NSZeroRect)
        backgroundColor = .clear
        
        var signal:Signal<ImageDataTransformation, NoError>?
        var size: NSSize?
        if let item = item as? MGalleryPhotoItem {
            signal = chatWebpageSnippetPhoto(account: item.context.account, imageReference: item.entry.imageReference(item.media), scale: backingScaleFactor, small: true, secureIdAccessContext: item.secureIdAccessContext)
            size = item.media.representations.first?.dimensions.size
            item.fetch()
        } else if let item = item as? MGalleryGIFItem {
            signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: item.entry.fileReference(item.media), scale: backingScaleFactor)
            size = item.media.videoSize
        } else if let item = item as? MGalleryVideoItem {
            signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: item.entry.fileReference(item.media), scale: backingScaleFactor)
            size = item.media.videoSize
        } else if let item = item as? MGalleryPeerPhotoItem {
            signal = chatMessagePhoto(account: item.context.account, imageReference: item.entry.imageReference(item.media), scale: backingScaleFactor)
            
            size = item.media.representations.first?.dimensions.size
            item.fetch()
        }
        

        if let signal = signal, let size = size {
            imageView.setSignal(signal)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize:size.aspectFilled(NSMakeSize(80, 80)), boundingSize: NSMakeSize(80, 80), intrinsicInsets: NSEdgeInsets())
            imageView.set(arguments: arguments)
        }
        overlay.setFrameSize(80, 80)
        imageView.setFrameSize(80, 80)
        addSubview(imageView)
        addSubview(overlay)
        overlay.backgroundColor = .black
        layer?.cornerRadius = .cornerRadius
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
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

    private let scrollView: HorizontalScrollView = HorizontalScrollView()
    private let documentView: View = View()
    private var selectedView: View?
    
    private var items: [GalleryThumbContainer] = []
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
        addSubview(scrollView)
        scrollView.documentView = documentView
        scrollView.backgroundColor = .clear
        scrollView.background = .clear
        
        documentView.backgroundColor = .clear
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrollDidUpdated), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(scrollDidUpdated), name: NSView.frameDidChangeNotification, object: scrollView)

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private var previousRange: NSRange? = nil
    
    @objc private func scrollDidUpdated() {
        
        
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        
        let distance:(min: CGFloat, max: CGFloat) = (min: scrollView.documentOffset.x - 80, max: scrollView.documentOffset.x + scrollView.frame.width + 80)
        
        for (i, item) in items.enumerated() {
            if item.frame.minX >= distance.min && item.frame.maxX <= distance.max {
                range.length += 1
                if range.location == NSNotFound {
                    range.location = i
                }
            } else if range.location != NSNotFound {
                break
            }
        }
        
        if previousRange == range {
            return
        }
        
        previousRange = range
        
        documentView.subviews = range.location == NSNotFound ? [] : items.subarray(with: range)
    }
    
    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    func insertItem(_ item: MGalleryItem, at: Int, isSelected: Bool, animated: Bool, callback:@escaping(MGalleryItem)->Void) {
        let view = GalleryThumbContainer(item)
        
        let difSize = NSMakeSize(frame.height / (!isSelected ? 2.0 : 1.0), frame.height)
        view.frame = focus(difSize)
        view.set(handler: { [weak item] _ in
            if let item = item {
                callback(item)
            }
        }, for: .SingleClick)
        
        
        if animated {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
        
        let idx = idsExcludeDisabled(at)
        
        items.insert(view, at: idx)
        
        documentView.needsDisplay = true
    }
    
    func idsExcludeDisabled(_ at: Int) -> Int {
        var idx = at
        for i in 0 ..< documentView.subviews.count {
            let subview = documentView.subviews[i] as! GalleryThumbContainer
            if !subview.isEnabled {
                if i <= at {
                    idx += 1
                }
            }
        }
        
        return idx
    }
    
    func removeItem(at: Int, animated: Bool) {
        
        let idx = idsExcludeDisabled(at)
        

        let subview = items[idx]
        subview.isEnabled = false
        subview.change(opacity: 0, animated: animated, completion: { [weak subview] completed in
            if completed {
                subview?.removeFromSuperview()
            }
        })
    }
    
    func updateItem(_ item: MGalleryItem, at: Int) {
        
    }
    
    var documentSize: NSSize {
        return NSMakeSize(min(documentView.frame.width, frame.width), documentView.frame.height)
    }
    
    func layoutItems(selectedIndex: Int? = nil, animated: Bool) {
        
        let idx = idsExcludeDisabled(selectedIndex ?? 0)
        
        let minWidth: CGFloat = frame.height / 2
        let difSize = NSMakeSize(frame.height, frame.height)
        
        var x:CGFloat = 0
        
        let duration: Double = 0.4
        var selectedView: GalleryThumbContainer?
        for i in 0 ..< items.count {
            let view = items[i]
            var size = idx == i ? difSize : NSMakeSize(minWidth, frame.height)
            view.overlay.change(opacity: 0.35)
            if view.isEnabled {
                view._change(size: size, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                
                let f = view.focus(view.imageView.frame.size)
                view.imageView._change(pos: f.origin, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                
                view._change(pos: NSMakePoint(x, 0), animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                
            } else {
                size.width -= minWidth
            }
            x += size.width + 4

            if idx == i {
                selectedView = view
                view.overlay.change(opacity: 0.0)
            }
        }
        
        self.selectedView = selectedView
        
        documentView.setFrameSize(x, frame.height)

        
        if let selectedView = selectedView {
            scrollView.clipView.scroll(to: NSMakePoint(min(max(selectedView.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0), animated: animated)
        }
        previousRange = nil
        scrollDidUpdated()
    }
    
}
