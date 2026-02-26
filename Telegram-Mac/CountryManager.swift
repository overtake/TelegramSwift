//
//  CountryManager.swift
//  TelegramMac
//
//  Created by keepcoder on 26/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

class CountryItem  {
    let shortName:String
    let fullName:String
    let smallName:String
    let code:Int
    init(shortName:String, fullName:String, smallName:String, code:Int) {
        self.shortName = shortName
        self.fullName = fullName
        self.smallName = smallName
        self.code = code
    }
}

class CountryManager {
    let countries:[CountryItem]
    private let coded:[Int:CountryItem]
    private let smalled:[String:CountryItem]
    private let fulled:[String:CountryItem]
    private let shorted:[String:CountryItem]
   
    init() {
        var countries:[CountryItem] = [CountryItem]()
        var coded:[Int:CountryItem] = [Int:CountryItem]()
        var smalled:[String:CountryItem] = [String:CountryItem]()
        var fulled:[String:CountryItem] = [String:CountryItem]()
        var shorted:[String:CountryItem] = [String:CountryItem]()
        
        
        if let resource = Bundle.main.path(forResource: "PhoneCountries", ofType: "txt"), let content = try? String(contentsOfFile: resource) {
            let list = content.components(separatedBy: CharacterSet.newlines)
            for country in list {
                let parameters = country.components(separatedBy: ";")
                if parameters.count == 3 {
                    let fullName = "\(parameters[2]) +\(parameters[0])"
                    let item = CountryItem(shortName: parameters[2], fullName: fullName, smallName: parameters[1], code: parameters[0].nsstring.integerValue)
                    
                    countries.append(item)
                    if coded[item.code] == nil {
                        coded[item.code] = item
                    }
                    smalled[item.smallName.lowercased()] = item
                    fulled[item.fullName.lowercased()] = item
                    shorted[item.shortName.lowercased()] = item
                }
            }
        }
        
        countries.sort { (item1, item2) -> Bool in
            return item1.fullName < item2.fullName
        }
        
        self.countries = countries
        self.coded = coded
        self.smalled = smalled
        self.fulled = fulled
        self.shorted = shorted
        
    }
    
    func item(byCodeNumber codeNumber: Int) -> CountryItem? {
        return coded[codeNumber]
    }
    
    func item(bySmallCountryName countryName: String) -> CountryItem? {
        return smalled[countryName.lowercased()]
    }
    
    func item(byFullCountryName countryName: String) -> CountryItem? {
        return fulled[countryName.lowercased()]
    }
    
    func item(byShortCountryName countryName: String) -> CountryItem? {
        return shorted[countryName.lowercased()]
    }
}



func loadCountryCodes() -> [Country] {
    guard let filePath = Bundle.main.path(forResource: "PhoneCountries", ofType: "txt") else {
        return []
    }
    guard let stringData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return []
    }
    guard let data = String(data: stringData, encoding: .utf8) else {
        return []
    }
    
    let delimiter = ";"
    let endOfLine = "\n"
    
    var result: [Country] = []
//    var countriesByPrefix: [String: (Country, Country.CountryCode)] = [:]
    
    var currentLocation = data.startIndex
    
    let locale = Locale(identifier: "en-US")
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = String(data[currentLocation ..< codeRange.lowerBound])
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        guard let patternRange = data.range(of: delimiter, options: [], range: idRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let pattern = String(data[idRange.upperBound ..< patternRange.lowerBound])
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: patternRange.upperBound ..< data.endIndex)
        
        let countryName = locale.localizedString(forIdentifier: countryId) ?? ""
        if let _ = Int(countryCode) {
            let code = Country.CountryCode(code: countryCode, prefixes: [], patterns: !pattern.isEmpty ? [pattern] : [])
            let country = Country(id: countryId, name: countryName, localizedName: nil, countryCodes: [code], hidden: false)
            result.append(country)
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
        
    return result
}
