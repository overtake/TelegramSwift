import SwiftSignalKit
import NaturalLanguage
import AppKit


private extension String {
    func replacingOccurrences(with: String, of: String) -> String {
        return self.replacingOccurrences(of: of, with: with)
    }
}

private func escape(with link:String) -> String {
    var escaped = link
    escaped = escaped.replacingOccurrences(with: "%21", of: "!")
    escaped = escaped.replacingOccurrences(with: "%24", of: "$")
    escaped = escaped.replacingOccurrences(with: "%26", of: "&")
    escaped = escaped.replacingOccurrences(with: "%2B", of: "+")
    escaped = escaped.replacingOccurrences(with: "%2C", of: ",")
    escaped = escaped.replacingOccurrences(with: "%2F", of: "/")
    escaped = escaped.replacingOccurrences(with: "%3A", of: ":")
    escaped = escaped.replacingOccurrences(with: "%3B", of: ";")
    escaped = escaped.replacingOccurrences(with: "%3D", of: "=")
    escaped = escaped.replacingOccurrences(with: "%3F", of: "?")
    escaped = escaped.replacingOccurrences(with: "%40", of: "@")
    escaped = escaped.replacingOccurrences(with: "%20", of: " ")
    escaped = escaped.replacingOccurrences(with: "%09", of: "\t")
    escaped = escaped.replacingOccurrences(with: "%23", of: "#")
    escaped = escaped.replacingOccurrences(with: "%3C", of: "<")
    escaped = escaped.replacingOccurrences(with: "%3E", of: ">")
    escaped = escaped.replacingOccurrences(with: "%22", of: "\"")
    escaped = escaped.replacingOccurrences(with: "%0A", of: "\n")
    escaped = escaped.replacingOccurrences(with: "%2E", of: ".")
    escaped = escaped.replacingOccurrences(with: "%2C", of: ",")
    escaped = escaped.replacingOccurrences(with: "%7D", of: "}")
    escaped = escaped.replacingOccurrences(with: "%7B", of: "{")
    escaped = escaped.replacingOccurrences(with: "%5B", of: "[")
    escaped = escaped.replacingOccurrences(with: "%5D", of: "]")
    return escaped
}

@available(macOS 10.14, *)
public struct Translate {
    
    public enum Error {
        case generic
    }
    
    public static var supportedTranslationLanguages = [
        "en",
        "ar",
        "zh",
        "fr",
        "de",
        "it",
        "jp",
        "ko",
        "pt",
        "ru",
        "es"
    ]
    
    public static var languagesEmojies:[String:String] = [
        "en":"🏴󠁧󠁢󠁥󠁮󠁧󠁿",
        "ar":"🇦🇷",
        "zh":"🇨🇳",
        "fr":"🇫🇷",
        "de":"🇩🇪",
        "it":"🇮🇹",
        "jp":"🇯🇵",
        "ko":"🇰🇷",
        "pt":"🇵🇹",
        "ru":"🇷🇺",
        "es":"🇪🇸"
    ]
    
    
    private static let userAgents: [String] = [
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36", // 13.5%
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36", // 6.6%
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0", // 6.4%
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:95.0) Gecko/20100101 Firefox/95.0", // 6.2%
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.93 Safari/537.36", // 5.2%
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36" // 4.8%
        ]
    
    public static func detectLanguage(for text: String) -> String? {
        let text = String(text.prefix(64))
        languageRecognizer.processString(text)
        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
        languageRecognizer.reset()
        
        if let value = hypotheses.sorted(by: { $0.value > $1.value }).first?.key.rawValue {
            if supportedTranslationLanguages.contains(value) {
                return value
            }
        }
        return nil
    }

    private static let languageRecognizer = NLLanguageRecognizer()
    public static func canTranslateText(baseLanguageCode: String, text: String, ignoredLanguages: [String]?) -> Bool {
        
        guard text.count > 0 else {
            return false
        }
        var dontTranslateLanguages: [String] = []
        if let ignoredLanguages = ignoredLanguages {
            dontTranslateLanguages = ignoredLanguages
        } else {
            dontTranslateLanguages = [baseLanguageCode]
        }
        
        let text = String(text.prefix(64))
        languageRecognizer.processString(text)
        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
        languageRecognizer.reset()
        
        let filteredLanguages = hypotheses.filter { supportedTranslationLanguages.contains($0.key.rawValue) }.sorted(by: { $0.value > $1.value })
        if let language = filteredLanguages.first(where: { supportedTranslationLanguages.contains($0.key.rawValue) }) {
            return !dontTranslateLanguages.contains(language.key.rawValue)
        } else {
            return false
        }
    }

    public static func translateText(text: String, from: String?, to: String) -> Signal<String, Error> {
        return Signal { subscriber in
            
            
            var uri = "https://translate.goo";
            uri += "gleapis.com/transl";
            uri += "ate_a";
            uri += "/singl";
            uri += "e?client=gtx&sl=" + (from ?? "auto") + "&tl=" + to + "&dt=t" + "&ie=UTF-8&oe=UTF-8&otf=1&ssel=0&tsel=0&kc=7&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&q=";
            uri += text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            
            var request = URLRequest(url: URL(string: uri)!)
            request.httpMethod = "GET"
            request.setValue(userAgents[Int.random(in: 0 ..< userAgents.count)], forHTTPHeaderField: "User-Agent")
            let session = URLSession.shared
            let task = session.dataTask(with: request, completionHandler: { data, response, error in
                if let _ = error {
                    subscriber.putError(.generic)
                } else if let data = data {
                    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSArray
                    if let json = json, json.count > 0 {
                        let array = json[0] as? NSArray ?? NSArray()
                        var result: String = ""
                        for i in 0 ..< array.count {
                            let blockText = array[i] as? NSArray
                            if let blockText = blockText, blockText.count > 0 {
                                let value = blockText[0] as? String
                                if let value = value, value != "null" {
                                    result += value
                                }
                            }
                        }
                        subscriber.putNext(result)
                    } else {
                        if let string = String(data: data, encoding: .utf8) {
                            print(string)
                            var bp = 0
                            bp += 1
                        }
                        subscriber.putError(.generic)
                    }
                }
            })
            task.resume()
            
            return ActionDisposable {
                task.cancel()
            }
        }
    }

}
