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
    
    
    
    static var get:TKPublicKey? {
        if let publicTonKey = SSKeychain.passwordData(forService: "TON", account: TKKeychainName.public.rawValue) {
            return TKPublicKey(key: publicTonKey)
        }
        return nil
    }
}

@available(OSX 10.12, *)
struct TKPrivateKey : Codable {
    let key: Data
    
    static var get:TKPrivateKey? {
        if let privateTonKey = SSKeychain.passwordData(forService: "TON", account: TKKeychainName.private.rawValue) {
            return TKPrivateKey(key: privateTonKey)
        }
        return nil
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
    
    static func initializePairAndSavePublic() -> Signal<TKKey?, NoError> {
        return Signal { subscriber in
            if let keys = createLocalPrivateKey() {
                let success = SSKeychain.setPasswordData(keys.publicKey.key, forService: "TON", account: TKKeychainName.public.rawValue)
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
    
    static func applyKeys(_ keys: TKKey, tonInstance: TonInstance, password: String) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let pbkdf = MTPBKDF2(password.data(using: .utf8)!, Data(), 100000)!
            return tonlibEncrypt(tonInstance: tonInstance, decryptedData: keys.privateKey.key, secret: pbkdf).start(next: { data in
                let success1 = SSKeychain.setPasswordData(keys.publicKey.key, forService: "TON", account: TKKeychainName.public.rawValue)
                let success2 = SSKeychain.setPasswordData(data, forService: "TON", account: TKKeychainName.private.rawValue)
                subscriber.putNext(success1 && success2)
                subscriber.putCompletion()
            }, completed: {
                subscriber.putCompletion()
            })
        } |> runOn(queue)
    }
    
    
    static func decryptedSecretKey(_ encryptedKey: TonKeychainEncryptedData, tonInstance: TonInstance, by password: String) -> Signal<Data?, NoError> {
        return Signal { subscriber in
            let privateKey = SSKeychain.passwordData(forService: "TON", account: TKKeychainName.private.rawValue)
            let publicKey = SSKeychain.passwordData(forService: "TON", account: TKKeychainName.public.rawValue)
            var disposable: Disposable?
            if let privateEncrypted = privateKey, let publicKey = publicKey {
                let pbkdf = MTPBKDF2(password.data(using: .utf8)!, Data(), 100000)!

                disposable = tonlibDecrypt(tonInstance: tonInstance, encryptedData: privateEncrypted, secret: pbkdf).start(next: { data in
                    if let privateKey = data {
                        let priv = TKPrivateKey(key: privateKey)
                        let pub = TKPrivateKey(key: publicKey)
                        if pub.key == encryptedKey.publicKey {
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


