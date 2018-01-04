//
//  LocalizableExtension.swift
//  Telegram
//
//  Created by keepcoder on 25/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit

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
    let language = Language(languageCode: settings.languageCode, strings: dictFromLocalization(settings.localization))
    #if !APP_STORE
       // SULocalizationWrapper.setLanguageCode(settings.languageCode)
    #endif
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
    applyMainMenuLocalization(mainWindow)
}

func applyShareUILocalization(_ settings: LocalizationSettings) {
    let language = Language(languageCode: settings.languageCode, strings: dictFromLocalization(settings.localization))
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
}
func dropShareLocalization() {
    let language = Language(languageCode: "en", strings: [:])
    _ = _appCurrentLanguage.swap(language)
    languagePromise.set(.single(language))
}

func dropLocalization() {
    #if !APP_STORE
       // SULocalizationWrapper.setLanguageCode("en")
    #endif
    let language = Language(languageCode: "en", strings: [:])
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
    let strings:[String: String]
    init (languageCode:String, strings:[String: String]) {
        self.languageCode = languageCode
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
                let code = languageCodehash(appCurrentLanguage.languageCode)
                
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
        for range in ranges.reversed() {
            if range.0 < args.count {
                let value = "\(args[range.0])"
                formatted = formatted.nsstring.replacingCharacters(in: range.1, with: value)
            } else {
                formatted = formatted.nsstring.replacingCharacters(in: range.1, with: "")
            }
        }
        return formatted
    }
    return "UndefinedKey"
}

private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\\\d+)\\\\$)?)([@df])", options: [])
func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}



let _appCurrentLanguage:Atomic<Language> = Atomic(value: Language(languageCode: "en", strings: [:]))
var appCurrentLanguage:Language {
    return _appCurrentLanguage.modify({$0})
}
let languagePromise:Promise<Language> = Promise(Language(languageCode: "en", strings: [:]))

var languageSignal:Signal<Language, Void> {
    return languagePromise.get() |> distinctUntilChanged |> deliverOnMainQueue
}

public func _NSLocalizedString(_ key: String) -> String {
    
    let language = appCurrentLanguage
    
    if let value = language.strings[key], !value.isEmpty {
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

