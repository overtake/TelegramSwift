//
//  PeerMediaVoiceRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TelegramMedia
import Postbox
import SwiftSignalKit


class PeerMediaVoiceRowItem: PeerMediaRowItem {
    fileprivate let file:TelegramMediaFile
    fileprivate let titleLayout: TextViewLayout
    fileprivate let nameLayout: TextViewLayout
    fileprivate let music: (Message, GalleryAppearType)->Void
    init(_ initialSize:NSSize, _ interface:ChatInteraction, _ object: PeerMediaSharedEntry, galleryType: GalleryAppearType = .history, gallery: @escaping(Message, GalleryAppearType)->Void, music: @escaping(Message, GalleryAppearType)->Void, viewType: GeneralViewType = .legacy) {
        let message = object.message!
        self.file = message.media[0] as! TelegramMediaFile
        self.music = music
        let formatter = DateSelectorUtil.mediaMediumDate
        
        let date = Date(timeIntervalSince1970: TimeInterval(object.message!.timestamp) - interface.context.timeDifference)
        
        
        titleLayout = TextViewLayout(.initialize(string: formatter.string(from: date), color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        
        var peer:Peer? = message.chatPeer(interface.context.peerId)
        
        var title:String = peer?.displayTitle ?? ""
        if let _peer = coreMessageMainPeer(message) as? TelegramChannel, case .broadcast(_) = _peer.info {
            title = _peer.displayTitle
            peer = _peer
        }
        
        nameLayout = TextViewLayout(.initialize(string: title, color: theme.colors.grayText, font: .normal(.short)), maximumNumberOfLines: 1)

        super.init(initialSize, interface, object, galleryType: galleryType, gallery: gallery, viewType: viewType)
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        titleLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaVoiceRowView.self
    }
}


final class PeerMediaVoiceRowView : PeerMediaRowView, APDelegate {
    private let titleView: TextView = TextView()
    private let nameView: TextView = TextView()
    private let progressView:RadialProgressView = RadialProgressView()
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var player:GIFPlayerView = GIFPlayerView()
    private let resourceDataDisposable = MetaDisposable()
    private let unreadDot: View = View()
    private var instantVideoData: AVGifData? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(nameView)
        addSubview(player)
        addSubview(progressView)
        addSubview(unreadDot)
        player.setFrameSize(40, 40)
        unreadDot.setFrameSize(NSMakeSize(6, 6))
        unreadDot.layer?.cornerRadius = 3
        progressView.fetchControls = FetchControls(fetch: { [weak self] in
            self?.executeInteraction(true)
        })
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updatePlayerIfNeeded() {
        player.set(data: acceptVisibility ? instantVideoData : nil)
    }
    
    var acceptVisibility:Bool {
    return window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect)
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: item?.table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: item?.table?.view)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    
    func open() {
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}

        item.music(item.message, item.galleryType)
    }
    
    
    
    func fetch() {
        if let item = item as? PeerMediaVoiceRowItem {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, messageId: item.message.id, messageReference: .init(item.message), file: item.file, userInitiated: false).start())
        }
    }
    
    
    func cancelFetching() {
        if let item = item as? PeerMediaVoiceRowItem {
            messageMediaFileCancelInteractiveFetch(context: item.interface.context, messageId: item.message.id, file: item.file)
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        checkState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        checkState()
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        
    }
    
    func delete() -> Void {
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        let messageId = item.message.id
        let engine = item.interface.context.engine.messages
        _ = item.interface.context.account.postbox.transaction { transaction -> Void in
            engine.deleteMessages(transaction: transaction, ids: [messageId])
        }.start()
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        guard let item = item as? PeerMediaVoiceRowItem else {return}

        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
            case .Fetching, .Paused:
                if isControl {
                    if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
                        delete()
                    }
                    cancelFetching()
                } else {
                    //open()
                }
            case .Remote:
                fetch()
            //open()
            case .Local:
                open()
                break
            }
        }
    }
    
    
    deinit {
        statusDisposable.dispose()
        fetchDisposable.dispose()
        resourceDataDisposable.dispose()
        player.set(data: nil)
        removeNotificationListeners()
    }
    
    var fetchStatus: MediaResourceStatus? {
        didSet {
            if let fetchStatus = fetchStatus {
                switch fetchStatus {
                case let .Fetching(_, progress), let .Paused(progress):
                    progressView.state = .Fetching(progress: progress, force: false)
                case .Remote:
                    progressView.state = .Remote
                case .Local:
                    progressView.state = .Play
                }
            }
        }
    }
    
    override func updateSelectingMode(with selectingMode: Bool, animated: Bool = false) {
        super.updateSelectingMode(with: selectingMode, animated: animated)
        progressView.userInteractionEnabled = !selectingMode
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        titleView.backgroundColor = backdorColor
        nameView.backgroundColor = backdorColor
        unreadDot.backgroundColor = theme.colors.accent
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        
        let center = floorToScreenPixels(backingScaleFactor, contentView.frame.height / 2)
        
        titleView.setFrameOrigin(item.contentInset.left, center - titleView.frame.height - 1)
        nameView.setFrameOrigin(item.contentInset.left, center + 1)
        
        progressView.centerY(x: 0)
        player.centerY(x: 0)
        
        unreadDot.setFrameOrigin(titleView.frame.maxX + 5, center - titleView.frame.height / 2 - unreadDot.frame.height / 2)
    }
    
    var isIncomingConsumed:Bool {
        var isConsumed:Bool = false
        if let parent = (item as? PeerMediaRowItem)?.message {
            for attr in parent.attributes {
                if let attr = attr as? ConsumableContentMessageAttribute {
                    isConsumed = attr.consumed
                    break
                }
            }
        }
        return isConsumed
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        
        titleView.update(item.titleLayout)
        nameView.update(item.nameLayout)
        
        unreadDot.isHidden = isIncomingConsumed
        
        updateListeners()
        
        if item.file.isInstantVideo {
            let size = player.frame.size
            player.layer?.cornerRadius = player.frame.height / 2
            
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: item.file.previewRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            player.setSignal( chatMessagePhoto(account: item.interface.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: image), scale: backingScaleFactor))
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 20), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            player.set(arguments: arguments)
            
            
            resourceDataDisposable.set((item.interface.context.account.postbox.mediaBox.resourceData(item.file.resource) |> deliverOnResourceQueue |> map { data in return data.complete ?  AVGifData.dataFrom(data.path) : nil} |> deliverOnMainQueue).start(next: { [weak self] data in
                self?.instantVideoData = data
            }))
            
        } else {
            player.setSignal(signal: .single(TransformImageResult(nil, false)))
            player.set(data: nil)
            instantVideoData = nil
            resourceDataDisposable.set(nil)
        }
        
        
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>
        
        let file:TelegramMediaFile = item.file
        
        if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(context: item.interface.context, message: item.message, file: file), item.interface.context.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                    if let pendingStatus = pendingStatus.0 {
                        return .Fetching(isActive: true, progress: pendingStatus.progress)
                    } else {
                        return resourceStatus
                    }
                } |> deliverOnMainQueue
        } else {
            updatedStatusSignal = chatMessageFileStatus(context: item.interface.context, message: item.message, file: file) |> deliverOnMainQueue
        }
        
        self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.fetchStatus = status
                
                switch status {
                case let .Fetching(_, progress):
                    strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                case .Remote, .Paused:
                    strongSelf.progressView.state = .Remote
                case .Local:
                    strongSelf.progressView.state = .Play
                }
            }
        }))
        
        checkState()
        
        needsLayout = true
        
        if item.automaticDownload.isDownloable(item.message) {
            fetch()
        }
        
    }
    
    func checkState() {
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        let backgroundColor: NSColor
        let foregroundColor: NSColor
        if let media = item.message.anyMedia as? TelegramMediaFile, media.isInstantVideo {
            backgroundColor = .blackTransparent
            foregroundColor = .white
        } else {
            backgroundColor = theme.colors.fileActivityBackground
            foregroundColor = theme.colors.fileActivityForeground
        }
        if let controller = item.context.sharedContext.getAudioPlayer(), let song = controller.currentSong {
           
            
            if song.entry.isEqual(to: item.message), case .playing = song.state {
                progressView.theme = RadialProgressTheme(backgroundColor: backgroundColor, foregroundColor: foregroundColor, icon: theme.icons.chatMusicPause, iconInset:NSEdgeInsets(left:0))
                progressView.state = .Icon(image: theme.icons.chatMusicPause)
            } else {
                progressView.theme = RadialProgressTheme(backgroundColor: backgroundColor, foregroundColor: foregroundColor, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
                progressView.state = .Play
            }
        } else {
            progressView.theme = RadialProgressTheme(backgroundColor: backgroundColor, foregroundColor: foregroundColor, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
        }
    }
    
}
