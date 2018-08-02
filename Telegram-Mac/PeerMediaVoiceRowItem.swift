//
//  PeerMediaVoiceRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


class PeerMediaVoiceRowItem: PeerMediaRowItem {
    fileprivate let file:TelegramMediaFile
    fileprivate let titleLayout: TextViewLayout
    fileprivate let nameLayout: TextViewLayout
    fileprivate let inset: NSEdgeInsets = NSEdgeInsetsMake(0, 60, 0, 20)
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        let message = object.message!
        file = message.media[0] as! TelegramMediaFile
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let date = Date(timeIntervalSince1970: TimeInterval(object.message!.timestamp) - account.context.timeDifference)
        
        
        titleLayout = TextViewLayout(.initialize(string: formatter.string(from: date), color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        
        var peer:Peer? = message.chatPeer
        
        var title:String = peer?.displayTitle ?? ""
        if let _peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = _peer.info {
            title = _peer.displayTitle
            peer = _peer
        }
        
        nameLayout = TextViewLayout(.initialize(string: title, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)

        super.init(initialSize, interface, account, object)
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: width - 100)
        titleLayout.measure(width: width - 100)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaVoiceRowView.self
    }
}


private final class PeerMediaVoiceRowView : PeerMediaRowView, APDelegate {
    private let titleView: TextView = TextView()
    private let nameView: TextView = TextView()
    private let progressView:RadialProgressView = RadialProgressView()
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(nameView)
        addSubview(progressView)
        
        progressView.fetchControls = FetchControls(fetch: { [weak self] in
            self?.executeInteraction(true)
            self?.open()
        })
    }
    
    func open() {
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}

        if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: item.message) {
            controller.playOrPause()
        } else {
            
            let controller:APController = APChatVoiceController(account: item.account, peerId: item.message.id.peerId, index: MessageIndex(item.message))
            item.interface.inlineAudioPlayer(controller)
            controller.start()
            addGlobalAudioToVisible()
        }
    }
    
    
    func addGlobalAudioToVisible() {
        if let controller = globalAudio {
            item?.table?.enumerateViews(with: { (view) in
                if  let view = (view as? PeerMediaVoiceRowView) {
                    controller.add(listener: view)
                }
                return true
            })
        }
        
    }
    
    func fetch() {
        if let item = item as? PeerMediaVoiceRowItem {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: item.account, messageId: item.message.id, file: item.file).start())
        }
        open()
    }
    
    
    func cancelFetching() {
        if let item = item as? PeerMediaVoiceRowItem {
            messageMediaFileCancelInteractiveFetch(account: item.account, messageId: item.message.id, file: item.file)
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
    
    func delete() -> Void {
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        let messageId = item.message.id
        _ = item.account.postbox.transaction { transaction -> Void in
            transaction.deleteMessages([messageId])
        }.start()
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        guard let item = item as? PeerMediaVoiceRowItem else {return}

        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
            case .Fetching:
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
    }
    
    var fetchStatus: MediaResourceStatus? {
        didSet {
            if let fetchStatus = fetchStatus {
                switch fetchStatus {
                case let .Fetching(_, progress):
                    progressView.state = .Fetching(progress: progress, force: false)
                case .Remote:
                    progressView.state = .Remote
                case .Local:
                    progressView.state = .Play
                }
            }
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        titleView.backgroundColor = backdorColor
        nameView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        
        let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2)
        
        titleView.setFrameOrigin(item.inset.left, center - titleView.frame.height - 1)
        nameView.setFrameOrigin(item.inset.left, center + 1)
        
        progressView.centerY(x: 10)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        
        titleView.update(item.titleLayout)
        nameView.update(item.nameLayout)
        
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>
        
        let file:TelegramMediaFile = item.file
        
        if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: item.account, file: file), item.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                    if let pendingStatus = pendingStatus {
                        return .Fetching(isActive: true, progress: pendingStatus.progress)
                    } else {
                        return resourceStatus
                    }
                } |> deliverOnMainQueue
        } else {
            updatedStatusSignal = chatMessageFileStatus(account: item.account, file: file) |> deliverOnMainQueue
        }
        
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
        
        checkState()
        
        needsLayout = true
        
    }
    
    func checkState() {
        guard let item = item as? PeerMediaVoiceRowItem else {return}
        if let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: item.message), case .playing = song.state {
                progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.fileActivityBackground, foregroundColor: theme.colors.fileActivityForeground, icon: theme.icons.chatMusicPause, iconInset:NSEdgeInsets(left:0))
            } else {
                progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.fileActivityBackground, foregroundColor: theme.colors.fileActivityForeground, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
            }
        } else {
            progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.fileActivityBackground, foregroundColor: theme.colors.fileActivityForeground, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
        }
    }
    
}
