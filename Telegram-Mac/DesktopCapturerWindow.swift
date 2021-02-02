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


private final class UnavailableToStreamView : View {
    let text: TextView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(text)
        backgroundColor = .black
        self.text.isSelectable = false

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isScreen: Bool) {
        let text: String
        //TODOLANG
        if isScreen {
            text = "Unavailable to share your screen, please grant access is [System Settings](screen)."
        } else {
            text = "Unavailable to share your camera, please grant access is [System Settings](camera)."
        }
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: GroupCallTheme.grayStatusColor), bold: MarkdownAttributeSet(font: .bold(.text), textColor: GroupCallTheme.grayStatusColor), link: MarkdownAttributeSet(font: .normal(.text), textColor: GroupCallTheme.accent), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in}))
        }))
        let layout = TextViewLayout(attr)
        let executor = globalLinkExecutor
        executor.processURL = { value in
            if let value = value as? inAppLink {
                switch value.link {
                case "screen":
                    openSystemSettings(.sharing)
                case "camera":
                    openSystemSettings(.camera)
                default:
                    break
                }
            }
        }
        layout.interactions = executor
        layout.measure(width: frame.width)
        self.text.update(layout)
    }

    override func layout() {
        super.layout()
        self.text.center()
    }
}

private final class DesktopCapturerView : View {
    private let listContainer = View()
    private let previewContainer = View()
    private let titleView = TextView()
    private let titleContainer = View()
    private let controls = View()
    
    let cancel = TitleButton()
    let share = TitleButton()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(listContainer)
        addSubview(previewContainer)
        
        addSubview(titleContainer)
        titleContainer.addSubview(titleView)
        addSubview(controls)
        previewContainer.layer?.cornerRadius = 10
        previewContainer.backgroundColor = .black
        backgroundColor = GroupCallTheme.windowBackground
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        layout()
        
        let titleLayout = TextViewLayout.init(.initialize(string: L10n.voiceChatVideoVideoSource, color: GroupCallTheme.titleColor, font: .medium(.title)))
        titleLayout.measure(width: frameRect.width)
        titleView.update(titleLayout)
        
        cancel.set(text: L10n.voiceChatVideoVideoSourceCancel, for: .Normal)
        cancel.set(color: .white, for: .Normal)
        cancel.set(background: GroupCallTheme.speakDisabledColor, for: .Normal)
        cancel.set(background: GroupCallTheme.speakDisabledColor.withAlphaComponent(0.8), for: .Highlight)
        cancel.sizeToFit(.zero, NSMakeSize(100, 30), thatFit: true)
        cancel.layer?.cornerRadius = .cornerRadius
        
        share.set(text: L10n.voiceChatVideoVideoSourceShare, for: .Normal)
        share.set(color: .white, for: .Normal)
        share.set(background: GroupCallTheme.accent, for: .Normal)
        share.set(background: GroupCallTheme.accent.withAlphaComponent(0.8), for: .Highlight)
        share.sizeToFit(.zero, NSMakeSize(100, 30), thatFit: true)
        share.layer?.cornerRadius = .cornerRadius
        
        controls.addSubview(cancel)
        controls.addSubview(share)
        
        cancel.scaleOnClick = true
        share.scaleOnClick = true

    }
    
    private var previousDesktop: (DesktopCaptureSourceScope, DesktopCaptureSourceManager)?
    
    func updatePreview(_ source: DesktopCaptureSource, isAvailable: Bool, manager: DesktopCaptureSourceManager, animated: Bool) {
        if let previous = previousDesktop {
            previous.1.stop(previous.0)
        }
        if isAvailable {
            let size = NSMakeSize(previewContainer.frame.width * 2.5, previewContainer.frame.size.height * 2.5)

            let scope = DesktopCaptureSourceScope(source: source, data: DesktopCaptureSourceData(size: size, fps: 24, captureMouse: true))

            let view = manager.create(for: scope)
            manager.start(scope)
            self.previousDesktop = (scope, manager)
            swapView(view, animated: animated)

        } else {
            let view = UnavailableToStreamView(frame: previewContainer.bounds)
            view.update(isScreen: true)
            swapView(view, animated: animated)
        }

        share.isEnabled = isAvailable
    }
    
    private func swapView(_ view: NSView, animated: Bool) {
        let previewView = previewContainer
        view.frame = previewView.bounds

        for previous in previewView.subviews {
            if animated {
                previous.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] _ in
                    previous?.removeFromSuperview()
                })
            } else {
                previous.removeFromSuperview()
            }
        }
        previewView.addSubview(view)
        if animated {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }

    }
    
    func updatePreview(_ source: CameraCaptureDevice, isAvailable: Bool, animated: Bool) {
        if let previous = previousDesktop {
            previous.1.stop(previous.0)
        }

        if isAvailable {
            let view: View = View()
            let session: AVCaptureSession = AVCaptureSession()
            let input = try? AVCaptureDeviceInput(device: source.device)
            if let input = input {
                session.addInput(input)
            }
            let captureLayer = AVCaptureVideoPreviewLayer(session: session)
            captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
            captureLayer.connection?.isVideoMirrored = true
            captureLayer.videoGravity = .resizeAspectFill
            view.layer = captureLayer


            swapView(view, animated: animated)

            session.startRunning()

        } else {
            let view = UnavailableToStreamView(frame: previewContainer.bounds)
            view.update(isScreen: false)
            swapView(view, animated: animated)

        }
        previousDesktop = nil
        share.isEnabled = isAvailable
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
        listContainer.frame = .init(origin: .init(x: 0, y: frame.height - 90 - 80), size: .init(width: frame.width, height: 90))
        if let listView = listView {
            listView.frame = listContainer.bounds
        }
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 53)
        titleView.center()
        
        controls.frame = NSMakeRect(0, frame.height - 80, frame.width, 80)
        
        cancel.centerY(x: frame.midX - cancel.frame.width - 5)
        share.centerY(x: frame.midX + 5)

    }
}

final class DesktopCapturerWindow : Window {
    
    private let listController: DesktopCapturerListController
    init(select: @escaping(VideoSource)->Void, devices: DevicesContext) {
        
        let size = NSMakeSize(700, 600)
        listController = DesktopCapturerListController(size: NSMakeSize(size.width, 90), devices: devices)
        
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
        self.level = .normal
        self.toolbar = NSToolbar(identifier: "window")
        self.toolbar?.showsBaselineSeparator = false
        
        var first: Bool = true
        listController.updateDesktopSelected = { [weak self] wrap, manager in
            self?.genericView.updatePreview(wrap.source as! DesktopCaptureSource, isAvailable: wrap.isAvailableToStream, manager: manager, animated: !first)
            first = false
        }
        
        listController.updateCameraSelected = { [weak self] wrap in
            self?.genericView.updatePreview(wrap.source as! CameraCaptureDevice, isAvailable: wrap.isAvailableToStream, animated: !first)
            first = false
        }
        
        self.listController.excludeWindowNumber = self.windowNumber
        self.genericView.listView = listController.genericView

        
        self.genericView.cancel.set(handler: { [weak self] _ in
            self?.orderOut(nil)
        }, for: .Click)
        
        self.genericView.share.set(handler: { [weak self] _ in
            self?.orderOut(nil)
            if let source = self?.listController.selected {
                select(source)
            }
        }, for: .Click)
        
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


func presentDesktopCapturerWindow(select: @escaping(VideoSource)->Void, devices: DevicesContext) -> DesktopCapturerWindow {
    let window = DesktopCapturerWindow(select: select, devices: devices)
    window.makeKeyAndOrderFront(nil)
    
    return window
}
