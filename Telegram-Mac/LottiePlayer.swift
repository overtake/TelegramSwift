import SwiftSignalKitMac
import PostboxMac
import RLottieMac
import TGUIKit
import Metal

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

//private struct RenderLoop {
//    let fps: Int
//    let action: ()->Void
//    init(fps: Int, action: @escaping()->Void) {
//        self.fps = fps
//        self.action = action
//    }
//}
//private final class RenderTimer {
//    private var loopTimers: [Int : SwiftSignalKitMac.Timer]
//
//    private var loops: [RenderLoop] = []
//    init() {
//        assert(stateQueue.isCurrent())
//    }
//
//    func add(loop: RenderLoop) {
//        assert(stateQueue.isCurrent())
//        loops.append(loop)
//
//    }
//
//    private func start() {
//        self.loop60 = SwiftSignalKitMac.Timer(timeout: TimeInterval(1000) / TimeInterval(60), repeat: true, completion: { [weak self] in
//            if let `self` = self {
//                for loop in self.loops {
//                    loop.action()
//                }
//            }
//        }, queue: stateQueue)
//
//        self.loop30 = SwiftSignalKitMac.Timer(timeout: TimeInterval(1000) / TimeInterval(60), repeat: true, completion: { [weak self] in
//            if let `self` = self {
//                for loop in self.loops {
//                    loop.action()
//                }
//            }
//        }, queue: stateQueue)
//
//        self.loop30?.start()
//    }
//
//    deinit {
//        assert(stateQueue.isCurrent())
//    }
//}

enum LottiePlayerState : Equatable {
    case initializing
    case failed
    case playing
    case stoped
}


final class RenderedFrame : Equatable {
    let frame: Int32
    let data: UnsafeRawPointer
    let size: NSSize
    let backingScale: Int
    let key: LottieAnimationEntryKey
    init(key: LottieAnimationEntryKey, frame: Int32, size: NSSize, data: UnsafeRawPointer, backingScale: Int) {
        self.key = key
        self.frame = frame
        self.size = size
        self.data = data
        self.backingScale = backingScale
    }
    static func ==(lhs: RenderedFrame, rhs: RenderedFrame) -> Bool {
        return lhs.frame == rhs.frame
    }
    
    var bufferSize: Int {
        return Int(size.width * CGFloat(backingScale) * size.height * CGFloat(backingScale) * 4)
    }
    
    deinit {
        data.deallocate()
        
        _ = sharedFrames.modify { value in
            var value = value
            if var shared = value[key] {
                shared.removeValue(forKey: frame)
                if shared.isEmpty {
                    value.removeValue(forKey: key)
                } else {
                    value[key] = shared
                }
            }
            return value
        }
       
    }
}

private var sharedFrames:RenderAtomic<[LottieAnimationEntryKey : [Int32: WeakReference<RenderedFrame>]]> = RenderAtomic(value: [:])

private final class RendererState  {
    fileprivate let animation: LottieAnimation
    private(set) var frames: [RenderedFrame]
    private(set) var previousFrame:RenderedFrame?
    private(set) var cachedFrames:[Int32 : RenderedFrame]
    private(set) var currentFrame: Int32
    private(set) var startFrame:Int32
    private(set) var endFrame: Int32
    private(set) var fps: Int32
    private(set) var cancelled: Bool
    private(set) weak var layer: RLottieBridge?
    private(set) var videoFormat:CMVideoFormatDescription?
    private var fileSupplyment: TRLotFileSupplyment?
    init(cancelled: Bool, animation: LottieAnimation, layer: RLottieBridge?, fileSupplyment: TRLotFileSupplyment?, frames: [RenderedFrame], cachedFrames: [Int32 : RenderedFrame], currentFrame: Int32, startFrame: Int32, endFrame: Int32, fps: Int32) {
        self.fileSupplyment = fileSupplyment
        self.animation = animation
        self.cancelled = cancelled
        self.layer = layer
        self.frames = frames
        self.cachedFrames = cachedFrames
        self.currentFrame = currentFrame
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.fps = fps
    }
    func withUpdatedFrames(_ frames: [RenderedFrame]) -> RendererState {
        self.frames = frames
        return self
    }
    func withAddedFrame(_ frame: RenderedFrame) {
        if let fileSupplyment = fileSupplyment {
            let prev = frame.frame == 0 ? nil : self.frames.last ?? previousFrame
            fileSupplyment.addFrame(prev, frame, endFrame: Int(self.endFrame))
        }
        
        _ = sharedFrames.modify { value in
            var value = value
            if value[self.animation.key] == nil {
                value[self.animation.key] = [:]
            }
            value[self.animation.key]?[frame.frame] = WeakReference(value: frame)
            return value
        }
       
        
        self.frames = self.frames + [frame]
    }
    
    func withUpdatedCurrentFrame(_ currentFrame: Int32) -> RendererState {
        self.currentFrame = currentFrame
        return self
    }
    func withUpdatedVideoFormat(_ videoFormat: CMVideoFormatDescription) -> RendererState {
        self.videoFormat = videoFormat
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
        self.frames = frames
        return prev
    }
    
    func renderFrame(at frame: Int32) -> RenderedFrame? {
        if let layer = self.layer {
            let s:(w: Int, h: Int) = (w: Int(animation.size.width) * animation.backingScale, h: Int(animation.size.height) * animation.backingScale)
            
            var data: UnsafeRawPointer?
            
            let sharedFrame = sharedFrames.with { value -> RenderedFrame? in
                return value[animation.key]?[frame]?.value
            }
            
            if let sharedFrame = sharedFrame {
                return sharedFrame
            }
            
            if let fileSupplyment = fileSupplyment {
                let previous = frame == startFrame ? nil : self.frames.last ?? previousFrame
                if let frame = fileSupplyment.readFrame(previous: previous, frame: Int(frame)) {
                    data = frame
                }
            }
            if data == nil {
                let bufferSize = s.w * s.h * 4
                let memoryData = malloc(bufferSize)!
                let frameData = memoryData.assumingMemoryBound(to: UInt8.self)
                layer.renderFrame(with: frame, into: frameData, width: Int32(s.w), height: Int32(s.h))
                data = UnsafeRawPointer(frameData)
            }
            
            if let data = data {
                return RenderedFrame(key: animation.key, frame: frame, size: animation.size, data: data, backingScale: self.animation.backingScale)
            }
           
        }
        return nil
    }
    
    deinit {
        
    }
    
    func cancel() -> RendererState {
        self.cancelled = true
        return self
    }
}

private let maximum_rendered_frames: Int = 4
private final class PlayerRenderer {
    
    private(set) var finished: Bool = false
    private let animation: LottieAnimation
    private var layer: Atomic<RLottieBridge?> = Atomic(value: nil)
    private let updateState:(LottiePlayerState)->Void
    private let displayFrame: (RenderedFrame)->Void
    private var timer: SwiftSignalKitMac.Timer?
    private let release:()->Void
    init(animation: LottieAnimation, displayFrame: @escaping(RenderedFrame)->Void, release:@escaping()->Void, updateState:@escaping(LottiePlayerState)->Void) {
        self.animation = animation
        self.displayFrame = displayFrame
        self.updateState = updateState
        self.release = release
    }
    
    private var onDispose: (()->Void)?
    deinit {
        self.timer?.invalidate()
        self.onDispose?()
        _ = self.layer.swap(nil)
        self.release()
    }
    
    private func with(_ f:@escaping(PlayerRenderer?)->Void) {
        stateQueue.async { [weak self] in
            f(self)
        }
    }
    
    func initializeAndPlay() {
        self.updateState(.initializing)
        self.with({ renderer in
            if let renderer = renderer {
                let decompressed = TGGUnzipData(renderer.animation.compressed, 8 * 1024 * 1024)
                let data: Data?
                if let decompressed = decompressed {
                    data = decompressed
                } else {
                    data = renderer.animation.compressed
                }
                if let data = data, !data.isEmpty, let json = String(data: data, encoding: .utf8) {
                    if let bridge = RLottieBridge(json: json, key: renderer.animation.cacheKey) {
                        renderer.play(renderer.layer.modify({_ in bridge})!)
                    } else {
                        self.updateState(.failed)
                    }
                } else {
                    self.updateState(.failed)
                }
            }
        })
    }
    
    func playAgain() {
        self.layer.with { lottie -> Void in
            if let lottie = lottie {
                self.play(lottie)
            }
        }
    }
    
    private func play(_ player: RLottieBridge) {
        
        self.finished = false
        
        let fps: Int = max(min(Int(player.fps()), self.animation.maximumFps), 30)
        
        let bufferSize = Int(self.animation.size.width) * animation.backingScale * Int(self.animation.size.height) * animation.backingScale * 4
        
        let fileSupplyment: TRLotFileSupplyment?
        switch self.animation.cache {
        case .temporaryLZ4:
            fileSupplyment = TRLotFileSupplyment(self.animation, bufferSize: bufferSize, frames: Int(player.endFrame()))
        case .none:
            fileSupplyment = nil
        }
        
        let maxFrames:Int32 = 180
        
        let initialState = RendererState(cancelled: false, animation: self.animation, layer: player, fileSupplyment: fileSupplyment, frames: [], cachedFrames: [:], currentFrame: 0, startFrame: min(min(player.startFrame(), maxFrames), min(player.endFrame(), maxFrames)), endFrame: min(player.endFrame(), maxFrames), fps: max(min(player.fps(), 60), 30))
        
        let stateValue:Unmanaged<RenderAtomic<RendererState>> = Unmanaged.passRetained(RenderAtomic(value: initialState));
        let updateState:(_ f:(RendererState)->RendererState)->Void = { f in
            _ = stateValue.takeUnretainedValue().modify(f)
        }
        
        var firstTask: ThreadPoolTask? = nil
        var framesTask: ThreadPoolTask? = nil
        
        var releaseState: Bool = false
        let isRendering: Atomic<Bool> = Atomic(value: false)
        
        self.onDispose = {
            updateState {
                $0.cancel()
            }
            firstTask?.cancel()
            framesTask?.cancel()
            
            firstTask = nil
            framesTask = nil
            
            isRendering.with { value in
                if !value {
                    stateValue.release()
                } else {
                    releaseState = true
                }
            }
        }
        
        let currentState:(_ state: Unmanaged<RenderAtomic<RendererState>>) -> RendererState = { state in
            return state.takeUnretainedValue().with { $0 }
        }
        
        
        var add_frames_impl:(()->Void)? = nil
        var askedRender: Bool = false
        
        let render:()->Void = { [weak self] in
            assert(stateQueue.isCurrent())
            if let renderer = self {
                var current: RenderedFrame?
                var hungry: Bool = false
                var cancelled: Bool = false
                updateState { state in
                    guard !state.frames.isEmpty else {
                        return state
                    }
                    current = state.takeFirst()
                    hungry = state.frames.count < maximum_rendered_frames - 1
                    cancelled = state.cancelled
                    return state
                }
                
                if !cancelled {
                    if let current = current {
                        let displayFrame = renderer.displayFrame
                        let updateState = renderer.updateState
                        displayFrame(current)
                        if current.frame > 0 {
                            updateState(.playing)
                        }
                        switch renderer.animation.playPolicy {
                        case .loop:
                            break
                        case .once:
                            if current.frame == currentState(stateValue).endFrame - 1 {
                                renderer.finished = true
                                renderer.timer?.invalidate()
                                firstTask?.cancel()
                                framesTask?.cancel()
                            }
                        }
                        
                    }
                }
                
                isRendering.with { isRendering in
                    if hungry && !isRendering && !cancelled && !askedRender {
                        askedRender = true
                        add_frames_impl?()
                    }
                }
            }
        }
        
        firstTask = ThreadPoolTask({ state in
            stateQueue.async {
                if !state.cancelled.with({$0}) {
                    render()
                } else {
                    askedRender = false
                }
            }
        })
        
        
       // var prerender: Bool = true
        
        let maximum = Int(initialState.startFrame + initialState.endFrame)
        
        
        framesTask = ThreadPoolTask { state in
            
            _ = isRendering.swap(true)
            
            while !releaseState && !state.cancelled.with({$0}) && currentState(stateValue).frames.count < min(maximum_rendered_frames, maximum) {
                
                let currentFrame = stateValue.takeUnretainedValue().with({ ($0.currentFrame) })
                
                let frame: RenderedFrame? = currentState(stateValue).renderFrame(at: currentFrame)
                
                _ = stateValue.takeUnretainedValue().modify { state -> RendererState in
                    var currentFrame = state.currentFrame
                    
                    if currentFrame % Int32(round(Float(state.fps) / Float(fps))) != 0 {
                        currentFrame += 1
                    }
                    if currentFrame >= state.startFrame + state.endFrame - 1 {
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
            _ = isRendering.modify { value -> Bool in
                if releaseState {
                    stateValue.release()
                }
                return false
            }
            stateQueue.async {
                askedRender = false
            }
        }
        
        let add_frames:()->Void = {
            if let framesTask = framesTask {
                lottieThreadPool.addTask(framesTask)
            }
        }
        
        add_frames_impl = {
            add_frames()
        }
        add_frames()
        
        self.timer = SwiftSignalKitMac.Timer(timeout: (1.0 / TimeInterval(fps)), repeat: true, completion: {
            firstTask?.cancel()
            firstTask = nil
            render()
        }, queue: stateQueue)
        
        self.timer?.start()
        
    }
    
}

private final class PlayerContext {
    private let rendererRef: QueueLocalObject<PlayerRenderer>
    fileprivate let animation: LottieAnimation
    init(_ animation: LottieAnimation, displayFrame: @escaping(RenderedFrame)->Void, release:@escaping()->Void, updateState: @escaping(LottiePlayerState)->Void) {
        self.animation = animation
        self.rendererRef = QueueLocalObject.init(queue: stateQueue, generate: {
            return PlayerRenderer(animation: animation, displayFrame: displayFrame, release: release, updateState: { state in
                Queue.mainQueue().async {
                    updateState(state)
                }
            })
        })
        
        self.rendererRef.with { renderer in
            renderer.initializeAndPlay()
        }
    }
    
    func playAgain() {
        self.rendererRef.with { renderer in
            if renderer.finished {
                renderer.playAgain()
            }
        }
    }
    
}


enum ASLiveTime : Int {
    case chat = 3_600
    case thumb = 86_400
}

enum ASCachePurpose {
    case none
    case temporaryLZ4(ASLiveTime)
}

struct LottieAnimationEntryKey : Hashable {
    let size: CGSize
    let backingScale: Int
    let key:LottieAnimationKey
    init(key: LottieAnimationKey, size: CGSize, backingScale: Int = Int(System.backingScale)) {
        self.key = key
        self.size = size
        self.backingScale = backingScale
    }
    
    func withUpdatedBackingScale(_ backingScale: Int) -> LottieAnimationEntryKey {
        return LottieAnimationEntryKey(key: key, size: size, backingScale: backingScale)
    }
    
    func hash(into hasher: inout Hasher) {
        
    }
}

enum LottieAnimationKey : Equatable {
    case media(MediaId?)
}

enum LottiePlayPolicy : Equatable {
    case loop
    case once
}

final class LottieAnimation : Equatable {
    static func == (lhs: LottieAnimation, rhs: LottieAnimation) -> Bool {
        return lhs.key == rhs.key
    }
    
    var liveTime: Int {
        switch cache {
        case .none:
            return 0
        case let .temporaryLZ4(liveTime):
            return liveTime.rawValue
        }
    }
    
    let compressed: Data
    let key: LottieAnimationEntryKey
    let cache: ASCachePurpose
    let maximumFps: Int
    let playPolicy: LottiePlayPolicy
    init(compressed: Data, key: LottieAnimationEntryKey, cachePurpose: ASCachePurpose = .temporaryLZ4(.thumb), playPolicy: LottiePlayPolicy = .loop, maximumFps: Int = 60) {
        self.compressed = compressed
        self.key = key
        self.cache = cachePurpose
        self.maximumFps = maximumFps
        self.playPolicy = playPolicy
    }
    
    var size: NSSize {
        return key.size
    }
    var backingScale: Int {
        return key.backingScale
    }
    
    func withUpdatedBackingScale(_ scale: Int) -> LottieAnimation {
        return LottieAnimation(compressed: self.compressed, key: self.key.withUpdatedBackingScale(scale), cachePurpose: self.cache, playPolicy: self.playPolicy, maximumFps: self.maximumFps)
    }
    
    var cacheKey: String {
        switch key.key {
        case let .media(key):
            if let key = key {
                return "animation-\(key.namespace)-\(key.id)"
            } else {
                return "\(arc4random())"
            }
        }
    }
}
private final class PlayerViewLayer: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }
    
    deinit {
        if !Thread.isMainThread {
            var bp: Int = 0
            bp += 1
        }
        // assertOnMainThread()
    }
}


final class MetalContext {
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    let sampler: MTLSamplerState
    
    init?() {
        if let device = CGDirectDisplayCopyCurrentMetalDevice(CGMainDisplayID()) {
            self.device = device
        } else {
            return nil
        }
        do {
            let library = try device.makeLibrary(source:
                """
using namespace metal;

struct VertexIn {
  packed_float3 position;
  packed_float2 texCoord;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

vertex VertexOut basic_vertex(
    const device VertexIn* vertex_array [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
  VertexIn VertexIn = vertex_array[vid];
  
  VertexOut VertexOut;
  VertexOut.position = float4(VertexIn.position, 1.0);
  VertexOut.texCoord = VertexIn.texCoord;
  
  return VertexOut;
}

fragment float4 basic_fragment(
    VertexOut interpolated [[stage_in]],
    texture2d<float> tex2D [[ texture(0) ]],
    sampler sampler2D [[ sampler(0) ]]
) {
  float4 color = tex2D.sample(sampler2D, interpolated.texCoord);
  return float4(color.b, color.g, color.r, color.a);
}
""", options: nil)
            
            let fragmentProgram = library.makeFunction(name: "basic_fragment")
            let vertexProgram = library.makeFunction(name: "basic_vertex")
            
            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexProgram
            pipelineStateDescriptor.fragmentFunction = fragmentProgram
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            
            
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
            sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0.0
            sampler.lodMaxClamp           = .greatestFiniteMagnitude
            self.sampler = device.makeSamplerState(descriptor: sampler)!
            
        } catch {
            return nil
        }
    }
}

private final class ContextHolder {
    private var useCount: Int = 0
    
    let context: MetalContext
    init?() {
        guard let context = MetalContext() else {
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



private final class MetalRenderer: View {
    private let texture: MTLTexture
    private let commandQueue: MTLCommandQueue?
    private let metalLayer: CAMetalLayer = CAMetalLayer()
    private let context: MetalContext
    init(animation: LottieAnimation, context: MetalContext) {
        self.context = context
        self.commandQueue = context.device.makeCommandQueue()
        let textureDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(animation.size.width) * animation.backingScale, height: Int(animation.size.height) * animation.backingScale, mipmapped: false)
        textureDesc.sampleCount = 1
        textureDesc.textureType = .type2D
        
        self.texture = context.device.makeTexture(descriptor: textureDesc)!
        
        super.init(frame: NSMakeRect(0, 0, animation.size.width, animation.size.height))
        
        self.metalLayer.device = context.device
        self.metalLayer.framebufferOnly = true
        self.metalLayer.isOpaque = false
        self.metalLayer.contentsScale = backingScaleFactor
        self.wantsLayer = true
        self.layer?.addSublayer(metalLayer)
        metalLayer.frame = CGRect(origin: CGPoint(), size: animation.size)
        
        holder?.incrementUseCount()
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
    
    func render(bytes: UnsafeRawPointer, size: NSSize, backingScale: Int) {
        assertNotOnMainThread()
        let region = MTLRegionMake2D(0, 0, Int(size.width) * backingScale, Int(size.height) * backingScale)
        
        self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: Int(size.width) * backingScale * 4)
        
        guard let drawable = metalLayer.nextDrawable(), let commandQueue = self.commandQueue, let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
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
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
}

class LottiePlayerView : NSView {
    private var context: PlayerContext?
    private let stateValue: ValuePromise<LottiePlayerState> = ValuePromise(.stoped, ignoreRepeated: true)
    var state: Signal<LottiePlayerState, NoError> {
        return stateValue.get()
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override func layout() {
        super.layout()
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
    
    func playIfNeeded() {
        if let context = self.context, context.animation.playPolicy == .once {
            context.playAgain()
        }
    }
    
    func set(_ animation: LottieAnimation?) {
        self.stateValue.set(.stoped)
        if let animation = animation {
            if self.context?.animation != animation {
                
                if holder == nil {
                    holder = ContextHolder()
                }
                if let holder = holder {
                    let metal = MetalRenderer(animation: animation, context: holder.context)
                    self.addSubview(metal)
                    let layer = Unmanaged.passRetained(metal)
                    
                    self.context = PlayerContext(animation, displayFrame: { frame in
                        layer.takeUnretainedValue().render(bytes: frame.data, size: frame.size, backingScale: frame.backingScale)
                    }, release: {
                        Queue.mainQueue().async {
                            layer.takeRetainedValue().removeFromSuperview()
                        }
                    }, updateState: { [weak self] state in
                        guard let _ = self?.context else {
                            return
                        }
                        self?.stateValue.set(state)
                    })
                } else {
                    let fallback = NSView()
                    fallback.wantsLayer = true
                    fallback.setFrameSize(animation.size)
                    self.addSubview(fallback)
                    let layer = Unmanaged.passRetained(fallback)
                    
                    self.context = PlayerContext(animation, displayFrame: { frame in
                        
                        let image = generateImagePixel(frame.size, scale: CGFloat(frame.backingScale), pixelGenerator: { (_, pixelData) in
                            memcpy(pixelData, frame.data, frame.bufferSize)
                        })
                        Queue.mainQueue().async {
                            layer.takeUnretainedValue().layer?.contents = image
                        }
                    }, release: {
                        Queue.mainQueue().async {
                            layer.takeRetainedValue().removeFromSuperview()
                        }
                    }, updateState: { [weak self] state in
                        guard let _ = self?.context else {
                            return
                        }
                        self?.stateValue.set(state)
                    })
                }
                
                
            }
            
        } else {
            self.context = nil
        }
    }
}

