//
//  ChatMessageAccessoryView.swift
//  Telegram
//
//  Created by keepcoder on 05/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac



class ChatMessageAccessoryView: Control {

    private var text:(TextNodeLayout, TextNode)?
    private var textNode:TextNode?
    private var maxWidth: CGFloat = 0
    private var stringValue: String = ""
    private let progress: RadialProgressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, cancelFetchingIcon: stopFetchStreamableControl), twist: true, size: NSMakeSize(24, 24))
    private let download: ImageButton = ImageButton(frame: NSMakeRect(0, 0, 24, 24))

    private var status: MediaResourceStatus?
    private var isStreamable: Bool = true
    private var isCompact: Bool = false
    
    private let progressCap: View = View()
    var isUnread: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {

        ctx.round(frame.size, isStreamable ? 8 : frame.height / 2)

        ctx.setFillColor(NSColor.blackTransparent.cgColor)
        ctx.fill(bounds)
        
        if let text = text {
            var rect = focus(text.0.size)
            rect.origin.x = 6
            if hasStremingControls  {
                rect.origin.x += download.frame.width + 6
            }
            if backingScaleFactor == 2 {
                rect.origin.y += 0.5
            }
          //  rect.origin.y += 1
            text.1.draw(rect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            
            if isUnread {
                ctx.setFillColor(.white)
                ctx.fillEllipse(in: NSMakeRect(rect.maxX + 3, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - 5)/2), 5, 5))
            }
        }
    }
    
    
    override func layout() {
        super.layout()
        download.centerY(x: 6)
        progress.centerY(x: 6)
    }
    
    var hasStremingControls: Bool {
        return !download.isHidden || !progress.isHidden
    }
    
    private var fetch:(()->Void)?
    private var cancelFetch:(()->Void)?
    func updateText(_ text: String, maxWidth: CGFloat, status: MediaResourceStatus?, isStreamable: Bool, isCompact: Bool = false, fetch: @escaping()-> Void = { }, cancelFetch: @escaping()-> Void = { }) -> Void {
        let updatedText = TextNode.layoutText(maybeNode: textNode, .initialize(string: isStreamable ? text.components(separatedBy: ", ").joined(separator: "\n") : text, color: .white, font: .normal(10.0)), nil, isStreamable && !isCompact ? 2 : 1, .end, NSMakeSize(maxWidth, 20), nil, false, .left)
        self.isStreamable = isStreamable
        self.status = status
        self.text = updatedText
        self.stringValue = text
        self.maxWidth = maxWidth
        self.fetch = fetch
        self.isCompact = isCompact
        self.cancelFetch = cancelFetch
        
        
        if let status = status, isStreamable {
            
            download.set(image: isCompact ? theme.icons.videoCompactFetching : theme.icons.streamingVideoDownload, for: .Normal)

            
            switch status {
            case .Remote:
                progress.isHidden = true
                download.isHidden = false
                progress.state = .None
            case .Local:
                progress.isHidden = true
                download.isHidden = true
                progress.state = .None
            case let .Fetching(_, progress):
                self.progress.state = !isCompact ? .Fetching(progress: progress, force: false) : .None
                self.progress.isHidden = isCompact
                download.isHidden = !isCompact
                download.set(image: isCompact ? theme.icons.compactStreamingFetchingCancel : theme.icons.streamingVideoDownload, for: .Normal)
            }
            
            _ = download.sizeToFit()
            
        } else {
            progress.isHidden = true
            download.isHidden = true
            progress.state = .None
        }
        
        setFrameSize(NSMakeSize(min(updatedText.0.size.width + 12 + (isUnread ? 8 : 0) + (hasStremingControls ? download.frame.width + 6 : 0), maxWidth), hasStremingControls && !isCompact ? 36 : updatedText.0.size.height + 6))
        needsDisplay = true
    }
    
    override func copy() -> Any {
        let view = ChatMessageAccessoryView(frame: frame)
        view.updateText(self.stringValue, maxWidth: self.maxWidth, status: self.status, isStreamable: self.isStreamable, isCompact: self.isCompact)
        return view
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progress)
        addSubview(download)
        
        progress.isHidden = true
        download.isHidden = true
        progress.fetchControls = FetchControls(fetch: { [weak self] in
            self?.cancelFetch?()
        })
        
        progressCap.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        progressCap.layer?.borderWidth = 2.0
        progressCap.frame = NSMakeRect(2, 2, progress.frame.width - 4, progress.frame.height - 4)
        progressCap.layer?.cornerRadius = progressCap.frame.width / 2

        progress.addSubview(progressCap)
        
        download.set(handler: { [weak self] _ in
            guard let `self` = self, let status = self.status else {return}
            switch status {
            case .Remote:
                 self.fetch?()
            case .Fetching:
                self.cancelFetch?()
            default:
                break
            }
        }, for: .Click)
        
        set(handler: { [weak self] _ in
            guard let `self` = self, let status = self.status else {return}
            switch status {
            case .Remote:
                self.fetch?()
            case .Fetching:
                self.cancelFetch?()
            default:
                break
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
