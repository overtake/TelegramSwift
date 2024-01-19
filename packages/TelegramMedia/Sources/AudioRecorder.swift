//
//  AudioRecorder.swift
//  TelegramMac
//
//  Created by keepcoder on 08/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import OpusBinding
import Foundation
import SwiftSignalKit
import CoreMedia
import AVFoundation
import TelegramCore

private final class CustomAudioConverter {
    struct Format: Equatable {
        let numChannels: Int
        let sampleRate: Int
    }

    let format: Format

    var asbd: AudioStreamBasicDescription
    var currentBuffer: AudioBuffer?
    var currentBufferOffset: UInt32 = 0

    init(asbd: AudioStreamBasicDescription) {
        self.asbd = asbd
        self.format = Format(
            numChannels: Int(asbd.mChannelsPerFrame),
            sampleRate: Int(asbd.mSampleRate)
        )
    }

    func convert(buffer: AudioBuffer) -> Data? {
                
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)

        

        let size = bufferList.mBuffers.mDataByteSize
        guard size != 0, let mData = bufferList.mBuffers.mData else {
            return nil
        }

        var outputDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var maybeAudioConverter: AudioConverterRef?
        let _ = AudioConverterNew(&asbd, &outputDescription, &maybeAudioConverter)
        guard let audioConverter = maybeAudioConverter else {
            return nil
        }
        
        self.currentBuffer = AudioBuffer(
            mNumberChannels: asbd.mChannelsPerFrame,
            mDataByteSize: UInt32(size),
            mData: mData
        )
        self.currentBufferOffset = 0

        var numPackets: UInt32?
        let outputSize = 32768 * 2
        var outputBuffer = Data(count: outputSize)
        outputBuffer.withUnsafeMutableBytes { (outputBytes: UnsafeMutableRawBufferPointer) -> Void in
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = outputDescription.mChannelsPerFrame
            outputBufferList.mBuffers.mDataByteSize = UInt32(outputSize)
            outputBufferList.mBuffers.mData = outputBytes.baseAddress!

            var outputDataPacketSize = UInt32(outputSize) / outputDescription.mBytesPerPacket

            let result = AudioConverterFillComplexBuffer(
                audioConverter,
                converterComplexInputDataProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &outputDataPacketSize,
                &outputBufferList,
                nil
            )
            if result == noErr {
                numPackets = outputDataPacketSize
            }
        }

        AudioConverterDispose(audioConverter)

        if let numPackets = numPackets {
            outputBuffer.count = Int(numPackets * outputDescription.mBytesPerPacket)
            return outputBuffer
        } else {
            return nil
        }
    }
}



private func converterComplexInputDataProc(inAudioConverter: AudioConverterRef, ioNumberDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, ioDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, inUserData: UnsafeMutableRawPointer?) -> Int32 {
    guard let inUserData = inUserData else {
        ioNumberDataPackets.pointee = 0
        return 0
    }
    let instance = Unmanaged<CustomAudioConverter>.fromOpaque(inUserData).takeUnretainedValue()
    guard let currentBuffer = instance.currentBuffer else {
        ioNumberDataPackets.pointee = 0
        return 0
    }
    let currentInputDescription = instance.asbd

    let numPacketsInBuffer = currentBuffer.mDataByteSize / currentInputDescription.mBytesPerPacket
    let numPacketsAvailable = numPacketsInBuffer - instance.currentBufferOffset / currentInputDescription.mBytesPerPacket

    let numPacketsToRead = min(ioNumberDataPackets.pointee, numPacketsAvailable)
    ioNumberDataPackets.pointee = numPacketsToRead

    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mData = currentBuffer.mData?.advanced(by: Int(instance.currentBufferOffset))
    ioData.pointee.mBuffers.mDataByteSize = currentBuffer.mDataByteSize - instance.currentBufferOffset
    ioData.pointee.mBuffers.mNumberChannels = currentBuffer.mNumberChannels

    instance.currentBufferOffset += numPacketsToRead * currentInputDescription.mBytesPerPacket

    return 0
}


private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

public func audioRecorderNativeStreamDescription(_ sampleRate:Float64) -> AudioStreamBasicDescription {
    var canonicalBasicStreamDescription = AudioStreamBasicDescription()
    canonicalBasicStreamDescription.mSampleRate = sampleRate
    canonicalBasicStreamDescription.mFormatID = kAudioFormatLinearPCM
    canonicalBasicStreamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
    canonicalBasicStreamDescription.mFramesPerPacket = 1
    canonicalBasicStreamDescription.mChannelsPerFrame = 1
    canonicalBasicStreamDescription.mBitsPerChannel = 16
    canonicalBasicStreamDescription.mBytesPerPacket = 2
    canonicalBasicStreamDescription.mBytesPerFrame = 2
    return canonicalBasicStreamDescription
}

private var nextRecorderContextId: Int32 = 0
public func getNextRecorderContextId() -> Int32 {
    return OSAtomicIncrement32(&nextRecorderContextId)
}

public protocol RecoderContextRenderer : AnyObject {
    func processAndDisposeAudioBuffer(_ buffer: AudioBuffer)
}

final class RecorderContextHolder {
    weak var context: RecoderContextRenderer?
    
    init(context: RecoderContextRenderer?) {
        self.context = context
    }
}

final class AudioUnitHolder {
    let queue: Queue
    let audioUnit: Atomic<AudioUnit?>
    
    init(queue: Queue, audioUnit: Atomic<AudioUnit?>) {
        self.queue = queue
        self.audioUnit = audioUnit
    }
}

private var audioRecorderContexts: [Int32: RecorderContextHolder] = [:]
private var audioUnitHolders = Atomic<[Int32: AudioUnitHolder]>(value: [:])

public func addAudioRecorderContext(_ id: Int32, _ context: RecoderContextRenderer) {
    audioRecorderContexts[id] = RecorderContextHolder(context: context)
}

public func removeAudioRecorderContext(_ id: Int32) {
    audioRecorderContexts.removeValue(forKey: id)
}

public func addAudioUnitHolder(_ id: Int32, _ queue: Queue, _ audioUnit: Atomic<AudioUnit?>) {
    _ = audioUnitHolders.modify { dict in
        var dict = dict
        dict[id] = AudioUnitHolder(queue: queue, audioUnit: audioUnit)
        return dict
    }
}

public func removeAudioUnitHolder(_ id: Int32) {
    _ = audioUnitHolders.modify { dict in
        var dict = dict
        dict.removeValue(forKey: id)
        return dict
    }
}

func withAudioRecorderContext(_ id: Int32, _ f: (RecoderContextRenderer?) -> Void) {
    if let holder = audioRecorderContexts[id], let context = holder.context {
        f(context)
    } else {
        f(nil)
    }
}

func withAudioUnitHolder(_ id: Int32, _ f: (Atomic<AudioUnit?>, Queue) -> Void) {
    let audioUnitAndQueue = audioUnitHolders.with { dict -> (Atomic<AudioUnit?>, Queue)? in
        if let record = dict[id] {
            return (record.audioUnit, record.queue)
        } else {
            return nil
        }
    }
    if let (audioUnit, queue) = audioUnitAndQueue {
        f(audioUnit, queue)
    }
}

public func rendererInputProc(refCon: UnsafeMutableRawPointer, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    let id = Int32(intptr_t(bitPattern: refCon))
    
    withAudioUnitHolder(id, { (holder, queue) in
        var buffer = AudioBuffer()
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = inNumberFrames * 2;
        buffer.mData = malloc(Int(inNumberFrames) * 2)
        
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        
        var status = noErr
        holder.with { audioUnit in
            if let audioUnit = audioUnit {
                status = AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList)
            } else {
                status = kAudioUnitErr_FailedInitialization
            }
        }
        
        if status == noErr {
            queue.async {
                withAudioRecorderContext(id, { context in
                    if let context = context {
                        context.processAndDisposeAudioBuffer(buffer)
                    } else {
                        free(buffer.mData)
                    }
                })
            }
        } else {
            free(buffer.mData)
            trace1("ManagedAudioRecorder", what: "AudioUnitRender returned \(status)")
        }
    })
    
    return noErr
}

public struct RecordedAudioData {
    public let compressedData: Data
    public let duration: Double
    public let waveform: Data?
    public let id:Int64?
    public let path: String
    public init(compressedData: Data, duration: Double, waveform: Data?, id: Int64?, path: String) {
        self.compressedData = compressedData
        self.duration = duration
        self.waveform = waveform
        self.id = id
        self.path = path
    }
}


final class ManagedAudioRecorderContext : RecoderContextRenderer {
    private let id: Int32
    private let micLevel: ValuePromise<Float>
    private let recordingState: ValuePromise<AudioRecordingState>
    private let liveUploading:PreUploadManager?
    private var paused = true
    
    private let queue: Queue
    private let oggWriter: TGOggOpusWriter
    private let dataItem: DataItem
    private var audioBuffer = Data()
    
    private let audioUnit = Atomic<AudioUnit?>(value: nil)
    
    private var waveformSamples = Data()
    private var waveformPeak: Int16 = 0
    private var waveformPeakCount: Int = 0
    
    private var micLevelPeak: Int16 = 0
    private var micLevelPeakCount: Int = 0
    private var sampleRate: Int32 = 0
    
    fileprivate var isPaused = false
    private var convertor: CustomAudioConverter!
    
    private var recordingStateUpdateTimestamp: Double?
    
    
    init(queue: Queue, micLevel: ValuePromise<Float>, recordingState: ValuePromise<AudioRecordingState>, liveUploading: PreUploadManager?, dataItem: DataItem) {
        assert(queue.isCurrent())
        self.liveUploading = liveUploading
        self.id = getNextRecorderContextId()
        self.micLevel = micLevel
        self.recordingState = recordingState
        
        self.queue = queue
        self.dataItem = dataItem
        self.oggWriter = TGOggOpusWriter()
        
        addAudioRecorderContext(self.id, self)
        addAudioUnitHolder(self.id, queue, self.audioUnit)
        
        self.oggWriter.begin(with: self.dataItem)
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        removeAudioRecorderContext(self.id)
        removeAudioUnitHolder(self.id)
        
        self.stop()
        
    }
    
    func start() {
        assert(self.queue.isCurrent())
        
        self.paused = false
        
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_HALOutput
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        guard let inputComponent = AudioComponentFindNext(nil, &desc) else {
            return
        }
        var maybeAudioUnit: AudioUnit? = nil
        AudioComponentInstanceNew(inputComponent, &maybeAudioUnit)
        
        guard let audioUnit = maybeAudioUnit else {
            return
        }
        
        var o: UInt32 = 1
        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &o, 4) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var z: UInt32 = 0
        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &z, 4) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var deviceId:AudioDeviceID = AudioDeviceID()
        var deviceIdRequest:AudioObjectPropertyAddress  = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var deviceIdSize:UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceIdRequest, 0, nil, &deviceIdSize, &deviceId) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }

        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, kOutputBus, &deviceId, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr else {
            return
        }
//
        var deviceDataRequest:AudioObjectPropertyAddress =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyAvailableNominalSampleRates, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var deviceDataSize:UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceId, &deviceDataRequest, 0, nil, &deviceDataSize) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        let audioValueCount = deviceDataSize / UInt32(MemoryLayout<AudioValueRange>.size)
        var table:[AudioValueRange] = Array<AudioValueRange>(repeating: AudioValueRange(), count: Int(audioValueCount))

        guard AudioObjectGetPropertyData(deviceId, &deviceDataRequest, 0, nil, &deviceDataSize, &table) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }

        
        var inputSampleRate:AudioValueRange = table[0]
        for i in 0 ..< Int(audioValueCount) {
            if table[i].mMinimum == 48000 {
                inputSampleRate = table[i]
                break
            }
        }
        deviceDataRequest.mSelector = kAudioDevicePropertyNominalSampleRate
        guard AudioObjectSetPropertyData(deviceId, &deviceDataRequest, 0, nil, UInt32(MemoryLayout<AudioValueRange>.size), &inputSampleRate) == noErr else {
            return
        }
        
        var audioStreamDescription = audioRecorderNativeStreamDescription(inputSampleRate.mMaximum)
        sampleRate = Int32(inputSampleRate.mMaximum)
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioStreamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        self.convertor = CustomAudioConverter(asbd: audioStreamDescription)
        
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioStreamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var callbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = rendererInputProc
        callbackStruct.inputProcRefCon = UnsafeMutableRawPointer(bitPattern: intptr_t(self.id))
        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var zero: UInt32 = 0
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 0, &zero, 4) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        guard AudioUnitInitialize(audioUnit) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        _ = self.audioUnit.swap(audioUnit)

        
        audioSessionAcquired()
        
    }
    
    
    func audioSessionAcquired() {
        self.audioUnit.with { audioUnit -> Void in
            if let audioUnit = audioUnit {
                guard AudioOutputUnitStart(audioUnit) == noErr else {
                    self.stop()
                    return
                }
            }
        }
    }

    
    func stop() {
        assert(self.queue.isCurrent())
        
        self.paused = true
        
        if let audioUnit = self.audioUnit.swap(nil) {
            var status = noErr
            
            status = AudioOutputUnitStop(audioUnit)
            if status != noErr {
                trace1("ManagedAudioRecorder", what: "AudioOutputUnitStop returned \(status)")
            }
            
            status = AudioUnitUninitialize(audioUnit)
            if status != noErr {
                trace1("ManagedAudioRecorder", what: "AudioUnitUninitialize returned \(status)")
            }
            
            status = AudioComponentInstanceDispose(audioUnit)
            if status != noErr {
                trace1("ManagedAudioRecorder", what: "AudioComponentInstanceDispose returned \(status)")
            }
        }
        
    }
    
//    func processAndDisposeAudioBuffer(_ buffer: AudioBuffer) {
//        assert(self.queue.isCurrent())
//
//        guard let data = convertor.convert(buffer: buffer) else {
//            return
//        }
//
//        defer {
//            free(buffer.mData)
//        }
//
//        let millisecondsPerPacket = 60
//        let encoderPacketSizeInBytes = 16000 / 1000 * millisecondsPerPacket * 2
//
//        let currentEncoderPacket = malloc(encoderPacketSizeInBytes)!
//        defer {
//            free(currentEncoderPacket)
//        }
//
//        var bufferOffset = 0
//
////        NSLog("byteSize: \(buffer.mDataByteSize), \(data.count), encder: \(encoderPacketSizeInBytes)")
//
//        while true {
//            var currentEncoderPacketSize = 0
//
//            while currentEncoderPacketSize < encoderPacketSizeInBytes {
//                if audioBuffer.count != 0 {
//                    let takenBytes = min(self.audioBuffer.count, encoderPacketSizeInBytes - currentEncoderPacketSize)
//                    if takenBytes != 0 {
//                        self.audioBuffer.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
//                            memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), bytes, takenBytes)
//                        }
//                        self.audioBuffer.replaceSubrange(0 ..< takenBytes, with: Data())
//                        currentEncoderPacketSize += takenBytes
//                    }
//                } else if bufferOffset < data.count {
//                    let takenBytes = min(data.count - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize)
//                    if takenBytes != 0 {
//                        self.audioBuffer.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
//                            memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), data.withUnsafeBytes {
//                                $0.advanced(by: bufferOffset)
//                            }, takenBytes)
//                        }
//                        bufferOffset += takenBytes
//                        currentEncoderPacketSize += takenBytes
//                    }
//                } else {
//                    break
//                }
//            }
//
//            if currentEncoderPacketSize < encoderPacketSizeInBytes {
//                self.audioBuffer.append(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), count: currentEncoderPacketSize)
//                break
//            } else {
//
//
//                self.processWaveformPreview(samples: currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)
//
//                self.oggWriter.writeFrame(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), frameByteCount: UInt(currentEncoderPacketSize))
//                liveUploading?.fileDidChangedSize(false)
//                let timestamp = CACurrentMediaTime()
//                if self.recordingStateUpdateTimestamp == nil || self.recordingStateUpdateTimestamp! < timestamp + 0.1 {
//                    self.recordingStateUpdateTimestamp = timestamp
//                    self.recordingState.set(.recording(duration: oggWriter.encodedDuration(), durationMediaTimestamp: timestamp))
//                }
//
//            }
//        }
//    }
    
    func processAndDisposeAudioBuffer(_ buffer: AudioBuffer) {
            assert(self.queue.isCurrent())
            
            var buffer = buffer
            
            if(sampleRate == 16000 || sampleRate == 24000) {
                let ratio = UInt32(48000.0 / Float(sampleRate))
                let initialBuffer=malloc(Int(buffer.mDataByteSize+(ratio - 1)));
                memcpy(initialBuffer, buffer.mData, Int(buffer.mDataByteSize));
                buffer.mData=realloc(buffer.mData, Int(buffer.mDataByteSize*ratio))
                let values = initialBuffer!.assumingMemoryBound(to: Int16.self)
                let resampled = buffer.mData!.assumingMemoryBound(to: Int16.self)
                values[Int(buffer.mDataByteSize/2)]=values[Int(buffer.mDataByteSize/2)-1]
                for i: Int in 0 ..< Int(buffer.mDataByteSize/2) {
                    let intRatio = Int(ratio)
                    if sampleRate == 16000 {
                        resampled[i*intRatio]=values[i]
                        resampled[i*intRatio+1]=values[i]/3+values[i+1]/3*2
                        resampled[i*intRatio+2]=values[i]/3*2+values[i+1]/3
                    } else {
                        resampled[i*intRatio]=values[i]
                        resampled[i*intRatio+1]=values[i]/2+values[i+1]/2
                    }
                }
                free(initialBuffer)
                buffer.mDataByteSize*=ratio
            }
            
            defer {
                free(buffer.mData)
            }
            
            let millisecondsPerPacket = 60
            let encoderPacketSizeInBytes = 16000 / 1000 * millisecondsPerPacket * 2
            
            let currentEncoderPacket = malloc(encoderPacketSizeInBytes)!
            defer {
                free(currentEncoderPacket)
            }
            
            var bufferOffset = 0
            
            while true {
                var currentEncoderPacketSize = 0
                
                while currentEncoderPacketSize < encoderPacketSizeInBytes {
                    if audioBuffer.count != 0 {
                        let takenBytes = min(self.audioBuffer.count, encoderPacketSizeInBytes - currentEncoderPacketSize)
                        if takenBytes != 0 {
                            self.audioBuffer.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                                memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), bytes, takenBytes)
                            }
                            self.audioBuffer.replaceSubrange(0 ..< takenBytes, with: Data())
                            currentEncoderPacketSize += takenBytes
                        }
                    } else if bufferOffset < Int(buffer.mDataByteSize) {
                        let takenBytes = min(Int(buffer.mDataByteSize) - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize)
                        if takenBytes != 0 {
                            self.audioBuffer.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                                memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), buffer.mData?.advanced(by: bufferOffset), takenBytes)
                            }
                            bufferOffset += takenBytes
                            currentEncoderPacketSize += takenBytes
                        }
                    } else {
                        break
                    }
                }
                
                if currentEncoderPacketSize < encoderPacketSizeInBytes {
                    self.audioBuffer.append(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), count: currentEncoderPacketSize)
                    break
                } else {
                    
                    self.processWaveformPreview(samples: currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)
                    
                    self.oggWriter.writeFrame(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), frameByteCount: UInt(currentEncoderPacketSize))
                    liveUploading?.fileDidChangedSize(false)
                    let timestamp = CACurrentMediaTime()
                    if self.recordingStateUpdateTimestamp == nil || self.recordingStateUpdateTimestamp! < timestamp + 0.1 {
                        self.recordingStateUpdateTimestamp = timestamp
                        self.recordingState.set(.recording(duration: oggWriter.encodedDuration(), durationMediaTimestamp: timestamp))
                    }
                    
                }
            }
        }

    
    func processWaveformPreview(samples: UnsafePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            var sample = samples.advanced(by: i).pointee
            if sample < 0 {
                if sample == Int16.min {
                    sample = Int16.max
                } else {
                    sample = -sample
                }
            }
            if self.waveformPeak < sample {
                self.waveformPeak = sample
            }
            self.waveformPeakCount += 1
            
            if self.waveformPeakCount >= 100 {
                self.waveformSamples.count += 2
                var waveformPeak = self.waveformPeak
                withUnsafeBytes(of: &waveformPeak, { bytes -> Void in
                    self.waveformSamples.append(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: 2)
                })
                self.waveformPeak = 0
                self.waveformPeakCount = 0
            }
            
            if self.micLevelPeak < sample {
                self.micLevelPeak = sample
            }
            self.micLevelPeakCount += 1
            
            if self.micLevelPeakCount >= 1200 {
                let level = Float(self.micLevelPeak) / 4000.0
                self.micLevel.set(level)
                self.micLevelPeak = 0
                self.micLevelPeakCount = 0
            }
        }
    }
    
    func takeData() -> RecordedAudioData? {
        if self.oggWriter.writeFrame(nil, frameByteCount: 0) {
            var scaledSamplesMemory = malloc(100 * 2)!
            var scaledSamples: UnsafeMutablePointer<Int16> = scaledSamplesMemory.assumingMemoryBound(to: Int16.self)
            defer {
                free(scaledSamplesMemory)
            }
            memset(scaledSamples, 0, 100 * 2);
            var waveform: Data?
            let count = self.waveformSamples.count
            self.waveformSamples.withUnsafeMutableBytes { (samples: UnsafeMutablePointer<Int16>) -> Void in
                defer {
                    let count = count / 2
                    for i in 0 ..< count {
                        let sample = samples[i]
                        let index = i * 100 / count
                        if (scaledSamples[index] < sample) {
                            scaledSamples[index] = sample;
                        }
                    }
                    
                    var peak: Int16 = 0
                    var sumSamples: Int64 = 0
                    for i in 0 ..< 100 {
                        let sample = scaledSamples[i]
                        if peak < sample {
                            peak = sample
                        }
                        sumSamples += Int64(peak)
                    }
                    var calculatedPeak: UInt16 = 0
                    calculatedPeak = UInt16((Double(sumSamples) * 1.8 / 100.0))
                    
                    if calculatedPeak < 2500 {
                        calculatedPeak = 2500
                    }
                    
                    for i in 0 ..< 100 {
                        let sample: UInt16 = UInt16(Int64(scaledSamples[i]))
                        if sample > calculatedPeak {
                            scaledSamples[i] = Int16(calculatedPeak)
                        }
                    }
                    
                    let resultWaveform = AudioWaveform(samples: Data(bytes: scaledSamplesMemory, count: 100 * 2), peak: Int32(calculatedPeak))
                    let bitstream = resultWaveform.makeBitstream()
                    waveform = AudioWaveform(bitstream: bitstream, bitsPerSample: 5).makeBitstream()
                }
                
            }
            liveUploading?.fileDidChangedSize(true)
            return RecordedAudioData(compressedData: self.dataItem.data(), duration: self.oggWriter.encodedDuration(), waveform: waveform, id: liveUploading?.id, path: dataItem.path)
        } else {
            return nil
        }
    }
}

public enum AudioRecordingState: Equatable {
    case paused(duration: Double)
    case recording(duration: Double, durationMediaTimestamp: Double)
    
    public static func ==(lhs: AudioRecordingState, rhs: AudioRecordingState) -> Bool {
        switch lhs {
        case let .paused(duration):
            if case .paused(duration) = rhs {
                return true
            } else {
                return false
            }
        case let .recording(duration, durationMediaTimestamp):
            if case .recording(duration, durationMediaTimestamp) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public final class ManagedAudioRecorder {
    private let queue = Queue()
    private var contextRef: Unmanaged<ManagedAudioRecorderContext>?
    private let micLevelValue = ValuePromise<Float>(0.0)
    private let recordingStateValue = ValuePromise<AudioRecordingState>(.paused(duration: 0.0))
    public var micLevel: Signal<Float, NoError> {
        return self.micLevelValue.get()
    }
    
    public var recordingState: Signal<AudioRecordingState, NoError> {
        return self.recordingStateValue.get()
    }
    
    public init(liveUploading: PreUploadManager?, dataItem: DataItem) {
        
        self.queue.async {
            let context = ManagedAudioRecorderContext(queue: self.queue, micLevel: self.micLevelValue, recordingState: self.recordingStateValue, liveUploading: liveUploading, dataItem: dataItem)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    public func start() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.start()
            }
        }
    }
    
    public func stop() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stop()
            }
        }
    }
    
    public func takenRecordedData() -> Signal<RecordedAudioData?, NoError> {
        return Signal { subscriber in
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    subscriber.putNext(context.takeData())
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            }
            return EmptyDisposable
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
}
