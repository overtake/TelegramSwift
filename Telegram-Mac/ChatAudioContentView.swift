//
//  ChatAudioContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit



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
        self.addSubview(textView)
        self.addSubview(durationView)
        progressView.fetchControls = fetchControls
        addSubview(progressView)
        
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x:leftInset)
    }
    
    private var testPlayer: MediaPlayer?
    
    override func open() {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters, let account = account, let parent = parent  {
            if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: parent) {
                controller.playOrPause()
            } else {
                
               
                let controller:APController

                if parameters.isWebpage {
                    controller = APSingleResourceController(account: account, wrapper: APSingleWrapper(resource: parameters.resource, mimeType: parameters.file.mimeType, name: parameters.title, performer: parameters.performer, id: parent.chatStableId), streamable: true)
                } else {
                    controller = APChatMusicController(account: account, peerId: parent.id.peerId, index: MessageIndex(parent))
                }
                parameters.showPlayer(controller)
                controller.start()
                addGlobalAudioToVisible()
            }
        }
    }
    
    
   
    
    override func fetch() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, messageId: parent.id, file: media).start())
        }
    }
    
    
    override func cancelFetching() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            messageMediaFileCancelInteractiveFetch(account: account, messageId: parent.id, file: media)
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController) {
        checkState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController) {
        checkState()
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        
    }
    
    func audioDidCompleteQueue(for controller:APController) {
        
    }
    
    
    func checkState() {
        
        let presentation: ChatMediaPresentation = parameters?.presentation ?? .Empty
        
        if let parent = parent, let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: parent), case .playing = song.state {
                progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.pauseThumb, iconInset:NSEdgeInsets(left:0))
            } else {
                progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.playThumb, iconInset:NSEdgeInsets(left:1))
            }
        } else {
            progressView.theme = RadialProgressTheme(backgroundColor: presentation.activityBackground, foregroundColor: presentation.activityForeground, icon: presentation.playThumb, iconInset:NSEdgeInsets(left:1))
        }
    }
    
    override func update(with media: Media, size:NSSize, account:Account, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: GroupLayoutPositionFlags? = nil) {
        
        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?

        
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = account.pendingMessageManager.pendingMessageStatus(parent.id) |> map { pendingStatus in
                if let pendingStatus = pendingStatus {
                    return .Fetching(isActive: true, progress: pendingStatus.progress)
                } else {
                    return .Local
                }
            } |> deliverOnMainQueue
        }
        
        if let updatedStatusSignal = updatedStatusSignal {
            self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.fetchStatus = status
                    
                    switch status {
                    case let .Fetching(_, progress):
                        strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                    case .Remote:
                        strongSelf.progressView.state = .Remote
                    case .Local:
                        strongSelf.progressView.state = .Play
                    }
                }
            }))
        }
       
        
        
        globalAudio?.add(listener: self)
        self.setNeedsDisplay()
        
        self.fetchStatus = .Local
        progressView.state = .Play
        checkState()

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
    
    override func setContent(size: NSSize) {
        super.setContent(size: size)
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func clean() {
        fetchDisposable.dispose()
        statusDisposable.dispose()
        globalAudio?.remove(listener: self)
    }
    
}
