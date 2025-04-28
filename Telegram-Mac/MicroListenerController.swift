//
//  MicroListenerController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TelegramCore
import InAppSettings
import Postbox
import TelegramMedia



private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

private let queue = Queue(name: "micro-listen", qos: .background)

private final class MicroListenerContextObject : RecoderContextRenderer {
    private let devicesDisposable = MetaDisposable()
    private let devices: DevicesContext
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    
    
    private var device: AVCaptureDevice?
    private var sampleRate: Int32 = 0

    
    private var onSpeaking:((Float)->Void)?
    private var always: Bool = false
    
    private var paused: Bool = true
    
    private var stack:[Float] = [] {
        didSet {
            if stack.count >= 70, onSpeaking != nil {
                onSpeaking?(stack.last!)
                onSpeaking = nil
                pause()
            }
        }
    }
    private let id: Int32
    private let audioUnit = Atomic<AudioUnit?>(value: nil)

    private var audioBuffer = Data()

    private var micLevelPeak: Int16 = 0
    private var micLevelPeakCount: Int = 0

    private let queue: Queue
    
    init(queue: Queue, devices:DevicesContext, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.devices = devices
        self.queue = queue
        self.accountManager = accountManager
        self.id = getNextRecorderContextId()
        
        addAudioRecorderContext(self.id, self)
        addAudioUnitHolder(self.id, queue, self.audioUnit)
    }
    
    deinit {
        removeAudioRecorderContext(self.id)
        removeAudioUnitHolder(self.id)
        stop()
    }
    
    func pause() {
        if !paused {
            paused = true
            devicesDisposable.set(nil)
            self.stop()
        }
    }
    func resume(onSpeaking: @escaping(Float)->Void, always: Bool) {
        if paused {
            paused = false
            self.always = always
            self.onSpeaking = onSpeaking
            let signal = combineLatest(queue: queue, devices.signal, voiceCallSettings(accountManager), requestMicrophonePermission())
            
            devicesDisposable.set(signal.start(next: { [weak self] devices, settings, permission in
                let device = settings.audioInputDeviceId == nil ? devices.audioInput.first : devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })

                if let device = device, permission {
                    self?.start(device)
                } else {
                    self?.stop()
                }
            }))
        }
    }
    
    
    private func start(_ device: AVCaptureDevice) {
        if self.device != device {
            self.device = device
            
            
            if let audioUnit = self.audioUnit.swap(nil) {
                var status = noErr
                status = AudioOutputUnitStop(audioUnit)
                status = AudioUnitUninitialize(audioUnit)
                status = AudioComponentInstanceDispose(audioUnit)
            }
            
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
            
            var audioStreamDescription = audioRecorderNativeStreamDescription(inputSampleRate.mMinimum)
            sampleRate = Int32(inputSampleRate.mMinimum)
            guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioStreamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
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

            
            self.audioUnit.with { audioUnit -> Void in
                if let audioUnit = audioUnit {
                    guard AudioOutputUnitStart(audioUnit) == noErr else {
                        self.stop()
                        return
                    }
                }
            }
        }
    }
    
    func stop() {
        device = nil
        assert(queue.isCurrent())
        
        
        self.paused = true
        
        if let audioUnit = self.audioUnit.swap(nil) {
            var status = noErr
            status = AudioOutputUnitStop(audioUnit)
            status = AudioUnitUninitialize(audioUnit)
            status = AudioComponentInstanceDispose(audioUnit)
        }
        removeAudioUnitHolder(self.id)

    }
    
    func processAndDisposeAudioBuffer(_ buffer: AudioBuffer) {
        assert(queue.isCurrent())
        
        var buffer = buffer
        
        if(sampleRate==16000){
            let initialBuffer=malloc(Int(buffer.mDataByteSize+2));
            memcpy(initialBuffer, buffer.mData, Int(buffer.mDataByteSize));
            buffer.mData=realloc(buffer.mData, Int(buffer.mDataByteSize*3))
            let values = initialBuffer!.assumingMemoryBound(to: Int16.self)
            let resampled = buffer.mData!.assumingMemoryBound(to: Int16.self)
            values[Int(buffer.mDataByteSize/2)]=values[Int(buffer.mDataByteSize/2)-1]
            for i: Int in 0 ..< Int(buffer.mDataByteSize/2) {
                resampled[i*3]=values[i]
                resampled[i*3+1]=values[i]/3+values[i+1]/3*2
                resampled[i*3+2]=values[i]/3*2+values[i+1]/3
            }
            free(initialBuffer)
            buffer.mDataByteSize*=3
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
            }
        }
    }

    private func processWaveformPreview(samples: UnsafePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            var sample = samples.advanced(by: i).pointee
            if sample < 0 {
                if sample == Int16.min {
                    sample = Int16.max
                } else {
                    sample = -sample
                }
            }
            
            if self.micLevelPeak < sample {
                self.micLevelPeak = sample
            }
            self.micLevelPeakCount += 1
            
            if self.micLevelPeakCount >= 1200 {
                let level = Float(self.micLevelPeak) / 4000.0
                if always {
                    self.onSpeaking?(level)
                } else {
                    if level >= 0.4 {
                        self.stack.append(level)
                    }
                }
               
                self.micLevelPeak = 0
                self.micLevelPeakCount = 0
            }
        }
    }
    
}


final class MicroListenerContext {
    private let contextRef: QueueLocalObject<MicroListenerContextObject>
    init(devices:DevicesContext, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        contextRef = .init(queue: queue, generate: {
            return MicroListenerContextObject(queue: queue, devices: devices, accountManager: accountManager)
        })
    }
    
    deinit {
        contextRef.syncWith({
            $0.stop()
        })
    }
    
    func pause() {
        contextRef.syncWith {
            $0.pause()
        }
    }
    func resume(onSpeaking: @escaping(Float)->Void, always: Bool = false) {
        contextRef.syncWith {
            $0.resume(onSpeaking: { value in
                DispatchQueue.main.async {
                    onSpeaking(value)
                }
            }, always: always)
        }
    }

}

