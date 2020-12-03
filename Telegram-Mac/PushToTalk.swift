//
//  PushToTalk.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/12/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import DDHotKey
import SwiftSignalKit
import TGUIKit

extension PushToTalkValue {
    func isEqual(_ value: KeyboardGlobalHandler.Result) -> Bool {
        return value.keyCodes == self.keyCodes && self.modifierFlags == value.modifierFlags
    }
}

final class KeyboardGlobalHandler {
    
    static func hasPermission() -> Bool {
        let dict:[String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(dict as CFDictionary)
    }
    
    private struct Handler {
        let pushToTalkValue: PushToTalkValue?
        let success:(Result)->Void
        let eventType: NSEvent.EventTypeMask
        init(PushToTalkValue: PushToTalkValue?, success:@escaping(Result)->Void, eventType: NSEvent.EventTypeMask) {
            self.pushToTalkValue = PushToTalkValue
            self.success = success
            self.eventType = eventType
        }
    }
    
    struct Result {
        let keyCodes: [UInt16]
        let modifierFlags: [PushToTalkValue.ModifierFlag]
        let string: String
        let eventType: NSEvent.EventTypeMask
    }
    

    private var monitors: [Any?] = []

    private var keyDownHandler: Handler?
    private var keyUpHandler: Handler?

    init() {
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            self?.process(event)
        }))
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.process(event)
        }))
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            self?.process(event)
            return event
        }))
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.process(event)
            return event
        }))
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.process(event)
        }))
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.process(event)
            return event
        }))
    }
    
    private var downStake:[NSEvent] = []
    private var flagsStake:[NSEvent] = []
        
    private var currentDownStake:[NSEvent] = []
    private var currentFlagsStake:[NSEvent] = []


    var activeCount: Int {
        var total:Int = 0
        if currentDownStake.count > 0 {
            total += currentDownStake.count
        }
        if currentFlagsStake.count > 0 {
            total += currentFlagsStake.count
        }
        return total
    }
    
    private func process(_ event: NSEvent) {
        
        let oldActiveCount = self.activeCount

        switch event.type {
        case .keyUp:
            currentDownStake.removeAll(where: { $0.keyCode == event.keyCode })
        case .keyDown:
            if !downStake.contains(where: { $0.keyCode == event.keyCode }) {
                downStake.append(event)
            }
            if !currentDownStake.contains(where: { $0.keyCode == event.keyCode }) {
                currentDownStake.append(event)
            }
        case .flagsChanged:
            if !flagsStake.contains(where: { $0.keyCode == event.keyCode }) {
                flagsStake.append(event)
            }
            if !currentFlagsStake.contains(where: { $0.keyCode == event.keyCode }) {
                currentFlagsStake.append(event)
            } else {
                currentFlagsStake.removeAll(where: { $0.keyCode == event.keyCode })
            }
        default:
            break
        }
        
        let newActiveCount = self.activeCount
        if oldActiveCount != newActiveCount {
            applyStake(oldActiveCount < newActiveCount)
        }
        
        if activeCount == 0 {
            self.downStake.removeAll()
            self.flagsStake.removeAll()
        }
    }
    
    private var isDownSent: Bool = false
    private var isUpSent: Bool = false
    private func applyStake(_ isDown: Bool) {
        var string = ""
        
        var _flags: [PushToTalkValue.ModifierFlag] = []
        
        
        let finalFlag = self.flagsStake.max(by: { lhs, rhs in
            return lhs.modifierFlags.rawValue < rhs.modifierFlags.rawValue
        })
        
        if let finalFlag = finalFlag {
            string += DDStringFromKeyCode(finalFlag.keyCode, finalFlag.modifierFlags.rawValue)!
        }
        
        for flag in flagsStake {
            _flags.append(PushToTalkValue.ModifierFlag(keyCode: flag.keyCode))
        }
        var _keyCodes:[UInt16] = []
        for key in downStake {
            string += DDStringFromKeyCode(key.keyCode, 0)!
            _keyCodes.append(key.keyCode)
        }
        
        string = string.uppercased().reduce("", { current, value in
            var current = current
            if current.isEmpty {
                current += String(value)
            } else {
                current += " + "
                current += String(value)
            }
            return current
        })
        
        
        let result = Result(keyCodes: _keyCodes, modifierFlags: _flags, string: string, eventType: isDown ? .keyDown : .keyUp)
        
        string = ""
        var flags: [PushToTalkValue.ModifierFlag] = []
        for flag in currentFlagsStake {
            flags.append(PushToTalkValue.ModifierFlag(keyCode: flag.keyCode))
        }
        var keyCodes:[UInt16] = []
        for key in currentDownStake {
            keyCodes.append(key.keyCode)
        }
                
        let invokeUp:(PushToTalkValue)->Bool = { ptt in
            var invoke: Bool = false
            for keyCode in ptt.keyCodes {
                if !keyCodes.contains(keyCode) {
                    invoke = true
                }
            }
            for flag in ptt.modifierFlags {
                if !flags.contains(flag) {
                    invoke = true
                }
            }
            return invoke
        }
        
        let invokeDown:(PushToTalkValue)->Bool = { ptt in
            var invoke: Bool = true
            for keyCode in ptt.keyCodes {
                if !keyCodes.contains(keyCode) {
                    invoke = false
                }
            }
            for flag in ptt.modifierFlags {
                if !flags.contains(flag) {
                    invoke = false
                }
            }
            return invoke
        }
          
                
        if isDown {
            isUpSent = false
            if let keyDown = self.keyDownHandler {
                if let ptt = keyDown.pushToTalkValue {
                    if invokeDown(ptt) {
                        isDownSent = true
                        keyDown.success(result)
                    }
                } else {
                    isDownSent = true
                    keyDown.success(result)
                }
            }
        } else {
            if let keyUp = self.keyUpHandler {
                if let ptt = keyUp.pushToTalkValue {
                    if invokeUp(ptt), (isDownSent || keyDownHandler == nil), !isUpSent {
                        keyUp.success(result)
                        isUpSent = true
                    }
                } else if (isDownSent || keyDownHandler == nil), !isUpSent {
                    keyUp.success(result)
                    isUpSent = true
                }
            }
        }
        if activeCount == 0 {
            isDownSent = false
        }
    }
    
    func setKeyDownHandler(_ PushToTalkValue: PushToTalkValue?, success: @escaping(Result)->Void) {
        self.keyDownHandler = .init(PushToTalkValue: PushToTalkValue, success: success, eventType: .keyDown)
    }
    
    func setKeyUpHandler(_ PushToTalkValue: PushToTalkValue?, success: @escaping(Result)->Void) {
        self.keyUpHandler = .init(PushToTalkValue: PushToTalkValue, success: success, eventType: .keyUp)
    }
    
    func removeHandlers() {
        self.keyDownHandler = nil
        self.keyUpHandler = nil
    }
    
    deinit {
        for monitor in monitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}


final class PushToTalk {
    
    enum Mode {
        case speaking
        case waiting
        case toggle
    }
    var update: (Mode)->Void = { _ in }
    
    private let disposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    private let monitor: KeyboardGlobalHandler = KeyboardGlobalHandler()

    init(sharedContext: SharedAccountContext) {
        let settings = voiceCallSettings(sharedContext.accountManager) |> deliverOnMainQueue
        
        disposable.set(settings.start(next: { [weak self] settings in
            self?.updateSettings(settings)
        }))
    
    }
    
    private func updateSettings(_ settings: VoiceCallSettings) {
        switch settings.mode {
        case .always:
            if let event = settings.pushToTalk {
                self.monitor.setKeyUpHandler(event, success: { [weak self] result in
                    self?.update(.toggle)
                })
                self.monitor.setKeyDownHandler(event, success: {_ in
                    
                })
            } else {
                self.monitor.removeHandlers()
            }
        case .pushToTalk:
            if let event = settings.pushToTalk {
                self.monitor.setKeyUpHandler(event, success: { [weak self] result in
                    self?.proccess(result.eventType)
                })
                self.monitor.setKeyDownHandler(event, success: { [weak self] result in
                    self?.proccess(result.eventType)
                })
            } else {
                self.monitor.removeHandlers()
            }
        }
    }
    
    private func proccess(_ eventType: NSEvent.EventTypeMask) {
        if eventType == .keyUp {
            let signal = Signal<NoValue, NoError>.complete() |> delay(0.15, queue: .mainQueue())
            actionDisposable.set(signal.start(completed: { [weak self] in
                self?.update(.waiting)
            }))
        } else if eventType == .keyDown {
            actionDisposable.set(nil)
            let signal = Signal<NoValue, NoError>.complete() |> delay(0.15, queue: .mainQueue())
            actionDisposable.set(signal.start(completed: { [weak self] in
                self?.update(.speaking)
            }))
        }
    }
    
    deinit {
        actionDisposable.dispose()
        disposable.dispose()

    }
    
}
