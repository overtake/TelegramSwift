//
//  Keychain.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Security
import MtProtoKitMac
import TelegramCoreMac
import SwiftSignalKitMac

private let salt = "string with no sense".data(using: .utf8)!

@available(OSX 10.12, *)
enum TKKeychainName : String {
    case `public`
    case `private`
}
@available(OSX 10.12, *)
struct TKKey : Equatable {
    static func == (lhs: TKKey, rhs: TKKey) -> Bool {
        return lhs.publicKey.key == rhs.publicKey.key && lhs.privateKey.key == rhs.privateKey.key
    }
    let publicKey: TKPublicKey
    let privateKey: TKPrivateKey
}

@available(OSX 10.12, *)
struct TKPublicKey : Codable, Equatable {
    let key: Data
    
    func encrypt(data: Data) -> Data? {
        let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                      kSecAttrKeySizeInBits as String : 256]
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(self.key as CFData,
                                             options as CFDictionary,
                                             &error) else {
                                                return nil
        }
        
        if data.count % 16 != 0 {
            return nil
        }
        return SecKeyCreateEncryptedData(publicKey, SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM, data as CFData, nil) as Data?
    }
    
    
    
    static func get(for account: Account) -> TKPublicKey? {
        if let publicTonKey = SSKeychain.passwordData(forService: serviceName(for: account), account: TKKeychainName.public.rawValue) {
            return TKPublicKey(key: publicTonKey)
        }
        return nil
    }
    func set(for account: Account) -> Bool {
        return SSKeychain.setPasswordData(self.key, forService: serviceName(for: account), account: TKKeychainName.public.rawValue)
    }
    static func delete(for account: Account) -> Void {
        SSKeychain.deletePassword(forService: serviceName(for: account), account: TKKeychainName.public.rawValue)
    }
}

@available(OSX 10.12, *)
struct TKPrivateKey : Codable {
    let key: Data
    
    static func get(for account: Account) -> TKPrivateKey? {
        if let privateTonKey = SSKeychain.passwordData(forService: serviceName(for: account), account: TKKeychainName.private.rawValue) {
            return TKPrivateKey(key: privateTonKey)
        }
        return nil
    }
    func set(for account: Account) -> Bool {
        return SSKeychain.setPasswordData(self.key, forService: serviceName(for: account), account: TKKeychainName.private.rawValue)
    }
    static func delete(for account: Account) -> Void {
        SSKeychain.deletePassword(forService: serviceName(for: account), account: TKKeychainName.private.rawValue)
    }
    func decrypt(data: Data) -> Data? {
        let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                                      kSecAttrKeySizeInBits as String : 256]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(self.key as CFData,
                                                   options as CFDictionary,
                                                   &error) else {
                                                    return nil
        }
        return SecKeyCreateDecryptedData(privateKey, SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM, data as CFData, nil) as Data?
    }
}

private func serviceName(for account: Account) -> String {
    return "TON-\(account.id.int64)"
}

@available(OSX 10.12, *)
final class TONKeychain {
    
    private static let queue = Queue(name: "TONKeychain", qos: DispatchQoS.default)
    
    static func createLocalPrivateKey() -> TKKey? {
        let attributes: [String: Any] = [kSecAttrKeyType as String : kSecAttrKeyTypeECSECPrimeRandom,
                                         kSecAttrKeySizeInBits as String: 256,
                                         kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent: true]]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return nil
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            return nil
        }
        
        return TKKey(publicKey: TKPublicKey(key: publicKeyData), privateKey: TKPrivateKey(key: privateKeyData))
    }
    
    static func initializePairAndSavePublic(for account: Account) -> Signal<TKKey?, NoError> {
        return Signal { subscriber in
            if let keys = createLocalPrivateKey() {
                let success = keys.publicKey.set(for: account)
                if success {
                    subscriber.putNext(keys)
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        } |> runOn(queue)
    }
    
    static func applyKeys(_ keys: TKKey, account: Account, tonInstance: TonInstance, password: String) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let pbkdf = MTPBKDF2(password.data(using: .utf8)!, salt, 100000)!
            
            return tonlibEncrypt(tonInstance: tonInstance, decryptedData: keys.privateKey.key, secret: pbkdf).start(next: { data in
                let success1 = keys.publicKey.set(for: account)
                let success2 = TKPrivateKey(key: data).set(for: account)
                subscriber.putNext(success1 && success2)
                subscriber.putCompletion()
            }, completed: {
                subscriber.putCompletion()
            })
        } |> runOn(queue)
    }
    
    static func hasKeys(for account: Account) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            subscriber.putNext(TKPrivateKey.get(for: account) != nil && TKPublicKey.get(for: account) != nil)
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(queue)
    }
    
    static func delete(account: Account) -> Signal<Void, NoError> {
        return Signal { subscriber in
            TKPrivateKey.delete(for: account)
            TKPublicKey.delete(for: account)
            subscriber.putNext(Void())
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
    
    static func decryptedSecretKey(_ encryptedKey: TonKeychainEncryptedData, account: Account, tonInstance: TonInstance, by password: String) -> Signal<Data?, NoError> {
        return Signal { subscriber in
            let privateKey = TKPrivateKey.get(for: account)?.key
            
            var disposable: Disposable?
            if let privateEncrypted = privateKey, let publicKey = TKPublicKey.get(for: account) {
                let pbkdf = MTPBKDF2(password.data(using: .utf8)!, salt, 100000)!

                disposable = tonlibDecrypt(tonInstance: tonInstance, encryptedData: privateEncrypted, secret: pbkdf).start(next: { data in
                    if let privateKey = data {
                        let priv = TKPrivateKey(key: privateKey)
                        if publicKey.key == encryptedKey.publicKey {
                            subscriber.putNext(priv.decrypt(data: encryptedKey.data))
                            subscriber.putCompletion()
                        } else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                        }
                    } else {
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    }
                }, completed: {
                    
                })
                
                
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
            return ActionDisposable {
                disposable?.dispose()
            }
        } |> runOn(queue)
    }
    
}


