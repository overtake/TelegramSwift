//
//  PhoneNumberUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import libphonenumber

private let phoneNumberUtil = NBPhoneNumberUtil()
func formatPhoneNumber(_ string: String) -> String {
    do {
        let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return string
    }
}

func isViablePhoneNumber(_ string: String) -> Bool {
    return phoneNumberUtil.isViablePhoneNumber(string)
}

class ParsedPhoneNumber: Equatable {
    let rawPhoneNumber: NBPhoneNumber?
    
    init?(string: String) {
        if let number = try? phoneNumberUtil.parse(string, defaultRegion: NB_UNKNOWN_REGION) {
            self.rawPhoneNumber = number
        } else {
            return nil
        }
    }
    
    static func == (lhs: ParsedPhoneNumber, rhs: ParsedPhoneNumber) -> Bool {
        var error: NSError?
        let result = phoneNumberUtil.isNumberMatch(lhs.rawPhoneNumber, second: rhs.rawPhoneNumber, error: &error)
        if error != nil {
            return false
        }
        if result != .NO_MATCH && result != .NOT_A_NUMBER {
            return true
        } else {
            return false
        }
    }
}
