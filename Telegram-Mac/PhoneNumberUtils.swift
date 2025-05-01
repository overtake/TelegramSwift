//
//  PhoneNumberUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import libphonenumber
import TelegramCore

class CountriesConfiguration {
    public let countries: [Country]
    public let countriesByPrefix: [String: (Country, Country.CountryCode)]
    
    public init(countries: [Country]) {
        self.countries = countries
        
        var countriesByPrefix: [String: (Country, Country.CountryCode)] = [:]
        for country in countries {
            for code in country.countryCodes {
                if !code.prefixes.isEmpty {
                    for prefix in code.prefixes {
                        countriesByPrefix["\(code.code)\(prefix)"] = (country, code)
                    }
                } else {
                    countriesByPrefix[code.code] = (country, code)
                }
            }
        }
        
        self.countriesByPrefix = countriesByPrefix
    }
}




private let phoneNumberUtil = NBPhoneNumberUtil()
func formatPhoneNumber(_ string: String) -> String {
    do {
        let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return string
    }
}


func formatPhoneNumber(context: AccountContext, number: String) -> String {
    if let pattern = lookupPatternByNumber(number, configuration: context.currentCountriesConfiguration.with { $0 }) {
        return "+\(formatPhoneNumberToMask(number, mask: pattern))"
    } else {
        do {
            let number = try phoneNumberUtil.parse("+" + number, defaultRegion: nil)
            return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
        } catch _ {
            return number
        }
    }
}

private func removePlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c != "+" {
                result += String(c)
            }
        }
    }
    return result
}

func lookupCountryIdByNumber(_ number: String, configuration: CountriesConfiguration) -> (Country, Country.CountryCode)? {
    let number = removePlus(number)
    var results: [(Country, Country.CountryCode)]? = nil
    for i in 0 ..< number.count {
        let prefix = String(number.prefix(number.count - i))
        if let country = configuration.countriesByPrefix[prefix] {
            if var currentResults = results {
                if let result = currentResults.first, result.1.code.count > country.1.code.count {
                    break
                } else {
                    currentResults.append(country)
                }
            } else {
                results = [country]
            }
        }
    }
    return results?.first
}

private func lookupPatternByNumber(_ number: String, configuration: CountriesConfiguration) -> String? {
    let number = removePlus(number)
    if let (_, code) = lookupCountryIdByNumber(number, configuration: configuration), !code.patterns.isEmpty {
        var prefixes: [String: String] = [:]
        for pattern in code.patterns {
            let cleanPattern = pattern.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "X", with: "")
            let cleanPrefix = "\(code.code)\(cleanPattern)"
            prefixes[cleanPrefix] = pattern
        }
        for i in 0..<number.count {
            let prefix = String(number.prefix(number.count - i))
            if let pattern = prefixes[prefix] {
                return "\(String(repeating: "X", count: code.code.count)) \(pattern)"
            }
        }
        if let pattern = code.patterns.first {
            return "\(String(repeating: "X", count: code.code.count)) \(pattern)"
        } else {
            return nil
        }
    }
    return nil
}

public func formatPhoneNumberToMask(_ string: String, mask: String) -> String {
    let replacementCharacter: Character = "X"
    let pattern = mask.replacingOccurrences( of: "[0-9]", with: "X", options: .regularExpression)
    var pureNumber = string.replacingOccurrences( of: "[^0-9]", with: "", options: .regularExpression)
    for index in 0 ..< pattern.count {
        guard index < pureNumber.count else { return pureNumber }
        let stringIndex = pattern.index(pattern.startIndex, offsetBy: index)
        let patternCharacter = pattern[stringIndex]
        guard patternCharacter != replacementCharacter else { continue }
        pureNumber.insert(patternCharacter, at: stringIndex)
    }
    return pureNumber
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
