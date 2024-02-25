//
//  ChatAudioContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore

import TGUIKit


final class SingleTimeVoiceBadgeView: ImageView {
   
    
    private struct Parameters: Equatable {
        var size: CGSize
        var text: String
        var foreground: NSColor
        var background: NSColor
        var blendMode: CGBlendMode
    }
    private var parameters: Parameters?
    private var hasContent: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    public func update(size: CGSize, text: String, foreground: NSColor, background: NSColor, blendMode: CGBlendMode) {
        let parameters = Parameters(size: size, text: text, foreground: foreground, background: background, blendMode: blendMode)
        if self.parameters != parameters || !self.hasContent {
            self.parameters = parameters
            self.update()
        }
    }
    
    private func update() {
        guard let parameters = self.parameters else {
            return
        }
        
        
        self.hasContent = true
        
        
        self.image = generateImage(parameters.size, rotatedContext: { size, context in
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setBlendMode(.copy)
            context.setFillColor(parameters.background.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            context.setBlendMode(parameters.blendMode)

            var fontSize: CGFloat = floor(parameters.size.height * 0.48)
            while true {
                let string: NSAttributedString = .initialize(string: parameters.text, color: parameters.foreground, font: .bold(fontSize))
                
                
                let line = CTLineCreateWithAttributedString(string)
                let stringBounds = CTLineGetBoundsWithOptions(line, [.excludeTypographicLeading])
                
                if stringBounds.width <= size.width - 5.0 * 2.0 || fontSize <= 2.0 {
                
                    context.saveGState()
                    
                    context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
                                        
                    context.textPosition = CGPoint(x: stringBounds.minX + floor((size.width - stringBounds.width) / 2.0), y: stringBounds.maxY + floor((size.height - stringBounds.height) / 2.0))
                    
                    CTLineDraw(line, context)
                    
                    context.restoreGState()
                    
                    break
                } else {
                    fontSize -= 1.0
                }
            }
            
            let lineWidth: CGFloat = 2
            let lineInset: CGFloat = 2.0
            let lineRadius: CGFloat = size.width * 0.5 - lineInset - lineWidth - 1.5
            
            context.setLineWidth(lineWidth)
            context.setStrokeColor(parameters.foreground.cgColor)
            context.setLineCap(.round)
            
            context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: CGFloat.pi * 0.5, endAngle: -CGFloat.pi * 0.5, clockwise: false)
            context.strokePath()
            
//            context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: size.width * 0.5 - lineWidth + 1.0, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
//            context.strokePath()
            
            let sectionAngle: CGFloat = CGFloat.pi / 8
            
            for i in 0 ..< 7 {
                if i % 2 == 0 {
                    continue
                }
                
                let startAngle = CGFloat.pi * 0.5 - CGFloat(i) * sectionAngle - sectionAngle * 0.15
                let endAngle = startAngle - sectionAngle * 0.75
                
                context.addArc(center: CGPoint(x: size.width * 0.5, y: size.height * 0.5), radius: lineRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                context.strokePath()
            }
        })
    }
}




class ChatAudioContentView: ChatMediaContentView, APDelegate {
    
    var actionsLayout:TextViewLayout?
    let progressView:RadialProgressView = RadialProgressView()
    
    let textView:TextView = TextView()
    let durationView:TextView = TextView()
    
    let statusDisposable = MetaDisposable()
    let fetchDisposable = MetaDisposable()
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        durationView.userInteractionEnabled = false
        self.addSubview(textView)
        self.addSubview(durationView)
        progressView.fetchControls = fetchControls
        addSubview(progressView)
        
    }
    
    override var fetchStatus: MediaResourceStatus? {
        didSet {
            if let fetchStatus = fetchStatus {
                
                switch fetchStatus {
                case let .Fetching(_, progress), let .Paused(progress):
                    let sentGrouped = parent?.groupingKey != nil && (parent!.flags.contains(.Sending) || parent!.flags.contains(.Unsent))
                    if progress == 1.0, sentGrouped {
                        progressView.state = .Success
                    } else {
                        progressView.state = .Fetching(progress: progress, force: false)
                    }
                case .Remote:
                    progressView.state = .Remote
                case .Local:
                    checkState(animated: false)
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
//        if mouseInside(), userInteractionEnabled {
//            progressView.fetchControls?.fetch()
//        } else {
//            super.mouseDown(with: event)
//        }
    }
    
 
    
    override func layout() {
        super.layout()
        textView.centerY(x:leftInset)
    }
    
    
    override func open() {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters, let context = context, let parent = parent  {
            if let controller = context.sharedContext.getAudioPlayer(), controller.playOrPause(parent.id) {
            } else {
                let controller:APController

                if parameters.isWebpage {
                    controller = APSingleResourceController(context: context, wrapper: APSingleWrapper(resource: parameters.resource, mimeType: parameters.file.mimeType, name: parameters.title, performer: parameters.performer, duration: parameters.file.duration, id: parent.chatStableId), streamable: true, volume: FastSettings.volumeRate)
                } else {
                    controller = APChatMusicController(context: context, chatLocationInput: parameters.chatLocationInput(parent), mode: parameters.chatMode, index: MessageIndex(parent), volume: FastSettings.volumeRate)
                }
                parameters.showPlayer(controller)
                controller.start()
            }
        }
    }
    
    
   
    
    override func fetch(userInitiated: Bool) {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, messageReference: .init(parent), file: media, userInitiated: userInitiated).start())
        }
    }
    
    
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        checkState(animated: animated)
    }
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        checkState(animated: animated)
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        
    }
    
    
    func checkState(animated: Bool) {
        
        let presentation: ChatMediaPresentation = parameters?.presentation ?? .Empty
        if let parent = parent, let controller = context?.sharedContext.getAudioPlayer(), let song = controller.currentSong {
            if song.entry.isEqual(to: parent), case .playing = song.state {
                progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.pauseThumb, iconInset:NSEdgeInsets(left:0), blendMode: presentation.blendingMode)
                progressView.state = .Icon(image: presentation.pauseThumb)
            } else {
                progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.playThumb, iconInset:NSEdgeInsets(left:1), blendMode: presentation.blendingMode)
                progressView.state = .Icon(image: presentation.playThumb)
            }
        } else {
            progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.playThumb, iconInset:NSEdgeInsets(left:1), blendMode: presentation.blendingMode)
            progressView.state = .Icon(image: presentation.playThumb)
        }
    }
    
    override func update(with media: Media, size:NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        

        
        
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = context.account.pendingMessageManager.pendingMessageStatus(parent.id) |> map { pendingStatus in
                if let pendingStatus = pendingStatus.0 {
                    return .Fetching(isActive: true, progress: pendingStatus.progress)
                } else {
                    return .Local
                }
            } |> deliverOnMainQueue
        }
        
        if let updatedStatusSignal = updatedStatusSignal {
            self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                self?.fetchStatus = status
            }))
        }
       
        
        
        context.sharedContext.getAudioPlayer()?.add(listener: self)
        self.setNeedsDisplay()
        
        self.fetchStatus = .Local
        checkState(animated: animated)

    }
    
    var leftInset:CGFloat {
        return 40.0 + 10.0;
    }
    
    override func draggingAbility(_ event:NSEvent) -> Bool {
        return NSPointInRect(convert(event.locationInWindow, from: nil), progressView.frame)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func copy() -> Any {
        let view = View()
        view.frame = self.frame
        return view
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self.progressView
    }
    
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func clean() {
        //fetchDisposable.dispose()
        statusDisposable.dispose()
        context?.sharedContext.getAudioPlayer()?.remove(listener: self)
    }
    
}
