//
//  LocalAuth.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import LocalAuthentication
import SwiftSignalKit
import BuildConfig

public enum LocalAuthBiometricAuthentication {
    case touchId
    case faceId
}

public struct LocalAuth {
    private static let customKeyIdPrefix = "$#_".data(using: .utf8)!
    
    public enum DecryptionResult {
        public enum Error {
            case cancelled
            case generic
        }
        
        case result(Data)
        case error(Error)
    }
    

    public final class PrivateKey {
        private let privateKey: SecKey
        private let publicKey: SecKey
        public let publicKeyRepresentation: Data
        
        fileprivate init(privateKey: SecKey, publicKey: SecKey, publicKeyRepresentation: Data) {
            self.privateKey = privateKey
            self.publicKey = publicKey
            self.publicKeyRepresentation = publicKeyRepresentation
        }
        
        public func encrypt(data: Data) -> Data? {
            var error: Unmanaged<CFError>?
            let cipherText = SecKeyCreateEncryptedData(self.publicKey, .eciesEncryptionCofactorVariableIVX963SHA512AESGCM, data as CFData, &error)
            if let error {
                error.release()
            }
            guard let cipherText else {
                return nil
            }
            
            let result = cipherText as Data
            return result
        }
        
        public func decrypt(data: Data) -> DecryptionResult {
            var maybeError: Unmanaged<CFError>?
            let plainText = SecKeyCreateDecryptedData(self.privateKey, .eciesEncryptionCofactorVariableIVX963SHA512AESGCM, data as CFData, &maybeError)
            let error = maybeError?.takeRetainedValue()
            
            guard let plainText else {
                if let error {
                    if CFErrorGetCode(error) == -2 {
                        return .error(.cancelled)
                    }
                }
                return .error(.generic)
            }
            
            let result = plainText as Data
            return .result(result)
        }
    }
    
    private static func bundleSeedId() -> String? {
        return "6N38VWS5BX"
    }
    
    public static func getOrCreatePrivateKey(baseAppBundleId: String, keyId: Data) -> PrivateKey? {
        if let key = self.getPrivateKey(baseAppBundleId: baseAppBundleId, keyId: keyId) {
            return key
        } else {
            return self.addPrivateKey(baseAppBundleId: baseAppBundleId, keyId: keyId)
        }
    }
    
    private static func getPrivateKey(baseAppBundleId: String, keyId: Data) -> PrivateKey? {
        guard let bundleSeedId = self.bundleSeedId() else {
            return nil
        }
        
        let applicationTag = customKeyIdPrefix + keyId
        let accessGroup = "\(bundleSeedId).\(baseAppBundleId)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey as String,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom as String,
            kSecReturnRef as String: true
        ]
        
        var maybePrivateKey: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &maybePrivateKey)
        if status != errSecSuccess {
            return nil
        }
        guard let maybePrivateKey else {
            return nil
        }
        if CFGetTypeID(maybePrivateKey) != SecKeyGetTypeID() {
            return nil
        }
        let privateKey = maybePrivateKey as! SecKey
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        guard let publicKeyRepresentation = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return nil
        }
        
        let result = PrivateKey(privateKey: privateKey, publicKey: publicKey, publicKeyRepresentation: publicKeyRepresentation as Data)
        
        return result
    }
    
    public static func removePrivateKey(baseAppBundleId: String, keyId: Data) -> Bool {
        guard let bundleSeedId = self.bundleSeedId() else {
            return false
        }
        
        let applicationTag = customKeyIdPrefix + keyId
        let accessGroup = "\(bundleSeedId).\(baseAppBundleId)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey as String,
            kSecAttrApplicationTag as String: applicationTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom as String,
            kSecAttrIsPermanent as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess {
            return false
        }
        return true
    }
    
    private static func addPrivateKey(baseAppBundleId: String, keyId: Data) -> PrivateKey? {
        guard let bundleSeedId = self.bundleSeedId() else {
            return nil
        }
        
        let applicationTag = customKeyIdPrefix + keyId
        let accessGroup = "\(bundleSeedId).\(baseAppBundleId)"
        
        guard let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [.applicationPassword], nil) else {
            return nil
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom as String,
            kSecAttrKeySizeInBits as String: 256 as NSNumber,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
            ] as [String: Any]
        ]
        var error: Unmanaged<CFError>?
        let maybePrivateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        if let error {
            error.release()
        }
        guard let privateKey = maybePrivateKey else {
            return nil
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        guard let publicKeyRepresentation = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return nil
        }
        
        let result = PrivateKey(privateKey: privateKey, publicKey: publicKey, publicKeyRepresentation: publicKeyRepresentation as Data)
        return result
    }
}

