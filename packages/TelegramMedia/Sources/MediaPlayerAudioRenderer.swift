import Foundation
import SwiftSignalKit
import CoreMedia
import AVFoundation
import TelegramCore
import MediaPlayer

private enum AudioPlayerRendererState {
    case paused
    case playing(rate: Double, didSetRate: Bool)
}

private final class AudioPlayerRendererBufferContext {
    var state: AudioPlayerRendererState = .paused
    let timebase: CMTimebase
    let buffer: RingByteBuffer
    var bufferMaxChannelSampleIndex: Int64 = 0
    var lowWaterSize: Int
    var notifyLowWater: () -> Void
    var updatedRate: () -> Void
    var notifiedLowWater = false
    var overflowData = Data()
    var overflowDataMaxChannelSampleIndex: Int64 = 0
    var renderTimestampTick: Int64 = 0
    
    init(timebase: CMTimebase, buffer: RingByteBuffer, lowWaterSize: Int, notifyLowWater: @escaping () -> Void, updatedRate: @escaping () -> Void) {
        self.timebase = timebase
        self.buffer = buffer
        self.lowWaterSize = lowWaterSize
        self.notifyLowWater = notifyLowWater
        self.updatedRate = updatedRate
    }
}

private let audioPlayerRendererBufferContextMap = Atomic<[Int32: Atomic<AudioPlayerRendererBufferContext>]>(value: [:])
private let audioPlayerRendererQueue = Queue()

private var _nextPlayerRendererBufferContextId: Int32 = 1
private func registerPlayerRendererBufferContext(_ context: Atomic<AudioPlayerRendererBufferContext>) -> Int32 {
    var id: Int32 = 0
    
    let _ = audioPlayerRendererBufferContextMap.modify { contextMap in
        id = _nextPlayerRendererBufferContextId
        _nextPlayerRendererBufferContextId += 1
        
        var contextMap = contextMap
        contextMap[id] = context
        return contextMap
    }
    return id
}

private func unregisterPlayerRendererBufferContext(_ id: Int32) {
    let _ = audioPlayerRendererBufferContextMap.modify { contextMap in
        var contextMap = contextMap
        let _ = contextMap.removeValue(forKey: id)
        return contextMap
    }
}

private func withPlayerRendererBuffer(_ id: Int32, _ f: (Atomic<AudioPlayerRendererBufferContext>) -> Void) {
    audioPlayerRendererBufferContextMap.with { contextMap in
        if let context = contextMap[id] {
            f(context)
        }
    }
}

private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

private func rendererInputProcPlayer(refCon: UnsafeMutableRawPointer, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    guard let ioData = ioData else {
        return noErr
    }
    
    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    
    var rendererFillOffset = (0, 0)
    var notifyLowWater: (() -> Void)?
    var updatedRate: (() -> Void)?
    
    withPlayerRendererBuffer(Int32(intptr_t(bitPattern: refCon)), { context in
        context.with { context in
            switch context.state {
            case let .playing(rate, didSetRate):
                if context.buffer.availableBytes != 0 {
                    let sampleIndex = context.bufferMaxChannelSampleIndex - Int64(context.buffer.availableBytes / (2 *
                        2))
                    
                    if !didSetRate {
                        context.state = .playing(rate: rate, didSetRate: true)
                        let masterClock: CMClockOrTimebase = CMTimebaseGetMaster(context.timebase)!
                        CMTimebaseSetRateAndAnchorTime(context.timebase, rate: rate, anchorTime: CMTimeMake(value: sampleIndex, timescale: 44100), immediateMasterTime: CMSyncGetTime(masterClock))
                        updatedRate = context.updatedRate
                    } else {
                        context.renderTimestampTick += 1
                        if context.renderTimestampTick % 1000 == 0 {
                            let delta = (Double(sampleIndex) / 44100.0) - CMTimeGetSeconds(CMTimebaseGetTime(context.timebase))
                            if delta > 0.01 {
                                CMTimebaseSetTime(context.timebase, time: CMTimeMake(value: sampleIndex, timescale: 44100))
                                updatedRate = context.updatedRate
                            }
                        }
                    }
                    
                    let rendererBuffer = context.buffer
                    
                    while rendererFillOffset.0 < bufferList.count {
                        if let bufferData = bufferList[rendererFillOffset.0].mData {
                            let bufferDataSize = Int(bufferList[rendererFillOffset.0].mDataByteSize)
                            
                            let dataOffset = rendererFillOffset.1
                            if dataOffset == bufferDataSize {
                                rendererFillOffset = (rendererFillOffset.0 + 1, 0)
                                continue
                            }
                            
                            let consumeCount = bufferDataSize - dataOffset
                            
                            let actualConsumedCount = rendererBuffer.dequeue(bufferData.advanced(by: dataOffset), count: consumeCount)
                            rendererFillOffset.1 += actualConsumedCount
                            
                            if actualConsumedCount == 0 {
                                break
                            }
                        } else {
                            break
                        }
                    }
                }
                
                if !context.notifiedLowWater {
                    let availableBytes = context.buffer.availableBytes
                    if availableBytes <= context.lowWaterSize {
                        context.notifiedLowWater = true
                        notifyLowWater = context.notifyLowWater
                    }
                }
            case .paused:
                break
            }
        }
    })
    
    for i in rendererFillOffset.0 ..< bufferList.count {
        var dataOffset = 0
        if i == rendererFillOffset.0 {
            dataOffset = rendererFillOffset.1
        }
        if let data = bufferList[i].mData {
            memset(data.advanced(by: dataOffset), 0, Int(bufferList[i].mDataByteSize) - dataOffset)
        }
    }
    
    if let notifyLowWater = notifyLowWater {
        notifyLowWater()
    }
    
    if let updatedRate = updatedRate {
        updatedRate()
    }
    
    return noErr
}

private struct RequestingFramesContext {
    let queue: DispatchQueue
    let takeFrame: () -> MediaTrackFrameResult
}

private final class AudioPlayerRendererContext {
    let audioStreamDescription: AudioStreamBasicDescription
    let bufferSizeInSeconds: Int = 5
    let lowWaterSizeInSeconds: Int = 2
    
    let controlTimebase: CMTimebase
    let updatedRate: () -> Void
    let audioPaused: () -> Void
    
    var paused = true
    var baseRate: Double
    var volume: Float
    
    var audioGraph: AUGraph?
    var timePitchAudioUnit: AudioComponentInstance?
    var outputAudioUnit: AudioComponentInstance?
    
    var bufferContextId: Int32!
    let bufferContext: Atomic<AudioPlayerRendererBufferContext>
    
    var requestingFramesContext: RequestingFramesContext?
    
    let audioSessionDisposable = MetaDisposable()
    var audioSessionControl: ManagedAudioSessionControl?
    let playAndRecord: Bool
    var forceAudioToSpeaker: Bool {
        didSet {
            if self.forceAudioToSpeaker != oldValue {
                if let audioSessionControl = self.audioSessionControl {
                    audioSessionControl.setOutputMode(self.forceAudioToSpeaker ? .speakerIfNoHeadphones : .system)
                }
            }
        }
    }
    
    init(controlTimebase: CMTimebase, playAndRecord: Bool, forceAudioToSpeaker: Bool, baseRate: Double, volume: Float, updatedRate: @escaping () -> Void, audioPaused: @escaping () -> Void) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.forceAudioToSpeaker = forceAudioToSpeaker
        self.baseRate = baseRate
        
        self.controlTimebase = controlTimebase
        self.updatedRate = updatedRate
        self.audioPaused = audioPaused
        self.volume = volume
        self.playAndRecord = playAndRecord
        
        self.audioStreamDescription = audioRendererNativeStreamDescription()
        
        let bufferSize = Int(self.audioStreamDescription.mSampleRate) * self.bufferSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        let lowWaterSize = Int(self.audioStreamDescription.mSampleRate) * self.lowWaterSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        
        var notifyLowWater: () -> Void = { }
        
        self.bufferContext = Atomic(value: AudioPlayerRendererBufferContext(timebase: controlTimebase, buffer: RingByteBuffer(size: bufferSize), lowWaterSize: lowWaterSize, notifyLowWater: {
            notifyLowWater()
        }, updatedRate: {
            updatedRate()
        }))
        self.bufferContextId = registerPlayerRendererBufferContext(self.bufferContext)
        
        notifyLowWater = { [weak self] in
            audioPlayerRendererQueue.async {
                if let strongSelf = self {
                    strongSelf.checkBuffer()
                }
            }
        }
    }
    
    deinit {
       // assert(audioPlayerRendererQueue.isCurrent())
        
        self.audioSessionDisposable.dispose()
        
        unregisterPlayerRendererBufferContext(self.bufferContextId)
        
        self.closeAudioUnit()
    }
    
    fileprivate func setBaseRate(_ baseRate: Double) {
        if let timePitchAudioUnit = self.timePitchAudioUnit, !self.baseRate.isEqual(to: baseRate) {
            self.baseRate = baseRate
            AudioUnitSetParameter(timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, Float32(baseRate), 0)
            self.bufferContext.with { context in
                if case .playing = context.state {
                    context.state = .playing(rate: baseRate, didSetRate: false)
                }
            }
        }
    }
    
    fileprivate func setRate(_ rate: Double) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if !rate.isZero && self.paused {
            self.start()
        }
        
        let baseRate = self.baseRate
        
        self.bufferContext.with { context in
            if !rate.isZero {
                if case .playing = context.state {
                } else {
                    context.state = .playing(rate: baseRate, didSetRate: false)
                }
            } else {
                context.state = .paused
                CMTimebaseSetRate(context.timebase, rate: 0.0)
            }
        }
    }
    
    fileprivate func flushBuffers(at timestamp: CMTime, completion: () -> Void) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            context.buffer.clear()
            context.bufferMaxChannelSampleIndex = 0
            context.notifiedLowWater = false
            context.overflowData = Data()
            context.overflowDataMaxChannelSampleIndex = 0
            CMTimebaseSetTime(context.timebase, time: timestamp)
            
            switch context.state {
            case let .playing(rate, _):
                context.state = .playing(rate: rate, didSetRate: false)
            case .paused:
                break
            }
        }
        
        completion()
    }
    
    fileprivate func start() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if self.paused {
            self.paused = false
            self.startAudioUnit()
        }
    }
    
    fileprivate func stop() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if !self.paused {
            self.paused = true
            self.setRate(0.0)
            self.closeAudioUnit()
        }
    }
    
    private func startAudioUnit() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if self.audioGraph == nil {
            var maybeAudioGraph: AUGraph?
            guard NewAUGraph(&maybeAudioGraph) == noErr, let audioGraph = maybeAudioGraph else {
                return
            }
            
            var converterNode: AUNode = 0
            var converterDescription = AudioComponentDescription()
            converterDescription.componentType = kAudioUnitType_FormatConverter
            converterDescription.componentSubType = kAudioUnitSubType_AUConverter
            converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &converterDescription, &converterNode) == noErr else {
                return
            }
            
            var timePitchNode: AUNode = 0
            var timePitchDescription = AudioComponentDescription()
            timePitchDescription.componentType = kAudioUnitType_FormatConverter
            timePitchDescription.componentSubType = kAudioUnitSubType_AUiPodTimeOther
            timePitchDescription.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &timePitchDescription, &timePitchNode) == noErr else {
                return
            }
            
            var outputNode: AUNode = 0
            var outputDesc = AudioComponentDescription()
            outputDesc.componentType = kAudioUnitType_Output
            outputDesc.componentSubType = kAudioUnitSubType_HALOutput
            outputDesc.componentFlags = 0
            outputDesc.componentFlagsMask = 0
            outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &outputDesc, &outputNode) == noErr else {
                return
            }
            
            guard AUGraphOpen(audioGraph) == noErr else {
                return
            }
            
            guard AUGraphConnectNodeInput(audioGraph, converterNode, 0, timePitchNode, 0) == noErr else {
                return
            }
            
            guard AUGraphConnectNodeInput(audioGraph, timePitchNode, 0, outputNode, 0) == noErr else {
                return
            }
            
            var maybeConverterAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, converterNode, &converterDescription, &maybeConverterAudioUnit) == noErr, let converterAudioUnit = maybeConverterAudioUnit else {
                return
            }
            
            var maybeTimePitchAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, timePitchNode, &timePitchDescription, &maybeTimePitchAudioUnit) == noErr, let timePitchAudioUnit = maybeTimePitchAudioUnit else {
                return
            }
            AudioUnitSetParameter(timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, Float32(self.baseRate), 0)
            
            var maybeOutputAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, outputNode, &outputDesc, &maybeOutputAudioUnit) == noErr, let outputAudioUnit = maybeOutputAudioUnit else {
                return
            }
            
            var outputAudioFormat = audioRendererNativeStreamDescription()
            
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputAudioFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            
            var streamFormat = AudioStreamBasicDescription()
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            AudioUnitSetProperty(timePitchAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            
            var callbackStruct = AURenderCallbackStruct()
            callbackStruct.inputProc = rendererInputProcPlayer
            callbackStruct.inputProcRefCon = UnsafeMutableRawPointer(bitPattern: intptr_t(self.bufferContextId))
            
            guard AUGraphSetNodeInputCallback(audioGraph, converterNode, 0, &callbackStruct) == noErr else {
                return
            }
            
            var one: UInt32 = 1
            guard AudioUnitSetProperty(outputAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &one, 4) == noErr else {
                return
            }
            
            AudioUnitSetParameter(outputAudioUnit, kHALOutputParam_Volume, kAudioUnitScope_Output, kOutputBus, max(min(1, volume), 0), 0)
                        
//            guard AudioUnitSetParameter(outputAudioUnit, kHALOutputParam_Volume, kAudioUnitScope_Output, kOutputBus, 0.1, 0) == noErr else {
//                return
//            }
            
            var maximumFramesPerSlice: UInt32 = 4096
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            AudioUnitSetProperty(timePitchAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            AudioUnitSetProperty(outputAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            
            guard AUGraphInitialize(audioGraph) == noErr else {
                return
            }
            
            self.audioGraph = audioGraph
            self.timePitchAudioUnit = timePitchAudioUnit
            self.outputAudioUnit = outputAudioUnit
        }
        audioSessionAcquired()
    }
    
    
    
    func setVolume(_ volume: Float)  {
        assert(audioPlayerRendererQueue.isCurrent())
        self.volume = max(min(1, volume), 0)
        if let outputAudioUnit = outputAudioUnit {
            AudioUnitSetParameter(outputAudioUnit, kHALOutputParam_Volume, kAudioUnitScope_Output, kOutputBus, self.volume, 0)
           
        }
    }
    
    private func audioSessionAcquired() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let audioGraph = self.audioGraph {
            guard AUGraphStart(audioGraph) == noErr else {
                self.closeAudioUnit()
                return
            }
        }
    }
    
    private func closeAudioUnit() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let audioGraph = self.audioGraph {
            var status = noErr
            
            self.bufferContext.with { context in
                context.buffer.clear()
            }
            
            status = AUGraphStop(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphStop error \(status)")
            }
            
            status = AUGraphUninitialize(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphUninitialize error \(status)")
            }
            
            status = AUGraphClose(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphClose error \(status)")
            }
            
            status = DisposeAUGraph(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "DisposeAUGraph error \(status)")
            }
            
            self.audioGraph = nil
            self.outputAudioUnit = nil
            self.timePitchAudioUnit = nil
        }
    }
    
    func checkBuffer() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        while true {
            let bytesToRequest = self.bufferContext.with { context -> Int in
                let availableBytes = context.buffer.availableBytes
                if availableBytes <= context.lowWaterSize {
                    return context.buffer.size - availableBytes
                } else {
                    return 0
                }
            }
            
            if bytesToRequest == 0 {
                self.bufferContext.with { context in
                    context.notifiedLowWater = false
                }
                break
            }
            
            let overflowTakenLength = self.bufferContext.with { context -> Int in
                let takeLength = min(context.overflowData.count, bytesToRequest)
                if takeLength != 0 {
                    if takeLength == context.overflowData.count {
                        let data = context.overflowData
                        context.overflowData = Data()
                        self.enqueueSamples(data, sampleIndex: context.overflowDataMaxChannelSampleIndex - Int64(data.count / (2 * 2)))
                    } else {
                        let data = context.overflowData.subdata(in: 0 ..< takeLength)
                        self.enqueueSamples(data, sampleIndex: context.overflowDataMaxChannelSampleIndex - Int64(context.overflowData.count / (2 * 2)))
                        context.overflowData.replaceSubrange(0 ..< takeLength, with: Data())
                    }
                }
                return takeLength
            }
            
            if overflowTakenLength != 0 {
                continue
            }
            
            if let requestingFramesContext = self.requestingFramesContext {
                requestingFramesContext.queue.async {
                    let takenFrame = requestingFramesContext.takeFrame()
                    audioPlayerRendererQueue.async {
                        switch takenFrame {
                        case let .frame(frame):
                            if let dataBuffer = CMSampleBufferGetDataBuffer(frame.sampleBuffer) {
                                let dataLength = CMBlockBufferGetDataLength(dataBuffer)
                                let takeLength = min(dataLength, bytesToRequest)
                                
                                let pts = CMSampleBufferGetPresentationTimeStamp(frame.sampleBuffer)
                                let bufferSampleIndex = CMTimeConvertScale(pts, timescale: 44100, method: .roundAwayFromZero).value
                                
                                let bytes = malloc(takeLength)!
                                CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: takeLength, destination: bytes)
                                self.enqueueSamples(Data(bytesNoCopy: bytes.assumingMemoryBound(to: UInt8.self), count: takeLength, deallocator: .free), sampleIndex: bufferSampleIndex)
                                
                                if takeLength < dataLength {
                                    self.bufferContext.with { context in
                                        let copyOffset = context.overflowData.count
                                        context.overflowData.count += dataLength - takeLength
                                        context.overflowData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                                            CMBlockBufferCopyDataBytes(dataBuffer, atOffset: takeLength, dataLength: dataLength - takeLength, destination: bytes.advanced(by: copyOffset))
                                        }
                                    }
                                }
                                
                                self.checkBuffer()
                            } else {
                                assertionFailure()
                            }
                        case .restoreState:
                            assertionFailure()
                            self.checkBuffer()
                            break
                        case .skipFrame:
                            self.checkBuffer()
                            break
                        case .noFrames, .finished:
                            self.requestingFramesContext = nil
                        }
                    }
                }
            } else {
                self.bufferContext.with { context in
                    context.notifiedLowWater = false
                }
            }
            
            break
        }
    }
    
    private func enqueueSamples(_ data: Data, sampleIndex: Int64) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            let bytesToCopy = min(context.buffer.size - context.buffer.availableBytes, data.count)
            data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                let _ = context.buffer.enqueue(UnsafeRawPointer(bytes), count: bytesToCopy)
                context.bufferMaxChannelSampleIndex = sampleIndex + Int64(data.count / (2 * 2))
            }
        }
    }
    
    fileprivate func beginRequestingFrames(queue: DispatchQueue, takeFrame: @escaping () -> MediaTrackFrameResult) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let _ = self.requestingFramesContext {
            return
        }
        
        self.requestingFramesContext = RequestingFramesContext(queue: queue, takeFrame: takeFrame)
        
        self.checkBuffer()
    }
    
    func endRequestingFrames() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.requestingFramesContext = nil
    }
}

private func audioRendererNativeStreamDescription() -> AudioStreamBasicDescription {
    var canonicalBasicStreamDescription = AudioStreamBasicDescription()
    canonicalBasicStreamDescription.mSampleRate = 44100.00
    canonicalBasicStreamDescription.mFormatID = kAudioFormatLinearPCM
    canonicalBasicStreamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
    canonicalBasicStreamDescription.mFramesPerPacket = 1
    canonicalBasicStreamDescription.mChannelsPerFrame = 2
    canonicalBasicStreamDescription.mBytesPerFrame = 2 * 2
    canonicalBasicStreamDescription.mBitsPerChannel = 8 * 2
    canonicalBasicStreamDescription.mBytesPerPacket = 2 * 2
    return canonicalBasicStreamDescription
}

final class MediaPlayerAudioSessionCustomControl {
    let activate: () -> Void
    let deactivate: () -> Void
    
    init(activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
        self.activate = activate
        self.deactivate = deactivate
    }
}

enum MediaPlayerAudioSessionControl {
    case manager(ManagedAudioSession)
    case custom((MediaPlayerAudioSessionCustomControl) -> Disposable)
}

public struct AudioAddress {
    public static var outputDevice = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                         mScope: kAudioObjectPropertyScopeGlobal,
                                                         mElement: kAudioObjectPropertyElementMaster)
    
    public static var nominalSampleRates = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamFormat,
                                                         mScope: kAudioObjectPropertyScopeOutput,
                                                         mElement: kAudioObjectPropertyElementMaster)

    
    public static var inputDevice = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                         mScope: kAudioObjectPropertyScopeGlobal,
                                                         mElement: kAudioObjectPropertyElementMaster)

}

public enum AudioNotification: String {
    case audioDevicesDidChange
    case audioInputDeviceDidChange
    case audioOutputDeviceDidChange
    case mixStereo
    
    public var stringValue: String {
        return "Audio" + rawValue
    }
    
    public var notificationName: NSNotification.Name {
        return NSNotification.Name(stringValue)
    }
}

public struct AudioListener {
    public static var output: AudioObjectPropertyListenerProc = { _, _, _, _ in
        NotificationCenter.default.post(name: AudioNotification.audioOutputDeviceDidChange.notificationName, object: nil)
        return 0
    }
    public static var input: AudioObjectPropertyListenerProc = { _, _, _, _ in
        NotificationCenter.default.post(name: AudioNotification.audioInputDeviceDidChange.notificationName, object: nil)
        return 0
    }
}


final class MediaPlayerAudioRenderer {
    private var contextRef: Unmanaged<AudioPlayerRendererContext>?
    
    let audioTimebase: CMTimebase
    
    init(playAndRecord: Bool, forceAudioToSpeaker: Bool, baseRate: Double, volume: Float, updatedRate: @escaping () -> Void, audioPaused: @escaping () -> Void) {
        
        
        audioPlayerRendererQueue.sync{}
        
        var audioClock: CMClock?
        
        var deviceId:AudioDeviceID = AudioDeviceID()
        var deviceIdRequest:AudioObjectPropertyAddress  = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var deviceIdSize:UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
        
         _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceIdRequest, 0, nil, &deviceIdSize, &deviceId)
        
        CMAudioDeviceClockCreateFromAudioDeviceID(allocator: kCFAllocatorDefault, deviceID: deviceId, clockOut: &audioClock)

        if audioClock == nil {
            CMAudioDeviceClockCreate(allocator: nil, deviceUID: nil, clockOut: &audioClock)
        }
        
        
        var audioTimebase: CMTimebase?
        if let audioClock = audioClock {
            CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: audioClock, timebaseOut: &audioTimebase)
        }
        
        
        if audioTimebase == nil {
            CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &audioTimebase)
        }
        
        let timebase = audioTimebase!
        
        
      //  AudioAddress.outputDevice
        
        self.audioTimebase = timebase
        CMTimebaseSetRate(self.audioTimebase, rate: baseRate)
        audioPlayerRendererQueue.async {
            let context = AudioPlayerRendererContext(controlTimebase: timebase, playAndRecord: playAndRecord, forceAudioToSpeaker: forceAudioToSpeaker, baseRate: baseRate, volume: volume, updatedRate: updatedRate, audioPaused: audioPaused)
            self.contextRef = Unmanaged.passRetained(context)
            context.setVolume(volume)
        }
        
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)), name: AudioNotification.audioOutputDeviceDidChange.notificationName, object: nil)
        

        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification(_:)), name: AudioNotification.mixStereo.notificationName, object: nil)

    }
    
    @objc private func handleNotification(_ notification: Notification) {
    
        audioPlayerRendererQueue.async {
            
            let context = self.contextRef!.takeRetainedValue()
            
            let newContext = AudioPlayerRendererContext(controlTimebase: context.controlTimebase, playAndRecord: false, forceAudioToSpeaker: false, baseRate: context.baseRate, volume: context.volume, updatedRate: context.updatedRate, audioPaused: context.audioPaused)
            
            self.contextRef = Unmanaged.passRetained(newContext)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
        let contextRef = self.contextRef
        audioPlayerRendererQueue.async {
            contextRef?.release()
        }
    }
    
    func start() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.start()
            }
        }
    }
    
    func stop() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.stop()
            }
        }
    }
    
    func volume(_  completion: @escaping (Float) -> Void) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                completion(context.volume)
            }
        }
    }
    
    func setVolume(_ volume: Float) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setVolume(volume)
            }
        }
    }
    
    func setRate(_ rate: Double) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setRate(rate)
            }
        }
    }
    
    func setBaseRate(_ baseRate: Double) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setBaseRate(baseRate)
            }
        }
    }
    
    func beginRequestingFrames(queue: DispatchQueue, takeFrame: @escaping () -> MediaTrackFrameResult) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.beginRequestingFrames(queue: queue, takeFrame: takeFrame)
            }
        }
    }
    
    func flushBuffers(at timestamp: CMTime, completion: @escaping () -> Void) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.flushBuffers(at: timestamp, completion: completion)
            }
        }
    }
    
    func setForceAudioToSpeaker(_ value: Bool) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.forceAudioToSpeaker = value
            }
        }
    }
}
