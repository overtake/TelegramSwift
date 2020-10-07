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
    let context: AccountContext
    let toggleInputAudioDevice:(String?)->Void
    let toggleOutputAudioDevice:(String?)->Void
    let toggleInputVideoDevice:(String?)->Void
    init(context: AccountContext, toggleInputAudioDevice: @escaping(String?)->Void, toggleOutputAudioDevice:@escaping(String?)->Void, toggleInputVideoDevice:@escaping(String?)->Void) {
        self.context = context
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
    
    init(_ settings: VoiceCallSettings ) {
        super.init()
        _ = updateCameraId(settings)
        _ = updateMicroId(settings)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil, using: { [weak self] _ in
            self?._signal.set(true)
        })
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil, queue: nil, using: { [weak self] _ in
            self?._signal.set(true)
        })
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
        
        let cameraDevice = devices.audio.first(where: { $0.uniqueID == settings.audioInputDeviceId })
        
        let activeDevice: AVCaptureDevice?
        if let cameraDevice = cameraDevice {
            if cameraDevice.isConnected && !cameraDevice.isSuspended {
                activeDevice = cameraDevice
            } else {
                activeDevice = nil
            }
        } else if settings.audioInputDeviceId == nil {
            activeDevice = AVCaptureDevice.default(for: .video)
        } else {
            activeDevice = devices.camera.first(where: { $0.isConnected && !$0.isSuspended })
        }
        
        defer {
            self.currentMicroId = activeDevice?.uniqueID
        }
        
        return self.currentMicroId != activeDevice?.uniqueID
    }
    
    deinit {
       NotificationCenter.default.removeObserver(self)
    }
}

func CallSettingsController(context: AccountContext) -> InputDataController {

    let deviceContextObserver = DevicesContext(VoiceCallSettings.defaultSettings)
    
    
    let arguments = CallSettingsArguments(context: context, toggleInputAudioDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedAudioInputDeviceId(value)
        }).start()
    }, toggleOutputAudioDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedAudioOutputDeviceId(value)
        }).start()
    }, toggleInputVideoDevice: { value in
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, {
            $0.withUpdatedCameraInputDeviceId(value)
        }).start()
    })
    
    let signal = combineLatest(deviceContextObserver.signal, voiceCallSettings(context.sharedContext.accountManager)) |> map { _, settings in
        return InputDataSignalValue(entries: callSettingsEntries(settings: settings, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.callSettingsTitle, hasDone: false)
    
    controller.contextOject = deviceContextObserver
    
    return controller
}


