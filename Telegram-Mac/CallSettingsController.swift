//
//  CallSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit
import SyncCore
import Postbox
import TgVoipWebrtc

private func devicesList() -> (camera: [AVCaptureDevice], audio: [AVCaptureDevice]) {
    
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
    
    return (camera: videoDevices, audio: audioDevices)
    
}

private final class CallSettingsArguments {
    let sharedContext: SharedAccountContext
    let toggleInputAudioDevice:(String?)->Void
    let toggleOutputAudioDevice:(String?)->Void
    let toggleInputVideoDevice:(String?)->Void
    init(sharedContext: SharedAccountContext, toggleInputAudioDevice: @escaping(String?)->Void, toggleOutputAudioDevice:@escaping(String?)->Void, toggleInputVideoDevice:@escaping(String?)->Void) {
        self.sharedContext = sharedContext
        self.toggleInputAudioDevice = toggleInputAudioDevice
        self.toggleOutputAudioDevice = toggleOutputAudioDevice
        self.toggleInputVideoDevice = toggleInputVideoDevice
    }
}

private let _id_input_camera = InputDataIdentifier("_id_input_camera")
private let _id_camera = InputDataIdentifier("_id_camera")
private let _id_input_audio = InputDataIdentifier("_id_input_audio")
private let _id_output_audio = InputDataIdentifier("_id_output_audio")
private let _id_micro = InputDataIdentifier("_id_micro")

private func callSettingsEntries(settings: VoiceCallSettings, arguments: CallSettingsArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    let devices = devicesList()
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var cameraDevice = devices.camera.first(where: { $0.uniqueID == settings.cameraInputDeviceId })
    var microDevice = devices.audio.first(where: { $0.uniqueID == settings.audioInputDeviceId })

    let activeCameraDevice: AVCaptureDevice?
    if let cameraDevice = cameraDevice {
        if cameraDevice.isConnected && !cameraDevice.isSuspended {
            activeCameraDevice = cameraDevice
        } else {
            activeCameraDevice = nil
        }
    } else if settings.cameraInputDeviceId == nil {
        activeCameraDevice = AVCaptureDevice.default(for: .video)
    } else {
        cameraDevice = devices.camera.first(where: { $0.isConnected && !$0.isSuspended })
        activeCameraDevice = cameraDevice
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.callSettingsCameraTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_camera, data: .init(name: L10n.callSettingsInputText, color: theme.colors.text, type: .contextSelector(cameraDevice?.localizedName ?? L10n.callSettingsDeviceDefault, [SPopoverItem(L10n.callSettingsDeviceDefault, {
        arguments.toggleInputVideoDevice(nil)
    })] + devices.camera.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputVideoDevice(value.uniqueID)
        })
    }), viewType: activeCameraDevice == nil ? .singleItem : .firstItem)))
    index += 1
    
    if let activeCameraDevice = activeCameraDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_camera, equatable: InputDataEquatable(activeCameraDevice.uniqueID), item: { initialSize, stableId -> TableRowItem in
            return CameraPreviewRowItem(initialSize, stableId: stableId, device: activeCameraDevice, viewType: .lastItem)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let activeMicroDevice: AVCaptureDevice?
    if let microDevice = microDevice {
        if microDevice.isConnected && !microDevice.isSuspended {
            activeMicroDevice = microDevice
        } else {
            activeMicroDevice = nil
        }
    } else if settings.audioInputDeviceId == nil {
        activeMicroDevice = AVCaptureDevice.default(for: .audio)
    } else {
        microDevice = devices.audio.first(where: { $0.isConnected && !$0.isSuspended })
        activeMicroDevice = microDevice
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.callSettingsInputTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_audio, data: .init(name: L10n.callSettingsInputText, color: theme.colors.text, type: .contextSelector(microDevice?.localizedName ?? L10n.callSettingsDeviceDefault, [SPopoverItem(L10n.callSettingsDeviceDefault, {
        arguments.toggleInputAudioDevice(nil)
    })] + devices.audio.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputAudioDevice(value.uniqueID)
        })
    }), viewType: activeMicroDevice == nil ? .singleItem : .firstItem)))
    index += 1
    
    if let activeMicroDevice = activeMicroDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_micro, equatable: InputDataEquatable(activeMicroDevice.uniqueID), item: { initialSize, stableId -> TableRowItem in
            return MicrophonePreviewRowItem(initialSize, stableId: stableId, device: activeMicroDevice, viewType: .lastItem)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}



final class DevicesContext : NSObject {
    private var _signal: ValuePromise<Bool> = ValuePromise.init(true, ignoreRepeated: false)
    var signal: Signal<Void, NoError> {
        return _signal.get() |> map { _ in return }
    }
    private var observeContext = 0;

    private(set) var currentCameraId: String? = nil
    private(set) var currentMicroId: String? = nil
    private(set) var currentOutputId: String? = nil
    
    init(_ settings: VoiceCallSettings ) {
        super.init()
        _ = updateCameraId(settings)
        _ = updateMicroId(settings)
        _ = updateOutputId(settings)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil, using: { [weak self] _ in
            self?._signal.set(true)
        })
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil, queue: nil, using: { [weak self] _ in
            self?._signal.set(true)
        })
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)

        NotificationCenter.default.addObserver(forName: AudioNotification.audioOutputDeviceDidChange.notificationName, object: nil, queue: nil, using: { [weak self] _ in
             self?._signal.set(true)
        })
    }
    
    @objc private func handleOutputNotification(_ notification: Notification) {
        self._signal.set(true)
    }
    
    func updateCameraId(_ settings: VoiceCallSettings) -> Bool {
        let devices = devicesList()
        
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
        
        defer {
            self.currentCameraId = activeDevice?.uniqueID
        }
        
        return self.currentCameraId != activeDevice?.uniqueID
    }
    func updateMicroId(_ settings: VoiceCallSettings) -> Bool {
        let devices = devicesList()
        
        let audiodevice = devices.audio.first(where: { $0.uniqueID == settings.audioInputDeviceId })
        
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
            activeDevice = devices.audio.first(where: { $0.isConnected && !$0.isSuspended })
        }
        
        defer {
            self.currentOutputId = activeDevice?.uniqueID
        }
        
        return self.currentOutputId != activeDevice?.uniqueID
    }
    
    func updateOutputId(_ settings: VoiceCallSettings) -> Bool {
        var deviceId:AudioDeviceID = AudioDeviceID()
        var deviceIdRequest:AudioObjectPropertyAddress  = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var deviceIdSize:UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceIdRequest, 0, nil, &deviceIdSize, &deviceId)

        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster)
        
        var deviceUid: CFString = "" as CFString
        AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &propertySize, &deviceUid)
        
        defer {
            self.currentMicroId = deviceUid as String
        }
        
        return self.currentMicroId != deviceUid as String
    }
    
    deinit {
       NotificationCenter.default.removeObserver(self)
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &AudioAddress.outputDevice, AudioListener.output, nil)
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
        
        private static func getDeviceName(deviceID: AudioDeviceID) -> String {
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
            
            var result: CFString = "" as CFString
            
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &result)
            
            return result as String
        }
        
        private static func getAllDevices() -> [AudioDeviceID] {
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

func CallSettingsController(sharedContext: SharedAccountContext) -> InputDataController {

    let deviceContextObserver = DevicesContext(VoiceCallSettings.defaultSettings)
    
    
    let arguments = CallSettingsArguments(sharedContext: sharedContext, toggleInputAudioDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
            $0.withUpdatedAudioInputDeviceId(value)
        }).start()
    }, toggleOutputAudioDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
            $0.withUpdatedAudioOutputDeviceId(value)
        }).start()
    }, toggleInputVideoDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
            $0.withUpdatedCameraInputDeviceId(value)
        }).start()
    })
    
    let signal = combineLatest(deviceContextObserver.signal, voiceCallSettings(sharedContext.accountManager)) |> map { _, settings in
        return InputDataSignalValue(entries: callSettingsEntries(settings: settings, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.callSettingsTitle, hasDone: false)
    
    controller.contextOject = deviceContextObserver
    
    return controller
}


