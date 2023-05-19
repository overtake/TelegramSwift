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

public struct Translate {
    
    public enum Error {
        case generic
    }
    
    public struct Value {
        public let language: String
        public let code: [String]
        public let emoji: String?
    }
    
    public static func find(_ code: String) -> Value? {
        return self.codes.first(where: {
            return $0.code.contains(code)
        })
    }
    
    public static var codes: [Value] {
        var values: [Value] = []
        values.append(.init(language: "Afrikaans", code: ["af"], emoji: nil))
        values.append(.init(language: "Albanian", code: ["sq"], emoji: nil))
        values.append(.init(language: "Amharic", code: ["am"], emoji: nil))
        values.append(.init(language: "Arabic", code: ["ar"], emoji: nil))
        values.append(.init(language: "Armenian", code: ["hy"], emoji: nil))
        values.append(.init(language: "Azerbaijani", code: ["az"], emoji: nil))
        values.append(.init(language: "Basque", code: ["eu"], emoji: nil))
        values.append(.init(language: "Belarusian", code: ["be"], emoji: nil))
        values.append(.init(language: "Bengali", code: ["bn"], emoji: nil))
        values.append(.init(language: "Bosnian", code: ["bs"], emoji: nil))
        values.append(.init(language: "Bulgarian", code: ["bg"], emoji: nil))
        values.append(.init(language: "Catalan", code: ["ca"], emoji: nil))
        values.append(.init(language: "Cebuano", code: ["ceb"], emoji: nil))
        values.append(.init(language: "Chinese (Simplified)", code: ["zh-CN", "zh"], emoji: nil))
        values.append(.init(language: "Chinese (Traditional)", code: ["zh-TW"], emoji: nil))
        values.append(.init(language: "Corsican", code: ["co"], emoji: nil))
        values.append(.init(language: "Croatian", code: ["hr"], emoji: nil))
        values.append(.init(language: "Czech", code: ["cs"], emoji: nil))
        values.append(.init(language: "Danish", code: ["da"], emoji: nil))
        values.append(.init(language: "Dutch", code: ["nl"], emoji: nil))
        values.append(.init(language: "English", code: ["en"], emoji: nil))
        values.append(.init(language: "Esperanto", code: ["eo"], emoji: nil))
        values.append(.init(language: "Estonian", code: ["et"], emoji: nil))
        values.append(.init(language: "Finnish", code: ["fi"], emoji: nil))
        values.append(.init(language: "French", code: ["fr"], emoji: nil))
        values.append(.init(language: "Frisian", code: ["fy"], emoji: nil))
        values.append(.init(language: "Galician", code: ["gl"], emoji: nil))
        values.append(.init(language: "Georgian", code: ["ka"], emoji: nil))
        values.append(.init(language: "German", code: ["de"], emoji: nil))
        values.append(.init(language: "Greek", code: ["el"], emoji: nil))
        values.append(.init(language: "Gujarati", code: ["gu"], emoji: nil))
        values.append(.init(language: "Haitian Creole", code: ["ht"], emoji: nil))
        values.append(.init(language: "Hausa", code: ["ha"], emoji: nil))
        values.append(.init(language: "Hawaiian", code: ["haw"], emoji: nil))
        values.append(.init(language: "Hebrew", code: ["he", "iw"], emoji: nil))
        values.append(.init(language: "Hindi", code: ["hi"], emoji: nil))
        values.append(.init(language: "Hmong", code: ["hmn"], emoji: nil))
        values.append(.init(language: "Hungarian", code: ["hu"], emoji: nil))
        values.append(.init(language: "Icelandic", code: ["is"], emoji: nil))
        values.append(.init(language: "Igbo", code: ["ig"], emoji: nil))
        values.append(.init(language: "Indonesian", code: ["id"], emoji: nil))
        values.append(.init(language: "Irish", code: ["ga"], emoji: nil))
        values.append(.init(language: "Italian", code: ["it"], emoji: nil))
        values.append(.init(language: "Japanese", code: ["ja"], emoji: nil))
        values.append(.init(language: "Javanese", code: ["jv"], emoji: nil))
        values.append(.init(language: "Kannada", code: ["kn"], emoji: nil))
        values.append(.init(language: "Kazakh", code: ["kk"], emoji: nil))
        values.append(.init(language: "Khmer", code: ["km"], emoji: nil))
        values.append(.init(language: "Kinyarwanda", code: ["rw"], emoji: nil))
        values.append(.init(language: "Korean", code: ["ko"], emoji: nil))
        values.append(.init(language: "Kurdish", code: ["ku"], emoji: nil))
        values.append(.init(language: "Kyrgyz", code: ["ky"], emoji: nil))
        values.append(.init(language: "Lao", code: ["lo"], emoji: nil))
        values.append(.init(language: "Latvian", code: ["lv"], emoji: nil))
        values.append(.init(language: "Lithuanian", code: ["lt"], emoji: nil))
        values.append(.init(language: "Luxembourgish", code: ["lb"], emoji: nil))
        values.append(.init(language: "Macedonian", code: ["mk"], emoji: nil))
        values.append(.init(language: "Malagasy", code: ["mg"], emoji: nil))
        values.append(.init(language: "Malay", code: ["ms"], emoji: nil))
        values.append(.init(language: "Malayalam", code: ["ml"], emoji: nil))
        values.append(.init(language: "Maltese", code: ["mt"], emoji: nil))
        values.append(.init(language: "Maori", code: ["mi"], emoji: nil))
        values.append(.init(language: "Marathi", code: ["mr"], emoji: nil))
        values.append(.init(language: "Mongolian", code: ["mn"], emoji: nil))
        values.append(.init(language: "Myanmar (Burmese)", code: ["my"], emoji: nil))
        values.append(.init(language: "Nepali", code: ["ne"], emoji: nil))
        values.append(.init(language: "Norwegian", code: ["no"], emoji: nil))
        values.append(.init(language: "Nyanja (Chichewa)", code: ["ny"], emoji: nil))
        values.append(.init(language: "Odia (Oriya)", code: ["or"], emoji: nil))
        values.append(.init(language: "Pashto", code: ["ps"], emoji: nil))
        values.append(.init(language: "Persian", code: ["fa"], emoji: nil))
        values.append(.init(language: "Polish", code: ["pl"], emoji: nil))
        values.append(.init(language: "Portuguese (Portugal, Brazil)", code: ["pt"], emoji: nil))
        values.append(.init(language: "Punjabi", code: ["pa"], emoji: nil))
        values.append(.init(language: "Romanian", code: ["ro"], emoji: nil))
        values.append(.init(language: "Russian", code: ["ru"], emoji: nil))
        values.append(.init(language: "Samoan", code: ["sm"], emoji: nil))
        values.append(.init(language: "Scots Gaelic", code: ["gd"], emoji: nil))
        values.append(.init(language: "Serbian", code: ["sr"], emoji: nil))
        values.append(.init(language: "Sesotho", code: ["st"], emoji: nil))
        values.append(.init(language: "Shona", code: ["sn"], emoji: nil))
        values.append(.init(language: "Sindhi", code: ["sd"], emoji: nil))
        values.append(.init(language: "Sinhala (Sinhalese)", code: ["si"], emoji: nil))
        values.append(.init(language: "Slovak", code: ["sk"], emoji: nil))
        values.append(.init(language: "Slovenian", code: ["sl"], emoji: nil))
        values.append(.init(language: "Somali", code: ["so"], emoji: nil))
        values.append(.init(language: "Spanish", code: ["es"], emoji: nil))
        values.append(.init(language: "Sundanese", code: ["su"], emoji: nil))
        values.append(.init(language: "Swahili", code: ["sw"], emoji: nil))
        values.append(.init(language: "Swedish", code: ["sv"], emoji: nil))
        values.append(.init(language: "Tagalog (Filipino)", code: ["tl"], emoji: nil))
        values.append(.init(language: "Tajik", code: ["tg"], emoji: nil))
        values.append(.init(language: "Tamil", code: ["ta"], emoji: nil))
        values.append(.init(language: "Tatar", code: ["tt"], emoji: nil))
        values.append(.init(language: "Telugu", code: ["te"], emoji: nil))
        values.append(.init(language: "Thai", code: ["th"], emoji: nil))
        values.append(.init(language: "Turkish", code: ["tr"], emoji: nil))
        values.append(.init(language: "Turkmen", code: ["tk"], emoji: nil))
        values.append(.init(language: "Ukrainian", code: ["uk"], emoji: nil))
        values.append(.init(language: "Urdu", code: ["ur"], emoji: nil))
        values.append(.init(language: "Uyghur", code: ["ug"], emoji: nil))
        values.append(.init(language: "Uzbek", code: ["uz"], emoji: nil))
        values.append(.init(language: "Vietnamese", code: ["vi"], emoji: nil))
        values.append(.init(language: "Welsh", code: ["cy"], emoji: nil))
        values.append(.init(language: "Xhosa", code: ["xh"], emoji: nil))
        values.append(.init(language: "Yiddish", code: ["yi"], emoji: nil))
        values.append(.init(language: "Yoruba", code: ["yo"], emoji: nil))
        values.append(.init(language: "Zulu", code: ["zu"], emoji: nil))

        return values
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
    
    @available(macOS 10.14, *)
    private static let languageRecognizer = NLLanguageRecognizer()

    public static func detectLanguage(for text: String) -> String? {
        let text = String(text.prefix(64))
        if #available(macOS 10.14, *) {
            languageRecognizer.processString(text)
            let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
            languageRecognizer.reset()
            if let value = hypotheses.sorted(by: { $0.value > $1.value }).first?.key.rawValue {
                return value
            }
        }
        
        return nil
    }

    public static func translateText(text: String, from: String?, to: String) -> Signal<(detect: String?, result: String), Error> {
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
                        subscriber.putNext((detect: json[2] as? String, result: result))
                    } else {
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
