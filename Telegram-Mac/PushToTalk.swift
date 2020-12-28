//
//  PushToTalk.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/12/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import HotKey
import SwiftSignalKit
import TGUIKit

extension PushToTalkValue {
    func isEqual(_ value: KeyboardGlobalHandler.Result) -> Bool {
        return value.keyCodes == self.keyCodes && self.modifierFlags == value.modifierFlags && value.otherMouse == self.otherMouse
    }
}

final class KeyboardGlobalHandler {
    
    static func hasPermission(askPermission: Bool = true) -> Bool {
        let result: Bool
        if #available(macOS 10.15, *) {
            result = PermissionsManager.checkInputMonitoring(withPrompt: false)
        } else if #available(macOS 10.14, *) {
            result = PermissionsManager.checkAccessibility(withPrompt: false)
        } else {
            result = true
        }
        if !result && askPermission {
            self.requestPermission()
        }
        return result
    }
    
    static func requestPermission() -> Void {
        if #available(macOS 10.15, *) {
            _ = PermissionsManager.checkInputMonitoring(withPrompt: true)
        } else if #available(macOS 10.14, *) {
            _ = PermissionsManager.checkAccessibility(withPrompt: true)
        } else {
            
        }
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
        let otherMouse:[Int]
        let modifierFlags: [PushToTalkValue.ModifierFlag]
        let string: String
        let eventType: NSEvent.EventTypeMask
    }
    

    private var monitors: [Any?] = []

    private var keyDownHandler: Handler?
    private var keyUpHandler: Handler?

    private var eventTap: CFMachPort?
    private var runLoopSource:CFRunLoopSource?
    
    static func getPermission()->Signal<Bool, NoError> {
        return Signal { subscriber in
            
            subscriber.putNext(KeyboardGlobalHandler.hasPermission(askPermission: false))
            subscriber.putCompletion()
            
            return EmptyDisposable
            
        } |> runOn(.concurrentDefaultQueue()) |> deliverOnMainQueue
    }
    
    private let disposable = MetaDisposable()
    
    enum Mode {
        case local(Window)
        case global
    }
    private let mode: Mode
    
    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .global:
            self.disposable.set(KeyboardGlobalHandler.getPermission().start(next: { [weak self] value in
                self?.runListener(hasPermission: value)
            }))
        case .local:
            self.runListener(hasPermission: false)
        }
    }
    
    private func runListener(hasPermission: Bool) {
        final class ProcessEvent {
            var process:(NSEvent)->Void = { _ in }
        }
        
        let processEvent = ProcessEvent()
        
        processEvent.process = { [weak self] event in
            self?.process(event)
        }
                
        if hasPermission {
            func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
                if let event = NSEvent(cgEvent: event) {
                    let processor = Unmanaged<ProcessEvent>.fromOpaque(refcon!).takeUnretainedValue()
                    processor.process(event)
                }
                return Unmanaged.passRetained(event)
            }
            let eventMask:Int32 = (1 << CGEventType.keyDown.rawValue) |
                (1 << CGEventType.otherMouseDown.rawValue) |
                (1 << CGEventType.otherMouseUp.rawValue) |
                (1 << CGEventType.keyUp.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue)
            
            self.eventTap = CGEvent.tapCreate(tap: .cghidEventTap,
                                                  place: .headInsertEventTap,
                                                  options: .listenOnly,
                                                  eventsOfInterest: CGEventMask(eventMask),
                                                  callback: callback,
                                                  userInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(processEvent).toOpaque()))

            if let eventTap = self.eventTap {
                let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                CGEvent.tapEnable(tap: eventTap, enable: true)
                self.runLoopSource = runLoopSource
            }
        } else {
            monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .keyDown, .flagsChanged, .otherMouseUp, .otherMouseDown], handler: { [weak self] event in
                guard let `self` = self else {
                    return event
                }
                self.process(event)
                return event
            }))
        }
    }
    
    deinit {
        for monitor in monitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let source = self.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        disposable.dispose()
    }
    
    private var downStake:[NSEvent] = []
    private var otherMouseDownStake:[NSEvent] = []
    private var flagsStake:[NSEvent] = []
        
    private var currentDownStake:[NSEvent] = []
    private var currentOtherMouseDownStake:[NSEvent] = []
    private var currentFlagsStake:[NSEvent] = []


    var activeCount: Int {
        var total:Int = 0
        if currentDownStake.count > 0 {
            total += currentDownStake.count
        }
        if currentFlagsStake.count > 0 {
            total += currentFlagsStake.count
        }
        if currentOtherMouseDownStake.count > 0 {
            total += currentOtherMouseDownStake.count
        }
        return total
    }
    
    @discardableResult private func process(_ event: NSEvent) -> Bool {
        
        switch mode {
        case .global:
            break
        case let .local(window):
            if window.windowNumber != event.windowNumber {
                return false
            }
        }
        
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
        case .otherMouseDown:
            if !otherMouseDownStake.contains(where: { $0.buttonNumber == event.buttonNumber }) {
                otherMouseDownStake.append(event)
            }
            if !currentOtherMouseDownStake.contains(where: { $0.buttonNumber == event.buttonNumber }) {
                currentOtherMouseDownStake.append(event)
            }
        case .otherMouseUp:
            currentOtherMouseDownStake.removeAll(where: { $0.buttonNumber == event.buttonNumber })
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

        if self.activeCount == 0 {
            self.downStake.removeAll()
            self.flagsStake.removeAll()
            self.otherMouseDownStake.removeAll()
        }

        return false
    }
    
    private var isDownSent: Bool = false
    private var isUpSent: Bool = false
    @discardableResult private func applyStake(_ isDown: Bool) -> Bool {
        var string = ""
        
        var _flags: [PushToTalkValue.ModifierFlag] = []
        
        
        let finalFlag = self.flagsStake.max(by: { lhs, rhs in
            return lhs.modifierFlags.rawValue < rhs.modifierFlags.rawValue
        })
        
        if let finalFlag = finalFlag {
            string += StringFromKeyCode(finalFlag.keyCode, finalFlag.modifierFlags.rawValue)!
        }
        
        for flag in flagsStake {
            _flags.append(PushToTalkValue.ModifierFlag(keyCode: flag.keyCode, flag: flag.modifierFlags.rawValue))
        }
        var _keyCodes:[UInt16] = []
        for key in downStake {
            string += StringFromKeyCode(key.keyCode, 0)!.uppercased()
            if key != downStake.last {
                string += " + "
            }
            _keyCodes.append(key.keyCode)
        }
        
        var _otherMouse:[Int] = []
        for key in otherMouseDownStake {
            if !string.isEmpty {
                string += " + "
            }
            string += "MOUSE\(key.buttonNumber)"
            if key != otherMouseDownStake.last {
                string += " + "
            }
            _otherMouse.append(key.buttonNumber)
        }
        
        
        let result = Result(keyCodes: _keyCodes, otherMouse: _otherMouse, modifierFlags: _flags, string: string, eventType: isDown ? .keyDown : .keyUp)
        
        string = ""
        var flags: [PushToTalkValue.ModifierFlag] = []
        for flag in currentFlagsStake {
            flags.append(PushToTalkValue.ModifierFlag(keyCode: flag.keyCode, flag: flag.modifierFlags.rawValue))
        }
        var keyCodes:[UInt16] = []
        for key in currentDownStake {
            keyCodes.append(key.keyCode)
        }
        var otherMouses:[Int] = []
        for key in currentOtherMouseDownStake {
            otherMouses.append(key.buttonNumber)
        }
                
        let invokeUp:(PushToTalkValue)->Bool = { ptt in
            var invoke: Bool = false
            for keyCode in ptt.keyCodes {
                if !keyCodes.contains(keyCode) {
                    invoke = true
                }
            }
            for mouse in ptt.otherMouse {
                if !otherMouses.contains(mouse) {
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
            for buttonNumber in ptt.otherMouse {
                if !otherMouses.contains(buttonNumber) {
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

        var isHandled: Bool = false
                
        if isDown {
            isUpSent = false
            if let keyDown = self.keyDownHandler {
                if let ptt = keyDown.pushToTalkValue {
                    if invokeDown(ptt) {
                        keyDown.success(result)
                        isDownSent = true
                        isHandled = true
                    }
                } else {
                    keyDown.success(result)
                    isDownSent = true
                    isHandled = true
                }
            }
        } else {
            if let keyUp = self.keyUpHandler {
                if let ptt = keyUp.pushToTalkValue {
                    if invokeUp(ptt), (isDownSent || keyDownHandler == nil), !isUpSent {
                        keyUp.success(result)
                        isHandled = true
                        isUpSent = true
                    }
                } else if (isDownSent || keyDownHandler == nil), !isUpSent {
                    keyUp.success(result)
                    isHandled = true
                    isUpSent = true
                }
            }
        }
        if activeCount == 0 {
            isDownSent = false
        }
        return isHandled
    }
    
    func setKeyDownHandler(_ pushToTalkValue: PushToTalkValue?, success: @escaping(Result)->Void) {
        self.keyDownHandler = .init(PushToTalkValue: pushToTalkValue, success: success, eventType: .keyDown)
    }
    
    func setKeyUpHandler(_ pushToTalkValue: PushToTalkValue?, success: @escaping(Result)->Void) {
        self.keyUpHandler = .init(PushToTalkValue: pushToTalkValue, success: success, eventType: .keyUp)
    }
    
    func removeHandlers() {
        self.keyDownHandler = nil
        self.keyUpHandler = nil
    }
    
}


final class PushToTalk {
    
    enum Mode {
        case speaking(sound: String?)
        case waiting(sound: String?)
        case toggle(activate: String?, deactivate: String?)
    }
    var update: (Mode)->Void = { _ in }
    
    private let disposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    private let monitor: KeyboardGlobalHandler
    private let spaceMonitor: KeyboardGlobalHandler

    private let spaceEvent = PushToTalkValue(keyCodes: [KeyboardKey.Space.rawValue], otherMouse: [], modifierFlags: [], string: "⎵")

    init(sharedContext: SharedAccountContext, window: Window) {
        self.monitor = KeyboardGlobalHandler(mode: .global)
        self.spaceMonitor = KeyboardGlobalHandler(mode: .local(window))
        let settings = voiceCallSettings(sharedContext.accountManager) |> deliverOnMainQueue
        
        disposable.set(settings.start(next: { [weak self] settings in
            self?.updateSettings(settings)
        }))
    }

    private func installSpaceMonitor(settings: VoiceCallSettings) {
        switch settings.mode {
        case .pushToTalk:
            self.spaceMonitor.setKeyDownHandler(spaceEvent, success: { [weak self] result in
                self?.proccess(result.eventType, false)
            })
            self.spaceMonitor.setKeyUpHandler(spaceEvent, success: { [weak self] result in
                self?.proccess(result.eventType, false)
            })
        case .always:
            self.spaceMonitor.setKeyDownHandler(spaceEvent, success: { _ in
            })
            self.spaceMonitor.setKeyUpHandler(spaceEvent, success: { [weak self] result in
                self?.update(.toggle(activate: nil, deactivate: nil))
            })
        case .none:
            self.spaceMonitor.removeHandlers()
        }
       
    }
    private func deinstallSpaceMonitor() {
        self.spaceMonitor.removeHandlers()
    }
    
    private func updateSettings(_ settings: VoiceCallSettings) {
        let performSound: Bool = settings.pushToTalkSoundEffects
        switch settings.mode {
        case .always:
            if let event = settings.pushToTalk {
                self.monitor.setKeyUpHandler(event, success: { [weak self] result in
                    self?.update(.toggle(activate: nil, deactivate: nil))
                })
                self.monitor.setKeyDownHandler(event, success: {_ in
                    
                })
                if event == spaceEvent {
                    deinstallSpaceMonitor()
                } else {
                    installSpaceMonitor(settings: settings)
                }
            } else {
                self.monitor.removeHandlers()
                installSpaceMonitor(settings: settings)
            }
        case .pushToTalk:
            if let event = settings.pushToTalk {
                self.monitor.setKeyUpHandler(event, success: { [weak self] result in
                    self?.proccess(result.eventType, performSound)
                })
                self.monitor.setKeyDownHandler(event, success: { [weak self] result in
                    self?.proccess(result.eventType, performSound)
                })
                if event == spaceEvent {
                    deinstallSpaceMonitor()
                } else {
                    installSpaceMonitor(settings: settings)
                }
            } else {
                self.monitor.removeHandlers()
                installSpaceMonitor(settings: settings)
            }
        case .none:
            self.monitor.removeHandlers()
            deinstallSpaceMonitor()
        }
    }
    
    private func proccess(_ eventType: NSEvent.EventTypeMask, _ performSound: Bool) {
        if eventType == .keyUp {
            let signal = Signal<NoValue, NoError>.complete() |> delay(0.15, queue: .mainQueue())
            actionDisposable.set(signal.start(completed: { [weak self] in
                self?.update(.waiting(sound: performSound ? "Pop" : nil))
            }))
        } else if eventType == .keyDown {
            actionDisposable.set(nil)
            self.update(.speaking(sound: performSound ? "Purr" : nil))
        }
    }
    
    deinit {
        actionDisposable.dispose()
        disposable.dispose()

    }
    
}
