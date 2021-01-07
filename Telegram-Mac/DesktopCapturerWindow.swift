//
//  DesktopCapturerWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TgVoipWebrtc


private final class DesktopCapturerView : View {
    private let listContainer = View()
    private let previewContainer = View()
    private let titleView = TextView()
    private let titleContainer = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(listContainer)
        addSubview(previewContainer)
        
        addSubview(titleContainer)
        titleContainer.addSubview(titleView)
        
        previewContainer.layer?.cornerRadius = 10
        previewContainer.backgroundColor = .black
        backgroundColor = GroupCallTheme.windowBackground
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        layout()
        
        let titleLayout = TextViewLayout.init(.initialize(string: L10n.voiceChatVideoVideoSource, color: GroupCallTheme.titleColor, font: .medium(.title)))
        titleLayout.measure(width: frameRect.width)
        titleView.update(titleLayout)
    }
    
    private var previous: (DesktopCaptureSourceScope, DesktopCaptureSourceManager)?
    
    func updatePreview(_ source: DesktopCaptureSource, manager: DesktopCaptureSourceManager, animated: Bool) {
        
        if let previous = previous {
            previous.1.stop(previous.0)
        }
        
        let size = previewContainer.frame.size.multipliedByScreenScale()

        let scope = DesktopCaptureSourceScope(source: source, data: DesktopCaptureSourceData(size: size, fps: 30))
        
        
        let view = manager.create(for: scope)
        view.frame = previewContainer.bounds
        let previewView = animated ? previewContainer.animator() : previewContainer
        previewView.subviews = [view]

        manager.start(scope)
        
        self.previous = (scope, manager)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var listView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let value = listView {
                listContainer.addSubview(value)
            }
        }
    }
    
    override func layout() {
        super.layout()
        previewContainer.frame = .init(origin: .init(x: 20, y: 53), size: .init(width: 660, height: 360))
        listContainer.frame = .init(origin: .init(x: 0, y: frame.height - 90 - 70), size: .init(width: frame.width, height: 90))
        if let listView = listView {
            listView.frame = listContainer.bounds
        }
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 53)
        titleView.center()
    }
}

final class DesktopCapturerWindow : Window {
    
    private let listController: DesktopCapturerListController
    init() {
        
        let size = NSMakeSize(700, 600)
        listController = DesktopCapturerListController(size: NSMakeSize(size.width, 90))
        
        var rect: NSRect = .init(origin: .zero, size: size)
        if let screen = NSScreen.main {
            let x = floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2)
            let y = floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2)
            rect = .init(origin: .init(x: x, y: y), size: size)
        }

        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless, .closable, .titled], backing: .buffered, defer: true)
        self.contentView = DesktopCapturerView(frame: .init(origin: .zero, size: size))
        self.minSize = NSMakeSize(700, 600)
        self.name = "DesktopCapturerWindow"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .visible
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        
        self.toolbar = NSToolbar(identifier: "window")
        self.toolbar?.showsBaselineSeparator = false
        
        var first: Bool = true
        listController.updateSelected = { [weak self] source, manager in
            self?.genericView.updatePreview(source, manager: manager, animated: !first)
            first = false
        }
        
        self.listController.excludeWindowNumber = self.windowNumber
        self.genericView.listView = listController.genericView

        
        initSaver()
    }
    
    private var genericView:DesktopCapturerView {
        return self.contentView as! DesktopCapturerView
    }
    
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        var point: NSPoint = NSMakePoint(20, 17)
        self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}


func showDesktopCapturerWindow() {
    let window = DesktopCapturerWindow()
    window.makeKeyAndOrderFront(nil)
}
