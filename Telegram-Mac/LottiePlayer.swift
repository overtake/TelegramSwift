import SwiftSignalKit
import Postbox
import RLottie
import TGUIKit
import Metal
import TelegramCore
import GZIP
import libwebp


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


let lottieThreadPool: ThreadPool = ThreadPool(threadCount: 1, threadPriority: 0.1)
private let stateQueue = Queue()



enum LottiePlayerState : Equatable {
    case initializing
    case failed
    case playing
    case stoped
}

protocol RenderedFrame {
    var duration: TimeInterval { get }
    var data: UnsafeRawPointer? { get }
    var image: CGImage? { get }
    var backingScale: Int { get }
    var size: NSSize { get }
    var key: LottieAnimationEntryKey { get }
    var frame: Int32 { get }
}

final class RenderedWebpFrame : RenderedFrame, Equatable {
    
    let frame: Int32
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    private let webpData: WebPImageFrame
    init(key: LottieAnimationEntryKey, frame: Int32, size: NSSize, webpData: WebPImageFrame, backingScale: Int) {
        self.key = key
        self.backingScale = backingScale
        self.size = size
        self.frame = frame
        self.webpData = webpData
    }
    var image: CGImage? {
        return webpData.image?._cgImage
    }
    var duration: TimeInterval {
        return webpData.duration
    }
    var data: UnsafeRawPointer? {
        return nil
    }
    static func == (lhs: RenderedWebpFrame, rhs: RenderedWebpFrame) -> Bool {
        return lhs.key == rhs.key
    }
}

final class RenderedLottieFrame : RenderedFrame, Equatable {
    let frame: Int32
    let data: UnsafeRawPointer?
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    let fps: Int
    init(key: LottieAnimationEntryKey, fps: Int, frame: Int32, size: NSSize, data: UnsafeRawPointer, backingScale: Int) {
        self.key = key
        self.frame = frame
        self.size = size
        self.data = data
        self.backingScale = backingScale
        self.fps = fps
    }
    static func ==(lhs: RenderedLottieFrame, rhs: RenderedLottieFrame) -> Bool {
        return lhs.frame == rhs.frame
    }
    
    var bufferSize: Int {
        return Int(size.width * CGFloat(backingScale) * size.height * CGFloat(backingScale) * 4)
    }
    
    var duration: TimeInterval {
        return 1.0 / Double(self.fps)
    }
    var image: CGImage? {
        if let data = data {
            return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData) in
                memcpy(pixelData, data, bufferSize)
            })
        }
        return nil
    }
    
    
    deinit {
        data?.deallocate()
        
//        _ = sharedFrames.modify { value in
//            var value = value
//            if var shared = value[key] {
//                shared.removeValue(forKey: frame)
//                if shared.isEmpty {
//                    value.removeValue(forKey: key)
//                } else {
//                    value[key] = shared
//                }
//            }
//            return value
//        }
       
    }
}

//private var sharedFrames:RenderAtomic<[LottieAnimationEntryKey : [Int32: WeakReference<RenderedFrame>]]> = RenderAtomic(value: [:])




private final class RendererState  {
    fileprivate let animation: LottieAnimation
    private(set) var frames: [RenderedFrame]
    private(set) var previousFrame:RenderedFrame?
    private(set) var cachedFrames:[Int32 : RenderedFrame]
    private(set) var currentFrame: Int32
    private(set) var startFrame:Int32
    private(set) var endFrame: Int32
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
        self.endFrame = endFrame
    }
    func withUpdatedFrames(_ frames: [RenderedFrame]) -> RendererState {
        self.frames = frames
        return self
    }
    func withAddedFrame(_ frame: RenderedFrame) {
        
        let prev = frame.frame == 0 ? nil : self.frames.last ?? previousFrame
        self.container?.cacheFrame(prev, frame)
//        _ = sharedFrames.modify { value in
//            var value = value
//            if value[self.animation.key] == nil {
//                value[self.animation.key] = [:]
//            }
//            value[self.animation.key]?[frame.frame] = WeakReference(value: frame)
//            return value
//        }
        self.frames = self.frames + [frame]
    }
    
    func withUpdatedCurrentFrame(_ currentFrame: Int32) -> RendererState {
        self.currentFrame = currentFrame
        return self
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
        return container?.render(at: frame, frames: frames, previousFrame: previousFrame)
    }
    
    deinit {
        
    }
    
    func cancel() -> RendererState {
        self.cancelled = true
        
        return self
    }
}

final class LottieSoundEffect {
    private let player: MediaPlayer
    let triggerOn: Int32?
    
    private(set) var isPlayable: Bool = false
    
    init(file: TelegramMediaFile, postbox: Postbox, triggerOn: Int32?) {
        self.player = MediaPlayer(postbox: postbox, reference: MediaResourceReference.standalone(resource: file.resource), streamable: false, video: false, preferSoftwareDecoding: false, enableSound: true, baseRate: 1.0, fetchAutomatically: true)
        self.triggerOn = triggerOn
    }
    func play() {
        if isPlayable {
            self.player.play()
            isPlayable = false
        }
    }
    
    func markAsPlayable() -> Void {
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
    private var timer: SwiftSignalKit.Timer?
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
        self.timer?.invalidate()
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
    private func play(_ player: RenderContainer) {
        
        self.finished = false
        
        let runOnQueue = animation.runOnQueue
        
        let maximum_renderer_frames: Int = Thread.isMainThread ? 2 : maximum_rendered_frames
        
        let fps: Int = min(player.fps, max(30, maxRefreshRate))
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
        
        let stateValue:RenderAtomic<RendererState?> = RenderAtomic(value: initialState)
        let updateState:(_ f:(RendererState?)->RendererState?)->Void = { f in
            _ = stateValue.modify(f)
        }
        
        self.getCurrentFrame = { [weak stateValue] in
            return stateValue?.with { $0?.renderIndex }
        }
        self.getTotalFrames = { [weak stateValue] in
            return stateValue?.with { $0?.endFrame }
        }
        
        var framesTask: ThreadPoolTask? = nil
        
        let isRendering: Atomic<Bool> = Atomic(value: false)
        
        self.onDispose = {
            updateState {
                $0?.cancel()
            }
            framesTask?.cancel()
            framesTask = nil
            _ = stateValue.swap(nil)
        }
        
        let currentState:(_ state: RenderAtomic<RendererState?>) -> RendererState? = { state in
            return state.with { $0 }
        }
        
        var renderNext:(()->Void)? = nil
        
        var add_frames_impl:(()->Void)? = nil
        var askedRender: Bool = false
        var playedCount: Int32 = 0
        let render:()->Void = { [weak self] in
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
                            updateState(.playing)
                        }
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
                                if endFrame - 1 == current.frame {
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
                            updateState(.stoped)
                            renderer.timer?.invalidate()
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
                            if let state = currentState(stateValue), state.endFrame - current.frame <= 1  {
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
                        }
                        
                    }
                    if !renderer.finished {
                        let duration = current?.duration ?? (1.0 / TimeInterval(fps))
                        if duration > 0, (renderer.totalFrames ?? 0) > 1 {
                            renderer.timer = SwiftSignalKit.Timer(timeout: duration, repeat: false, completion: {
                                renderNext?()
                            }, queue: runOnQueue)
                            
                            renderer.timer?.start()
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
        framesTask = ThreadPoolTask { state in
            _ = isRendering.swap(true)
            while !state.cancelled.with({$0}) && (currentState(stateValue)?.frames.count ?? Int.max) < min(maximum_renderer_frames, maximum) {
                
                let currentFrame = stateValue.with { $0?.currentFrame ?? 0 }
                
                let value = stateValue.with { $0 }
                
                let frame: RenderedFrame?
                if let value = value {
                    frame = value.renderFrame(at: currentFrame)
                } else {
                    frame = nil
                }
                                
                _ = stateValue.modify { stateValue -> RendererState? in
                    guard let state = stateValue else {
                        return stateValue
                    }
                    var currentFrame = state.currentFrame
                    
                    if mainFps >= fps {
                        if currentFrame % Int32(round(Float(mainFps) / Float(fps))) != 0 {
                            currentFrame += 1
                        }
                    } else {
                        currentFrame += 1
                    }
                    
                    if currentFrame >= state.endFrame - 1 {
                        currentFrame = state.startFrame - 1
                    }
                    if let frame = frame {
                        state.withAddedFrame(frame)
                    }
                    return state.withUpdatedCurrentFrame(currentFrame + 1)
                }
                if frame == nil {
                    break
                }
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

private final class PlayerContext {
    private let rendererRef: QueueLocalObject<PlayerRenderer>
    fileprivate let animation: LottieAnimation
    init(_ animation: LottieAnimation, maxRefreshRate: Int = 60, displayFrame: @escaping(RenderedFrame, LottieRunLoop)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) {
        self.animation = animation
        self.rendererRef = QueueLocalObject.init(queue: animation.runOnQueue, generate: {
            return PlayerRenderer(animation: animation, displayFrame: displayFrame, release: release, updateState: { state in
                Queue.mainQueue().async {
                    updateState(state)
                }
            })
        })
        
        self.rendererRef.with { renderer in
            renderer.initializeAndPlay(maxRefreshRate: maxRefreshRate)
        }
    }
    
    func playAgain() {
        self.rendererRef.with { renderer in
            if renderer.finished {
                renderer.playAgain()
            }
        }
    }
    
    func setColors(_ colors: [LottieColor]) {
        self.rendererRef.with { renderer in
            renderer.setColors(colors)
        }
    }
    
    func playSoundEffect() {
        self.rendererRef.with { renderer in
            renderer.playSoundEffect()
        }
    }
    func updateSize(_ size: NSSize) {
        self.rendererRef.syncWith { renderer in
            renderer.updateSize(size)
        }
    }
    var currentFrame:Int32? {
        var currentFrame:Int32? = nil
        self.rendererRef.syncWith { renderer in
            currentFrame = renderer.currentFrame
        }
        return currentFrame
    }
    var totalFrames:Int32? {
        var totalFrames:Int32? = nil
        self.rendererRef.syncWith { renderer in
            totalFrames = renderer.totalFrames
        }
        return totalFrames
    }
}


enum ASLiveTime : Int {
    case chat = 3_600
    case thumb = 259200
    case effect = 241_920 // 7 days
}

enum ASCachePurpose {
    case none
    case temporaryLZ4(ASLiveTime)
}

struct LottieAnimationEntryKey : Hashable {
    let size: CGSize
    let backingScale: Int
    let key:LottieAnimationKey
    let fitzModifier: EmojiFitzModifier?
    let colors: [LottieColor]
    init(key: LottieAnimationKey, size: CGSize, backingScale: Int = Int(System.backingScale), fitzModifier: EmojiFitzModifier? = nil, colors: [LottieColor] = []) {
        self.key = key
        self.size = size
        self.backingScale = backingScale
        self.fitzModifier = fitzModifier
        self.colors = colors
    }
    
    func withUpdatedColors(_ colors: [LottieColor]) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors)
    }
    func withUpdatedBackingScale(_ backingScale: Int) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors)
    }
    func withUpdatedSize(_ size: CGSize) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors)
    }
    
    func hash(into hasher: inout Hasher) {
        
    }
}

enum LottieAnimationKey : Hashable {
    case media(MediaId?)
    case bundle(String)
}

enum LottiePlayPolicy : Equatable {
    case loop
    case loopAt(firstStart:Int32?, range: ClosedRange<Int32>)
    case once
    case onceEnd
    case toEnd(from: Int32)
    case toStart(from: Int32)
    case framesCount(Int32)
    case onceToFrame(Int32)
    
    static func ==(lhs: LottiePlayPolicy, rhs: LottiePlayPolicy) -> Bool {
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
        }
        return false
    }
}

struct LottieColor : Equatable {
    let keyPath: String
    let color: NSColor
}

enum LottiePlayerTriggerFrame : Equatable {
    case first
    case last
    case custom(Int32)
}

private protocol RenderContainer : class {
    func render(at frame: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame?
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame)
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

private final class LottieRenderer : RenderContainer {
    
    private let animation: LottieAnimation
    private let bridge: RLottieBridge
    private let fileSupplyment: TRLotFileSupplyment?
    
    init(animation: LottieAnimation, bridge: RLottieBridge, fileSupplyment: TRLotFileSupplyment?) {
        self.animation = animation
        self.bridge = bridge
        self.fileSupplyment = fileSupplyment
    }
    var fps: Int {
        return max(min(Int(bridge.fps()), self.animation.maximumFps), 24)
    }
    var mainFps: Int {
        return Int(bridge.fps())
    }
    var endFrame: Int32 {
        return bridge.endFrame()
    }
    var startFrame: Int32 {
        return bridge.startFrame()
    }
    
    func setColor(_ color: NSColor, keyPath: String) {
        self.bridge.setColor(color, forKeyPath: keyPath)
    }
    
    func cacheFrame(_ previous: RenderedFrame?, _ current: RenderedFrame) {
        if let fileSupplyment = fileSupplyment {
            fileSupplyment.addFrame(previous, current, endFrame: Int(endFrame))
        }
    }
    
    func render(at frame: Int32, frames: [RenderedFrame], previousFrame: RenderedFrame?) -> RenderedFrame? {
        let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
        
        var data: UnsafeRawPointer?
        
//        let sharedFrame = sharedFrames.with { value -> RenderedLottieFrame? in
//            return value[animation.key]?[frame]?.value
//        }
//
//        if let sharedFrame = sharedFrame {
//            return sharedFrame
//        }
//
        if let fileSupplyment = fileSupplyment {
            let previous = frame == startFrame ? nil : frames.last ?? previousFrame
            if let frame = fileSupplyment.readFrame(previous: previous, frame: Int(frame)) {
                data = frame
            }
        }
        if data == nil {
            let bufferSize = s.w * s.h * 4
            let memoryData = malloc(bufferSize)!
            let frameData = memoryData.assumingMemoryBound(to: UInt8.self)
            bridge.renderFrame(with: frame, into: frameData, width: Int32(s.w), height: Int32(s.h))
            data = UnsafeRawPointer(frameData)
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

enum LottieAnimationType {
    case lottie
    case webp
}

final class LottieAnimation : Equatable {
    static func == (lhs: LottieAnimation, rhs: LottieAnimation) -> Bool {
        return lhs.key == rhs.key && lhs.playPolicy == rhs.playPolicy && lhs.colors == rhs.colors
    }
    
    let type: LottieAnimationType
    
    var liveTime: Int {
        switch cache {
        case .none:
            return 0
        case let .temporaryLZ4(liveTime):
            return liveTime.rawValue
        }
    }
    
    var supportsMetal: Bool {
        switch type {
        case .lottie:
            return true
        default:
            return false
        }
    }
    
    let compressed: Data
    let key: LottieAnimationEntryKey
    let cache: ASCachePurpose
    let maximumFps: Int
    let playPolicy: LottiePlayPolicy
    let colors:[LottieColor]
    let soundEffect: LottieSoundEffect?
    let postbox: Postbox?
    let runOnQueue: Queue
    var onFinish:(()->Void)?

    var triggerOn:(LottiePlayerTriggerFrame, ()->Void, ()->Void)? 

    
    init(compressed: Data, key: LottieAnimationEntryKey, type: LottieAnimationType = .lottie, cachePurpose: ASCachePurpose = .temporaryLZ4(.thumb), playPolicy: LottiePlayPolicy = .loop, maximumFps: Int = 60, colors: [LottieColor] = [], soundEffect: LottieSoundEffect? = nil, postbox: Postbox? = nil, runOnQueue: Queue = stateQueue) {
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
    }
    
    var size: NSSize {
        let size = key.size
        return size
    }
    var viewSize: NSSize {
        return key.size
    }
    var backingScale: Int {
        return key.backingScale
    }
    
    func withUpdatedBackingScale(_ scale: Int) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedBackingScale(scale), cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: self.colors, postbox: self.postbox, runOnQueue: self.runOnQueue)
    }
    func withUpdatedColors(_ colors: [LottieColor]) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key, cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue)
    }
    func withUpdatedPolicy(_ playPolicy: LottiePlayPolicy) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key, cachePurpose: self.cache, playPolicy: playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue)
    }
    func withUpdatedSize(_ size: CGSize) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedSize(size), cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue)
    }
    
    var cacheKey: String {
        switch key.key {
        case let .media(id):
            if let id = id {
                if let fitzModifier = key.fitzModifier {
                    return "animation-\(id.namespace)-\(id.id)-fitz\(fitzModifier.rawValue)" + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
                } else {
                    return "animation-\(id.namespace)-\(id.id)" + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
                }
            } else {
                return "\(arc4random())"
            }
        case let .bundle(string):
            return string + self.colors.map { $0.keyPath + $0.color.hexString }.joined(separator: " ")
        }
    }
    
    fileprivate var bufferSize: Int {
        return Int(size.width * CGFloat(backingScale) * size.height * CGFloat(backingScale) * 4)
    }
    
    
    fileprivate func initialize() -> RenderContainer? {
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
                let modified: Data
                if let color = self.colors.first(where: { $0.keyPath == "" }) {
                    modified = applyLottieColor(data: data, color: color.color)
                } else {
                    modified = transformedWithFitzModifier(data: data, fitzModifier: self.key.fitzModifier)
                }
                if let json = String(data: modified, encoding: .utf8) {
                    if let bridge = RLottieBridge(json: json, key: self.cacheKey) {
                        for color in self.colors {
                            bridge.setColor(color.color, forKeyPath: color.keyPath)
                        }
                        let fileSupplyment: TRLotFileSupplyment?
                        switch self.cache {
                        case .temporaryLZ4:
                            fileSupplyment = TRLotFileSupplyment(self, bufferSize: bufferSize, frames: Int(bridge.endFrame()), queue: Queue())
                        case .none:
                            fileSupplyment = nil
                        }
                        return LottieRenderer(animation: self, bridge: bridge, fileSupplyment: fileSupplyment)
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
        }, queue: stateQueue)
        
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
        self.loops = QueueLocalObject(queue: stateQueue, generate: {
            return Loops()
        })
        self.displayId = CGMainDisplayID()
        var refreshRate = CGDisplayCopyDisplayMode(displayId)?.refreshRate ?? 60
        if refreshRate == 0 {
            refreshRate = 60
        }
        self.refreshRate = Int(min(refreshRate, 60))
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


struct LottieRunLoop : Hashable {
    let fps: Int
    
    func hash(into hasher: inout Hasher) {
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
        
        guard let drawable = metalLayer.nextDrawable(), let bytes = frame.data else {
            return nil
        }
        
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
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        renderEncoder.endEncoding()
                
        return drawable
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
}

class LottiePlayerView : NSView {
    private var context: PlayerContext?
    private var _ignoreCachedContext: Bool = false
    private let _currentState: Atomic<LottiePlayerState> = Atomic(value: .initializing)
    var currentState: LottiePlayerState {
        return _currentState.with { $0 }
    }
    
    private let stateValue: ValuePromise<LottiePlayerState> = ValuePromise(.initializing, ignoreRepeated: true)
    var state: Signal<LottiePlayerState, NoError> {
        return stateValue.get()
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    var animation: LottieAnimation? {
        return context?.animation
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        update(size: newSize, transition: .immediate)
    }
    
    func update(size: NSSize, transition: ContainedViewLayoutTransition) {
        for subview in subviews {
            transition.updateFrame(view: subview, frame: size.bounds)
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidChangeBackingProperties() {
        if let context = context {
            self.set(context.animation.withUpdatedBackingScale(Int(backingScaleFactor)))
        }
    }
    
    func playIfNeeded(_ playSound: Bool = false) {
        if let context = self.context, context.animation.playPolicy == .once {
            context.playAgain()
            if playSound {
                context.playSoundEffect()
            }
        } else {
            context?.playSoundEffect()
        }
    }
    
    func playAgain() {
        self.context?.playAgain()
    }
    
    var currentFrame: Int32? {
        if _ignoreCachedContext {
            return nil
        }
        if let context = self.context {
            return context.currentFrame
        } else {
            return nil
        }
    }
    
    func ignoreCachedContext() {
        _ignoreCachedContext = true
    }
    
    var totalFrames: Int32? {
        if _ignoreCachedContext {
            return nil
        }
        if let context = self.context {
            return context.totalFrames
        } else {
            return nil
        }
    }
    
    func setColors(_ colors: [LottieColor]) {
        context?.setColors(colors)
    }
    
    func set(_ animation: LottieAnimation?, reset: Bool = false, saveContext: Bool = false, animated: Bool = false) {
        assertOnMainThread()
        _ignoreCachedContext = false
        if let animation = animation {
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
                    
                    
                    var cachedContext:Unmanaged<PlayerContext>?
                    if let context = self.context, saveContext {
                        cachedContext = Unmanaged.passRetained(context)
                    }  else  {
                        cachedContext = nil
                    }
                    
                    self.context = PlayerContext(animation, maxRefreshRate: holder.context.refreshRate, displayFrame: { frame, runLoop in
                        layer.takeUnretainedValue().render(frame: frame, runLoop: runLoop)
                    }, release: {
                        Queue.mainQueue().async {
                            layer.takeRetainedValue().removeFromSuperview()
                            _ = cachedContext?.takeRetainedValue()
                            cachedContext = nil
                        }
                        
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
                    let fallback = LottieFallbackView()
                    fallback.wantsLayer = true
                    fallback.frame = CGRect(origin: CGPoint(), size: self.frame.size)
                    fallback.layer?.contentsGravity = .resize
                    self.addSubview(fallback)
                    if animated {
                        fallback.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    let layer = Unmanaged.passRetained(fallback)
                    
                    self.context = PlayerContext(animation, displayFrame: { frame, _ in
                        
                        let image = frame.image
                        Queue.mainQueue().async {
                            layer.takeUnretainedValue().layer?.contents = image
                        }
                    }, release: {
                        Queue.mainQueue().async {
                            let view = layer.takeRetainedValue()
                            if animated {
                                view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            } else {
                                view.removeFromSuperview()
                            }
                        }
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
            self.stateValue.set(self._currentState.modify { _ in .stoped })
        }
    }
}

