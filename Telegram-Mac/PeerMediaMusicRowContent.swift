//
//  MediaMusicRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

class PeerMediaMusicRowItem: PeerMediaRowItem {
    fileprivate let textLayout:TextViewLayout
    fileprivate let descLayout:TextViewLayout?
    fileprivate let file:TelegramMediaFile
    fileprivate let thumbResource: TelegramMediaResource?
    fileprivate let isCompactPlayer: Bool
    fileprivate let music:(Message, GalleryAppearType)->Void
    init(_ initialSize:NSSize, _ interface:ChatInteraction, _ object: PeerMediaSharedEntry, isCompactPlayer: Bool = false, galleryType: GalleryAppearType = .history, gallery: @escaping(Message, GalleryAppearType)->Void = { _, _ in }, music: @escaping(Message, GalleryAppearType)->Void, viewType: GeneralViewType = .legacy) {
        self.isCompactPlayer = isCompactPlayer
        self.music = music
        file = object.message!.media[0] as! TelegramMediaFile
        
        let music = file.musicText
        self.textLayout = TextViewLayout(.initialize(string: music.0, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)

        if !music.1.isEmpty {
            let text: String
            if let duration = file.duration {
                text = timerText(Int(duration)) + " • " + music.1
            } else {
                text = music.1
            }
            self.descLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.short)), maximumNumberOfLines: 1)
        } else if let size = file.size {
            self.descLayout = TextViewLayout(.initialize(string: String.prettySized(with: size), color: theme.colors.grayText, font: .normal(.short)), maximumNumberOfLines: 1)
        } else {
            descLayout = nil
        }
        let resource: TelegramMediaResource?
        if file.previewRepresentations.isEmpty {
            if !file.mimeType.contains("ogg")  {
                resource = ExternalMusicAlbumArtResource(title: file.musicText.0, performer: file.musicText.1, isThumbnail: true)
            } else {
                resource = nil
            }
        } else {
            resource = file.previewRepresentations.first!.resource
        }
        self.thumbResource = resource
        
        
        super.init(initialSize, interface, object, galleryType: galleryType, gallery: gallery, viewType: viewType)
        
    }
    
    override var inset: NSEdgeInsets {
        if isCompactPlayer {
            return NSEdgeInsetsMake(5, 10, 5, 10)
        } else {
            return NSEdgeInsetsMake(0, 0, 0, 0)
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        descLayout?.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaMusicRowView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if isCompactPlayer {
            return .single([])
        } else {
            return super.menuItems(in: location)
        }
    }
    
}

class PeerMediaMusicRowView : PeerMediaRowView, APDelegate {
    private let textView:TextView = TextView()
    private let descView:TextView = TextView()

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
        
        descView.isSelectable = false
        descView.userInteractionEnabled = false
        
        addSubview(textView)
        addSubview(descView)
        addSubview(thumbView)
//        fetchControls = FetchControls(fetch: { [weak self] in
//            self?.executeInteraction(true)
//        })
       
      //  thumbView.fetchControls = fetchControls
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
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
        if let item = item as? PeerMediaMusicRowItem {
            textView.update(item.textLayout, origin: NSMakePoint(item.contentInset.left, item.contentInset.top + 2))
            
            if let descLayout = item.descLayout {
                descView.update(descLayout, origin: NSMakePoint(item.contentInset.left, item.contentSize.height - descLayout.layoutSize.height - item.contentInset.bottom - 2))
            } else {
                descView.update(nil)
                textView.centerY()
            }
            
            thumbView.centerY(x: 0)
            playAnimationView?.centerY(x: 0)
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        checkState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        checkState()
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState()
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState()
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        //checkState()
    }
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        checkState()
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        open()
    }
    
    func checkState() {
        if let item = item as? PeerMediaMusicRowItem {
            if let controller = item.context.audioPlayer, let song = controller.currentSong {
                if song.entry.isEqual(to: item.message.id) {
                    if playAnimationView == nil {
                        playAnimationView = PeerMediaPlayerAnimationView()
                        addSubview(playAnimationView!)
                        playAnimationView?.centerY(x: 0)
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
            textView.centerY(x: item.contentInset.left)
            textView.backgroundColor = backdorColor
            item.context.audioPlayer?.add(listener: self)
            
            
            let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
            let arguments = TransformImageArguments(corners: imageCorners, imageSize: PeerMediaIconSize, boundingSize: PeerMediaIconSize, intrinsicInsets: NSEdgeInsets())
            
            thumbView.layer?.contents = theme.icons.playerMusicPlaceholder
            thumbView.layer?.cornerRadius = .cornerRadius
            if let resource = item.thumbResource {
                let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(PeerMediaIconSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                
                thumbView.setSignal(chatMessagePhotoThumbnail(account: item.interface.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: image)))
                
                thumbView.set(arguments: arguments)
            }

            
            if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
                updatedStatusSignal = combineLatest(chatMessageFileStatus(context: item.interface.context, message: item.message, file: item.file), item.interface.context.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                    |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                        if let pendingStatus = pendingStatus.0 {
                            return .Fetching(isActive: true, progress: pendingStatus.progress)
                        } else {
                            return resourceStatus
                        }
                    } |> deliverOnMainQueue
            } else {
                updatedStatusSignal = chatMessageFileStatus(context: item.interface.context, message: item.message, file: item.file) |> deliverOnMainQueue
            }
            
            
            if let updatedStatusSignal = updatedStatusSignal {
                self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                    self?.fetchStatus = status
                }))
                checkState()
            }
            needsLayout = true
        }
    }
    
    func open() {
        if let item = item as? PeerMediaMusicRowItem  {
            item.music(item.message, item.galleryType)
        }
    }
    

    
    func fetch() {
        if let item = item as? PeerMediaMusicRowItem {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, messageId: item.message.id, messageReference: .init(item.message), file: item.file, userInitiated: true).start())
        }
        open()
    }
    
    
    func cancelFetching() {
        if let item = item as? PeerMediaMusicRowItem {
            messageMediaFileCancelInteractiveFetch(context: item.interface.context, messageId: item.message.id, file: item.file)
        }
    }
    
    
    deinit {
        clean()
    }
    
    func clean() {
        fetchDisposable.dispose()
        statusDisposable.dispose()
        if let item = item as? PeerMediaMusicRowItem {
            item.context.audioPlayer?.remove(listener: self)
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


