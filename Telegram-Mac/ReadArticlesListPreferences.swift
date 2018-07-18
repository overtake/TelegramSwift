//
//  ReadArticlesListPreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac

final class ReadArticle : PreferencesEntry, Equatable {
    static func == (lhs: ReadArticle, rhs: ReadArticle) -> Bool {
        return lhs.messageId == rhs.messageId && lhs.webPage.webpageId == rhs.webPage.webpageId && lhs.percent == rhs.percent && lhs.date == rhs.date
    }
    
    var id: MediaId {
        return webPage.webpageId
    }
    
    init(webPage: TelegramMediaWebpage, messageId: MessageId?, percent: Int32, date: Int32) {
        self.messageId = messageId
        self.webPage = webPage
        self.percent = percent
        self.date = date
    }
    let percent: Int32
    let webPage: TelegramMediaWebpage
    let messageId: MessageId?
    let date: Int32
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ReadArticle {
            return to == self
        } else {
            return false
        }
    }
    
    init(decoder: PostboxDecoder) {
        if let messageIdPeerId = decoder.decodeOptionalInt64ForKey("m.p"), let messageIdNamespace = decoder.decodeOptionalInt32ForKey("m.n"), let messageIdId = decoder.decodeOptionalInt32ForKey("m.i") {
            self.messageId = MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId)
        } else {
            self.messageId = nil
        }
        self.webPage = decoder.decodeObjectForKey("wp", decoder: {TelegramMediaWebpage(decoder: $0)}) as! TelegramMediaWebpage
        self.percent = decoder.decodeInt32ForKey("p", orElse: 0)
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let messageId = messageId {
            encoder.encodeInt64(messageId.peerId.toInt64(), forKey: "m.p")
            encoder.encodeInt32(messageId.namespace, forKey: "m.n")
            encoder.encodeInt32(messageId.id, forKey: "m.i")
        } else {
            encoder.encodeNil(forKey: "m.p")
            encoder.encodeNil(forKey: "m.n")
            encoder.encodeNil(forKey: "m.i")
        }
        encoder.encodeObject(webPage, forKey: "wp")
        encoder.encodeInt32(percent, forKey: "p")
        encoder.encodeInt32(date, forKey: "d")
    }
    
    func withUpdatedPercent(_ percent: Int32, force: Bool = false) -> ReadArticle {
        return ReadArticle(webPage: webPage, messageId: messageId, percent: force ? percent : min(max(percent, self.percent), 100), date: force && percent == 100 ? Int32(Date().timeIntervalSince1970) : self.date)
    }
    
    
}

class ReadArticlesListPreferences: PreferencesEntry, Equatable {
    
    
    let list: [ReadArticle]
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ReadArticlesListPreferences {
            return self == to
        } else {
            return false
        }
    }
    
    init(list: [ReadArticle] = []) {
        self.list = list
    }
    
    static func == (lhs: ReadArticlesListPreferences, rhs: ReadArticlesListPreferences) -> Bool {
        return lhs.list == rhs.list
    }
    
    required init(decoder: PostboxDecoder) {
        self.list = decoder.decodeObjectArrayForKey("l")
    }
    
    func withAddedArticle(_ article: ReadArticle) -> ReadArticlesListPreferences {
        var list = self.list
        
        if let index = list.firstIndex(where: {$0.id == article.id}) {
            list.remove(at: index)
            list.insert(article, at: 0)
        } else {
            list.insert(article, at: 0)
        }
        return ReadArticlesListPreferences(list: list)
    }
    
    func withReadAll() -> ReadArticlesListPreferences {
        var list = self.list
        for i in 0 ..< list.count {
            list[i] = list[i].withUpdatedPercent(100)
        }
        return ReadArticlesListPreferences(list: list)
    }
    
    func withRemovedAll() -> ReadArticlesListPreferences {
        return ReadArticlesListPreferences(list: [])
    }
    
    func withUpdatedArticle(_ article: ReadArticle) -> ReadArticlesListPreferences {
        var list = self.list
        
        if let index = list.firstIndex(where: {$0.id == article.id}) {
            list[index] = article
        }
        return ReadArticlesListPreferences(list: list)
    }

    var unreadList: [ReadArticle] {
        return list.filter({$0.percent < 100})
    }
    
    func withRemovedArticles(_ article: ReadArticle) -> ReadArticlesListPreferences {
        var list = self.list
        list.removeAll(where: {$0.id == article.id})
        return ReadArticlesListPreferences(list: list)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.list, forKey: "l")
    }
    
    
    static var defaultSettings: ReadArticlesListPreferences {
        return ReadArticlesListPreferences()
    }

}


func readArticlesListPreferences(_ postbox: Postbox) -> Signal<ReadArticlesListPreferences, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.readArticles]) |> map { preferences in
        return (preferences.values[ApplicationSpecificPreferencesKeys.readArticles] as? ReadArticlesListPreferences) ?? ReadArticlesListPreferences.defaultSettings
    }
}

func updateReadArticlesPreferences(postbox: Postbox, _ f:@escaping(ReadArticlesListPreferences)->ReadArticlesListPreferences) -> Signal<Void, Void> {
    
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.readArticles, { entry in
            let currentSettings: ReadArticlesListPreferences
            if let entry = entry as? ReadArticlesListPreferences {
                currentSettings = entry
            } else {
                currentSettings = ReadArticlesListPreferences.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
