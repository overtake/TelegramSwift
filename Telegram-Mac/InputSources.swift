//
//  InputSources.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import SwiftSignalKit
import Foundation
import TelegramCore
import ObjcUtils
import Postbox
import InAppSettings

final class InputSources: NSObject {
    
    private let _inputSource: Promise<[String]> = Promise(["en"])
    
    var value: Signal<[String], NoError> {
        _inputSource.set(Signal { subscriber in
            subscriber.putNext(currentAppInputSource().uniqueElements)
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(.mainQueue()))
        return _inputSource.get() |> distinctUntilChanged(isEqual: { $0 == $1 })
    }
    
    func searchEmoji(postbox: Postbox, engine: TelegramEngine, sharedContext: SharedAccountContext, query: String, completeMatch: Bool, checkPrediction: Bool) -> Signal<[String], NoError> {
        return combineLatest(value, baseAppSettings(accountManager: sharedContext.accountManager)) |> mapToSignal { sources, settings in
            if settings.predictEmoji || !checkPrediction {
                return combineLatest(sources.map({ engine.stickers.searchEmojiKeywords(inputLanguageCode: $0, query: query.lowercased(), completeMatch: completeMatch) })) |> map { results in
                    let result = results.reduce([], { $0 + $1 })
                    if result.isEmpty {
                        return query.emojis
                    } else {
                        return result.reduce([], { current, value -> [String] in
                            if completeMatch {
                                if query.lowercased() == value.keyword.lowercased() {
                                    return current + value.emoticons
                                } else {
                                    return current
                                }
                            } else {
                                return current + value.emoticons
                            }
                        }).uniqueElements.map { $0.fixed }
                    }
                    
                } |> distinctUntilChanged
            } else {
                return .single([])
            }
        }
    }
    
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(inputSourceChanged), name: NSTextInputContext.keyboardSelectionDidChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func inputSourceChanged() {
        _inputSource.set(.single(currentAppInputSource().uniqueElements))
    }
}
