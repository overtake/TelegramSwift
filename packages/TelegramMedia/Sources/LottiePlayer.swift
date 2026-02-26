import SwiftSignalKit
import Postbox
import TGUIKit
import Metal
import TelegramCore
import GZIP
import libwebp
import Accelerate
import QuartzCore
import TelegramMediaPlayer
import CoreMedia

public protocol R_LottieBridge: NSObject {
    func renderFrame(with index: Int32, into buffer: UnsafeMutablePointer<UInt8>, width: Int32, height: Int32, bytesPerRow: Int32)
    func startFrame() -> Int32
    func endFrame() -> Int32
    func fps() -> Int32
    func setColor(_ color: NSColor, forKeyPath keyPath: String)
}

public var makeRLottie:((String, String)->R_LottieBridge?)? = nil


final class RenderAtomic<T> {
    private var lock: pthread_mutex_t
    private var value: T
    
    public init(value: T) {
        self.lock = pthread_mutex_t()
        self.value = value
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    public func with<R>(_ f: (T) -> R) -> R {
        pthread_mutex_lock(&self.lock)
        let result = f(self.value)
        pthread_mutex_unlock(&self.lock)
        
        return result
    }
    
    public func modify(_ f: (T) -> T) -> T {
        pthread_mutex_lock(&self.lock)
        let result = f(self.value)
        self.value = result
        pthread_mutex_unlock(&self.lock)
        
        return result
    }
    
    public func swap(_ value: T) -> T {
        pthread_mutex_lock(&self.lock)
        let previous = self.value
        self.value = value
        pthread_mutex_unlock(&self.lock)
        
        return previous
    }
}


public let lottieThreadPool: ThreadPool = ThreadPool(threadCount: 4, threadPriority: 1.0)
public let lottieStateQueue = Queue(name: "lottieStateQueue", qos: .default)



public enum LottiePlayerState : Equatable {
    case initializing
    case failed
    case playing
    case stoped
    case finished
}

public protocol RenderedFrame {
    var duration: TimeInterval { get }
    var data: Data? { get }
    var image: CGImage? { get }
    var backingScale: Int { get }
    var size: NSSize { get }
    var key: LottieAnimationEntryKey { get }
    var frame: Int32 { get }
    var mirror: Bool { get }
    var bytesPerRow: Int { get }
}

final class RenderedWebpFrame : RenderedFrame, Equatable {
    
    let frame: Int32
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    private let webpData: WebPImageFrame
    let _image: CGImage?
    init(key: LottieAnimationEntryKey, frame: Int32, size: NSSize, webpData: WebPImageFrame, backingScale: Int) {
        self.key = key
        self.backingScale = backingScale
        self.size = size
        self.frame = frame
        self.webpData = webpData
        _image = webpData.image?._cgImage
    }
    
    var bytesPerRow: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        return DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
    }
    
    var image: CGImage? {
        return _image
    }
    var duration: TimeInterval {
        return webpData.duration
    }
    var data: Data? {
        return nil
    }
    var mirror: Bool {
        return key.mirror
    }
    static func == (lhs: RenderedWebpFrame, rhs: RenderedWebpFrame) -> Bool {
        return lhs.key == rhs.key
    }
}

private let loops = RenderFpsLoops()

private struct RenderFpsToken : Hashable {
    
    struct LoopToken : Hashable {
        let duration: Double
        let queue: Queue
        static func ==(lhs: LoopToken, rhs: LoopToken) -> Bool {
            return lhs.duration == rhs.duration && lhs.queue === rhs.queue
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(duration)
        }
    }
    
    func deinstall() {
        loops.remove(token: self)
    }
    func install(_ callback:@escaping()->Void) {
        loops.add(token: self, callback: callback)
    }
    
    private let index: Int
    let value: LoopToken
    
    
    init(duration: Double, queue: Queue, index: Int) {
        self.value = .init(duration: duration, queue: queue)
        self.index = index
    }
    

    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.value)
        hasher.combine(self.index)
    }
}

private final class RenderFpsLoops {
    private let loops:Atomic<[RenderFpsToken.LoopToken: RenderFpsLoop]> = Atomic(value: [:])
    private var index: Int = 0
    init() {
        
    }
    
    func getIndex() -> Int {
        self.index += 1
        return index
    }
    
    func add(token: RenderFpsToken, callback:@escaping()->Void) {
        let current: RenderFpsLoop
        if let value = self.loops.with({ $0[token.value] }) {
            current = value
        } else {
            current = RenderFpsLoop(duration: token.value.duration, queue: token.value.queue)
            _ = self.loops.modify { value in
                var value = value
                value[token.value] = current
                return value
            }
        }
        current.add(token, callback: callback)
    }
    func remove(token: RenderFpsToken) {
        _ = self.loops.modify { loops in
            var loops = loops
            let loop = loops[token.value]
            if let loop = loop {
                let isEmpty = loop.remove(token)
                if isEmpty {
                    loops.removeValue(forKey: token.value)
                }
            }
            return loops
        }
    }
}


private struct RenderFpsCallback {
    let callback:()->Void
    init(callback: @escaping()->Void) {
        self.callback = callback
    }
}
private final class RenderFpsLoop {
    
    private class Values {
        var values: [RenderFpsToken: RenderFpsCallback] = [:]
    }
    
    private let duration: Double
    private var timer: SwiftSignalKit.Timer?
    private let values:QueueLocalObject<Values>
    private let queue: Queue
    init(duration: Double, queue: Queue) {
        
        
        self.duration = duration
        self.queue = queue
        self.values = .init(queue: queue, generate: {
            return .init()
        })
        
        self.timer = .init(timeout: duration, repeat: true, completion: { [weak self] in
            self?.loop()
        }, queue: queue)
        
        self.timer?.start()
    }
    
    private func loop() {
        
                
        self.values.with { current in
            let values = current.values
            for (_, c) in values {
                c.callback()
            }
        }
    }
    
    func remove(_ token: RenderFpsToken) -> Bool {
        return self.values.syncWith { current in
            current.values.removeValue(forKey: token)
            return current.values.isEmpty
        }
    }
    
    func add(_ token: RenderFpsToken, callback: @escaping()->Void) {
        self.values.with { current in
            current.values[token] = .init(callback: callback)
        }
    }
}


final class RenderedWebmFrame : RenderedFrame, Equatable {
    
    let _image: CGImage?
    let frame: Int32
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    private let _data: Data
    private let fps: Int
    init(key: LottieAnimationEntryKey, frame: Int32, fps: Int, size: NSSize, data: Data, backingScale: Int) {
        self.key = key
        self.backingScale = backingScale
        self.size = size
        self.frame = frame
        self._data = data
        self.fps = fps
        
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
        let bufferSize = s.h * bytesPerRow
        
        _image = data.withUnsafeBytes { pointer in
            let bytes = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)

            let mutableBytes = UnsafeMutableRawPointer(mutating: bytes)
            var buffer = vImage_Buffer(data: mutableBytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: bytesPerRow)
                       
            if key.mirror {
                vImageHorizontalReflect_ARGB8888(&buffer, &buffer, vImage_Flags(kvImageDoNotTile))
            }
            return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
                memcpy(pixelData, mutableBytes, bufferSize)
            })
        }
    }
    
    var bytesPerRow: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        return DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
    }
    
    var image: CGImage? {
        return _image
    }
    var duration: TimeInterval {
        return 1.0 / Double(self.fps)
    }
    var bufferSize: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)

        return s.h * bytesPerRow
    }
    var data: Data? {
        return _data
    }
    var mirror: Bool {
        return key.mirror
    }
    static func == (lhs: RenderedWebmFrame, rhs: RenderedWebmFrame) -> Bool {
        return lhs.key == rhs.key
    }
    
    deinit {
        
    }
}


final class RenderedLottieFrame : RenderedFrame, Equatable {
    let frame: Int32
    let data: Data?
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    let fps: Int
    let initedOnMain: Bool
    
    let _image: CGImage?
    init(key: LottieAnimationEntryKey, fps: Int, frame: Int32, size: NSSize, data: Data, backingScale: Int) {
        self.key = key
        self.frame = frame
        self.size = size
        self.data = data
        self.backingScale = backingScale
        self.fps = fps
        self.initedOnMain = Thread.isMainThread
        
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
        let bufferSize = s.h * bytesPerRow
        
        _image = data.withUnsafeBytes({ pointer in
            let bytes = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
                
                let mutableBytes = UnsafeMutableRawPointer(mutating: bytes)
                var buffer = vImage_Buffer(data: mutableBytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: bytesPerRow)
                           
                if key.mirror {
                    vImageHorizontalReflect_ARGB8888(&buffer, &buffer, vImage_Flags(kvImageDoNotTile))
                }
                
                memcpy(pixelData, mutableBytes, bufferSize)
            })
        })
    }
    static func ==(lhs: RenderedLottieFrame, rhs: RenderedLottieFrame) -> Bool {
        return lhs.frame == rhs.frame
    }
    var bufferSize: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        return s.h * bytesPerRow
    }
    
    var bytesPerRow: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
        return bytesPerRow
    }
    var mirror: Bool {
        return key.mirror
    }
    var duration: TimeInterval {
        return 1.0 / Double(self.fps)
    }
    var image: CGImage? {
        return _image
    }
    
    
    deinit {

    }
}


private final class RendererState  {
    fileprivate let animation: LottieAnimation
    private(set) var frames: [RenderedFrame]
    private(set) var previousFrame:RenderedFrame?
    private(set) var cachedFrames:[Int32 : RenderedFrame]
    private(set) var currentFrame: Int32
    private(set) var startFrame:Int32
    private(set) var _endFrame: Int32
    private(set) var cancelled: Bool
    private(set) weak var container: RenderContainer?
    private(set) var renderIndex: Int32?
    init(cancelled: Bool, animation: LottieAnimation, container: RenderContainer?, frames: [RenderedLottieFrame], cachedFrames: [Int32 : RenderedLottieFrame], currentFrame: Int32, startFrame: Int32, endFrame: Int32) {
        self.animation = animation
        self.cancelled = cancelled
        self.container = container
        self.frames = frames
        self.cachedFrames = cachedFrames
        self.currentFrame = currentFrame
        self.startFrame = startFrame
        self._endFrame = endFrame
    }
    
    var endFrame: Int32 {
        return container?.endFrame ?? _endFrame
    }
    
    func withUpdatedFrames(_ frames: [RenderedFrame]) {
        self.frames = frames
    }
    func addFrame(_ frame: RenderedFrame) {
        let prev = frame.frame == 0 ? nil : self.frames.last ?? previousFrame
        self.container?.cacheFrame(prev, frame)
        self.frames = self.frames + [frame]
    }
    
    func loopComplete() {
        self.container?.markFinished()
    }
    
    func updateCurrentFrame(_ currentFrame: Int32) {
        self.currentFrame = currentFrame
    }

    func takeFirst() -> RenderedFrame {
        var frames = self.frames
        if frames.first?.frame == endFrame {
            self.previousFrame = nil
        } else {
            self.previousFrame = frames.last
        }
        let prev = frames.removeFirst()
        self.renderIndex = prev.frame
        self.frames = frames
        return prev
    }
    
    func renderFrame(at frame: Int32) -> RenderedFrame? {
        let rendered = container?.render(at: frame, frames: frames, previousFrame: previousFrame)
        return rendered
    }
    
    deinit {
        
    }
    
    func cancel() -> RendererState {
        self.cancelled = true
        
        return self
    }
}

public final class LottieSoundEffect {
    private let player: MediaPlayer
    let triggerOn: Int32?
    
    private(set) var isPlayable: Bool = false
    
    public init(file: TelegramMediaFile, postbox: Postbox, triggerOn: Int32?) {
        self.player = MediaPlayer(postbox: postbox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.standalone(resource: file.resource), streamable: false, video: false, preferSoftwareDecoding: false, enableSound: true, baseRate: 1.0, fetchAutomatically: true)
        self.triggerOn = triggerOn
    }
    public func play() {
        if isPlayable {
            self.player.play()
            isPlayable = false
        }
    }
    
    public func markAsPlayable() -> Void {
        isPlayable = true
    }
}

protocol Renderer {
    func render(at frame: Int32) -> RenderedFrame
}

private let maximum_rendered_frames: Int = 4
private final class PlayerRenderer {
    
    private var soundEffect: LottieSoundEffect?
    
    private(set) var finished: Bool = false
    private var animation: LottieAnimation
    private var layer: Atomic<RenderContainer?> = Atomic(value: nil)
    private let updateState:(LottiePlayerState)->Void
    private let displayFrame: (RenderedFrame, LottieRunLoop)->Void
    private var renderToken: RenderFpsToken?
    private let release:()->Void
    private var maxRefreshRate: Int = 60
    init(animation: LottieAnimation, displayFrame: @escaping(RenderedFrame, LottieRunLoop)->Void, release:@escaping()->Void, updateState:@escaping(LottiePlayerState)->Void) {
        self.animation = animation
        self.displayFrame = displayFrame
        self.updateState = updateState
        self.release = release
        self.soundEffect = animation.soundEffect
    }
    
    private var onDispose: (()->Void)?
    deinit {
        self.renderToken?.deinstall()
        self.onDispose?()
        _ = self.layer.swap(nil)
        self.release()
        self.updateState(.stoped)
    }
    
    
    func initializeAndPlay(maxRefreshRate: Int) {
        self.maxRefreshRate = maxRefreshRate
        self.updateState(.initializing)
        assert(animation.runOnQueue.isCurrent())
        
        let container = self.animation.initialize()
        
        if let container = container {
            self.play(self.layer.modify({_ in container })!)
        } else {
            self.updateState(.failed)
        }
    }
    
    func playAgain() {
        self.layer.with { container -> Void in
            if let container = container {
                self.play(container)
            }
        }
    }
    
    func playSoundEffect() {
        self.soundEffect?.markAsPlayable()
    }
    
    func updateSize(_ size: NSSize) {
        self.animation = self.animation.withUpdatedSize(size)
    }
    
    func setColors(_ colors: [LottieColor]) {
        self.layer.with { container -> Void in
            for color in colors {
                container?.setColor(color.color, keyPath: color.keyPath)
            }
        }
    }
    
    private var getCurrentFrame:()->Int32? = { return nil }
    var currentFrame: Int32? {
        return self.getCurrentFrame()
    }
    private var getTotalFrames:()->Int32? = { return nil }
    var totalFrames: Int32? {
        return self.getTotalFrames()
    }
    private var jumpTo:(Int32)->Void = { _ in }
    func jump(to frame: Int32) -> Void {
        self.jumpTo(frame)
    }
    
    private func play(_ player: RenderContainer) {
        
        
        self.finished = false
        
        let runOnQueue = animation.runOnQueue
        
        let maximum_renderer_frames: Int = Thread.isMainThread ? 2 : maximum_rendered_frames
        
        let fps: Int = max(1, min(player.fps, max(30, maxRefreshRate)))
        let mainFps: Int = player.mainFps
        
        let maxFrames:Int32 = 180
        var currentFrame: Int32 = 0
        var startFrame: Int32 = min(min(player.startFrame, maxFrames), min(player.endFrame, maxFrames))
        var endFrame: Int32 = min(player.endFrame, maxFrames)
        switch self.animation.playPolicy {
        case let .loopAt(firstStart, range):
            startFrame = range.lowerBound
            endFrame = range.upperBound
            if let firstStart = firstStart {
                currentFrame = firstStart
            }
        case let .toEnd(from):
            startFrame = max(min(from, endFrame - 1), startFrame)
            currentFrame = max(min(from, endFrame - 1), startFrame)
        case let .toStart(from):
            startFrame = 1
            
            currentFrame = max(min(from, endFrame - 1), startFrame)
        default:
            break
        }
        
        let initialState = RendererState(cancelled: false, animation: self.animation, container: player, frames: [], cachedFrames: [:], currentFrame: currentFrame, startFrame: startFrame, endFrame: endFrame)
        
        var stateValue:RenderAtomic<RendererState?>? = RenderAtomic(value: initialState)
        let updateState:(_ f:(RendererState?)->RendererState?)->Void = { [weak stateValue] f in
            _ = stateValue?.modify(f)
        }
        
        self.getCurrentFrame = { [weak stateValue] in
            return stateValue?.with { $0?.renderIndex }
        }
        self.getTotalFrames = { [weak stateValue] in
            return stateValue?.with { $0?.endFrame }
        }
        
        self.jumpTo = { [weak stateValue] frame in
            _ = stateValue?.with { state in
                state?.updateCurrentFrame(frame)
            }
        }
        
        var framesTask: ThreadPoolTask? = nil
        
        let isRendering: Atomic<Bool> = Atomic(value: false)
        
        self.onDispose = {
            updateState {
                $0?.cancel()
            }
            framesTask?.cancel()
            framesTask = nil
            _ = stateValue?.swap(nil)
            stateValue = nil
        }
        
        let currentState:(_ state: RenderAtomic<RendererState?>?) -> RendererState? = { state in
            return state?.with { $0 }
        }
        
        var renderNext:(()->Void)? = nil
        
        var add_frames_impl:(()->Void)? = nil
        var askedRender: Bool = false
        var playedCount: Int32 = 0
        var loopCount: Int32 = 0
        var previousFrame: Int32 = 0
        var currentPlayerState: LottiePlayerState? = nil
        
        let render:()->Void = { [weak self, weak stateValue] in
            var hungry: Bool = false
            var cancelled: Bool = false
            if let renderer = self {
                var current: RenderedFrame?
                updateState { stateValue in
                    guard let state = stateValue, !state.frames.isEmpty else {
                        return stateValue
                    }
                    current = state.takeFirst()
                    hungry = state.frames.count < maximum_renderer_frames - 1
                    cancelled = state.cancelled
                    return state
                }
                
                
                if !cancelled {
                    if let current = current {
                        let displayFrame = renderer.displayFrame
                        let updateState = renderer.updateState
                        displayFrame(current, .init(fps: fps))
                        playedCount += 1
                        if current.frame > 0 {
                            if currentPlayerState != .playing {
                                updateState(.playing)
                                currentPlayerState = .playing
                            }
                        }
                        
                        if previousFrame > current.frame {
                            loopCount += 1
                        }
                        
                        previousFrame = current.frame
                        
                        if let soundEffect = renderer.soundEffect {
                            if let triggerOn = soundEffect.triggerOn {
                                let triggers:[Int32] = [triggerOn - 1, triggerOn, triggerOn + 1]
                                if triggers.contains(current.frame) {
                                    soundEffect.play()
                                }
                            } else {
                                if current.frame == 0 {
                                    soundEffect.play()
                                }
                            }
                        }
                        if let triggerOn = renderer.animation.triggerOn {
                            switch triggerOn.0 {
                            case .first:
                                if currentState(stateValue)?.startFrame == current.frame {
                                    DispatchQueue.main.async(execute: triggerOn.1)
                                }
                            case .last:
                                if endFrame - 2 == current.frame {
                                    DispatchQueue.main.async(execute: triggerOn.1)
                                }
                            case let .custom(index):
                                if index == current.frame {
                                    DispatchQueue.main.async(execute: triggerOn.1)
                                }
                            }
                            
                        }
                        
                        let finish:()->Void = {
                            renderer.finished = true
                            cancelled = true
                            if currentPlayerState != .finished {
                                updateState(.finished)
                                currentPlayerState = .finished
                            }
                            renderer.renderToken?.deinstall()
                            framesTask?.cancel()
                            let onFinish = renderer.animation.onFinish ?? {}
                            DispatchQueue.main.async(execute: onFinish)
                        }
                        
                        switch renderer.animation.playPolicy {
                        case .loop, .loopAt:
                            break
                        case .once:
                            if current.frame + 1 == currentState(stateValue)?.endFrame {
                                finish()
                            }
                        case .onceEnd, .toEnd:
                            let end = fps == 60 ? 1 : 2
                            if let state = currentState(stateValue), state.endFrame - current.frame <= end  {
                                finish()
                            }
                        case .toStart:
                            if current.frame <= 1, playedCount > 1 {
                                finish()
                            }
                        case let .framesCount(limit):
                            if limit <= playedCount {
                                finish()
                            }
                        case let .onceToFrame(frame):
                            if frame <= current.frame  {
                                finish()
                            }
                        case let .playCount(count):
                            if loopCount >= count {
                                finish()
                            }
                        }
                        
                    }
                    if !renderer.finished {
                        let duration = current?.duration ?? (1.0 / TimeInterval(fps))
                        if duration > 0, (renderer.totalFrames ?? 0) > 1 {
                            let token = RenderFpsToken(duration: duration, queue: runOnQueue, index: loops.getIndex())
                            if renderer.renderToken != token {
                                renderer.renderToken?.deinstall()
                                token.install {
                                    renderNext?()
                                }
                                renderer.renderToken = token
                            }
                        }
                        
                    }
                }
                let isRendering = isRendering.with { $0 }
                if hungry && !isRendering && !cancelled && !askedRender {
                    askedRender = true
                    add_frames_impl?()
                }
            }
            
        }
        
        renderNext = {
            render()
        }
        
        var firstTimeRendered: Bool = true
        
        let maximum = Int(initialState.endFrame - initialState.startFrame)
        framesTask = ThreadPoolTask { [weak stateValue] state in
            _ = isRendering.swap(true)
            _ = stateValue?.with { stateValue -> RendererState? in
                while let stateValue = stateValue, stateValue.frames.count < min(maximum_renderer_frames, maximum) {
                    let cancelled = state.cancelled.with({$0})
                    if cancelled {
                        return stateValue
                    }
                    
                    var currentFrame = stateValue.currentFrame
                    let frame = stateValue.renderFrame(at: currentFrame)
                    
                    if mainFps >= fps {
                        if currentFrame % Int32(round(Float(mainFps) / Float(fps))) != 0 {
                            currentFrame += 1
                        }
                    }

                    if let frame = frame {
                        stateValue.updateCurrentFrame(currentFrame + 1)
                        stateValue.addFrame(frame)
                    } else {
                        if stateValue.startFrame != currentFrame {
                            stateValue.updateCurrentFrame(stateValue.startFrame)
                            stateValue.loopComplete()
                        } else {
                            break
                        }
                    }
                }
                return stateValue
            }
            _ = isRendering.swap(false)
            runOnQueue.async {
                askedRender = false
                if firstTimeRendered {
                    firstTimeRendered = false
                    render()
                }
            }
        }
        
        let add_frames:()->Void = {
            if let framesTask = framesTask {
                if Thread.isMainThread {
                    framesTask.execute()
                } else {
                    lottieThreadPool.addTask(framesTask)
                }
            }
        }
        
        add_frames_impl = {
            add_frames()
        }
        add_frames()
        
    }
    
}

public final class AnimationPlayerContext {
    private let rendererRef: QueueLocalObject<PlayerRenderer>
    fileprivate let animation: LottieAnimation
    public init(_ animation: LottieAnimation, maxRefreshRate: Int = 60, displayFrame: @escaping(RenderedFrame, LottieRunLoop)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) {
        self.animation = animation
        self.rendererRef = QueueLocalObject(queue: animation.runOnQueue, generate: {
            return PlayerRenderer(animation: animation, displayFrame: displayFrame, release: release, updateState: { state in
                delay(0.032, closure: {
                    updateState(state)
                })
            })
        })
        
        self.rendererRef.with { renderer in
            renderer.initializeAndPlay(maxRefreshRate: maxRefreshRate)
        }
    }
    
    public func playAgain() {
        self.rendererRef.with { renderer in
            if renderer.finished {
                renderer.playAgain()
            }
        }
    }
    
    public func setColors(_ colors: [LottieColor]) {
        self.rendererRef.with { renderer in
            renderer.setColors(colors)
        }
    }
    
    public func playSoundEffect() {
        self.rendererRef.with { renderer in
            renderer.playSoundEffect()
        }
    }
    public func updateSize(_ size: NSSize) {
        self.rendererRef.syncWith { renderer in
            renderer.updateSize(size)
        }
    }
    public var currentFrame:Int32? {
        var currentFrame:Int32? = nil
        self.rendererRef.syncWith { renderer in
            currentFrame = renderer.currentFrame
        }
        return currentFrame
    }
    public var totalFrames:Int32? {
        var totalFrames:Int32? = nil
        self.rendererRef.syncWith { renderer in
            totalFrames = renderer.totalFrames
        }
        return totalFrames
    }
    
    public func jump(to frame: Int32) -> Void {
        self.rendererRef.with { renderer in
            renderer.jump(to: frame)
        }
    }
}


public enum ASLiveTime : Int {
    case chat = 3_600
    case thumb = 259200
    case effect = 241_920 // 7 days
}

public enum ASCachePurpose {
    case none
    case temporaryLZ4(ASLiveTime)
}

public struct LottieAnimationEntryKey : Hashable {
    public let size: CGSize
    public let backingScale: Int
    public let key:LottieAnimationKey
    public let fitzModifier: EmojiFitzModifier?
    public let colors: [LottieColor]
    public let mirror: Bool
    public init(key: LottieAnimationKey, size: CGSize, backingScale: Int = Int(System.backingScale), fitzModifier: EmojiFitzModifier? = nil, colors: [LottieColor] = [], mirror: Bool = false) {
        self.key = key
        self.size = size
        self.backingScale = backingScale
        self.fitzModifier = fitzModifier
        self.colors = colors
        self.mirror = mirror
    }
    
    public func withUpdatedColors(_ colors: [LottieColor]) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
    }
    public func withUpdatedBackingScale(_ backingScale: Int) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
    }
    public func withUpdatedSize(_ size: CGSize) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(size.width)
        hasher.combine(size.height)
        hasher.combine(backingScale)
        hasher.combine(key)
        if let fitzModifier = fitzModifier {
            hasher.combine(fitzModifier)
        }
        for color in colors {
            hasher.combine(color.keyPath)
            hasher.combine(color.color.argb)
        }
        hasher.combine(mirror)
    }
}

public enum LottieAnimationKey : Hashable {
    case media(MediaId?)
    case bundle(String)
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .bundle(value):
            hasher.combine("bundle")
            hasher.combine(value)
        case let .media(mediaId):
            hasher.combine("media")
            if let mediaId = mediaId {
                hasher.combine(mediaId)
            }
        }
    }
}

public enum LottiePlayPolicy : Hashable {
    case loop
    case loopAt(firstStart:Int32?, range: ClosedRange<Int32>)
    case once
    case onceEnd
    case toEnd(from: Int32)
    case toStart(from: Int32)
    case framesCount(Int32)
    case onceToFrame(Int32)
    case playCount(Int32)
    
    
    public static func ==(lhs: LottiePlayPolicy, rhs: LottiePlayPolicy) -> Bool {
        switch lhs {
        case .loop:
            if case .loop = rhs {
                return true
            }
        case let .loopAt(firstStart, range):
            if case .loopAt(firstStart, range) = rhs {
                return true
            }
        case .once:
            if case .once = rhs {
                return true
            }
        case .onceEnd:
            if case .onceEnd = rhs {
                return true
            }
        case .toEnd:
            if case .toEnd = rhs {
                return true
            }
        case .toStart:
            if case .toStart = rhs {
                return true
            }
        case let .framesCount(count):
            if case .framesCount(count) = rhs {
                return true
            }
        case let .onceToFrame(count):
            if case .onceToFrame(count) = rhs {
                return true
            }
        case .playCount:
            if case .playCount = rhs {
                return true
            }
        }
        return false
    }

}

public struct LottieColor : Equatable {
    public let keyPath: String
    public let color: NSColor
    public init(keyPath: String, color: NSColor) {
        self.keyPath = keyPath
        self.color = color
    }
}

public enum LottiePlayerTriggerFrame : Equatable {
    case first
    case last
    case custom(Int32)
}

public protocol RenderContainer : AnyObject {
    func render(at frame: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame?
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame)
    func markFinished()
    func setColor(_ color: NSColor, keyPath: String)
    
    var endFrame: Int32 { get }
    var startFrame: Int32 { get }
    
    var fps: Int { get }
    var mainFps: Int { get }

}

private final class WebPRenderer : RenderContainer {
    
    private let animation: LottieAnimation
    private let decoder: WebPImageDecoder
    
    init(animation: LottieAnimation, decoder: WebPImageDecoder) {
        self.animation = animation
        self.decoder = decoder
    }
    
    func render(at frame: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame? {
        if let webpFrame = self.decoder.frame(at: UInt(frame), decodeForDisplay: true) {
            return RenderedWebpFrame(key: animation.key, frame: frame, size: animation.size, webpData: webpFrame, backingScale: animation.backingScale)
        } else {
            return nil
        }
    }
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame) {
        
    }
    func markFinished() {
        
    }
    func setColor(_ color: NSColor, keyPath: String) {
        
    }
    var endFrame: Int32 {
        return Int32(decoder.frameCount)
    }
    var startFrame: Int32 {
        return 0
    }
    var fps: Int {
        return 1
    }
    var mainFps: Int {
        return 1
    }
}

private final class WebmRenderer : RenderContainer {
    
    private let animation: LottieAnimation
    private let decoder: SoftwareVideoSource
    
    
    private var index: Int32 = 1
    
    private let fileSupplyment: TRLotFileSupplyment?

    init(animation: LottieAnimation, decoder: SoftwareVideoSource, fileSupplyment: TRLotFileSupplyment?) {
        self.animation = animation
        self.decoder = decoder
        self.fileSupplyment = fileSupplyment
    }

    func render(at frameIndex: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame? {
        
        let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
        
        if let fileSupplyment = fileSupplyment {
            let previous = frameIndex == startFrame ? nil : frames.last ?? previousFrame
            if let data = fileSupplyment.readFrame(previous: previous?.data, frame: Int(frameIndex)) {
                return RenderedWebmFrame(key: animation.key, frame: frameIndex, fps: self.fps, size: animation.size, data: data, backingScale: animation.backingScale)
            }
            if fileSupplyment.isFinished {
                return nil
            }
        }

        let frameAndLoop = decoder.readFrame(maxPts: nil)
        if frameAndLoop.0 == nil {
            return nil
        }
        
        guard let frame = frameAndLoop.0 else {
            return nil
        }
        
        self.index += 1
                
        func processFrame(frame: MediaTrackFrame, s: (w: Int, h: Int)) -> Data? {
            let destBytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
            let bufferSize = s.h * destBytesPerRow
            
            var destData = Data(count: bufferSize)
            
            let result = destData.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) -> Bool in
                guard let destBaseAddress = destBytes.baseAddress else { return false }
                let destBufferPointer = destBaseAddress.assumingMemoryBound(to: UInt8.self)
                
                guard let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer) else { return false }
                CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                
                let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                let width = CVPixelBufferGetWidth(imageBuffer)
                let height = CVPixelBufferGetHeight(imageBuffer)
                guard let srcData = CVPixelBufferGetBaseAddress(imageBuffer) else {
                    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                    return false
                }
                
                var sourceBuffer = vImage_Buffer(data: srcData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: sourceBytesPerRow)
                var destBuffer = vImage_Buffer(data: destBufferPointer, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: destBytesPerRow)
                
                let error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageDoNotTile))
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                
                return error == kvImageNoError
            }
            
            return result ? destData : nil
        }
        
        if let data = processFrame(frame: frame, s: s) {
            return RenderedWebmFrame(key: animation.key, frame: frameIndex, fps: self.fps, size: animation.size, data: data, backingScale: animation.backingScale)
        } else {
            return nil
        }
    }
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame) {
        if let fileSupplyment = fileSupplyment {
            fileSupplyment.addFrame(previous?.data, (current.data!, current.frame))
        }
    }
    func markFinished() {
        fileSupplyment?.markFinished()
    }
    func setColor(_ color: NSColor, keyPath: String) {
        
    }
    var endFrame: Int32 {
        return Int32(60)
    }
    var startFrame: Int32 {
        return 0
    }
    var fps: Int {
        return min(30, decoder.getFramerate())
    }
    var mainFps: Int {
        return 1
    }
}


private final class LottieRenderer : RenderContainer {
    
    private let animation: LottieAnimation
    private let bridge: R_LottieBridge?
    private let fileSupplyment: TRLotFileSupplyment?
    
    init(animation: LottieAnimation, bridge: R_LottieBridge?, fileSupplyment: TRLotFileSupplyment?) {
        self.animation = animation
        self.bridge = bridge
        self.fileSupplyment = fileSupplyment
    }
    var fps: Int {
        return max(min(Int(bridge?.fps() ?? fileSupplyment?.fps ?? 60), self.animation.maximumFps), 24)
    }
    var mainFps: Int {
        return Int(bridge?.fps() ?? fileSupplyment?.fps ?? 60)
    }
    var endFrame: Int32 {
        return bridge?.endFrame() ?? fileSupplyment?.endFrame ?? 0
    }
    var startFrame: Int32 {
        return bridge?.startFrame() ?? fileSupplyment?.startFrame ?? 0
    }
    
    func setColor(_ color: NSColor, keyPath: String) {
        self.bridge?.setColor(color, forKeyPath: keyPath)
    }
    
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame) {
        if let fileSupplyment = fileSupplyment {
            fileSupplyment.addFrame(previous?.data, (current.data!, current.frame))
        }
    }
    func markFinished() {
        fileSupplyment?.markFinished()
    }
    func render(at frame: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame? {
        let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
        
        var data: Data?

        if let fileSupplyment = fileSupplyment {
            let previous = frame == startFrame ? nil : frames.last ?? previousFrame
            if let frame = fileSupplyment.readFrame(previous: previous?.data, frame: Int(frame)) {
                data = frame
            }
        }
        if frame > endFrame {
            return nil
        }
        if data == nil {
            func renderFrame(s: (w: Int, h: Int), bridge: R_LottieBridge?, frame: Int32) -> Data? {
                let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
                let bufferSize = s.h * bytesPerRow

                var data = Data(count: bufferSize)
                
                let result = data.withUnsafeMutableBytes { (frameData: UnsafeMutableRawBufferPointer) -> Bool in
                    guard let baseAddress = frameData.baseAddress else { return false }
                    let frameDataPointer = baseAddress.assumingMemoryBound(to: UInt8.self)
                    
                    bridge?.renderFrame(with: frame, into: frameDataPointer, width: Int32(s.w), height: Int32(s.h), bytesPerRow: Int32(bytesPerRow))
                    return true
                }
                
                return result ? data : nil
            }

            data = renderFrame(s: s, bridge: bridge, frame: frame)
        }
        
        
        if let data = data {
            return RenderedLottieFrame(key: animation.key, fps: fps, frame: frame, size: animation.size, data: data, backingScale: self.animation.backingScale)
        }
        
        return nil
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

public enum LottieAnimationType {
    case lottie
    case webp
    case webm
}

public final class LottieAnimation : Equatable {
    public static func == (lhs: LottieAnimation, rhs: LottieAnimation) -> Bool {
        return lhs.key == rhs.key && lhs.playPolicy == rhs.playPolicy && lhs.colors == rhs.colors
    }
    
    public let type: LottieAnimationType
    
    public var liveTime: Int {
        switch cache {
        case .none:
            return 0
        case let .temporaryLZ4(liveTime):
            return liveTime.rawValue
        }
    }
    
    public var supportsMetal: Bool {
        switch type {
        case .lottie:
            return self.metalSupport
        case .webm:
            return false
        default:
            return false
        }
    }
    
    public let compressed: Data
    public let key: LottieAnimationEntryKey
    public let cache: ASCachePurpose
    public let maximumFps: Int
    public let playPolicy: LottiePlayPolicy
    public let colors:[LottieColor]
    public let soundEffect: LottieSoundEffect?
    public let metalSupport: Bool
    public let postbox: Postbox?
    public let runOnQueue: Queue
    public var onFinish:(()->Void)?

    public var triggerOn:(LottiePlayerTriggerFrame, ()->Void, ()->Void)? {
        didSet {
            var bp = 0
            bp += 1
        }
    }

    
    public init(compressed: Data, key: LottieAnimationEntryKey, type: LottieAnimationType = .lottie, cachePurpose: ASCachePurpose = .temporaryLZ4(.thumb), playPolicy: LottiePlayPolicy = .loop, maximumFps: Int = 60, colors: [LottieColor] = [], soundEffect: LottieSoundEffect? = nil, postbox: Postbox? = nil, runOnQueue: Queue = lottieStateQueue, metalSupport: Bool = false) {
        self.compressed = compressed
        self.key = key.withUpdatedColors(colors)
        self.cache = cachePurpose
        self.maximumFps = maximumFps
        self.playPolicy = playPolicy
        self.colors = colors
        self.postbox = postbox
        self.soundEffect = soundEffect
        self.runOnQueue = runOnQueue
        self.type = type
        self.metalSupport = metalSupport
    }
    
    public var size: NSSize {
        let size = key.size
        return size
    }
    public var viewSize: NSSize {
        return key.size
    }
    public var backingScale: Int {
        return key.backingScale
    }
    
    public func withUpdatedBackingScale(_ scale: Int) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedBackingScale(scale), type: self.type, cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: self.colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedColors(_ colors: [LottieColor]) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key, type: self.type, cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedPolicy(_ playPolicy: LottiePlayPolicy) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key, type: self.type, cachePurpose: self.cache, playPolicy: playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedSize(_ size: CGSize) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedSize(size), type: self.type, cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    
    var cacheKey: String {
        switch key.key {
        case let .media(id):
            if let id = id {
                if let fitzModifier = key.fitzModifier {
                    return "animation-\(id.namespace)-\(id.id)-\(key.mirror)-fitz\(fitzModifier.rawValue)" + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
                } else {
                    return "animation-\(id.namespace)-\(id.id)-\(key.mirror)" + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
                }
            } else {
                return "\(arc4random())"
            }
        case let .bundle(string):
            return string + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
        }
    }
    
    var bufferSize: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        let bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)

        return s.h * bytesPerRow
    }
    
    
    public func initialize() -> RenderContainer? {
        switch type {
        case .lottie:
            let decompressed = TGGUnzipData(self.compressed, 8 * 1024 * 1024)
            let data: Data?
            if let decompressed = decompressed {
                data = decompressed
            } else {
                data = self.compressed
            }
            if let data = data, !data.isEmpty {
                
                let fileSupplyment: TRLotFileSupplyment?
                switch self.cache {
                case .temporaryLZ4:
                    fileSupplyment = TRLotFileSupplyment(self, bufferSize: bufferSize, queue: Queue())
                case .none:
                    fileSupplyment = nil
                }
                
                if fileSupplyment?.isFinished == true {
                    return LottieRenderer(animation: self, bridge: nil, fileSupplyment: fileSupplyment)
                } else {
                    let modified: Data
                    if let color = self.colors.first(where: { $0.keyPath == "" }) {
                        modified = applyLottieColor(data: data, color: color.color)
                    } else {
                        modified = transformedWithFitzModifier(data: data, fitzModifier: self.key.fitzModifier)
                    }
                   
                    if let json = String(data: modified, encoding: .utf8) {
                        if let bridge = makeRLottie?(json, self.cacheKey) {
                            for color in self.colors {
                                bridge.setColor(color.color, forKeyPath: color.keyPath)
                            }
                            fileSupplyment?.initialize(fps: bridge.fps(), startFrame: bridge.startFrame(), endFrame: bridge.endFrame())
                            return LottieRenderer(animation: self, bridge: bridge, fileSupplyment: fileSupplyment)
                        }
                    }
                }
            }
        case .webp:
            let decompressed = TGGUnzipData(self.compressed, 8 * 1024 * 1024)
            let data: Data?
            if let decompressed = decompressed {
                data = decompressed
            } else {
                data = self.compressed
            }
            if let data = data, !data.isEmpty {
                if let decoder = WebPImageDecoder(data: data, scale: CGFloat(backingScale)) {
                    return WebPRenderer(animation: self, decoder: decoder)
                }
            }
        case .webm:
            let path = String(data: self.compressed, encoding: .utf8)
            if let path = path {
                let premultiply = (DeviceGraphicsContextSettings.shared.opaqueBitmapInfo.rawValue & CGImageAlphaInfo.premultipliedFirst.rawValue) == 0
                let decoder = SoftwareVideoSource(path: path, hintVP9: true, unpremultiplyAlpha: premultiply)
                let fileSupplyment: TRLotFileSupplyment?
                if size.width > 40 {
                    switch self.cache {
                    case .temporaryLZ4:
                        fileSupplyment = TRLotFileSupplyment(self, bufferSize: bufferSize, queue: Queue())
                    case .none:
                        fileSupplyment = nil
                    }
                } else {
                    fileSupplyment = nil
                }
                return WebmRenderer(animation: self, decoder: decoder, fileSupplyment: fileSupplyment)
            }
        }
        return nil
    }
}

private struct RenderLoopItem {
    weak private(set) var view: MetalRenderer?
    let frame: RenderedFrame
    
    func render(_ commandBuffer: MTLCommandBuffer) -> MTLDrawable? {
        return view?.draw(frame: frame, commandBuffer: commandBuffer)
    }
}


private class Loops {
    
    
    var data: [LottieRunLoop : Loop] = [:]
    
    func add(_ view: MetalRenderer, frame: RenderedFrame, runLoop: LottieRunLoop, commandQueue: MTLCommandQueue) {
        let loop = getLoop(runLoop, commandQueue: commandQueue)
        loop.append(.init(view: view, frame: frame))
    }
    func clean() {
        data.removeAll()
    }
    private func getLoop(_ runLoop: LottieRunLoop, commandQueue: MTLCommandQueue) -> Loop {
        var loop: Loop
        if let c = data[runLoop] {
            loop = c
        } else {
            loop = Loop(runLoop, commandQueue: commandQueue)
            data[runLoop] = loop
        }
        return loop
    }
}

private final class Loop {
    var list:[RenderLoopItem] = []
    
    private let commandQueue: MTLCommandQueue

    private var timer: SwiftSignalKit.Timer?
    init(_ runLoop: LottieRunLoop, commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
        self.timer = SwiftSignalKit.Timer(timeout: 1 / TimeInterval(runLoop.fps), repeat: true, completion: { [weak self] in
            self?.renderItems()
        }, queue: lottieStateQueue)
        
        self.timer?.start()
    }
    
    private func renderItems() {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        if let commandBuffer = commandBuffer {
            var drawables: [MTLDrawable] = []
            while !self.list.isEmpty {
                let item = self.list.removeLast()
                let drawable = item.render(commandBuffer)
                if let drawable = drawable {
                    drawables.append(drawable)
                }
            }
            
            if drawables.isEmpty {
                return
            }

            commandBuffer.addScheduledHandler { _ in
                for drawable in drawables {
                    drawable.present()
                }
            }
            commandBuffer.commit()
        } else {
            self.list.removeAll()
        }
    }
    
    func append(_ item: RenderLoopItem) {
        self.list.append(item)
    }
    
}


final class MetalContext {
    
  
    
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    let sampler: MTLSamplerState
    let commandQueue: MTLCommandQueue?
    let displayId: CGDirectDisplayID
    let refreshRate: Int
    private var loops: QueueLocalObject<Loops>
    
    init?() {
        self.loops = QueueLocalObject(queue: lottieStateQueue, generate: {
            return Loops()
        })
        self.displayId = CGMainDisplayID()
        self.refreshRate = 60
        if let device = CGDirectDisplayCopyCurrentMetalDevice(displayId) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
        } else {
            return nil
        }
        do {
            let library = device.makeDefaultLibrary()
            
            let fragmentProgram = library?.makeFunction(name: "basic_fragment")
            let vertexProgram = library?.makeFunction(name: "basic_vertex")
            
            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexProgram
            pipelineStateDescriptor.fragmentFunction = fragmentProgram
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            
            
            let vertexData: [Float] = [
                -1.0, -1.0, 0.0, 0.0, 1.0,
                -1.0, 1.0, 0.0, 0.0, 0.0,
                1.0, -1.0, 0.0, 1.0, 1.0,
                1.0, -1.0, 0.0, 1.0, 1.0,
                -1.0, 1.0, 0.0, 0.0, 0.0,
                1.0, 1.0, 0.0, 1.0, 0.0
            ]
            
            let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
            self.vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
            
            let sampler = MTLSamplerDescriptor()
            sampler.minFilter             = MTLSamplerMinMagFilter.nearest
            sampler.magFilter             = MTLSamplerMinMagFilter.nearest
            sampler.mipFilter             = MTLSamplerMipFilter.nearest
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.clampToZero
            sampler.tAddressMode          = MTLSamplerAddressMode.clampToZero
            sampler.rAddressMode          = MTLSamplerAddressMode.clampToZero
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0.0
            sampler.lodMaxClamp           = .greatestFiniteMagnitude
            self.sampler = device.makeSamplerState(descriptor: sampler)!
            
        } catch {
            return nil
        }
    }
    
    func cleanLoops() {
        self.loops.with { loops in
            loops.clean()
        }
    }
    
    fileprivate func add(_ view: MetalRenderer, frame: RenderedFrame, runLoop: LottieRunLoop, commandQueue: MTLCommandQueue) {
        self.loops.with { loops in
            loops.add(view, frame: frame, runLoop: runLoop, commandQueue: commandQueue)
        }
    }
}

private var metalContext: MetalContext?


private final class ContextHolder {
    private var useCount: Int = 0
    
    let context: MetalContext
    init?() {
        
        if metalContext == nil {
            metalContext = MetalContext()
        } else if metalContext?.displayId != CGMainDisplayID() {
            metalContext = MetalContext()
        }
        
        guard let context = metalContext else {
            return nil
        }
        self.context = context
    }
    func incrementUseCount() {
        assert(Queue.mainQueue().isCurrent())
        useCount += 1
    }
    func decrementUseCount() {
        assert(Queue.mainQueue().isCurrent())
        useCount -= 1
        assert(useCount >= 0)
        
        if shouldRelease() {
            holder = nil
            metalContext?.cleanLoops()
        }
    }
    func shouldRelease() -> Bool {
        return useCount == 0
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
    }
}

private var holder: ContextHolder?


public struct LottieRunLoop : Hashable {
    public let fps: Int
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fps)
    }
}

private final class MetalRenderer: View {
    private let texture: MTLTexture
    private let metalLayer: CAMetalLayer = CAMetalLayer()
    private let context: MetalContext
    init(animation: LottieAnimation, context: MetalContext) {
        self.context = context
        let textureDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(animation.size.width) * animation.backingScale, height: Int(animation.size.height) * animation.backingScale, mipmapped: false)
        textureDesc.sampleCount = 1
        textureDesc.textureType = .type2D
        
        self.texture = context.device.makeTexture(descriptor: textureDesc)!
        
        super.init(frame: NSMakeRect(0, 0, animation.viewSize.width, animation.viewSize.height))
        
        self.metalLayer.device = context.device
        self.metalLayer.framebufferOnly = true
        self.metalLayer.isOpaque = false
        self.metalLayer.contentsScale = backingScaleFactor
        self.wantsLayer = true
        self.layer?.addSublayer(metalLayer)
        metalLayer.frame = CGRect(origin: CGPoint(), size: animation.viewSize)
        holder?.incrementUseCount()
    }
    
    override func layout() {
        super.layout()
        metalLayer.frame = self.bounds
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    deinit {
        holder?.decrementUseCount()
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        self.metalLayer.contentsScale = backingScaleFactor
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func draw(frame: RenderedFrame, commandBuffer: MTLCommandBuffer) -> MTLDrawable? {
        
        guard let drawable = metalLayer.nextDrawable(), let data = frame.data else {
            return nil
        }
        return data.withUnsafeBytes { pointer in
            let bytes = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let size: NSSize = frame.size
            let backingScale: Int = frame.backingScale
            
            let region = MTLRegionMake2D(0, 0, Int(size.width) * backingScale, Int(size.height) * backingScale)
            
            self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: Int(size.width) * backingScale * 4)
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                   
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            renderEncoder.setRenderPipelineState(self.context.pipelineState)
            renderEncoder.setVertexBuffer(self.context.vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(self.texture, index: 0)
            renderEncoder.setFragmentSamplerState(self.context.sampler, index: 0)
            
            var mirror = frame.mirror
            
            renderEncoder.setFragmentBytes(&mirror, length: MemoryLayout<Bool>.size, index: 0)
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
            
            renderEncoder.endEncoding()
                    
            return drawable
        }
    }

    
    func render(frame: RenderedFrame, runLoop: LottieRunLoop) {
        guard let commandQueue = self.context.commandQueue else {
            return
        }
        self.context.add(self, frame: frame, runLoop: runLoop, commandQueue: commandQueue)
    }
}

private final class LottieFallbackView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}

open class LottiePlayerView : View {
    private var context: AnimationPlayerContext?
    private var _ignoreCachedContext: Bool = false
    private let _currentState: Atomic<LottiePlayerState> = Atomic(value: .initializing)
    public var currentState: LottiePlayerState {
        return _currentState.with { $0 }
    }
    
    private let stateValue: ValuePromise<LottiePlayerState> = ValuePromise(.initializing, ignoreRepeated: true)
    public var state: Signal<LottiePlayerState, NoError> {
        return stateValue.get()
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    public required override init() {
        super.init()
    }
    
    private var temporary: LottieAnimation?
    public func updateVisible() {
        if self.visibleRect == .zero {
            self.temporary = self.animation
        } else {
            if let temporary = temporary {
                self.set(temporary)
            }
            self.temporary = nil
        }
    }
    
    public var animation: LottieAnimation?
    
    public var contextAnimation: LottieAnimation? {
        return context?.animation
    }
    
    public override var isFlipped: Bool {
        return true
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        update(size: newSize, transition: .immediate)
    }
    
    public func update(size: NSSize, transition: ContainedViewLayoutTransition) {
        for subview in subviews {
            transition.updateFrame(view: subview, frame: size.bounds)
        }
        if let sublayers = layer?.sublayers {
            for sublayer in sublayers {
                transition.updateFrame(layer: sublayer, frame: size.bounds)
            }
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    public required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidChangeBackingProperties() {
        if let context = context {
            self.set(context.animation.withUpdatedBackingScale(Int(backingScaleFactor)))
        }
    }
    
    public func playIfNeeded(_ playSound: Bool = false) {
        if let context = self.context, context.animation.playPolicy == .once {
            context.playAgain()
            if playSound {
                context.playSoundEffect()
            }
        } else {
            context?.playSoundEffect()
        }
    }
    
    public func playAgain() {
        self.context?.playAgain()
    }
    
    public var currentFrame: Int32? {
        if _ignoreCachedContext {
            return nil
        }
        if let context = self.context {
            return context.currentFrame
        } else {
            return nil
        }
    }
    
    public func ignoreCachedContext() {
        _ignoreCachedContext = true
    }
    
    public var totalFrames: Int32? {
        if _ignoreCachedContext {
            return nil
        }
        if let context = self.context {
            return context.totalFrames
        } else {
            return nil
        }
    }
    
    public func setColors(_ colors: [LottieColor]) {
        context?.setColors(colors)
    }
    
    
    
    public func set(_ animation: LottieAnimation?, reset: Bool = false, saveContext: Bool = false, animated: Bool = false) {
        assertOnMainThread()
        _ignoreCachedContext = false
        
        self.animation = animation
        
        if animation == nil {
            self.temporary = nil
        }
        
        var accept: Bool = true
        switch animation?.playPolicy {
        case let.framesCount(count):
            accept = count != 0
        default:
            break
        }
        
        if let animation = animation, accept {
            
            
            
            self.stateValue.set(self._currentState.modify { _ in .initializing })
            if self.context?.animation != animation || reset {
                if !animation.runOnQueue.isCurrent() && animation.supportsMetal {
                    if holder == nil {
                        holder = ContextHolder()
                    }
                } else {
                    holder = nil
                }
                
                if let holder = holder {
                    let metal = MetalRenderer(animation: animation, context: holder.context)
                    self.addSubview(metal)
                    let layer = Unmanaged.passRetained(metal)
                    
                    
                    var cachedContext:Unmanaged<AnimationPlayerContext>?
                    if let context = self.context, saveContext {
                        cachedContext = Unmanaged.passRetained(context)
                    }  else  {
                        cachedContext = nil
                    }
                    
                    self.context = AnimationPlayerContext(animation, maxRefreshRate: holder.context.refreshRate, displayFrame: { frame, runLoop in
                        layer.takeUnretainedValue().render(frame: frame, runLoop: runLoop)
                    }, release: {
                        delay(0.032, closure: {
                            layer.takeRetainedValue().removeFromSuperview()
                            _ = cachedContext?.takeRetainedValue()
                            cachedContext = nil
                        })
                        
                    }, updateState: { [weak self] state in
                        guard let `self` = self else {
                            return
                        }
                        switch state {
                        case .playing, .failed, .stoped:
                            _ = cachedContext?.takeRetainedValue()
                            cachedContext = nil
                        default:
                            break
                        }
                        self.stateValue.set(self._currentState.modify { _ in state } )
                    })
                } else {
                    let fallback = SimpleLayer()
                    fallback.frame = CGRect(origin: CGPoint(), size: self.frame.size)
                    fallback.contentsGravity = .resize
                    self.layer?.addSublayer(fallback)
                    if animated {
                        fallback.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    let layer = Unmanaged.passRetained(fallback)
                    
                    self.context = AnimationPlayerContext(animation, displayFrame: { frame, _ in
                        let image = frame.image
                        Queue.mainQueue().async {
                            layer.takeUnretainedValue().contents = image
                        }
                    }, release: {
                        delay(0.032, closure: {
                            let view = layer.takeRetainedValue()
                            if animated {
                                view.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                                    view?.removeFromSuperlayer()
                                })
                            } else {
                                view.removeFromSuperlayer()
                            }
                        })
                    }, updateState: { [weak self] state in
                        guard let `self` = self else {
                            return
                        }
                        self.stateValue.set(self._currentState.modify { _ in state } )
                    })
                }
            }
        } else {
            self.context = nil
            //self.stateValue.set(self._currentState.modify { _ in .stoped })
        }
    }
}

