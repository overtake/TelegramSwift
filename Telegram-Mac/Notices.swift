import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore


public final class ApplicationSpecificBoolNotice: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

public final class ApplicationSpecificVariantNotice: Codable {
    public let value: Bool
    
    public init(value: Bool) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.value ? 1 : 0) as Int32, forKey: "v")
    }
}

public final class ApplicationSpecificCounterNotice: Codable {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value, forKey: "v")
    }
}

public final class ApplicationSpecificTimestampNotice: Codable {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(Int32.self, forKey: "v")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value, forKey: "v")
    }
}

public final class ApplicationSpecificTimestampAndCounterNotice: Codable {
    public let counter: Int32
    public let timestamp: Int32
    
    public init(counter: Int32, timestamp: Int32) {
        self.counter = counter
        self.timestamp = timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.counter = try container.decode(Int32.self, forKey: "v")
        self.timestamp = try container.decode(Int32.self, forKey: "t")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.counter, forKey: "v")
        try container.encode(self.timestamp, forKey: "t")
    }
}

public final class ApplicationSpecificInt64ArrayNotice: Codable {
    public let values: [Int64]
    
    public init(values: [Int64]) {
        self.values = values
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.values = try container.decode([Int64].self, forKey: "v")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.values, forKey: "v")
    }
}

private func noticeNamespace(namespace: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: namespace)
    return key
}

private func noticeKey(peerId: PeerId, key: Int32) -> ValueBoxKey {
    let v = ValueBoxKey(length: 8 + 4)
    v.setInt64(0, value: peerId.toInt64())
    v.setInt32(8, value: key)
    return v
}

private enum ApplicationSpecificGlobalNotice: Int32 {
    case value = 0
    
    var key: ValueBoxKey {
        let v = ValueBoxKey(length: 4)
        v.setInt32(0, value: self.rawValue)
        return v
    }
}


private struct ApplicationSpecificNoticeKeys {
    private static let botPaymentLiabilityNamespace: Int32 = 1
  
    
    static func botPaymentLiabilityNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botPaymentLiabilityNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
}

public struct ApplicationSpecificNotice {
    public static func getBotPaymentLiability(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Bool, NoError> {
        return accountManager.transaction { transaction -> Bool in
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId))?.get(ApplicationSpecificBoolNotice.self) {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setBotPaymentLiability(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            if let entry = CodableEntry(ApplicationSpecificBoolNotice()) {
                transaction.setNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId), entry)
            }
        }
    }
}
