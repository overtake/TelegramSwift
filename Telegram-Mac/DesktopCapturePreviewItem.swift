//
//  DesktopCapturerPreviewItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TgVoipWebrtc
import TGUIKit
final class DesktopCapturePreviewItem : GeneralRowItem {
    fileprivate let sources: [DesktopCaptureSource]
    fileprivate let selectedSource: DesktopCaptureSource?
    fileprivate let select: (DesktopCaptureSource)->Void
    fileprivate private(set) weak var manager: DesktopCaptureSourceManager?
    init(_ initialSize: NSSize, stableId: AnyHashable, sources: [DesktopCaptureSource], selectedSource: DesktopCaptureSource?, manager: DesktopCaptureSourceManager?, select: @escaping(DesktopCaptureSource)->Void) {
        self.manager = manager
        self.sources = sources
        self.select = select
        self.selectedSource = selectedSource
        super.init(initialSize, height: 140, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return DesktopCapturePreviewView.self
    }
}
 
private final class DesktopCaptureSourceView : Control {
    
    
    private var contentView: View = View()
    private let backgroundView: View = View()
    
    private let picture: ImageView = ImageView()

    private var callback:(()->Void)?
    private var source: DesktopCaptureSource?
    private var selected: Bool = false
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(contentView)
        addSubview(picture)
        layer?.cornerRadius = .cornerRadius
        
        set(handler: { [weak self] control in
            if self?.selected == false {
                self?.picture.change(opacity: 1)
            }
        }, for: .Hover)
        
        set(handler: { [weak self] control in
            if self?.selected == false {
                self?.picture.change(opacity: 1)
            }
        }, for: .Highlight)
        
        set(handler: { [weak self] control in
            if self?.selected == false {
                self?.picture.change(opacity: 0)
            }
        }, for: .Normal)
                
        set(handler: { [weak self] _ in
            self?.callback?()
        }, for: .Click)
    }
    
    func update(view: NSView, source: DesktopCaptureSource, selected: Bool, callback:@escaping()->Void) {
        self.callback = callback
        view.frame = bounds
        
        if source != self.source {
            if let oldView = contentView.subviews.first {
                contentView.animator().replaceSubview(oldView, with: view)
            } else {
                self.contentView.addSubview(view)
            }
        }
      
        self.source = source
        self.selected = selected
        backgroundView.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        
//        picture.animates = true
        
        picture.layer?.opacity = selected ? 1 : 0
        
        picture.image = generateImage(frame.size, contextGenerator: { size, ctx in
            ctx.clear(.init(origin: .zero, size: size))
            
            if selected {
                ctx.setStrokeColor(theme.colors.accent.cgColor)
            } else {
                ctx.setStrokeColor(theme.colors.grayIcon.cgColor)
            }
            ctx.setLineWidth(5)
            let path = CGMutablePath()
            path.addRoundedRect(in: .init(origin: .zero, size: size), cornerWidth: .cornerRadius, cornerHeight: .cornerRadius)
            path.closeSubpath()
            ctx.addPath(path)
            ctx.strokePath()
        })
        picture.sizeToFit()
        
        updateState()
    }
    
    override func layout() {
        super.layout()
        self.backgroundView.frame = bounds
        self.contentView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class DesktopCapturePreviewView : TableRowView {
    
    private let containerView: View = View()
    private let textViews: View = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        addSubview(textViews)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? DesktopCapturePreviewItem else {
            return
        }
        containerView.frame = CGRect(origin: .init(x: 10, y: 0), size: NSMakeSize(CGFloat(item.sources.count) * 160 + CGFloat(item.sources.count - 1) * 10, 140))
        
        textViews.frame = NSMakeRect(0, 100, frame.width, 40)
        
        var x: CGFloat = 0
        for (i, subview) in self.containerView.subviews.enumerated() {
            subview.setFrameOrigin(NSMakePoint(x, 0))
            let textView = self.textViews.subviews[i]
            textView.setFrameOrigin(NSMakePoint(x + 10 + floorToScreenPixels(backingScaleFactor, (subview.frame.width - textView.frame.width) / 2), 6))

            x += subview.frame.width + 10
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateListeners() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSView.boundsDidChangeNotification, object: enclosingScrollView?.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSView.frameDidChangeNotification, object: enclosingScrollView)
    }
    @objc private func update() {
        guard let item = item as? DesktopCapturePreviewItem else {
            return
        }
        if let manager = item.manager {
            for source in item.sources {
                if visibleRect != .zero {
                    manager.start(source)
                } else {
                    manager.stop(source)
                }
            }
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        super.updateColors()
        self.backgroundColor = backdorColor
    }
    
    override func updateMouse() {
        super.updateMouse()
        for subview in self.containerView.subviews {
            (subview as? Control)?.updateState()
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? DesktopCapturePreviewItem else {
            return
        }
        
        while self.containerView.subviews.count > item.sources.count {
            self.containerView.subviews.last?.removeFromSuperview()
        }
        while self.containerView.subviews.count < item.sources.count {
            self.containerView.addSubview(DesktopCaptureSourceView(frame: NSMakeRect(0, 0, 160, 100)))
        }
        
        while self.textViews.subviews.count > item.sources.count {
            self.textViews.subviews.last?.removeFromSuperview()
        }
        while self.textViews.subviews.count < item.sources.count {
            let textView = TextView()
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            self.textViews.addSubview(textView)
        }
        
        if let manager = item.manager {
            for (i, source) in item.sources.enumerated() {
                let view = manager.create(for: source)
                (self.containerView.subviews[i] as? DesktopCaptureSourceView)?.update(view: view, source: source, selected: source == item.selectedSource, callback: {
                    item.select(source)
                })
                let layout = TextViewLayout(.initialize(string: source.title(), color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .middle)
                layout.measure(width: 140)
                (self.textViews.subviews[i] as? TextView)?.update(layout)
            }
        }
        
        update()
        needsLayout = true
    }
    
}
