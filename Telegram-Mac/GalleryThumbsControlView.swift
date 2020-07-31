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

private class GalleryThumb {
    var signal:Signal<ImageDataTransformation, NoError>? {
        var signal:Signal<ImageDataTransformation, NoError>?
        if let item = item as? MGalleryPhotoItem {
            signal = chatWebpageSnippetPhoto(account: item.context.account, imageReference: item.entry.imageReference(item.media), scale: System.backingScale, small: true, secureIdAccessContext: item.secureIdAccessContext)
        } else if let item = item as? MGalleryGIFItem {
            signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: item.entry.fileReference(item.media), scale: System.backingScale)
        } else if let item = item as? MGalleryVideoItem {
            signal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: item.entry.fileReference(item.media), scale: System.backingScale)
        } else if let item = item as? MGalleryPeerPhotoItem {
            signal = chatMessagePhoto(account: item.context.account, imageReference: item.entry.imageReference(item.media), scale: System.backingScale)
        }
        return signal
    }
    let size: NSSize?
    private weak var _view: GalleryThumbContainer? = nil
    var selected: Bool = false
    var isEnabled: Bool = true
    private let callback:(MGalleryItem)->Void
    private let item: MGalleryItem
    
    var frame: NSRect = .zero
    
    init(_ item: MGalleryItem, callback:@escaping(MGalleryItem)->Void) {
        self.callback = callback
        self.item = item
        
        if let item = item as? MGalleryPhotoItem {
            item.fetch()
        } else if let item = item as? MGalleryPeerPhotoItem {
            item.fetch()
        }
       
        var size: NSSize?
        if let item = item as? MGalleryPhotoItem {
            size = item.media.representations.first?.dimensions.size
        } else if let item = item as? MGalleryGIFItem {
            size = item.media.videoSize
        } else if let item = item as? MGalleryVideoItem {
            size = item.media.videoSize
        } else if let item = item as? MGalleryPeerPhotoItem {
            size = item.media.representations.first?.dimensions.size
        }
        
        self.size = size
    }
    
    var viewSize: NSSize {
        if selected {
            return NSMakeSize(80, 80)
        } else {
            return NSMakeSize(40, 80)
        }
    }
    
    var view: GalleryThumbContainer {
        if _view == nil {
            let view = GalleryThumbContainer(self)
            view.frame = frame
            view.set(handler: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                self.callback(self.item)
            }, for: .Click)
            _view = view
            return view
        }
        return _view!
    }
    
    var opt:GalleryThumbContainer? {
        return _view
    }
    
    func cleanup() {
        _view?.removeFromSuperview()
        _view = nil
    }
    
}

class GalleryThumbContainer : Control {
    
    fileprivate let imageView: TransformImageView = TransformImageView()
    fileprivate let overlay: View = View()
    fileprivate init(_ item: GalleryThumb) {
        super.init(frame: NSZeroRect)
        backgroundColor = .clear
        if let signal = item.signal, let size = item.size {
            imageView.setSignal(signal)
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize:size.aspectFilled(NSMakeSize(80, 80)), boundingSize: NSMakeSize(80, 80), intrinsicInsets: NSEdgeInsets())
            imageView.set(arguments: arguments)
        }
        overlay.layer?.opacity = 0.35
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
    
    private var items: [GalleryThumb] = []
    
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
        
        documentView.subviews = range.location == NSNotFound ? [] : items.subarray(with: range).map { $0.view }
    }
    
    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    func insertItem(_ item: MGalleryItem, at: Int, isSelected: Bool, animated: Bool, callback:@escaping(MGalleryItem)->Void) {
        let view = GalleryThumb(item, callback: callback)
        view.selected = isSelected
        
        let idx = idsExcludeDisabled(at)
        
        items.insert(view, at: idx)
        
    }
    
    func idsExcludeDisabled(_ at: Int) -> Int {
        var idx = at
        for i in 0 ..< items.count {
            if !items[i].isEnabled {
                if i <= at {
                    idx += 1
                }
            }
        }
        
        return idx
    }
    
    func removeItem(at: Int, animated: Bool) {
        
        let idx = idsExcludeDisabled(at)
        var subview:GalleryThumb? = items[idx]
        subview?.isEnabled = false
        subview?.opt?.isEnabled = false
        items.remove(at: idx)
        subview?.opt?.change(opacity: 0, animated: animated, completion: { completed in
            subview?.cleanup()
            subview = nil
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
            let thumb = items[i]
            var size = idx == i ? difSize : NSMakeSize(minWidth, frame.height)
            let view = thumb.opt
            
            let rect = CGRect(origin: NSMakePoint(x, 0), size: size)
            thumb.frame = rect
            
            view?.overlay.change(opacity: 0.35)
            if thumb.isEnabled {
                if let view = view {
                    view._change(size: rect.size, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                    
                    let f = view.focus(view.imageView.frame.size)
                    view.imageView._change(pos: f.origin, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                    
                    view._change(pos: rect.origin, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
                }
            } else {
                size.width -= minWidth
            }
            x += size.width + 4
            
            if idx == i {
                selectedView = view
                view?.overlay.change(opacity: 0.0)
            }
        }
        
        self.selectedView = selectedView
        
        documentView.setFrameSize(x, frame.height)

        
        if let selectedView = selectedView {
            scrollView.clipView.scroll(to: NSMakePoint(min(max(selectedView.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0), animated: animated && documentView.subviews.count > 0)
        }
        previousRange = nil
        scrollDidUpdated()
    }
    
}
