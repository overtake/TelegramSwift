//
//  LocalizableExtension.swift
//  Telegram
//
//  Created by keepcoder on 25/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//
import SwiftSignalKit
import TelegramCore
import SyncCore
import TGUIKit
import SyncCore
#if !APP_STORE
    import Sparkle
#endif

extension Int {
    func description() -> String {
        return "\(self)"
    }
    
}
extension Int32 {
    var description:String {
        return "\(self)"
    }
}
extension Float {
    var description:String {
        return "\(self)"
    }
}
extension Double {
    var description:String {
        return "\(self)"
    }
}


 func tr(_ string: String) -> String {
    return string
}

private func dictFromLocalization(_ value: Localization) -> [String: String] {
    var dict: [String: String] = [:]
    for entry in value.entries {
        switch entry {
        case let .string(key, value):
            dict[key] = value
        case let .pluralizedString(key, zero, one, two, few, many, other):
            if let zero = zero {
                dict["\(key)_zero"] = zero
            }
            if let one = one {
                dict["\(key)_one"] = one
            }
            if let two = two {
                dict["\(key)_two"] = two
            }
            if let few = few {
                dict["\(key)_few"] = few
            }
            if let many = many {
                dict["\(key)_many"] = many
            }
            dict["\(key)_other"] = other
        }
    }
    return dict
}

func applyUILocalization(_ settings: LocalizationSettings) {
    let primaryLanguage = Language(languageCode: settings.primaryComponent.languageCode, customPluralizationCode: settings.primaryComponent.customPluralizationCode, strings: dictFromLocalization(settings.primaryComponent.localization))
    let secondaryLanguage = settings.secondaryComponent != nil ? Language.init(languageCode: settings.secondaryComponent!.languageCode, customPluralizationCode: settings.secondaryComponent!.customPluralizationCode, strings: dictFromLocalization(settings.secondaryComponent!.localization)) : nil

    let language = TelegramLocalization(primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage, localizedName: settings.primaryComponent.localizedName)
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
    applyMainMenuLocalization(mainWindow)
}

func applyShareUILocalization(_ settings: LocalizationSettings) {
    let primaryLanguage = Language(languageCode: settings.primaryComponent.languageCode, customPluralizationCode: settings.primaryComponent.customPluralizationCode, strings: dictFromLocalization(settings.primaryComponent.localization))
    let secondaryLanguage = settings.secondaryComponent != nil ? Language.init(languageCode: settings.secondaryComponent!.languageCode, customPluralizationCode: settings.secondaryComponent!.customPluralizationCode, strings: dictFromLocalization(settings.secondaryComponent!.localization)) : nil
    
    let language = TelegramLocalization(primaryLanguage: primaryLanguage, secondaryLanguage: secondaryLanguage, localizedName: settings.primaryComponent.localizedName)
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
}
func dropShareLocalization() {
    let language = TelegramLocalization(primaryLanguage: Language(languageCode: "en", customPluralizationCode: nil, strings: [:]), secondaryLanguage: nil, localizedName: "English")
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
}

func dropLocalization() {

    let language = TelegramLocalization(primaryLanguage: Language(languageCode: "en", customPluralizationCode: nil, strings: [:]), secondaryLanguage: nil, localizedName: "English")
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
    applyMainMenuLocalization(mainWindow)
}

func applyMainMenuLocalization(_ window: Window) {
    if let items = window.menu?.items {
        for item in items {
            localizeMainMenuItem(item)
        }
    }
}

private func localizeMainMenuItem(_ item:NSMenuItem) {
    var title = item.title
    
    item.title = title
    item.submenu?.title = title
    if let items = item.submenu?.items {
        for item in items {
            localizeMainMenuItem(item)
        }
    }
}

class Language : Equatable {
    let languageCode:String
    let customPluralizationCode: String?
    let strings:[String: String]
    init (languageCode:String, customPluralizationCode: String?, strings:[String: String]) {
        self.languageCode = languageCode
        self.customPluralizationCode = customPluralizationCode
        self.strings = strings
    }
}

func ==(lhs:Language, rhs:Language) -> Bool {    
    return lhs === rhs
}

func translate(key: String, _ args: [CVarArg]) -> String {
    var format:String?
    var args = args
    if key.hasSuffix("_countable") {
        
        for i in 0 ..< args.count {
            if let count = args[i] as? Int {
                let code = languageCodehash(appCurrentLanguage.pluralizationCode)
                
                if let index = key.range(of: "_")?.lowerBound {
                    var string = String(key[..<index])
                    string += "_\(presentationStringsPluralizationForm(code, Int32(count)).name)"
                    format = _NSLocalizedString(string)
                    //if args.count > 1 {
                        //args.remove(at: i)
                    //}
                } else {
                    format = _NSLocalizedString(key)
                }
                break
            }
        }
        if format == nil {
            format = _NSLocalizedString(key)
        }

        
    } else {
        format = _NSLocalizedString(key)
    }
    
    if let format = format {
        let ranges = extractArgumentRanges(format)
        var formatted = format
        while ranges.count != args.count {
            args.removeFirst()
        }
        let argIndexes = ranges.sorted(by: { lhs, rhs -> Bool in
            return lhs.2 < rhs.2
        })
        
        var argValues:[String] = args.map { "\($0)" }
        
        for index in argIndexes.map ({ $0.0 }) {
            if !args.isEmpty {
                argValues[index] = "\(args.removeFirst())"
            }
        }
        
        for range in ranges.reversed() {
            if !argValues.isEmpty {
                let value = argValues.removeLast()
                formatted = formatted.nsstring.replacingCharacters(in: range.1, with: value)
            } else {
                formatted = formatted.nsstring.replacingCharacters(in: range.1, with: "")
            }
        }
        return formatted
    }
    return "UndefinedKey"
}

private let argumentRegex = try! NSRegularExpression(pattern: "(%(((\\d+)\\$)?)([0-9])%(((\\d+)\\$)?)([@df]))|(%(((\\d+)\\$)?)([@df]))", options: [])
func extractArgumentRanges(_ value: String) -> [(Int, NSRange, Int)] {
    var result: [(Int, NSRange, Int)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        let range = match.range(at: 0)
        var valueIndex = index
        if range.length >= 4, let index = Int(string.substring(with: NSMakeRange(range.location + 1, range.length - 3))) {
            valueIndex = index
        }
        result.append((index, range, valueIndex))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}

final class TelegramLocalization : Equatable {
    
    
    let primaryLanguage: Language
    let secondaryLanguage: Language?
    let baseLanguageCode: String
    let localizedName: String
    init(primaryLanguage: Language, secondaryLanguage: Language?, localizedName: String) {
        self.primaryLanguage = primaryLanguage
        self.secondaryLanguage = secondaryLanguage
        self.localizedName = localizedName
        self.baseLanguageCode = secondaryLanguage?.languageCode ?? primaryLanguage.languageCode
    }
    
    var languageCode: String {
        return baseLanguageCode
    }
    
    static func == (lhs: TelegramLocalization, rhs: TelegramLocalization) -> Bool {
        return lhs.primaryLanguage == rhs.primaryLanguage && lhs.secondaryLanguage == rhs.secondaryLanguage && lhs.baseLanguageCode == rhs.baseLanguageCode
    }
    
    var pluralizationCode: String {
        return primaryLanguage.customPluralizationCode ?? secondaryLanguage?.customPluralizationCode ?? secondaryLanguage?.languageCode ?? primaryLanguage.languageCode
    }
    
}

let _appCurrentLanguage:Atomic<TelegramLocalization> = Atomic(value: TelegramLocalization(primaryLanguage: Language(languageCode: "en", customPluralizationCode: nil, strings: [:]), secondaryLanguage: nil, localizedName: "English"))
var appCurrentLanguage:TelegramLocalization {
    return _appCurrentLanguage.modify {$0}
}
private let languagePromise:Promise<TelegramLocalization> = Promise(appCurrentLanguage)

var languageSignal:Signal<TelegramLocalization, NoError> {
    return languagePromise.get() |> distinctUntilChanged |> deliverOnMainQueue
}

public func _NSLocalizedString(_ key: String) -> String {
    
    let primary = appCurrentLanguage.primaryLanguage
    let secondary = appCurrentLanguage.secondaryLanguage

    if let value = (primary.strings[key] ?? secondary?.strings[key]), !value.isEmpty {
        return value
    } else {
        let path = Bundle.main.path(forResource: "en", ofType: "lproj")
        if let path = path, let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, comment: "")
        
    }
}

public func NativeLocalization(_ key: String) -> String {
    
    let path = Bundle.main.path(forResource: "en", ofType: "lproj")
    if let path = path, let bundle = Bundle(path: path) {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    return NSLocalizedString(key, comment: "")
}

