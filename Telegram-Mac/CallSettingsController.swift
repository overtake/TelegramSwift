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

import Postbox
import TgVoipWebrtc

final class CallSettingsArguments {
    let sharedContext: SharedAccountContext
    let toggleInputAudioDevice:(String?)->Void
    let toggleOutputAudioDevice:(String?)->Void
    let toggleInputVideoDevice:(String?)->Void
    let finishCall:()->Void
    init(sharedContext: SharedAccountContext, toggleInputAudioDevice: @escaping(String?)->Void, toggleOutputAudioDevice:@escaping(String?)->Void, toggleInputVideoDevice:@escaping(String?)->Void, finishCall:@escaping()->Void) {
        self.sharedContext = sharedContext
        self.toggleInputAudioDevice = toggleInputAudioDevice
        self.toggleOutputAudioDevice = toggleOutputAudioDevice
        self.toggleInputVideoDevice = toggleInputVideoDevice
        self.finishCall = finishCall
    }
}

private let _id_input_camera = InputDataIdentifier("_id_input_camera")
private let _id_camera = InputDataIdentifier("_id_camera")
private let _id_input_audio = InputDataIdentifier("_id_input_audio")
private let _id_output_audio = InputDataIdentifier("_id_output_audio")
private let _id_micro = InputDataIdentifier("_id_micro")

private func callSettingsEntries(settings: VoiceCallSettings, devices: IODevices, arguments: CallSettingsArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    var cameraDevice = devices.camera.first(where: { $0.uniqueID == settings.cameraInputDeviceId })
    var microDevice = devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })
    
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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().callSettingsCameraTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_camera, data: .init(name: strings().callSettingsInputText, color: theme.colors.text, type: .contextSelector(cameraDevice?.localizedName ?? strings().callSettingsDeviceDefault, [SPopoverItem(strings().callSettingsDeviceDefault, {
        arguments.toggleInputVideoDevice(nil)
    })] + devices.camera.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputVideoDevice(value.uniqueID)
        })
        }), viewType: activeCameraDevice == nil ? .singleItem : .firstItem)))
    index += 1
    
    if let activeCameraDevice = activeCameraDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_camera, equatable: InputDataEquatable(activeCameraDevice.uniqueID), comparable: nil, item: { initialSize, stableId -> TableRowItem in
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
        microDevice = devices.audioInput.first(where: { $0.isConnected && !$0.isSuspended })
        activeMicroDevice = microDevice
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().callSettingsInputTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_audio, data: .init(name: strings().callSettingsInputText, color: theme.colors.text, type: .contextSelector(microDevice?.localizedName ?? strings().callSettingsDeviceDefault, [SPopoverItem(strings().callSettingsDeviceDefault, {
        arguments.toggleInputAudioDevice(nil)
    })] + devices.audioInput.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputAudioDevice(value.uniqueID)
        })
        }), viewType: activeMicroDevice == nil ? .singleItem : .firstItem)))
    index += 1
    
    if let activeMicroDevice = activeMicroDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_micro, equatable: InputDataEquatable(activeMicroDevice.uniqueID), comparable: nil, item: { initialSize, stableId -> TableRowItem in
            return MicrophonePreviewRowItem(initialSize, stableId: stableId, context: arguments.sharedContext, viewType: .lastItem)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}




func CallSettingsController(sharedContext: SharedAccountContext) -> InputDataController {
    
    let devicesContext = sharedContext.devicesContext
    
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
    }, finishCall: {
        
    })
    
    let signal = combineLatest(voiceCallSettings(sharedContext.accountManager), devicesContext.signal) |> map { settings, devices in
        return InputDataSignalValue(entries: callSettingsEntries(settings: settings, devices: devices, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().callSettingsTitle, hasDone: false)
    
    
    controller.contextObject = combineLatest(requestCameraPermission(), requestMicrophonePermission()).start()
    
    return controller
}


