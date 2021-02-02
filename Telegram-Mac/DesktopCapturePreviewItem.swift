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
import SwiftSignalKit

final class DesktopCapturePreviewItem : GeneralRowItem {
    fileprivate let scope: DesktopCaptureSourceScope
    fileprivate let selected: Bool
    fileprivate let select: (DesktopCaptureSource, DesktopCaptureSourceManager)->Void
    fileprivate private(set) weak var manager: DesktopCaptureSourceManager?
    fileprivate let isAvailable: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, source: DesktopCaptureSource, isAvailable: Bool, isSelected: Bool, manager: DesktopCaptureSourceManager?, select: @escaping(DesktopCaptureSource, DesktopCaptureSourceManager)->Void) {
        self.manager = manager
        self.scope = DesktopCaptureSourceScope(source: source, data: DesktopCaptureSourceData(size: CGSize(width: 135, height: 90).multipliedByScreenScale(), fps: 0.5, captureMouse: false))
        self.select = select
        self.isAvailable = isAvailable
        self.selected = isSelected
        super.init(initialSize, stableId: stableId)
    }
    
    override var height:CGFloat {
        return 145
    }
    override var width: CGFloat {
        return 90
    }
    
    override func viewClass() -> AnyClass {
        return DesktopCapturePreviewView.self
    }
}


class DesktopCameraCapturerRowItem: GeneralRowItem {
    fileprivate let source: CameraCaptureDevice
    fileprivate let selected: Bool
    fileprivate let select:(CameraCaptureDevice)->Void
    fileprivate let isAvailable: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, device: CameraCaptureDevice, isAvailable: Bool, isSelected: Bool, select:@escaping(CameraCaptureDevice)->Void) {
        self.source = device
        self.selected = isSelected
        self.select = select
        self.isAvailable = isAvailable
        super.init(initialSize, stableId: stableId)

    }
    
    override var height:CGFloat {
        return 145
    }
    override var width: CGFloat {
        return 90
    }
    

    
    override func viewClass() -> AnyClass {
        return DesktopCapturePreviewView.self
    }
}


 
private final class DesktopCaptureSourceView : Control {
    
    
    private var contentView: View = View()
    private let backgroundView: View = View()
    private let textView = TextView()

    private let picture: ImageView = ImageView()

    private var callback:(()->Void)?
    private var selected: Bool = false
    
    
    private var view: NSView? = nil
    
    private let shadowView = ShadowView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentView)
        addSubview(picture)
        
        shadowView.shadowBackground = .blackTransparent
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    
        
        layer?.cornerRadius = 10
        self.contentView.layer?.cornerRadius = 10
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
    
    var previousState: ControlState?

    
    override func stateDidUpdated(_ state: ControlState) {
        super.stateDidUpdated(state)
        
        switch controlState {
        case .Normal:
            if self.selected == false {
                self.picture.change(opacity: 0)
            }
        case .Hover, .Highlight:
            if self.selected == false {
                self.picture.change(opacity: 1)
            }
        default:
            break
        }
        previousState = state
    }
    
    var contentRect: NSRect {
        let rect: NSRect
        rect = NSMakeRect(4, 4, frame.width - 8, frame.height - 8)
        return rect
    }
    
    private var source: VideoSource?
    func update(view: NSView, source: VideoSource, selected: Bool, animated: Bool, callback:@escaping()->Void) {
        self.callback = callback
        self.source = source
        view.frame = bounds
        self.view = view
        self.contentView.subviews = [self.backgroundView, view, self.shadowView, self.textView]

        
        let layout = TextViewLayout(.initialize(string: source.title(), color: theme.colors.text, font: .normal(.short)), maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: frame.width - 20)
        textView.update(layout)
      
        self.selected = selected
        backgroundView.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        
        contentView.layer?.cornerRadius = 6
        
//        picture.animates = true
        
        picture.layer?.opacity = selected ? 1 : 0
        
        picture.image = generateImage(frame.size, contextGenerator: { size, ctx in
            ctx.clear(.init(origin: .zero, size: size))
            
            if selected {
                ctx.setStrokeColor(GroupCallTheme.accent.cgColor)
            } else {
                ctx.setStrokeColor(GroupCallTheme.secondary.cgColor)
            }
            ctx.setLineWidth(5)
            let path = CGMutablePath()
            path.addRoundedRect(in: .init(origin: .zero, size: size), cornerWidth: 10, cornerHeight: 10)
            path.closeSubpath()
            ctx.addPath(path)
            ctx.strokePath()
        })
        picture.sizeToFit()
        
        updateState()
        
        needsLayout = true
    }

    func viewFor(_ other: VideoSource) -> NSView? {
        if let source = self.source {
            if source.isEqual(other) {
                return self.view
            }
        }
        return nil
    }
    
    override func layout() {
        super.layout()
        self.contentView.frame = contentRect
        self.textView.centerX(y: contentRect.height - self.textView.frame.height - 8)
        self.backgroundView.frame = contentView.bounds
        self.view?.frame = contentView.bounds
        self.shadowView.frame = contentView.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DesktopCapturePreviewView : HorizontalRowView {
        
    private let contentView = DesktopCaptureSourceView(frame: NSMakeRect(5, 0, 135, 90))
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(contentView)

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
        update()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        disposable.dispose()
    }
    
    private func updateListeners() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSView.boundsDidChangeNotification, object: enclosingScrollView?.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSView.frameDidChangeNotification, object: enclosingScrollView)
    }
    @objc private func update() {
        if let item = item as? DesktopCapturePreviewItem {
            if let manager = item.manager {
                if visibleRect != .zero, item.isAvailable, window != nil {
                    disposable.set(delaySignal(0.1).start(completed: { [weak manager, weak item] in
                        if let item = item {
                            manager?.start(item.scope)
                        }
                    }))
                } else {
                    disposable.set(nil)
                    manager.stop(item.scope)
                }
            }
        }
        if let item = item as? DesktopCameraCapturerRowItem {
            if item.isAvailable {
                if let session = (contentView.viewFor(item.source)?.layer as? AVCaptureVideoPreviewLayer)?.session {
                    if visibleRect != .zero {
                        disposable.set(delaySignal(0.07).start(completed: { [weak session] in
                            DispatchQueue.global().async { [weak session] in
                                session?.startRunning()
                            }
                        }))
                    } else {
                        disposable.set(nil)
                        DispatchQueue.global().async { [weak session] in
                            session?.stopRunning()
                        }
                    }
                }
            }
        }
        
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateColors() {
        super.updateColors()
        self.backgroundColor = backdorColor
    }
    
    override func updateMouse() {
        super.updateMouse()
        contentView.updateState()
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
                
        let previous = self.item as? DesktopCapturePreviewItem
        
        super.set(item: item, animated: animated)
        
        if let previous = previous {
            if let manager = previous.manager {
                manager.stop(previous.scope)
            }
        }
        
        if let item = item as? DesktopCapturePreviewItem {
            if let manager = item.manager {
                let view: NSView
                if item.isAvailable {
                    view = contentView.viewFor(item.scope.source) ?? manager.create(for: item.scope)
                } else {
                    view = View()
                }
                contentView.update(view: view, source: item.scope.source, selected: item.selected, animated: animated, callback: { [weak item] in
                    if let item = item, let manager = item.manager {
                        item.select(item.scope.source, manager)
                    }
                })
            }
        }
        
        if let item = item as? DesktopCameraCapturerRowItem {
            if item.isAvailable {

            }
            let view: View
            if item.isAvailable {
                if let exist = contentView.viewFor(item.source) as? View  {
                    view = exist
                } else {
                    let session: AVCaptureSession = AVCaptureSession()
                    let input = try? AVCaptureDeviceInput(device: item.source.device)
                    if let input = input {
                        session.addInput(input)
                    }
                    let captureLayer = AVCaptureVideoPreviewLayer()
                    captureLayer.session = session
                    captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
                    captureLayer.connection?.isVideoMirrored = true
                    captureLayer.videoGravity = .resizeAspectFill
                    view = View()
                    view.layer = captureLayer
                }
            } else {
                view = View()
            }

            
            contentView.update(view: view, source: item.source, selected: item.selected, animated: animated, callback: { [weak item] in
                if let item = item {
                    item.select(item.source)
                }
            })
        }
        
        
        update()
        needsLayout = true
    }
    
}
