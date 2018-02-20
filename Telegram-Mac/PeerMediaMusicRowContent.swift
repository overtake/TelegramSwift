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
    fileprivate var textLayout:TextViewLayout?
    fileprivate var file:TelegramMediaFile!
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        super.init(initialSize,interface,account,object)
        
        file = message.media[0] as! TelegramMediaFile
        let attr = NSMutableAttributedString()
        let music = file.musicText
        _ = attr.append(string: music.0, color: theme.colors.text, font: .medium(.header))
        _ = attr.append(string: "\n")
        _ = attr.append(string: music.1, color: theme.colors.grayText, font: .normal(.text))
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 2, truncationType: .middle)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout?.measure(width: width - 70)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaMusicRowView.self
    }
    
}

class PeerMediaMusicRowView : PeerMediaRowView, APDelegate {
    private let textView:TextView = TextView()
    let statusView:RadialProgressView = RadialProgressView()
    
    var fetchStatus: MediaResourceStatus?
    let statusDisposable = MetaDisposable()
    let fetchDisposable = MetaDisposable()
    private(set) var fetchControls:FetchControls!
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(statusView)
        fetchControls = FetchControls(fetch: { [weak self] in
            self?.executeInteraction(true)
        })
        statusView.fetchControls = fetchControls
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerMediaMusicRowItem, let layout = item.textLayout {
            let f = focus(layout.layoutSize)
            textView.update(layout, origin: NSMakePoint(60, f.minY))
            statusView.centerY(x: 10)
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
                if song.entry.isEqual(to: item.message), case .playing = song.state {
                    statusView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPause, iconInset:NSEdgeInsets(left:1))
                } else {
                    statusView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
                }
            } else {
                statusView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
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
                    if let strongSelf = self {
                        strongSelf.fetchStatus = status
                        switch status {
                        case let .Fetching(_, progress):
                            strongSelf.statusView.state = .Fetching(progress: progress, force: false)
                        case .Local, .Remote:
                            strongSelf.statusView.state = .Play
                        }
                    }
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
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: item.account, messageId: item.message.id, file: item.file).start())
        }
        open()
    }
    
    
    func cancelFetching() {
        if let item = item as? PeerMediaMusicRowItem {
            messageMediaFileCancelInteractiveFetch(account: item.account, messageId: item.message.id, file: item.file)
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


