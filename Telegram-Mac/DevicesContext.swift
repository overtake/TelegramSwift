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


struct IODevices {
    let camera: [AVCaptureDevice]
    let audioInput: [AVCaptureDevice]
    let audioOutput: [AudioDeviceID]
    let loading: Bool
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
        
        subscriber.putNext(.init(camera: [], audioInput: [], audioOutput: [], loading: true))

        let defAudioDevice = AVCaptureDevice.default(for: .audio)
        let defVideoDevice = AVCaptureDevice.default(for: .video)
        
        var videoDevices = AVCaptureDevice.devices(for: .video)
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
    } |> runOn(.concurrentBackgroundQueue())
    
}



final class DevicesContext : NSObject {
    private var _signal: Promise<IODevices> = Promise()
    var signal: Signal<IODevices, NoError> {
        return _signal.get()
    }
    
    
    private var observeContext = 0;
    
    private final class UpdaterContext {
        var status: (camera: String?, input: String?, output: String?) = (camera: nil, input: nil, output: nil)
        let subscribers = Bag<((camera: String?, input: String?, output: String?)) -> Void>()
    }
    
    private let updaterContext: UpdaterContext = UpdaterContext()
    
   
    
    func updater() -> Signal<(camera: String?, input: String?, output: String?), NoError> {
        return Signal { subscriber in
            
            let disposable = MetaDisposable()
            let statusContext: UpdaterContext = self.updaterContext
            
            let index = statusContext.subscribers.add({ status in
                subscriber.putNext(status)
            })
            
            subscriber.putNext(statusContext.status)
            
            disposable.set(ActionDisposable {
                DispatchQueue.main.async {
                    self.updaterContext.subscribers.remove(index)
                }
            })
            
            return disposable
        } |> runOn(.mainQueue())
    }
    
    
    private let disposable = MetaDisposable()
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
    
    init(_ accountManager: AccountManager ) {
        super.init()
    
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
        
        NotificationCenter.default.addObserver(forName: AudioNotification.audioOutputDeviceDidChange.notificationName, object: nil, queue: nil, using: { [weak self] _ in
            self?.update()
        })
        
        let currentCameraId = self._currentCameraId
        let currentMicroId = self._currentMicroId
        let currentOutputId = self._currentOutputId
        
        let updated = combineLatest(queue: devicesQueue, voiceCallSettings(accountManager), signal) |> map { settings, devices -> (camera: String?, input: String?, output: String?) in
            let inputUpdated = DevicesContext.updateMicroId(settings, devices: devices)
            let cameraUpdated = DevicesContext.updateCameraId(settings, devices: devices)
            let outputUpdated = DevicesContext.updateOutputId(settings, devices: devices)
            
            var result:(camera: String?, input: String?, output: String?) = (camera: nil, input: nil, output: nil)
            
            if currentMicroId.swap(inputUpdated) != inputUpdated {
                result.input = inputUpdated
            }
            if currentCameraId.swap(cameraUpdated) != cameraUpdated {
                result.camera = cameraUpdated
            }
            if currentOutputId.swap(outputUpdated) != outputUpdated {
                result.output = outputUpdated
            }
            return result
        } |> deliverOnMainQueue
        
        disposable.set(updated.start(next: { [weak self] result in
            guard let `self` = self else {
                return
            }
            self.updaterContext.status = result
            
            for subscriber in self.updaterContext.subscribers.copyItems() {
                subscriber(self.updaterContext.status)
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
        let cameraDevice = devices.camera.first(where: { $0.uniqueID == settings.cameraInputDeviceId })
        
        let activeDevice: AVCaptureDevice?
        if let cameraDevice = cameraDevice {
            if cameraDevice.isConnected && !cameraDevice.isSuspended {
                activeDevice = cameraDevice
            } else {
                activeDevice = nil
            }
        } else if settings.cameraInputDeviceId == nil {
            activeDevice = AVCaptureDevice.default(for: .video)
        } else {
            activeDevice = devices.camera.first(where: { $0.isConnected && !$0.isSuspended })
        }
        
        return activeDevice?.uniqueID
    }
    static func updateMicroId(_ settings: VoiceCallSettings, devices: IODevices) -> String? {
        let audiodevice = devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })
        
        let activeDevice: AVCaptureDevice?
        if let audiodevice = audiodevice {
            if audiodevice.isConnected && !audiodevice.isSuspended {
                activeDevice = audiodevice
            } else {
                activeDevice = nil
            }
        } else if settings.audioInputDeviceId == nil {
            activeDevice = AVCaptureDevice.default(for: .audio)
        } else {
            activeDevice = devices.audioInput.first(where: { $0.isConnected && !$0.isSuspended })
        }
        
        return activeDevice?.uniqueID
    }
    
    static func updateOutputId(_ settings: VoiceCallSettings, devices: IODevices) -> String? {
        var deviceUid: String? = nil
        var found = false
        for id in devices.audioOutput {
            let current = Audio.getDeviceUid(deviceId: id)
            if settings.audioOutputDeviceId == current {
                deviceUid = current
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
        disposable.dispose()
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
