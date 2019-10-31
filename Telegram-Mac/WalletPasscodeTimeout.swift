//
//  WalletPasscodeTimeout.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

enum WalletPasscodeTimeoutLevel : Int32, Equatable  {
    case none = 0
    case first = 1
    case second = 2
    case thrid = 3
    case fourth = 4
    case fifth = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    var timeout: Int32 {
        switch self {
        case .first:
            return 0
        case .none:
            return 0
        case .second:
            return 0
        case .thrid:
            return 0
        case .fourth:
            return 30
        case .fifth:
            return 30
        case .six:
            return 60
        case .seven:
            return 60 * 5
        case .eight:
            return 60 * 30
        case .nine:
            return 60 * 60
        }
    }
    var incremented: WalletPasscodeTimeoutLevel {
        let value = self.rawValue
        return WalletPasscodeTimeoutLevel(rawValue: value + 1) ?? .nine
    }
    
}

struct WalletPasscodeTimeout: PreferencesEntry, Equatable {
    let timeout: Int32
    let level: WalletPasscodeTimeoutLevel
    static var defaultSettings: WalletPasscodeTimeout {
        return WalletPasscodeTimeout(timeout: 0, level: .none)
    }
    
    init(timeout: Int32, level: WalletPasscodeTimeoutLevel) {
        self.timeout = timeout
        self.level = level
    }
    
    init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeInt32ForKey("to", orElse: 0)
        self.level = WalletPasscodeTimeoutLevel(rawValue: decoder.decodeInt32ForKey("level", orElse: 0)) ?? .none
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timeout, forKey: "to")
        encoder.encodeInt32(self.level.rawValue, forKey: "level")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WalletPasscodeTimeout {
            return self == to
        } else {
            return false
        }
    }
    
    func withUpdatedTimeout(_ timeout: Int32) -> WalletPasscodeTimeout {
        return WalletPasscodeTimeout(timeout: timeout, level: self.level)
    }
    func withUpdatedLevel(_ level: WalletPasscodeTimeoutLevel) -> WalletPasscodeTimeout {
        return WalletPasscodeTimeout(timeout: self.timeout, level: level)
    }
}

func updateWalletTimeoutInteractively(postbox: Postbox, _ f: @escaping (WalletPasscodeTimeout) -> WalletPasscodeTimeout) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.walletPasscodeTimeout, { entry in
            let currentSettings: WalletPasscodeTimeout
            if let entry = entry as? WalletPasscodeTimeout {
                currentSettings = entry
            } else {
                currentSettings = WalletPasscodeTimeout.defaultSettings
            }
            return f(currentSettings)
        })
    }
}



final class WalletPasscodeTimeoutContext {
    private(set) var timeout: WalletPasscodeTimeout = .defaultSettings {
        didSet {
            applyTimer()
            self.valuePromise.set(timeout.timeout)
        }
    }
    
    private var valuePromise:ValuePromise<Int32> = ValuePromise(0, ignoreRepeated: true)
    
    var value: Signal<Int32, NoError> {
        return self.valuePromise.get()
    }
    
    private let postbox: Postbox
    private let disposable = MetaDisposable()
    private let updateTimeoutDisposable = MetaDisposable()
    private let updateSettingsDisposable = MetaDisposable()
    init(postbox: Postbox) {
        self.postbox = postbox
        self.disposable.set((postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.walletPasscodeTimeout]) |> deliverOnMainQueue).start(next: { [weak self] view in
            self?.timeout = view.values[ApplicationSpecificPreferencesKeys.walletPasscodeTimeout] as? WalletPasscodeTimeout ?? WalletPasscodeTimeout.defaultSettings
        }))
    }
    
    private func applyTimer() {
        if timeout.timeout > 0 {
            let signal = updateWalletTimeoutInteractively(postbox: self.postbox, {
                $0.withUpdatedTimeout($0.timeout - 1)
            }) |> delay(1.0, queue: .concurrentDefaultQueue())
            updateTimeoutDisposable.set(signal.start())
        } else {
            updateTimeoutDisposable.set(nil)
        }
    }
    
    func incrementLevel()  {
        updateSettingsDisposable.set(updateWalletTimeoutInteractively(postbox: self.postbox, { settings in
            return settings.withUpdatedLevel(settings.level.incremented).withUpdatedTimeout(settings.level.timeout)
        }).start())
    }
    
    func disposeLevel() {
        updateSettingsDisposable.set(updateWalletTimeoutInteractively(postbox: self.postbox, { settings in
            return settings.withUpdatedLevel(.none).withUpdatedTimeout(0)
        }).start())
    }

    
    func clear() {
        disposable.dispose()
        updateTimeoutDisposable.dispose()
        updateSettingsDisposable.dispose()
    }
    
    deinit {
        clear()
    }
}


