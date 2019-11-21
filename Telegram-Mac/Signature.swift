//
//  Signature.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Security
import MtProtoKit


func evaluateApiHash() -> String? {
    var rawStaticCode: SecStaticCode? = nil
    var result = SecStaticCodeCreateWithPath(URL(fileURLWithPath: Bundle.main.bundlePath) as CFURL, [], &rawStaticCode)
   
    guard result == 0, let staticCode = rawStaticCode else {
        return nil
    }
    
    var dictionary: CFDictionary? = nil
    
    let flags: SecCSFlags = SecCSFlags(rawValue: kSecCSSigningInformation);
    
    result = SecCodeCopySigningInformation(staticCode, flags, &dictionary)
    
    guard result == 0, let info = dictionary as? [String: Any] else {
        return nil
    }
    
    guard let rawTrast = info[kSecCodeInfoTrust as String] else {
        return nil
    }
    
    guard let _ = info[kSecCodeInfoIdentifier as String] else {
        return nil
    }
    
    let trust = (rawTrast as! SecTrust)
    let certsCount = SecTrustGetCertificateCount(trust)
    var certsData: Data = Data()
    
    for i in 0 ..< certsCount {
        if let cert = SecTrustGetCertificateAtIndex(trust, i) {
            certsData.append(SecCertificateCopyData(cert) as Data)
        } else {
            return nil
        }
    }
    
    let apiHash = MTSha1(certsData)
    return apiHash!.map { String(format: "%02hhx", $0) }.joined()
}
