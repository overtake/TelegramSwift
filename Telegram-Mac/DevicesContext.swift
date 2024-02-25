//
//  DevicesContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import CoreMediaIO
import InAppSettings
import TelegramMedia

struct IODevices {
    let camera: [AVCaptureDevice]
    let audioInput: [AVCaptureDevice]
    let audioOutput: [AudioDeviceID]
    let loading: Bool
}

private extension AudioListener {
    static var nominalSampler: AudioObjectPropertyListenerProc = { _, _, _, _ in
        incrementSampleIndex()
        return 0
    }
}


extension AudioDeviceID {
    var uniqueID: String {
        return DevicesContext.Audio.getDeviceUid(deviceId: self)
    }
    var localizedName: String {
        return DevicesContext.Audio.getDeviceName(deviceID: self)
    }
}

private func devicesList() -> Signal<IODevices, NoError> {
    return Signal { subscriber in
        
        let defAudioDevice = AVCaptureDevice.default(for: .audio)
        let defVideoDevice = AVCaptureDevice.default(for: .video)
        
        var videoDevices = DALDevices()
        var audioDevices = AVCaptureDevice.devices(for: .audio)
        
        if !videoDevices.isEmpty, let device = defVideoDevice {
            videoDevices.removeAll(where: { $0.uniqueID == device.uniqueID})
            videoDevices.insert(device, at: 0)
        }
        if !audioDevices.isEmpty, let device = defAudioDevice {
            audioDevices.removeAll(where: { $0.uniqueID == device.uniqueID})
            audioDevices.insert(device, at: 0)
        }
        subscriber.putNext(.init(camera: videoDevices, audioInput: audioDevices, audioOutput: DevicesContext.Audio.getAllDevices().filter { DevicesContext.Audio.isOutputDevice(deviceID: $0) }, loading: false))
        subscriber.putCompletion()
        
        
        return EmptyDisposable
    } |> runOn(.concurrentDefaultQueue())
    
}


func sizeof <T> (_ : T.Type) -> Int
{
    return (MemoryLayout<T>.size)
}

func sizeof <T> (_ : T) -> Int
{
    return (MemoryLayout<T>.size)
}

func sizeof <T> (_ value : [T]) -> Int
{
    return (MemoryLayout<T>.size * value.count)
}

private let sampleUpdater = ValuePromise(0, ignoreRepeated: false)
private var index: Int = -1
private func incrementSampleIndex() {
    index += 1
    sampleUpdater.set(index)
}

final class DevicesContext : NSObject {
    private var _signal: Promise<IODevices> = Promise()
    var signal: Signal<IODevices, NoError> {
        return _signal.get()
    }
    
    
    private var observeContext = 0;
    
    private final class UpdaterContext {
//        var status: (camera: String?, input: String?, output: String?) = (camera: nil, input: nil, output: nil)
        let subscribers = Bag<((camera: String?, input: String?, output: String?, sampleUpdateIndex: Int?)) -> Void>()
    }
    
    private let updaterContext: UpdaterContext = UpdaterContext()
    
   
    
    func updater() -> Signal<(camera: String?, input: String?, output: String?, sampleUpdateIndex: Int?), NoError> {
        return Signal { subscriber in
            
            let disposable = MetaDisposable()
            let statusContext: UpdaterContext = self.updaterContext
            
            let index = statusContext.subscribers.add({ status in
                subscriber.putNext(status)
            })
            
//            subscriber.putNext(statusContext.status)
            
            disposable.set(ActionDisposable {
                DispatchQueue.main.async {
                    self.updaterContext.subscribers.remove(index)
                }
            })
            
            return disposable
        } |> runOn(.mainQueue())
    }
    
    
    private let disposable = MetaDisposable()
    private let updateSampler = MetaDisposable()
    private let devicesQueue = Queue(name: "devicesQueue")
    
    private let _currentCameraId: Atomic<String?> = Atomic(value: nil)
    private let _currentMicroId: Atomic<String?> = Atomic(value: nil)
    private let _currentOutputId: Atomic<String?> = Atomic(value: nil)
    
    var currentCameraId: String? {
        return _currentCameraId.with { $0 }
    }
    var currentMicroId: String? {
        return _currentMicroId.with { $0 }
    }
    var currentOutputId: String? {
        return _currentOutputId.with { $0 }
    }
    
    init(_ accountManager: AccountManager<TelegramAccountManagerTypes> ) {
        super.init()
        

        var prop : CMIOObjectPropertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))
        
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject),
                                &prop, 0, nil,
                                UInt32(sizeof(allow)), &allow );
        

    
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
        

        
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.inputDevice, AudioListener.input, nil)

        
        NotificationCenter.default.addObserver(forName: AudioNotification.audioOutputDeviceDidChange.notificationName, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        
        NotificationCenter.default.addObserver(forName: AudioNotification.audioInputDeviceDidChange.notificationName, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        
        NotificationCenter.default.addObserver(forName: AudioNotification.mixStereo.notificationName, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        
        
        
        let currentCameraId = self._currentCameraId
        let currentMicroId = self._currentMicroId
        let currentOutputId = self._currentOutputId
        
        var sampleIndex:Int = -1
        
        let updated = combineLatest(queue: devicesQueue, voiceCallSettings(accountManager), signal, sampleUpdater.get()) |> map { settings, devices, index -> (camera: String?, input: String?, output: String?, sampleUpdateIndex: Int?) in
            let inputUpdated = DevicesContext.updateMicroId(settings, devices: devices)
            let cameraUpdated = DevicesContext.updateCameraId(settings, devices: devices)
            let outputUpdated = DevicesContext.updateOutputId(settings, devices: devices)
            
            var result:(camera: String?, input: String?, output: String?, sampleUpdateIndex: Int?) = (camera: nil, input: nil, output: nil, sampleUpdateIndex: nil)
            
            if currentMicroId.swap(inputUpdated) != inputUpdated || sampleIndex != index {
                result.input = inputUpdated
            }
            if currentCameraId.swap(cameraUpdated) != cameraUpdated {
                result.camera = cameraUpdated
            }
            if currentOutputId.swap(outputUpdated) != outputUpdated || sampleIndex != index {
                result.output = outputUpdated
            }
            if sampleIndex != index {
                result.sampleUpdateIndex = index
            }
            sampleIndex = index
            
            return result
        } |> deliverOnMainQueue
        
        disposable.set(updated.start(next: { [weak self] result in
            guard let `self` = self else {
                return
            }
            //self.updaterContext.status = result
            
            for subscriber in self.updaterContext.subscribers.copyItems() {
                subscriber(result)
            }

           // self.updaterContext.status = (camera: nil, input: nil, output: nil)
        }))
        
        let previous: Atomic<IODevices?> = Atomic(value: nil)
        
        let signal = self.signal |> afterDisposed {
            let devices = previous.swap(nil)
            if let list = devices?.audioOutput {
                for device in list {
                    AudioObjectRemovePropertyListener(device, &AudioAddress.nominalSampleRates, AudioListener.nominalSampler, nil)
                }
            }
        }
        
        updateSampler.set(signal.start(next: { devices in
            let previous = previous.swap(devices)
            if let list = previous?.audioOutput {
                for device in list {
                    AudioObjectRemovePropertyListener(device, &AudioAddress.nominalSampleRates, AudioListener.nominalSampler, nil)
                }
            }
            for device in devices.audioOutput {
                AudioObjectAddPropertyListener(device, &AudioAddress.nominalSampleRates, AudioListener.nominalSampler, nil)
            }
        }))
        
        update()
    }
    
    private func update() {
        _signal.set(devicesList() |> filter { !$0.loading })
    }
    
    @objc private func handleOutputNotification(_ notification: Notification) {
        self.update()
    }
    
    static func updateCameraId(_ settings: VoiceCallSettings, devices: IODevices) -> String? {
        var cameraDevice = devices.camera.first(where: { $0.uniqueID == settings.cameraInputDeviceId })
        
        var activeDevice: AVCaptureDevice?
        if let cameraDevice = cameraDevice {
            if cameraDevice.isConnected && !cameraDevice.isSuspended {
                activeDevice = cameraDevice
            } else {
                activeDevice = nil
            }
        }
        
        if activeDevice == nil {
            activeDevice = AVCaptureDevice.default(for: .video)
        }
        return activeDevice?.uniqueID
    }
    static func updateMicroId(_ settings: VoiceCallSettings, devices: IODevices) -> String? {
        var audiodevice = devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })
        
        var activeDevice: AVCaptureDevice?
        if let audiodevice = audiodevice {
            if audiodevice.isConnected && !audiodevice.isSuspended {
                activeDevice = audiodevice
            } else {
                activeDevice = nil
            }
        }
        if activeDevice == nil {
            activeDevice = AVCaptureDevice.default(for: .audio)
        }
                
        return activeDevice?.uniqueID
    }
    
    static func updateOutputId(_ settings: VoiceCallSettings, devices: IODevices) -> String? {
        var deviceUid: String? = nil
        var found = false
        for id in devices.audioOutput {
            let current = Audio.getDeviceUid(deviceId: id)
            if settings.audioOutputDeviceId == current {
                deviceUid = Audio.getDeviceUid(deviceId: id)
                found = true
            }
        }
        if !found {
            deviceUid = Audio.getDeviceUid(deviceId: Audio.getDefaultOutputDevice())
        }
        
        return deviceUid
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.inputDevice, AudioListener.input, nil)
        disposable.dispose()
        updateSampler.dispose()
    }
}

private extension DevicesContext {
    class Audio {
        static func getOutputDevices() -> [AudioDeviceID: String]? {
            var result: [AudioDeviceID: String] = [:]
            let devices = getAllDevices()
            
            for device in devices {
                if isOutputDevice(deviceID: device) {
                    result[device] = getDeviceName(deviceID: device)
                }
            }
            
            return result
        }
        static func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
            var propertySize: UInt32 = 256
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
                mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            _ = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize)
            
            return propertySize > 0
        }
        
        static func getAggregateDeviceSubDeviceList(deviceID: AudioDeviceID) -> [AudioDeviceID] {
            let subDevicesCount = getNumberOfSubDevices(deviceID: deviceID)
            var subDevices = [AudioDeviceID](repeating: 0, count: Int(subDevicesCount))
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioAggregateDevicePropertyActiveSubDeviceList),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            var subDevicesSize = subDevicesCount * UInt32(MemoryLayout<UInt32>.size)
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &subDevicesSize, &subDevices)
            
            return subDevices
        }
        
        static func isAggregateDevice(deviceID: AudioDeviceID) -> Bool {
            let deviceType = getDeviceTransportType(deviceID: deviceID)
            return deviceType == kAudioDeviceTransportTypeAggregate
        }
        
        static func setDeviceVolume(deviceID: AudioDeviceID, leftChannelLevel: Float, rightChannelLevel: Float) {
            let channelsCount = 2
            var channels = [UInt32](repeating: 0, count: channelsCount)
            var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
            var leftLevel = leftChannelLevel
            var rigthLevel = rightChannelLevel
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
                mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)
            
            if status != noErr { return }
            
            propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
            propertySize = UInt32(MemoryLayout<Float32>.size)
            propertyAddress.mElement = channels[0]
            
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &leftLevel)
            
            propertyAddress.mElement = channels[1]
            
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &rigthLevel)
        }
        
        static func setOutputDevice(newDeviceID: AudioDeviceID) {
            let propertySize = UInt32(MemoryLayout<UInt32>.size)
            var deviceID = newDeviceID
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, propertySize, &deviceID)
        }
        
        static func getDeviceVolume(deviceID: AudioDeviceID) -> [Float] {
            let channelsCount = 2
            var channels = [UInt32](repeating: 0, count: channelsCount)
            var propertySize = UInt32(MemoryLayout<UInt32>.size * channelsCount)
            var leftLevel = Float32(-1)
            var rigthLevel = Float32(-1)
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
                mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &channels)
            
            if status != noErr { return [-1] }
            
            propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
            propertySize = UInt32(MemoryLayout<Float32>.size)
            propertyAddress.mElement = channels[0]
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &leftLevel)
            
            propertyAddress.mElement = channels[1]
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &rigthLevel)
            
            return [leftLevel, rigthLevel]
        }
        
        static func getDefaultOutputDevice() -> AudioDeviceID {
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var deviceID = kAudioDeviceUnknown
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
            
            return deviceID
        }
        
        private static func getDeviceTransportType(deviceID: AudioDeviceID) -> AudioDevicePropertyID {
            var deviceTransportType = AudioDevicePropertyID()
            var propertySize = UInt32(MemoryLayout<AudioDevicePropertyID>.size)
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyTransportType),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &deviceTransportType)
            
            return deviceTransportType
        }
        
        private static func getNumberOfDevices() -> UInt32 {
            var propertySize: UInt32 = 0
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            _ = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
            
            return propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        }
        
        private static func getNumberOfSubDevices(deviceID: AudioDeviceID) -> UInt32 {
            var propertySize: UInt32 = 0
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioAggregateDevicePropertyActiveSubDeviceList),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            _ = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize)
            
            return propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        }
        
        static func getDeviceName(deviceID: AudioDeviceID) -> String {
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            var result: CFString = "" as CFString
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &result)
            
            return result as String
        }
        
        static func getDeviceUid(deviceId: AudioDeviceID) -> String {
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster)
            
            var deviceUid: CFString = "" as CFString
            AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &propertySize, &deviceUid)
            
            return deviceUid as String
        }
        
        static func getAllDevices() -> [AudioDeviceID] {
            let devicesCount = getNumberOfDevices()
            var devices = [AudioDeviceID](repeating: 0, count: Int(devicesCount))
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            var devicesSize = devicesCount * UInt32(MemoryLayout<UInt32>.size)
            
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &devicesSize, &devices)
            
            return devices
        }
        
    }
}
