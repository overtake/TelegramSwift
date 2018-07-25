//
//  MediaMusicRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class PeerMediaMusicRowItem: PeerMediaRowItem {
    fileprivate private(set) var textLayout:TextViewLayout?
    fileprivate private(set) var file:TelegramMediaFile!
    fileprivate private(set) var thumbResource: ExternalMusicAlbumArtResource!
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        super.init(initialSize,interface,account,object)
        
        file = message.media[0] as! TelegramMediaFile
        let attr = NSMutableAttributedString()
        let music = file.musicText
        _ = attr.append(string: music.0, color: theme.colors.text, font: .medium(.header))
        _ = attr.append(string: "\n")
        _ = attr.append(string: music.1, color: theme.colors.grayText, font: .normal(.text))
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 2, truncationType: .middle)
        
        thumbResource = ExternalMusicAlbumArtResource(title: file.musicText.0, performer: file.musicText.1, isThumbnail: true)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout?.measure(width: width - 70)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaMusicRowView.self
    }
    
}

class PeerMediaMusicRowView : PeerMediaRowView, APDelegate {
    private let textView:TextView = TextView()
    let thumbView:TransformImageView = TransformImageView(frame: NSMakeRect(0, 0, 40, 40))
    
    var fetchStatus: MediaResourceStatus?
    let statusDisposable = MetaDisposable()
    let fetchDisposable = MetaDisposable()
    private var playAnimationView: PeerMediaPlayerAnimationView?
    private(set) var fetchControls:FetchControls!
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        addSubview(textView)
        addSubview(thumbView)
//        fetchControls = FetchControls(fetch: { [weak self] in
//            self?.executeInteraction(true)
//        })
       
      //  thumbView.fetchControls = fetchControls
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let item = item as? PeerMediaMusicRowItem else {
            super.mouseUp(with: event)
            return
        }
        if item.interface.presentation.state == .normal {
            executeInteraction(true)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerMediaMusicRowItem, let layout = item.textLayout {
            let f = focus(layout.layoutSize)
            textView.update(layout, origin: NSMakePoint(60, f.minY))
            thumbView.centerY(x: 10)
            playAnimationView?.centerY(x: 10)
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController) {
        checkState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController) {
        checkState()
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        checkState()
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        checkState()
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        //checkState()
    }
    
    func audioDidCompleteQueue(for controller:APController) {
        checkState()
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
            case .Fetching:
                if isControl {
                    cancelFetching()
                }
            case .Remote:
                fetch()
            case .Local:
                open()
                break
            }
        }
    }
    
    func checkState() {
        if let item = item as? PeerMediaMusicRowItem {
            if let controller = globalAudio, let song = controller.currentSong {
                if song.entry.isEqual(to: item.message) {
                    if playAnimationView == nil {
                        playAnimationView = PeerMediaPlayerAnimationView()
                        addSubview(playAnimationView!)
                        playAnimationView?.centerY(x: 10)
                    }
                    if case .playing = song.state {
                        playAnimationView?.isPlaying = true
                    } else if case .stoped = song.state {
                        playAnimationView?.removeFromSuperview()
                        playAnimationView = nil
                    } else  {
                        playAnimationView?.isPlaying = false
                    }
                    
                } else {
                    playAnimationView?.removeFromSuperview()
                    playAnimationView = nil
                }
            } else {
                playAnimationView?.removeFromSuperview()
                playAnimationView = nil
            }
        }
    }

    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? PeerMediaMusicRowItem {
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
            textView.update(item.textLayout)
            textView.centerY(x: 60)
            textView.backgroundColor = backdorColor
            globalAudio?.add(listener: self)
            
            
            let iconSize = CGSize(width: 40, height: 40)
            let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
            let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
            
            thumbView.layer?.contents = theme.icons.playerMusicPlaceholder
            thumbView.layer?.cornerRadius = .cornerRadius
            
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: iconSize, resource: item.thumbResource)], reference: nil)
            
            thumbView.setSignal(chatMessagePhotoThumbnail(account: item.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: image)))
            
            thumbView.set(arguments: arguments)

            
            if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
                updatedStatusSignal = combineLatest(chatMessageFileStatus(account: item.account, file: item.file), item.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                    |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                        if let pendingStatus = pendingStatus {
                            return .Fetching(isActive: true, progress: pendingStatus.progress)
                        } else {
                            return resourceStatus
                        }
                    } |> deliverOnMainQueue
            } else {
                updatedStatusSignal = chatMessageFileStatus(account: item.account, file: item.file) |> deliverOnMainQueue
            }
            
            
            if let updatedStatusSignal = updatedStatusSignal {
                self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                    self?.fetchStatus = status
                }))
                checkState()
            }

        }
    }
    
    func open() {
        if let item = item as? PeerMediaMusicRowItem  {
            if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: item.message) {
                controller.playOrPause()
            } else {
                let controller = APChatMusicController(account: item.account, peerId: item.message.id.peerId, index: MessageIndex(item.message))
                item.interface.inlineAudioPlayer(controller)
                controller.start()
                addGlobalAudioToVisible()
            }
        }
    }
    
    
    func addGlobalAudioToVisible() {
        if let controller = globalAudio {
            item?.table?.enumerateViews(with: { (view) in
                if  let view = (view as? PeerMediaMusicRowView) {
                    controller.add(listener: view)
                }
                return true
            })
        }
        
    }
    
    func fetch() {
        if let item = item as? PeerMediaMusicRowItem {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: item.account, messageId: item.message.id, fileReference: FileMediaReference.message(message: MessageReference(item.message), media: item.file)).start())
        }
        open()
    }
    
    
    func cancelFetching() {
        if let item = item as? PeerMediaMusicRowItem {
            messageMediaFileCancelInteractiveFetch(account: item.account, messageId: item.message.id, fileReference: FileMediaReference.message(message: MessageReference(item.message), media: item.file))
        }
    }
    
    
    deinit {
        clean()
    }
    
    func clean() {
        fetchDisposable.dispose()
        statusDisposable.dispose()
        globalAudio?.remove(listener: self)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


