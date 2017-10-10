//
//  CountryManager.swift
//  TelegramMac
//
//  Created by keepcoder on 26/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

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
