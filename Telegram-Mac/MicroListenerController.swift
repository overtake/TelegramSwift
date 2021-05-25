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
import SyncCore
import Postbox

final class MicroListenerController {
    private let devicesDisposable = MetaDisposable()
    private let devices: DevicesContext
    private let accountManager: AccountManager
    
    
    private var device: AVCaptureDevice?
    private var session: AVCaptureSession?
    
    private var onSpeaking:(()->Void)?
    
    private var paused: Bool = true
    
    private var stack:[Int] = [] {
        didSet {
            if stack.count >= 10, onSpeaking != nil {
                onSpeaking?()
                onSpeaking = nil
                pause()
            }
        }
    }
    private var peakDisposable = MetaDisposable()
    
    init(devices:DevicesContext, accountManager: AccountManager) {
        self.devices = devices
        self.accountManager = accountManager
    }
    
    func pause() {
        if !paused {
            paused = true
            stop()
            devicesDisposable.set(nil)
        }
    }
    func resume(onSpeaking: @escaping()->Void) {
        if paused {
            paused = false
            self.onSpeaking = onSpeaking
            let signal = combineLatest(devices.signal, voiceCallSettings(accountManager), requestMicrophonePermission()) |> deliverOnMainQueue
            
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
            let session = AVCaptureSession()
            let input = try? AVCaptureDeviceInput(device: device)
            if let input = input {
                session.addInput(input)
            }
            let output = AVCaptureAudioDataOutput()
            session.addOutput(output)
            
            let connection = output.connection(with: .audio)
            
            let channel = connection?.audioChannels.first
            
            self.session = session
            
            let signal: Signal<Void, NoError> = .single(Void()) |> delay(0.1, queue: .mainQueue()) |> restart
            peakDisposable.set(signal.start(next: { [weak channel, weak self] in
                if let channel = channel {
                    let value = Int(floor(max(0, 36 - abs(channel.averagePowerLevel))))
                    if value >= 10 {
                        self?.stack.append(value)
                    }
                }
            }))
            
            session.startRunning()
        }
    }
    
    private func stop() {
        device = nil
        stack.removeAll()
        session?.stopRunning()
        session = nil
        peakDisposable.set(nil)
    }
    
}
