//
//  SELottiePlayer.swift
//  TelegramShare
//
//  Created by Mikhail Filimonov on 20.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import Postbox
import TGUIKit
import TelegramCore
import GZIP
import Accelerate
import QuartzCore
import CoreMedia
import RLottie
import libwebp
import TelegramMediaPlayer

public protocol SE_R_LottieBridge: NSObject {
    func renderFrame(with index: Int32, into buffer: UnsafeMutablePointer<UInt8>, width: Int32, height: Int32, bytesPerRow: Int32)
    func startFrame() -> Int32
    func endFrame() -> Int32
    func fps() -> Int32
    func setColor(_ color: NSColor, forKeyPath keyPath: String)
}

extension RLottieBridge : SE_R_LottieBridge {
   
}

final class SE_RenderAtomic<T> {
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


public let SE_lottieThreadPool: ThreadPool = ThreadPool(threadCount: 4, threadPriority: 1.0)
public let SE_lottieStateQueue = Queue(name: "lottieStateQueue", qos: .utility)



public enum SE_LottiePlayerState : Equatable {
    case initializing
    case failed
    case playing
    case stoped
    case finished
}

public protocol SE_RenderedFrame {
    var duration: TimeInterval { get }
    var data: Data? { get }
    var image: CGImage? { get }
    var backingScale: Int { get }
    var size: NSSize { get }
    var key: SE_LottieAnimationEntryKey { get }
    var frame: Int32 { get }
    var mirror: Bool { get }
    var bytesPerRow: Int { get }
}


private let loops = RenderFpsLoops()

private struct SE_RenderFpsToken : Hashable {
    
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
    private let loops:Atomic<[SE_RenderFpsToken.LoopToken: SE_RenderFpsLoop]> = Atomic(value: [:])
    private var index: Int = 0
    init() {
        
    }
    
    func getIndex() -> Int {
        self.index += 1
        return index
    }
    
    func add(token: SE_RenderFpsToken, callback:@escaping()->Void) {
        let current: SE_RenderFpsLoop
        if let value = self.loops.with({ $0[token.value] }) {
            current = value
        } else {
            current = SE_RenderFpsLoop(duration: token.value.duration, queue: token.value.queue)
            _ = self.loops.modify { value in
                var value = value
                value[token.value] = current
                return value
            }
        }
        current.add(token, callback: callback)
    }
    func remove(token: SE_RenderFpsToken) {
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
private final class SE_RenderFpsLoop {
    
    private class Values {
        var values: [SE_RenderFpsToken: RenderFpsCallback] = [:]
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
    
    func remove(_ token: SE_RenderFpsToken) -> Bool {
        return self.values.syncWith { current in
            current.values.removeValue(forKey: token)
            return current.values.isEmpty
        }
    }
    
    func add(_ token: SE_RenderFpsToken, callback: @escaping()->Void) {
        self.values.with { current in
            current.values[token] = .init(callback: callback)
        }
    }
}



final class SE_RenderedLottieFrame : SE_RenderedFrame, Equatable {
    let frame: Int32
    let data: Data?
    let size: NSSize
    let backingScale: Int
    let key: SE_LottieAnimationEntryKey
    let fps: Int
    let initedOnMain: Bool
    init(key: SE_LottieAnimationEntryKey, fps: Int, frame: Int32, size: NSSize, data: Data, backingScale: Int) {
        self.key = key
        self.frame = frame
        self.size = size
        self.data = data
        self.backingScale = backingScale
        self.fps = fps
        self.initedOnMain = Thread.isMainThread
    }
    static func ==(lhs: SE_RenderedLottieFrame, rhs: SE_RenderedLottieFrame) -> Bool {
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
        if let data = data {
            return data.withUnsafeBytes({ pointer in
                let bytes = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
                    
                    let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
                    let mutableBytes = UnsafeMutableRawPointer(mutating: bytes)
                    var buffer = vImage_Buffer(data: mutableBytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: bytesPerRow)
                               
                    if self.key.mirror {
                        vImageHorizontalReflect_ARGB8888(&buffer, &buffer, vImage_Flags(kvImageDoNotTile))
                    }
                    
                    memcpy(pixelData, mutableBytes, bufferSize)
                })
            })
            
        }
        return nil
    }
    
    
    deinit {

    }
}


private final class SE_RendererState  {
    fileprivate let animation: SE_LottieAnimation
    private(set) var frames: [SE_RenderedFrame]
    private(set) var previousFrame:SE_RenderedFrame?
    private(set) var cachedFrames:[Int32 : SE_RenderedFrame]
    private(set) var currentFrame: Int32
    private(set) var startFrame:Int32
    private(set) var _endFrame: Int32
    private(set) var cancelled: Bool
    private(set) weak var container: SE_RenderContainer?
    private(set) var renderIndex: Int32?
    init(cancelled: Bool, animation: SE_LottieAnimation, container: SE_RenderContainer?, frames: [SE_RenderedLottieFrame], cachedFrames: [Int32 : SE_RenderedLottieFrame], currentFrame: Int32, startFrame: Int32, endFrame: Int32) {
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
    
    func withUpdatedFrames(_ frames: [SE_RenderedFrame]) {
        self.frames = frames
    }
    func addFrame(_ frame: SE_RenderedFrame) {
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

    func takeFirst() -> SE_RenderedFrame {
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
    
    func renderFrame(at frame: Int32) -> SE_RenderedFrame? {
        let rendered = container?.render(at: frame, frames: frames, previousFrame: previousFrame)
        return rendered
    }
    
    deinit {
        
    }
    
    func cancel() -> SE_RendererState {
        self.cancelled = true
        
        return self
    }
}


private let SE_maximum_rendered_frames: Int = 4
private final class SE_PlayerRenderer {
    
    
    private(set) var finished: Bool = false
    private var animation: SE_LottieAnimation
    private var layer: Atomic<SE_RenderContainer?> = Atomic(value: nil)
    private let updateState:(SE_LottiePlayerState)->Void
    private let displayFrame: (SE_RenderedFrame, SE_LottieRunLoop)->Void
    private var renderToken: SE_RenderFpsToken?
    private let release:()->Void
    private var maxRefreshRate: Int = 60
    init(animation: SE_LottieAnimation, displayFrame: @escaping(SE_RenderedFrame, SE_LottieRunLoop)->Void, release:@escaping()->Void, updateState:@escaping(SE_LottiePlayerState)->Void) {
        self.animation = animation
        self.displayFrame = displayFrame
        self.updateState = updateState
        self.release = release
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
    
    private func play(_ player: SE_RenderContainer) {
        
        
        self.finished = false
        
        let runOnQueue = animation.runOnQueue
        
        let maximum_renderer_frames: Int = Thread.isMainThread ? 2 : SE_maximum_rendered_frames
        
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
        
        let initialState = SE_RendererState(cancelled: false, animation: self.animation, container: player, frames: [], cachedFrames: [:], currentFrame: currentFrame, startFrame: startFrame, endFrame: endFrame)
        
        var stateValue:SE_RenderAtomic<SE_RendererState?>? = SE_RenderAtomic(value: initialState)
        let updateState:(_ f:(SE_RendererState?)->SE_RendererState?)->Void = { [weak stateValue] f in
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
        
        let currentState:(_ state: SE_RenderAtomic<SE_RendererState?>?) -> SE_RendererState? = { state in
            return state?.with { $0 }
        }
        
        var renderNext:(()->Void)? = nil
        
        var add_frames_impl:(()->Void)? = nil
        var askedRender: Bool = false
        var playedCount: Int32 = 0
        var loopCount: Int32 = 0
        var previousFrame: Int32 = 0
        var currentPlayerState: SE_LottiePlayerState? = nil
        
        let render:()->Void = { [weak self, weak stateValue] in
            var hungry: Bool = false
            var cancelled: Bool = false
            if let renderer = self {
                var current: SE_RenderedFrame?
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
                            let token = SE_RenderFpsToken(duration: duration, queue: runOnQueue, index: loops.getIndex())
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
            _ = stateValue?.with { stateValue -> SE_RendererState? in
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
                    SE_lottieThreadPool.addTask(framesTask)
                }
            }
        }
        
        add_frames_impl = {
            add_frames()
        }
        add_frames()
        
    }
    
}

public final class SE_AnimationPlayerContext {
    private let rendererRef: QueueLocalObject<SE_PlayerRenderer>
    fileprivate let animation: SE_LottieAnimation
    public init(_ animation: SE_LottieAnimation, maxRefreshRate: Int = 60, displayFrame: @escaping(SE_RenderedFrame, SE_LottieRunLoop)->Void, release:@escaping()->Void, updateState: @escaping(SE_LottiePlayerState)->Void) {
        self.animation = animation
        self.rendererRef = QueueLocalObject(queue: animation.runOnQueue, generate: {
            return SE_PlayerRenderer(animation: animation, displayFrame: displayFrame, release: release, updateState: { state in
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




public struct SE_LottieAnimationEntryKey : Hashable {
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
    
    public func withUpdatedColors(_ colors: [LottieColor]) -> SE_LottieAnimationEntryKey {
        return SE_LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
    }
    public func withUpdatedBackingScale(_ backingScale: Int) -> SE_LottieAnimationEntryKey {
        return SE_LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
    }
    public func withUpdatedSize(_ size: CGSize) -> SE_LottieAnimationEntryKey {
        return SE_LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale, fitzModifier: fitzModifier, colors: colors, mirror: mirror)
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

public enum SE_LottiePlayPolicy : Hashable {
    case loop
    case loopAt(firstStart:Int32?, range: ClosedRange<Int32>)
    case once
    case onceEnd
    case toEnd(from: Int32)
    case toStart(from: Int32)
    case framesCount(Int32)
    case onceToFrame(Int32)
    case playCount(Int32)
    
    
    public static func ==(lhs: SE_LottiePlayPolicy, rhs: SE_LottiePlayPolicy) -> Bool {
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

public enum SE_LottiePlayerTriggerFrame : Equatable {
    case first
    case last
    case custom(Int32)
}

public protocol SE_RenderContainer : AnyObject {
    func render(at frame: Int32, frames: [SE_RenderedFrame], previousFrame: SE_RenderedFrame?) -> SE_RenderedFrame?
    func cacheFrame(_ previous: SE_RenderedFrame?, _ current: SE_RenderedFrame)
    func markFinished()
    func setColor(_ color: NSColor, keyPath: String)
    
    var endFrame: Int32 { get }
    var startFrame: Int32 { get }
    
    var fps: Int { get }
    var mainFps: Int { get }

}


final class SE_RenderedWebpFrame : SE_RenderedFrame, Equatable {
    
    let frame: Int32
    let size: NSSize
    let backingScale: Int
    let key: SE_LottieAnimationEntryKey
    private let webpData: WebPImageFrame
    init(key: SE_LottieAnimationEntryKey, frame: Int32, size: NSSize, webpData: WebPImageFrame, backingScale: Int) {
        self.key = key
        self.backingScale = backingScale
        self.size = size
        self.frame = frame
        self.webpData = webpData
    }
    
    var bytesPerRow: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        return DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
    }
    
    var image: CGImage? {
        return webpData.image?._cgImage
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
    static func == (lhs: SE_RenderedWebpFrame, rhs: SE_RenderedWebpFrame) -> Bool {
        return lhs.key == rhs.key
    }
}


final class SE_RenderedWebmFrame : SE_RenderedFrame, Equatable {
    
    let frame: Int32
    let size: NSSize
    let backingScale: Int
    let key: SE_LottieAnimationEntryKey
    private let _data: Data
    private let fps: Int
    init(key: SE_LottieAnimationEntryKey, frame: Int32, fps: Int, size: NSSize, data: Data, backingScale: Int) {
        self.key = key
        self.backingScale = backingScale
        self.size = size
        self.frame = frame
        self._data = data
        self.fps = fps
    }
    
    var bytesPerRow: Int {
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        return DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
    }
    
    var image: CGImage? {
        
        if let data = data {
            let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
            
            return data.withUnsafeBytes { pointer in
                let bytes = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)

                let mutableBytes = UnsafeMutableRawPointer(mutating: bytes)
                var buffer = vImage_Buffer(data: mutableBytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: bytesPerRow)
                           
                if self.key.mirror {
                    vImageHorizontalReflect_ARGB8888(&buffer, &buffer, vImage_Flags(kvImageDoNotTile))
                }
                return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
                    memcpy(pixelData, mutableBytes, bufferSize)
                })
            }
            
        }
        return nil
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
    static func == (lhs: SE_RenderedWebmFrame, rhs: SE_RenderedWebmFrame) -> Bool {
        return lhs.key == rhs.key
    }
    
    deinit {
        
    }
}


private final class SE_WebPRenderer : SE_RenderContainer {
    
    private let animation: SE_LottieAnimation
    private let decoder: WebPImageDecoder
    
    init(animation: SE_LottieAnimation, decoder: WebPImageDecoder) {
        self.animation = animation
        self.decoder = decoder
    }
    
    func render(at frame: Int32, frames: [SE_RenderedFrame], previousFrame: SE_RenderedFrame?) -> SE_RenderedFrame? {
        if let webpFrame = self.decoder.frame(at: UInt(frame), decodeForDisplay: true) {
            return SE_RenderedWebpFrame(key: animation.key, frame: frame, size: animation.size, webpData: webpFrame, backingScale: animation.backingScale)
        } else {
            return nil
        }
    }
    func cacheFrame(_ previous: SE_RenderedFrame?, _ current: SE_RenderedFrame) {
        
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

private final class SE_WebmRenderer : SE_RenderContainer {
    
    private let animation: SE_LottieAnimation
    private let decoder: SoftwareVideoSource
    
    
    private var index: Int32 = 1
    

    init(animation: SE_LottieAnimation, decoder: SoftwareVideoSource) {
        self.animation = animation
        self.decoder = decoder
    }

    func render(at frameIndex: Int32, frames: [SE_RenderedFrame], previousFrame: SE_RenderedFrame?) -> SE_RenderedFrame? {
        
        let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
        

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
            return SE_RenderedWebmFrame(key: animation.key, frame: frameIndex, fps: self.fps, size: animation.size, data: data, backingScale: animation.backingScale)
        } else {
            return nil
        }
    }
    func cacheFrame(_ previous: SE_RenderedFrame?, _ current: SE_RenderedFrame) {
        
    }
    func markFinished() {
        
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



private final class SE_LottieRenderer : SE_RenderContainer {
    
    private let animation: SE_LottieAnimation
    private let bridge: SE_R_LottieBridge?
    
    init(animation: SE_LottieAnimation, bridge: SE_R_LottieBridge?) {
        self.animation = animation
        self.bridge = bridge
    }
    var fps: Int {
        return max(min(Int(bridge?.fps() ?? 60), self.animation.maximumFps), 24)
    }
    var mainFps: Int {
        return Int(bridge?.fps() ?? 60)
    }
    var endFrame: Int32 {
        return bridge?.endFrame() ?? 0
    }
    var startFrame: Int32 {
        return bridge?.startFrame() ?? 0
    }
    
    func setColor(_ color: NSColor, keyPath: String) {
        self.bridge?.setColor(color, forKeyPath: keyPath)
    }
    
    func cacheFrame(_ previous: SE_RenderedFrame?, _ current: SE_RenderedFrame) {
        
    }
    func markFinished() {
       
    }
    func render(at frame: Int32, frames: [SE_RenderedFrame], previousFrame: SE_RenderedFrame?) -> SE_RenderedFrame? {
        let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
        
        var data: Data?

        if frame > endFrame {
            return nil
        }
        if data == nil {
            func renderFrame(s: (w: Int, h: Int), bridge: SE_R_LottieBridge?, frame: Int32) -> Data? {
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
            return SE_RenderedLottieFrame(key: animation.key, fps: fps, frame: frame, size: animation.size, data: data, backingScale: self.animation.backingScale)
        }
        
        return nil
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

public enum SE_LottieAnimationType {
    case lottie
    case webp
    case webm
}


public final class SE_LottieAnimation : Equatable {
    public static func == (lhs: SE_LottieAnimation, rhs: SE_LottieAnimation) -> Bool {
        return lhs.key == rhs.key && lhs.playPolicy == rhs.playPolicy && lhs.colors == rhs.colors
    }
    
    public let type: SE_LottieAnimationType
    
    
    public let compressed: Data
    public let key: SE_LottieAnimationEntryKey
    public let maximumFps: Int
    public let playPolicy: SE_LottiePlayPolicy
    public let colors:[LottieColor]
    public let metalSupport: Bool
    public let postbox: Postbox?
    public let runOnQueue: Queue
    public var onFinish:(()->Void)?

    public var triggerOn:(SE_LottiePlayerTriggerFrame, ()->Void, ()->Void)? {
        didSet {
            var bp = 0
            bp += 1
        }
    }

    
    public init(compressed: Data, key: SE_LottieAnimationEntryKey, type: SE_LottieAnimationType = .lottie, playPolicy: SE_LottiePlayPolicy = .loop, maximumFps: Int = 60, colors: [LottieColor] = [], postbox: Postbox? = nil, runOnQueue: Queue = SE_lottieStateQueue, metalSupport: Bool = false) {
        self.compressed = compressed
        self.key = key.withUpdatedColors(colors)
        self.maximumFps = maximumFps
        self.playPolicy = playPolicy
        self.colors = colors
        self.postbox = postbox
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
    
    public func withUpdatedBackingScale(_ scale: Int) -> SE_LottieAnimation {
        return SE_LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedBackingScale(scale), type: self.type, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: self.colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedColors(_ colors: [LottieColor]) -> SE_LottieAnimation {
        return SE_LottieAnimation(compressed: self.compressed, key: self.key, type: self.type, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedPolicy(_ playPolicy: SE_LottiePlayPolicy) -> SE_LottieAnimation {
        return SE_LottieAnimation(compressed: self.compressed, key: self.key, type: self.type, playPolicy: playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
    }
    public func withUpdatedSize(_ size: CGSize) -> SE_LottieAnimation {
        return SE_LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedSize(size), type: self.type, playPolicy: self.playPolicy, maximumFps: self.maximumFps, colors: colors, postbox: self.postbox, runOnQueue: self.runOnQueue, metalSupport: self.metalSupport)
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
    
    
    public func initialize() -> SE_RenderContainer? {
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
                        return SE_LottieRenderer(animation: self, bridge: bridge)
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
                    return SE_WebPRenderer(animation: self, decoder: decoder)
                }
            }
        case .webm:
            let path = String(data: self.compressed, encoding: .utf8)
            if let path = path {
                let premultiply = (DeviceGraphicsContextSettings.shared.opaqueBitmapInfo.rawValue & CGImageAlphaInfo.premultipliedFirst.rawValue) == 0
                let decoder = SoftwareVideoSource(path: path, hintVP9: true, unpremultiplyAlpha: premultiply)
                return SE_WebmRenderer(animation: self, decoder: decoder)
            }
        }
        return nil
    }
}



public struct SE_LottieRunLoop : Hashable {
    public let fps: Int
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fps)
    }
}


private final class SE_LottieFallbackView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}

open class SE_LottiePlayerView : View {
    private var context: SE_AnimationPlayerContext?
    private var _ignoreCachedContext: Bool = false
    private let _currentState: Atomic<SE_LottiePlayerState> = Atomic(value: .initializing)
    public var currentState: SE_LottiePlayerState {
        return _currentState.with { $0 }
    }
    
    private let stateValue: ValuePromise<SE_LottiePlayerState> = ValuePromise(.initializing, ignoreRepeated: true)
    public var state: Signal<SE_LottiePlayerState, NoError> {
        return stateValue.get()
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    public required override init() {
        super.init()
    }
    
    private var temporary: SE_LottieAnimation?
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
    
    public var animation: SE_LottieAnimation?
    
    public var contextAnimation: SE_LottieAnimation? {
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
    
    public func playIfNeeded() {
        if let context = self.context, context.animation.playPolicy == .once {
            context.playAgain()
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
    
    
    
    public func set(_ animation: SE_LottieAnimation?, reset: Bool = false, saveContext: Bool = false, animated: Bool = false) {
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
                let fallback = SimpleLayer()
                fallback.frame = CGRect(origin: CGPoint(), size: self.frame.size)
                fallback.contentsGravity = .resize
                self.layer?.addSublayer(fallback)
                if animated {
                    fallback.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                let layer = Unmanaged.passRetained(fallback)
                
                self.context = SE_AnimationPlayerContext(animation, displayFrame: { frame, _ in
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
        } else {
            self.context = nil
            //self.stateValue.set(self._currentState.modify { _ in .stoped })
        }
    }
}

