//
//  AudioPlayerController.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit
import AVKit




class APSingleWrapper {
    let resource:TelegramMediaResource
    let name:String?
    let mimeType: String
    let performer:String?
    let id:AnyHashable
    init(resource:TelegramMediaResource, mimeType: String = "mp3", name:String?, performer:String?, id: AnyHashable) {
        self.resource = resource
        self.name = name
        self.mimeType = mimeType
        self.performer = performer
        self.id = id
    }
}

let globalAudioPromise: Promise<APController?> = Promise(nil)

fileprivate(set) var globalAudio:APController? {
    didSet {
        globalAudioPromise.set(.single(globalAudio))
    }
}

enum APState : Equatable {
    case waiting
    case playing(current:TimeInterval,duration:TimeInterval, progress:TimeInterval, animated:Bool) // current, duration
    case paused(current:TimeInterval,duration:TimeInterval, progress:TimeInterval, animated:Bool)
    case stoped
    case fetching(Float, Bool)
}



struct APResource {
    let complete:Bool
    let progress:Float
    let path:String
}

class APItem : Equatable {
    
    private(set) var status: MediaPlayerStatus = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0, dimensions: CGSize(), timestamp: 0, baseRate: 1.0, volume: 1.0, seekId: 0, status: .paused)
    
    func setStatus(_ status: MediaPlayerStatus, rate: Double) {
        
        let status = status.withUpdatedDuration(max(status.duration, self.status.duration))
        
        var progress:TimeInterval = (status.timestamp / status.duration)
        if progress.isNaN {
            progress = 0
        } 
        
        if !progress.isFinite {
            progress = 1.0
        }

        switch status.status {
        case .playing:
            self.state = .playing(current: status.timestamp, duration: status.duration, progress: progress, animated: true)
        case .paused:
            self.state = .paused(current: status.timestamp, duration: status.duration, progress: progress, animated: true)
        default:
            self.state = .paused(current: status.timestamp, duration: status.duration, progress: progress, animated: true)
        }
        self.status = status
    }
    
    private var _state: APState = .waiting
    fileprivate(set) var state:APState {
        get {
            return _state
        }
        set {
            _state = newValue
            _stateValue.set(.single(newValue))
        }
    }

    private let _stateValue:Promise<APState> = Promise()
    var stateValue: Signal<APState, NoError> {
        return _stateValue.get()
    }
    
    let entry:APEntry
    let account:Account
    init(_ entry:APEntry, _ account:Account) {
        self.entry = entry
        self.account = account
    }
    var stableId:ChatHistoryEntryId {
        return .undefined
    }
}

func ==(lhs:APItem, rhs:APItem) -> Bool {
    return lhs.stableId == rhs.stableId
}



class APSongItem : APItem {
    let songName:String
    let performerName:String
    let resource:TelegramMediaResource
    let ext:String
    private let fetchDisposable:MetaDisposable = MetaDisposable()

    override init(_ entry:APEntry, _ account:Account) {
        if case let .song(message) = entry {
            let file = (message.media.first as! TelegramMediaFile)
            resource = file.resource
            if let _ = file.mimeType.range(of: "m4a") {
                self.ext = "m4a"
            } else if let _ = file.mimeType.range(of: "mp4") {
                self.ext = "mp4"
            } else if let ext = file.fileName?.nsstring.pathExtension {
                self.ext = ext
            } else {
                self.ext = "mp3"
            }
            if file.isVoice || file.isInstantVideo {
                if let forward = message.forwardInfo {
                    performerName = forward.authorTitle
                } else if let peer = message.author {
                    if peer.id == account.peerId {
                        performerName = localizedString("You");
                    } else {
                        performerName = peer.displayTitle
                    }
                } else {
                    performerName = ""
                }
                if file.isVoice {
                    songName = tr(L10n.audioControllerVoiceMessage)
                } else {
                    songName = tr(L10n.audioControllerVideoMessage)
                }
            }  else {
                var t:String?
                var p:String?

                for attribute in file.attributes {
                    if case let .Audio(_, _, title, performer, _) = attribute {
                        t = title
                        p = performer
                        break
                    }
                }
                if let t = t {
                    songName = t
                } else {
                    songName = p != nil ? L10n.audioUntitledSong : ""
                }
                if let p = p {
                    performerName = p
                } else {
                    performerName = file.fileName ?? L10n.audioUnknownArtist
                }
            }


        } else if case let .single(wrapper) = entry {
            resource = wrapper.resource
            if let name = wrapper.name {
                songName = name
            } else {
                songName = ""
            }
            if let performer = wrapper.performer {
                performerName = performer
            } else {
                performerName = ""
            }
            if let _ = wrapper.mimeType.range(of: "m4a") {
                self.ext = "m4a"
            } else if let _ = wrapper.mimeType.range(of: "mp4") {
                self.ext = "mp4"
            } else {
                self.ext = "mp3"
            }
        } else {
            fatalError("🤔")
        }
        super.init(entry, account)
    }

    override var stableId: ChatHistoryEntryId {
        return entry.stableId
    }
    
    var reference: MediaResourceReference {
        switch entry {
        case let .song(message):
            return FileMediaReference.message(message: MessageReference(message), media: message.media.first as! TelegramMediaFile).resourceReference(resource)
        default:
            return MediaResourceReference.standalone(resource: resource)
        }
    }

    private func fetch() {
        fetchDisposable.set(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: reference).start())
    }

    private func cancelFetching() {
        fetchDisposable.set(nil)
    }

    deinit {
        fetchDisposable.dispose()
    }

    fileprivate func pullResource()->Signal<APResource, NoError> {
        fetch()
        return account.postbox.mediaBox.resourceStatus(resource) |> deliverOnMainQueue |> mapToSignal { [weak self] status -> Signal<APResource, NoError> in
            if let strongSelf = self {
                let ext = strongSelf.ext
                switch status {
                case .Local:
                    return strongSelf.account.postbox.mediaBox.resourceData(strongSelf.resource) |> filter {$0.complete} |> map { resource -> APResource in
                        return APResource(complete: resource.complete, progress: 1, path: link(path: resource.path, ext: ext)!)
                    }
                case .Remote:
                    return .complete()
                case let .Fetching(_, progress):
                    return .single(APResource(complete: false, progress: progress, path: ""))
                }

            } else {
                return .complete()
            }
        } |> deliverOnMainQueue

    }


}

struct APTransition {
    let inserted:[(Int,APItem)]
    let removed:[Int]
    let updated:[(Int,APItem)]
}

fileprivate func prepareItems(from:[APEntry]?, to:[APEntry], account:Account) -> Signal<APTransition, NoError> {
    return Signal {(subscriber) in
        let (removed, inserted, updated) = proccessEntries(from, right: to, { (entry) -> APItem in
            switch entry {
            case  .song:
                return APSongItem(entry,account)
            case .single:
                return APSongItem(entry,account)
            }

        })
        subscriber.putNext(APTransition(inserted: inserted, removed: removed, updated:updated))
        subscriber.putCompletion()
        return EmptyDisposable

    } |> runOn(prepareQueue)
}

enum APHistoryLocation : Equatable {
    case initial
    case index(MessageIndex)
}

enum APEntry : Comparable, Identifiable {
    case song(Message)
    case single(APSingleWrapper)
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .song(message):
            return message.chatStableId
        case let .single(wrapper):
            if let stableId = wrapper.id.base as? ChatHistoryEntryId {
                return stableId
            }
            return .maybeId(wrapper.id)

        }
    }

    func isEqual(to wrapper:APSingleWrapper) -> Bool {
        return stableId == .maybeId(wrapper.id)
    }

    func isEqual(to message:Message) -> Bool {
        return stableId == message.chatStableId
    }

    var index: MessageIndex {
        switch self {
        case let .song(message):
            return MessageIndex(message)
        case .single(_):
            return MessageIndex.absoluteLowerBound()
        }
    }
}

func ==(lhs:APEntry, rhs:APEntry) -> Bool {
    switch lhs {
    case let .song(lhsMessage):
        if case let .song(rhsMessage) = rhs, lhsMessage.id == rhsMessage.id {
            return true
        } else {
            return false
        }
    case .single(_):
        return false
    }
}

func <(lhs:APEntry, rhs:APEntry) -> Bool {
    return lhs.index < rhs.index
}

private struct APHistory {
    let original:MessageHistoryView
    let filtred:[APEntry]
}

func ==(lhs:APHistoryLocation, rhs:APHistoryLocation) -> Bool {
    switch lhs {
    case .initial:
        if case .initial = rhs {
            return true
        } else {
            return false
        }
    case let .index(lhsIndex):
        if case let .index(rhsIndex) = rhs, lhsIndex == rhsIndex {
            return true
        } else {
            return false
        }
    }
}

protocol APDelegate : class {
    func songDidChanged(song:APSongItem, for controller:APController)
    func songDidChangedState(song:APSongItem, for controller:APController)
    func songDidStartPlaying(song:APSongItem, for controller:APController)
    func songDidStopPlaying(song:APSongItem, for controller:APController)
    func playerDidChangedTimebase(song:APSongItem, for controller:APController)
    func audioDidCompleteQueue(for controller:APController)
}



class APController : NSResponder {

    private var mediaPlayer: MediaPlayer?
   
    private let statusDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()



    public let ready:Promise<Bool> = Promise()
    let context: AccountContext
    
    var account: Account {
        return context.account
    }
    
    private var _timebase: CMTimebase?

    fileprivate let history:Promise<APHistoryLocation> = Promise()
    fileprivate let entries:Atomic<APHistory?> = Atomic(value:nil)
    fileprivate let items:Atomic<[APItem]> = Atomic(value:[])
    fileprivate let disposable:MetaDisposable = MetaDisposable()

    fileprivate let itemDisposable:MetaDisposable = MetaDisposable()
    fileprivate let songStateDisposable:MetaDisposable = MetaDisposable()
    fileprivate let timebaseDisposable:MetaDisposable = MetaDisposable()
    private var listeners:[WeakReference<NSObject>] = []

   // fileprivate var player:AudioPlayer?
    fileprivate var current:Int = -1
    
    private let bufferingStatusValuePromise = Promise<(IndexSet, Int)?>()
    
    
    private(set) var bufferingStatus: Signal<(IndexSet, Int)?, NoError> {
        set {
           self.bufferingStatusValuePromise.set(newValue)
        }
        get {
            return bufferingStatusValuePromise.get()
        }
    }

    
    fileprivate(set) var needRepeat:Bool = false

    fileprivate var timer:SwiftSignalKit.Timer?

    fileprivate var prevNextDisposable = DisposableSet()

    private var _song:APSongItem?
    fileprivate var song:APSongItem? {
        set {
            self.stop()
            _song = newValue
            if let song = newValue {
                songStateDisposable.set((song.stateValue |> distinctUntilChanged).start(next: {[weak self] (state) in
                    if let strongSelf = self {
                        strongSelf.notifyStateChanged(item: song)
                    }
                }))
            } else {
                songStateDisposable.set(nil)
            }
        }
        get {
            return _song
        }
    }

    var timebase:CMTimebase? {
        return _timebase//self.player?.timebase
    }

    func notifyGlobalStateChanged() {
        if let song = song {
            notifyStateChanged(item: song)
        }
    }

    var isPlaying: Bool {
        if let currentSong = currentSong {
            switch currentSong.state {
            case .playing:
                return true
            default:
                return false
            }
        }
        return false
    }

    var isDownloading: Bool {
        if let currentSong = currentSong {
            switch currentSong.state {
            case .fetching:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func notifyStateChanged(item:APSongItem) {
        for listener in listeners {
            if let value = listener.value as? APDelegate {
                value.songDidChangedState(song: item, for: self)
            }
        }
    }

    private func notifySongChanged(item:APSongItem) {
        Queue.mainQueue().async {
            for listener in self.listeners {
                if let value = listener.value as? APDelegate {
                    value.songDidChanged(song: item, for: self)
                }
            }
        }
    }

    private func notifySongDidStartPlaying(item:APSongItem) {
        Queue.mainQueue().async {
            for listener in self.listeners {
                if let value = listener.value as? APDelegate {
                    value.songDidStartPlaying(song: item, for: self)
                }
            }
        }
    }
    private func notifySongDidChangedTimebase(item:APSongItem) {
        Queue.mainQueue().async {
            for listener in self.listeners {
                if let value = listener.value as? APDelegate {
                    value.playerDidChangedTimebase(song: item, for: self)
                }
            }
        }
    }



    private func notifySongDidStopPlaying(item:APSongItem) {
        Queue.mainQueue().async {
            for listener in self.listeners {
                if let value = listener.value as? APDelegate {
                    value.songDidStopPlaying(song: item, for: self)
                }
            }
        }
    }

    func notifyCompleteQueue() {
        Queue.mainQueue().async {
            for listener in self.listeners {
                if let value = listener.value as? APDelegate {
                    value.audioDidCompleteQueue(for: self)
                }
            }
        }
    }

    private let streamable: Bool
    var baseRate: Double {
        didSet {
            mediaPlayer?.setBaseRate(baseRate)
        }
    }
    
    var volume: Float = FastSettings.volumeRate {
        didSet {
            mediaPlayer?.setVolume(volume)
        }
    }
    
    init(context: AccountContext, streamable: Bool, baseRate: Double) {
        self.context = context
        self.streamable = streamable
        self.baseRate = baseRate
        super.init()

//        readyDisposable.set((ready.get() |> filter {$0} |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
//
//        }))
    }

    @objc open func windowDidBecomeKey() {
        
    }


    @objc open func windowDidResignKey() {
       
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        globalAudio?.stop()
        globalAudio?.cleanup()

        globalAudio = self
    }


    fileprivate func merge(with transition:APTransition) {

        var previous:[APItem] = self.items.modify({$0})
        let current = self.current
        let items = self.items.modify { items -> [APItem] in
            var new:[APItem] = items
            for rdx in transition.removed.reversed() {
                new.remove(at: rdx)
            }
            for (idx,item) in transition.inserted {
                new.insert(item, at: idx)
            }
            for (idx,item) in transition.updated {
                new[idx] = item
            }
            return new
        }

        if current != -1, current >= 0 {
            if current < previous.count {
                let previousCurrent = previous[current]
                var foundIndex:Int? = nil
                for i in 0 ..< items.count {
                    if previousCurrent.stableId == items[i].stableId {
                        foundIndex = i
                        break
                    }
                }
                if let foundIndex = foundIndex {
                    self.current = foundIndex
                } else {
                    if pullItems.isEmpty {
                        self.stop()
                        self.complete()
                    } else {
                        self.next()
                    }
                }
            }
        }

    }

    fileprivate var pullItems:[APItem] {
        return items.modify({$0})
    }

    func toggleRepeat() {
        needRepeat = !needRepeat
    }

    var needLoop:Bool {
        return true
    }

    func next() {
        if !nextEnabled {
            return
        }
        if current == 0 {
            current = pullItems.count - 1
        } else {
            current -= 1
        }
        dequeueCurrent()
    }

    func playOrPause() {
        if let song = song {
            if case  .playing = song.state {
               // player?.pause()
                mediaPlayer?.pause()
            } else if case .paused = song.state {
                //player?.play()
                mediaPlayer?.play()
            } else if song.state == .stoped {
                dequeueCurrent()
            }
        }
    }

    func pause() -> Bool {
        if let song = song {
            if case  .playing = song.state {
               // player?.pause()
                mediaPlayer?.pause()
                return true
            }
        }
        return false
    }

    func play() -> Bool {
        if let song = song {
            if case .paused = song.state {
              //  player?.play()
                mediaPlayer?.play()
                return true
            }
        }
        return false
    }

    func prev() {
        if !prevEnabled {
            return
        }
        if current == pullItems.count - 1 {
            current = 0
        } else {
            current += 1
        }
        dequeueCurrent()
    }

    var nextEnabled:Bool {
        return pullItems.count > 1
    }


    var prevEnabled:Bool {
        return pullItems.count > 1
    }

    var needNext:Bool {
        return true
    }

    func complete() {
        notifyCompleteQueue()
        cleanup()
    }

    var currentSong:APSongItem? {
        if !pullItems.isEmpty, pullItems.count > current, let song = pullItems[max(0, current)] as? APSongItem {
            return song
        }
        return nil
    }

    fileprivate func dequeueCurrent() {
        if let current = currentSong {
            self.song = current
            play(with: current)
            notifySongChanged(item: current)
        }
    }


    fileprivate func play(with item:APSongItem) {
        

        self.mediaPlayer?.seek(timestamp: 0)

        let player = MediaPlayer(postbox: account.postbox, reference: item.reference, streamable: streamable, video: false, preferSoftwareDecoding: false, enableSound: true, baseRate: baseRate, volume: self.volume, fetchAutomatically: false)
        
        player.play()

        player.actionAtEnd = .action({ [weak self] in
             self?.audioPlayerDidFinishPlaying()
        })
        
        self.mediaPlayer = player

        
        let size = item.resource.size ?? 0
        bufferingStatus = account.postbox.mediaBox.resourceRangesStatus(item.resource)
            |> map { ranges -> (IndexSet, Int) in
                return (ranges, size)
        }
        
        timebaseDisposable.set((player.timebase |> deliverOnMainQueue).start(next: { [weak self] timebase in
            self?._timebase = timebase
            self?.notifySongDidChangedTimebase(item: item)
        }))

        self.statusDisposable.set((player.status |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let `self` = self else {return}
            item.setStatus(status, rate: self.baseRate)
            switch status.status {
            case .paused:
                self.stopTimer()
            case .playing:
                self.startTimer()
            default:
                self.stopTimer()
            }
            self.updateUIAfterTick(status)
        }))

//
        if !streamable {
            itemDisposable.set(item.pullResource().start(next: { [weak self] resource in
                if let strongSelf = self {
                    if resource.complete {
                        //                    strongSelf.player = .player(for: resource.path)
                        //                    strongSelf.player?.delegate = strongSelf
                        //                    strongSelf.player?.play()
                        
                        
                        let items = strongSelf.items.modify({$0}).filter({$0 is APSongItem}).map{$0 as! APSongItem}
                        if let index = items.index(of: item) {
                            let previous = index - 1
                            let next = index + 1
                            if previous >= 0 {
                                strongSelf.prevNextDisposable.add(fetchedMediaResource(mediaBox: strongSelf.account.postbox.mediaBox, reference: items[previous].reference, statsCategory: .audio).start())
                            }
                            if next < items.count {
                                strongSelf.prevNextDisposable.add(fetchedMediaResource(mediaBox: strongSelf.account.postbox.mediaBox, reference: items[next].reference, statsCategory: .audio).start())
                            }
                        }
                        
                    } else {
                        item.state = .fetching(resource.progress,true)
                    }
                }
            }))
        }
        
    }


    var currentTime: TimeInterval {
        if let current = currentSong {
            switch current.state {
            case let .paused(current, _, _, _), let .playing(current, _, _, _):
                return current
            default:
                break
            }
        }
        return 0//self.player?.currentTime ?? 0
    }

    var duration: TimeInterval {
        if let current = currentSong {
            switch current.state {
            case let .paused(_, duration, _, _), let .playing(_, duration, _, _):
                return duration
            default:
                break
            }
        }
        return 0//self.player?.currentTime ?? 0
    }

    var isLatest:Bool {
        return current == 0
    }

    func audioPlayerDidFinishPlaying() {
        Queue.mainQueue().async {
            self.stop()
            
            if self.needRepeat {
                self.dequeueCurrent()
            } else if self.needNext && self.nextEnabled {
                if self.isLatest {
                    if self.needLoop {
                        self.next()
                    } else {
                        self.complete()
                    }
                } else {
                    self.next()
                }
            } else {
                self.complete()
            }
        }
    }


    func audioPlayerDidChangedTimebase(_ audioPLayer: MediaPlayer) {
        if let current = currentSong {
            notifySongDidChangedTimebase(item: current)
        }
    }

    func stop() {
      //  player?.stop()
        mediaPlayer = nil
        if let item = song {
            notifySongDidStopPlaying(item: item)
        }
        song?.state = .stoped
        stopTimer()
    }

    func set(trackProgress:Float) {
        if let player = mediaPlayer, let song = song {
            let current: Double = song.status.duration * Double(trackProgress)
            player.seek(timestamp: current)
//            if case .paused = song.state {
//                var progress:TimeInterval = (current / song.status.duration)
//                if progress.isNaN {
//                    progress = 1
//                }
//               // song.state = .playing(current: current, duration: song.status.duration, progress: progress, animated: false)
//               // song.state = .paused(current: current, duration: song.status.duration, progress: progress, animated: false)
//            }
        }
    }

    func cleanup() {
        listeners.removeAll()
        globalAudio = nil
        mainWindow.applyResponderIfNeeded()
        stop()
    }

    private func updateUIAfterTick(_ status: MediaPlayerStatus) {
        
    }


    private func startTimer() {
        var additional: Double = 0.2
        let duration: TimeInterval = 0.2
        timer = SwiftSignalKit.Timer(timeout: duration, repeat: true, completion: { [weak self] in
            if let `self` = self, let item = self.song {
                let new = item.status.timestamp + additional * item.status.baseRate
                item.state = .playing(current: new, duration: item.status.duration, progress: new / max((item.status.duration), 0.2), animated: true)
                additional += duration 
                self.updateUIAfterTick(item.status)
            }
        }, queue: Queue.mainQueue())
        timer?.start()
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        disposable.dispose()
        itemDisposable.dispose()
        songStateDisposable.dispose()
        prevNextDisposable.dispose()
        readyDisposable.dispose()
        statusDisposable.dispose()
        timebaseDisposable.dispose()
    }

    fileprivate var tags:MessageTags {
        return .music
    }

    func add(listener:NSObject) {
        listeners.append(WeakReference(value: listener))
    }

    func remove(listener:NSObject) {
        let index = listeners.index(where: { (weakValue) -> Bool in
            return listener == weakValue.value
        })
        if let index = index {
            listeners.remove(at: index)
        }
    }
}

class APChatController : APController {

    private let peerId:PeerId
    private let index:MessageIndex?

    init(context: AccountContext, peerId: PeerId, index: MessageIndex?, streamable: Bool, baseRate: Double = 1.0) {
        self.peerId = peerId
        self.index = index
        super.init(context: context, streamable: streamable, baseRate: baseRate)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func start() {
        super.start()
        let tagMask:MessageTags = self.tags
        let list = self.entries
        let items = self.items
        let account = self.context.account
        let peerId = self.peerId
        let index = self.index
        let apply = history.get() |> distinctUntilChanged |> mapToSignal { location -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
            switch location {
            case .initial:
                return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, count: 100, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: [], additionalData: [])
            case let .index(index):
                return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: 100, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: [], additionalData: [])
            }

        } |> map { view -> (APHistory?,APHistory) in
            var entries:[APEntry] = []
            for viewEntry in view.0.entries {
                entries.append(.song(viewEntry.message))
            }

            let new = APHistory(original: view.0, filtred: entries)
            return (list.swap(new),new)
        }
        |> mapToQueue { view -> Signal<APTransition, NoError> in
            let transition = prepareItems(from: view.0?.filtred, to: view.1.filtred, account: account)
            return transition
        } |> deliverOnMainQueue

        let first:Atomic<Bool> = Atomic(value:true)
        disposable.set(apply.start(next: {[weak self] (transition) in

            let isFirst = first.swap(false)

            self?.merge(with: transition)

            if isFirst {
                if let index = index {
                    let list:[APItem] = items.modify({$0})
                    for i in 0 ..< list.count {
                        if list[i].entry.index == index {
                            self?.current = i
                            break
                        }
                    }
                }

                self?.dequeueCurrent()
                self?.ready.set(.single(true))
            }

        }))

        if let index = index {
            history.set(.single(.index(index)) |> delay(0.1, queue: Queue.mainQueue()))
        } else {
            history.set(.single(.initial) |> delay(0.1, queue: Queue.mainQueue()))
        }
    }
}

class APChatMusicController : APChatController {

    init(context: AccountContext, peerId: PeerId, index: MessageIndex?, baseRate: Double = 1.0) {
        super.init(context: context, peerId: peerId, index: index, streamable: true, baseRate: baseRate)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate override var tags: MessageTags {
        return .music
    }
}

class APChatVoiceController : APChatController {
    private let markAsConsumedDisposable = MetaDisposable()
    init(context: AccountContext, peerId: PeerId, index: MessageIndex?, baseRate: Double = 1.0) {
        super.init(context: context, peerId: peerId, index:index, streamable: false, baseRate: baseRate)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var nextEnabled: Bool {
        return current > 0
    }

    override var prevEnabled: Bool {
        return current < pullItems.count - 1
    }

    override func play(with item: APSongItem) {
        super.play(with: item)
        markAsConsumedDisposable.set(markMessageContentAsConsumedInteractively(postbox: account.postbox, messageId: item.entry.index.id).start())
    }

    deinit {
        markAsConsumedDisposable.dispose()
    }

    fileprivate override var tags: MessageTags {
        return .voiceOrInstantVideo
    }

    override var needLoop:Bool {
        return false
    }

}

class APSingleResourceController : APController {
    let wrapper:APSingleWrapper
    init(context: AccountContext, wrapper:APSingleWrapper, streamable: Bool, baseRate: Double = 1.0) {
        self.wrapper = wrapper
        super.init(context: context, streamable: streamable, baseRate: baseRate)
        merge(with: APTransition(inserted: [(0,APSongItem(.single(wrapper), account))], removed: [], updated: []))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func start() {
        super.start()
        ready.set(.single(true))
        dequeueCurrent()
    }

    override var needLoop:Bool {
        return false
    }

    override var needNext: Bool {
        return false
    }
}

