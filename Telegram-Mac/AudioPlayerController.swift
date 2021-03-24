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
    let duration: Int32?
    init(resource:TelegramMediaResource, mimeType: String = "mp3", name:String?, performer:String?, duration: Int32?, id: AnyHashable) {
        self.resource = resource
        self.name = name
        self.mimeType = mimeType
        self.performer = performer
        self.id = id
        self.duration = duration
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
    case playing(current:TimeInterval,duration:TimeInterval, progress:TimeInterval) // current, duration
    case paused(current:TimeInterval,duration:TimeInterval, progress:TimeInterval)
    case stoped
    case fetching(Float)
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
            self.state = .playing(current: status.timestamp, duration: status.duration, progress: progress)
        case .paused:
            self.state = .paused(current: status.timestamp, duration: status.duration, progress: progress)
        default:
            self.state = .paused(current: status.timestamp, duration: status.duration, progress: progress)
        }
        self.status = status
    }
    
    func setProgress(_ progress: TimeInterval) {
        switch status.status {
        case .playing:
            self.state = .playing(current: status.timestamp, duration: status.duration, progress: progress)
        case .paused:
            self.state = .paused(current: status.timestamp, duration: status.duration, progress: progress)
        default:
            break
        }
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
                    songName = forward.authorTitle
                } else if let peer = message.author {
                    if peer.id == account.peerId {
                        songName = localizedString("You");
                    } else {
                        songName = peer.displayTitle
                    }
                } else {
                    songName = ""
                }
                if file.isVoice {
                    performerName = L10n.audioControllerVoiceMessage
                } else {
                    performerName = L10n.audioControllerVideoMessage
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
    
    var isPaused: Bool {
        switch self.state {
        case .paused:
            return true
        default:
            return false
        }
    }
    var isFetching: Bool {
        switch self.state {
        case .fetching:
            return true
        default:
            return false
        }
    }
    
    var reference: MediaResourceReference {
        switch entry {
        case let .song(message):
            return FileMediaReference.message(message: MessageReference(message), media: message.media.first as! TelegramMediaFile).resourceReference(resource)
        default:
            return MediaResourceReference.standalone(resource: resource)
        }
    }
    
    var coverImageMediaReference: ImageMediaReference? {
        if let resource = coverResource {
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(PeerMediaIconSize), resource: resource, progressiveSizes: [])], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            
            switch self.entry {
            case let .song(message):
                return ImageMediaReference.message(message: MessageReference(message), media: image)
            default:
                return ImageMediaReference.standalone(media: image)
            }
        }
        return nil
    }
    
    var coverResource: TelegramMediaResource? {
        switch entry {
        case let .song(message):
            if let file = message.media.first as? TelegramMediaFile {
                if file.previewRepresentations.isEmpty {
                    if ext == "mp3" {
                        return ExternalMusicAlbumArtResource(title: file.musicText.0, performer: file.musicText.1, isThumbnail: true)
                    } else {
                        return nil
                    }
                } else {
                    return file.previewRepresentations.first!.resource
                }
            } else {
                if ext == "mp3" {
                    return ExternalMusicAlbumArtResource(title: songName, performer: performerName, isThumbnail: true)
                } else {
                    return nil
                }
            }
        default:
            if ext == "mp3" {
                return ExternalMusicAlbumArtResource(title: songName, performer: performerName, isThumbnail: true)
            } else {
                return nil
            }
        }
    }

    var duration: Int32? {
        switch entry {
        case let .song(message):
            return (message.media.first as? TelegramMediaFile)?.duration
        case let .single(wrapper):
            return wrapper.duration
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
    
    func isEqual(to messageId: MessageId) -> Bool {
        switch self {
        case let .song(message):
            return message.id == messageId
        case let .single(wrapper):
            if let stableId = wrapper.id.base as? ChatHistoryEntryId {
                switch stableId {
                case let .message(message):
                    return message.id == messageId
                default:
                    break
                }
            }
        }
        return false
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
    func songDidChanged(song:APSongItem, for controller:APController, animated: Bool)
    func songDidChangedState(song:APSongItem, for controller:APController, animated: Bool)
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool)
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool)
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool)
    func audioDidCompleteQueue(for controller:APController, animated: Bool)
}



class APController : NSResponder {

    struct State : Equatable {
        enum Status : Equatable {
            case playing
            case paused
            case waiting
            case stopped
        }
        enum RepeatState {
            case none
            case circle
            case one
        }
        enum OrderState {
            case normal
            case reversed
            case random
        }
        fileprivate(set) var status: Status
        fileprivate(set) var repeatState: RepeatState
        fileprivate(set) var orderState: OrderState
        
        fileprivate(set) var volume: Float
        fileprivate(set) var baseRate: Double
        
        static var `default`:State {
            return State(status: .waiting, repeatState: .none, orderState: .normal, volume: 1, baseRate: 1.0)
        }

    }
    
    private var mediaPlayer: MediaPlayer?
   
    private let statusDisposable = MetaDisposable()
    private let readyDisposable = MetaDisposable()


    private let statePromise = ValuePromise(State.default, ignoreRepeated: true)
    var stateValue: Signal<State, NoError> {
        return statePromise.get()
    }
    private(set) var state: State = State.default {
        didSet {
            statePromise.set(self.state)
            if oldValue != state {
                if oldValue.baseRate != state.baseRate {
                    mediaPlayer?.setBaseRate(state.baseRate)
                }
                if oldValue.volume != state.volume {
                    mediaPlayer?.setVolume(state.volume)
                }
                notifyGlobalStateChanged(animated: true)
            }
        }
    }

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
    fileprivate var played:[Int] = []

    private let bufferingStatusValuePromise = Promise<(IndexSet, Int)?>()
    
    
    private(set) var bufferingStatus: Signal<(IndexSet, Int)?, NoError> {
        set {
           self.bufferingStatusValuePromise.set(newValue)
        }
        get {
            return bufferingStatusValuePromise.get()
        }
    }

    
    fileprivate var timer:SwiftSignalKit.Timer?

    fileprivate var prevNextDisposable = DisposableSet()

    private var _song:APSongItem?
    fileprivate var song:APSongItem? {
        set {
            self.stop()
            _song = newValue
            if let song = newValue {
                songStateDisposable.set((song.stateValue |> distinctUntilChanged).start(next: { [weak self] _ in
                    self?.notifyStateChanged(item: song, animated: true)
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

    func notifyGlobalStateChanged(animated: Bool) {
        if let song = song {
            notifyStateChanged(item: song, animated: animated)
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

    private func notifyStateChanged(item:APSongItem, animated: Bool) {
        for listener in listeners {
            if let value = listener.value as? APDelegate {
                value.songDidChangedState(song: item, for: self, animated: animated)
            }
        }
    }

    private func notifySongChanged(item:APSongItem, animated: Bool) {
        for listener in self.listeners {
            if let value = listener.value as? APDelegate {
                value.songDidChanged(song: item, for: self, animated: animated)
            }
        }
    }

    private func notifySongDidStartPlaying(item:APSongItem,animated: Bool) {
        for listener in self.listeners {
            if let value = listener.value as? APDelegate {
                value.songDidStartPlaying(song: item, for: self, animated: animated)
            }
        }
    }
    private func notifySongDidChangedTimebase(item:APSongItem, animated: Bool) {
        for listener in self.listeners {
            if let value = listener.value as? APDelegate {
                value.playerDidChangedTimebase(song: item, for: self, animated: animated)
            }
        }
    }



    private func notifySongDidStopPlaying(item:APSongItem, animated: Bool) {
        for listener in self.listeners {
            if let value = listener.value as? APDelegate {
                value.songDidStopPlaying(song: item, for: self, animated: animated)
            }
        }
    }

    func notifyCompleteQueue(animated: Bool) {
        for listener in self.listeners {
            if let value = listener.value as? APDelegate {
                value.audioDidCompleteQueue(for: self, animated: animated)
            }
        }
    }

    private let streamable: Bool
    var baseRate: Double {
        set {
            state.baseRate = newValue
        }
        get {
            return state.baseRate
        }
    }
    
    var volume: Float {
        set {
            state.volume = newValue
        }
        get {
            return state.volume
        }
    }
    
    init(context: AccountContext, streamable: Bool, baseRate: Double, volume: Float) {
        self.context = context
        self.state.volume = volume
        self.streamable = streamable
        self.state.baseRate = baseRate
        super.init()
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

        let previous:[APItem] = self.items.modify({$0})
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
        return items.with { $0 }
    }
    
    func nextOrderState() {
        switch self.state.orderState {
        case .normal:
            self.state.orderState = .reversed
        case .reversed:
            self.state.orderState = .random
        case .random:
            self.state.orderState = .normal
        }
    }
    func nextRepeatState() {
        switch self.state.repeatState {
        case .none:
            self.state.repeatState = .circle
        case .circle:
            self.state.repeatState = .one
        case .one:
            self.state.repeatState = .none
        }
    }
    
    var canMakeRepeat: Bool {
        return false
    }
    var canMakeOrder: Bool {
        return false
    }

    func playOrPause() {
        if let _ = song {
            if case .playing = state.status {
                mediaPlayer?.pause()
                state.status = .paused
            } else if case .paused = state.status {
                mediaPlayer?.play()
                state.status = .playing
            } else if state.status == .stopped {
                dequeueCurrent()
            }
        }
    }
    
    func playOrPause(_ id: APSingleWrapper) -> Bool {
        return playOrPause(pullItems.firstIndex(where: { $0.entry.isEqual(to: id) }))
    }
    
    func playOrPause(_ id: MessageId) -> Bool {
        return playOrPause(pullItems.firstIndex(where: { $0.entry.isEqual(to: id) }))
    }

    private func playOrPause(_ index: Int?) -> Bool {
        if let index = index {
            if index != self.current {
                self.current = index
                dequeueCurrent()
            } else {
                playOrPause()
            }
            return true
        } else {
            return false
        }
    }
    
    func pause() -> Bool {
        if let song = song {
            if case  .playing = song.state {
                mediaPlayer?.pause()
                state.status = .paused
                return true
            }
        }
        return false
    }

    func play() -> Bool {
        if let _ = song {
            if case .paused = state.status {
                mediaPlayer?.play()
                state.status = .playing
                return true
            }
        }
        return false
    }
    
    
    func next() {
        if !nextEnabled {
            return
        }
        switch self.state.orderState {
        case .normal:
            if current == 0 {
                current = pullItems.count - 1
            } else {
                current -= 1
            }
        case .reversed:
            if current == pullItems.count - 1 {
                current = 0
            } else {
                current += 1
            }
        case .random:
            played.append(current)
            current = Int.random(in: 0 ..< pullItems.count)
        }
        
        dequeueCurrent()
    }

    func prev() {
        if !prevEnabled {
            return
        }
        switch self.state.orderState {
        case .normal:
            if current == pullItems.count - 1 {
                current = 0
            } else {
                current += 1
            }
        case .reversed:
            if current == 0 {
                current = pullItems.count - 1
            } else {
                current -= 1
            }
        case .random:
            if !played.isEmpty {
                current = played.removeLast()
            } else {
                current = Int.random(in: 0 ..< pullItems.count)
            }
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
        notifyCompleteQueue(animated: true)
        state.status = .stopped
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
            notifySongChanged(item: current, animated: true)
        }
    }


    fileprivate func play(with item:APSongItem) {
        self.mediaPlayer?.seek(timestamp: 0)

        let player = MediaPlayer(postbox: account.postbox, reference: item.reference, streamable: streamable, video: false, preferSoftwareDecoding: false, enableSound: true, baseRate: baseRate, volume: self.volume, fetchAutomatically: false)
        
        player.play()
        state.status = .playing
        player.actionAtEnd = .action({ [weak self] in
            Queue.mainQueue().async {
                self?.audioPlayerDidFinishPlaying()
            }
        })
        
        self.mediaPlayer = player

        
        let size = item.resource.size ?? 0
        bufferingStatus = account.postbox.mediaBox.resourceRangesStatus(item.resource)
            |> map { ranges -> (IndexSet, Int) in
                return (ranges, size)
        }
        
        timebaseDisposable.set((player.timebase |> deliverOnMainQueue).start(next: { [weak self] timebase in
            self?._timebase = timebase
            self?.notifySongDidChangedTimebase(item: item, animated: true)
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
                        let items = strongSelf.items.modify({$0}).filter({$0 is APSongItem}).map{$0 as! APSongItem}
                        if let index = items.firstIndex(of: item) {
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
                        item.state = .fetching(resource.progress)
                    }
                }
            }))
        }
        
    }


    var currentTime: TimeInterval {
        if let current = currentSong {
            switch current.state {
            case let .paused(current, _, _), let .playing(current, _, _):
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
            case let .paused(_, duration, _), let .playing(_, duration, _):
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
        self.stop()

        switch self.state.repeatState {
        case .one:
            self.dequeueCurrent()
        case .none:
            if self.isLatest {
                self.complete()
            } else if needNext && self.nextEnabled {
                self.next()
            } else {
                self.complete()
            }
        case .circle:
            next()
        }
    }


    func audioPlayerDidChangedTimebase(_ audioPLayer: MediaPlayer) {
        if let current = currentSong {
            notifySongDidChangedTimebase(item: current, animated: true)
        }
    }

    func stop() {
      //  player?.stop()
        mediaPlayer = nil
        if let item = song {
            notifySongDidStopPlaying(item: item, animated: false)
        }
        song?.state = .stoped
        stopTimer()
    }

    func set(trackProgress:Float) {
        if let player = mediaPlayer, let song = song {
            let current: Double = song.status.duration * Double(trackProgress)
            player.seek(timestamp: current)
            song.setProgress(TimeInterval(trackProgress))
            notifyStateChanged(item: song, animated: false)
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
                item.state = .playing(current: new, duration: item.status.duration, progress: new / max((item.status.duration), 0.2))
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
        let index = listeners.firstIndex(where: { (weakValue) -> Bool in
            return listener == weakValue.value
        })
        if let index = index {
            listeners.remove(at: index)
        }
    }
}

class APChatController : APController {

    let chatLocationInput:ChatLocationInput
    fileprivate let mode: ChatMode
    private let index:MessageIndex?
    let messages: [Message]
    init(context: AccountContext, chatLocationInput: ChatLocationInput, mode: ChatMode, index: MessageIndex?, streamable: Bool, baseRate: Double = 1.0, volume: Float = 1.0, messages: [Message] = []) {
        self.chatLocationInput = chatLocationInput
        self.mode = mode
        self.index = index
        self.messages = messages
        super.init(context: context, streamable: streamable, baseRate: baseRate, volume: volume)
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
        let chatLocationInput = self.chatLocationInput
        let index = self.index
        let mode = self.mode
        let apply: Signal<APTransition, NoError>
        if messages.isEmpty {
            apply = history.get() |> distinctUntilChanged |> mapToSignal { location -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
                switch mode {
                case .scheduled:
                    return account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput, additionalData: [])
                default:
                    switch location {
                    case .initial:
                        return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, count: 100, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: [], additionalData: [])
                    case let .index(index):
                        return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: 100, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: [], additionalData: [])
                    }
                }
               
                
                } |> map { view -> (APHistory?,APHistory) in
                    var entries:[APEntry] = []
                    for viewEntry in view.0.entries {
                        if let media = viewEntry.message.media.first as? TelegramMediaFile, media.isMusicFile || media.isInstantVideo || media.isVoice {
                            entries.append(.song(viewEntry.message))
                        }
                    }
                    
                    let new = APHistory(original: view.0, filtred: entries)
                    return (list.swap(new),new)
                }
                |> mapToQueue { view -> Signal<APTransition, NoError> in
                    let transition = prepareItems(from: view.0?.filtred, to: view.1.filtred, account: account)
                    return transition
                } |> deliverOnMainQueue
        } else {
            var entries:[APEntry] = []
            for message in messages {
                entries.append(.song(message))
            }
            apply = prepareItems(from: [], to: entries, account: account) |> deliverOnMainQueue
        }
        

        let first:Atomic<Bool> = Atomic(value:true)
        disposable.set(apply.start(next: {[weak self] (transition) in

            let isFirst = first.swap(false)

            self?.merge(with: transition)

            if isFirst {
                if let index = index {
                    let list:[APItem] = items.with { $0 }
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
            let list = items.with({ $0 })
            if let song = self?.song, !list.contains(song) {
                self?.audioPlayerDidFinishPlaying()
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

    init(context: AccountContext, chatLocationInput: ChatLocationInput, mode: ChatMode, index: MessageIndex?, baseRate: Double = 1.0, volume: Float = 1.0, messages: [Message] = []) {
        super.init(context: context, chatLocationInput: chatLocationInput, mode: mode, index: index, streamable: true, baseRate: baseRate, volume: volume, messages: messages)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate override var tags: MessageTags {
        return .music
    }
    
    override var canMakeRepeat: Bool {
        return true
    }
    override var canMakeOrder: Bool {
        return true
    }
}

class APChatVoiceController : APChatController {
    private let markAsConsumedDisposable = MetaDisposable()
    init(context: AccountContext, chatLocationInput: ChatLocationInput, mode: ChatMode, index: MessageIndex?, baseRate: Double = 1.0, volume: Float = 1.0) {
        super.init(context: context, chatLocationInput: chatLocationInput, mode: mode, index:index, streamable: false, baseRate: baseRate, volume: volume)
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


}

class APSingleResourceController : APController {
    let wrapper:APSingleWrapper
    init(context: AccountContext, wrapper:APSingleWrapper, streamable: Bool, baseRate: Double = 1.0, volume: Float = 1.0) {
        self.wrapper = wrapper
        super.init(context: context, streamable: streamable, baseRate: baseRate, volume: volume)
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

    override var needNext: Bool {
        return false
    }
}

