import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public final class ApplicationSpecificBoolNotice: NoticeEntry {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: NoticeEntry) -> Bool {
        if let _ = to as? ApplicationSpecificBoolNotice {
            return true
        } else {
            return false
        }
    }
}

public final class ApplicationSpecificVariantNotice: NoticeEntry {
    public let value: Bool
    
    public init(value: Bool) {
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value ? 1 : 0, forKey: "v")
    }
    
    public func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificVariantNotice {
            if self.value != to.value {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public final class ApplicationSpecificCounterNotice: NoticeEntry {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value, forKey: "v")
    }
    
    public func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificCounterNotice {
            if self.value != to.value {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public final class ApplicationSpecificTimestampNotice: NoticeEntry {
    public let value: Int32
    
    public init(value: Int32) {
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value, forKey: "v")
    }
    
    public func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificTimestampNotice {
            if self.value != to.value {
                return false
            }
            return true
        } else {
            return false
        }
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
            if let _ = transaction.getNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId)) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    public static func setBotPaymentLiability(accountManager: AccountManager<TelegramAccountManagerTypes>, peerId: PeerId) -> Signal<Void, NoError> {
        return accountManager.transaction { transaction -> Void in
            transaction.setNotice(ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId), ApplicationSpecificBoolNotice())
        }
    }
}
