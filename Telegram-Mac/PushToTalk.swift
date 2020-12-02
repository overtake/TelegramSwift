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

final class PushToTalk {
    private var hotKey:DDHotKey?
    
    enum Mode {
        case speaking
        case waiting
    }
    var update: (Mode)->Void = { _ in }
    
    private let disposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    init(sharedContext: SharedAccountContext) {        
        let settings = voiceCallSettings(sharedContext.accountManager) |> deliverOnMainQueue
        
        disposable.set(settings.start(next: { [weak self] settings in
            self?.updateSettings(settings)
        }))
    }
    
    private func updateSettings(_ settings: VoiceCallSettings) {
        if let hotKey = self.hotKey {
            DDHotKeyCenter.shared()?.unregisterHotKey(hotKey)
        }
        switch settings.mode {
        case .always:
            if let hotKey = self.hotKey {
                DDHotKeyCenter.shared()?.unregisterHotKey(hotKey)
            }
        case .pushToTalk:
            if let event = settings.pushToTalk {
                hotKey = DDHotKey(keyCode: event.keyCode, modifierFlags: event.modifierFlags, task: { [weak self] event in
                    if let event = event {
                        self?.proccess(event)
                    }
                })
                DDHotKeyCenter.shared()?.register(hotKey!)
            }
        }
    }
    
    private func proccess(_ event: NSEvent) {
        if event.type == .keyUp {
            let signal = Signal<NoValue, NoError>.complete() |> delay(0.2, queue: .mainQueue())
            actionDisposable.set(signal.start(completed: { [weak self] in
                self?.update(.waiting)
            }))
        } else if event.type == .keyDown {
            actionDisposable.set(nil)
            self.update(.speaking)
        }
    }
    
    deinit {
        if let hotKey = hotKey {
            DDHotKeyCenter.shared()?.unregisterHotKey(hotKey)
        }
        actionDisposable.dispose()
        disposable.dispose()
    }
    
}
