//
//  GalleryRecognition.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.11.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TextRecognizing
import SwiftSignalKit
import TelegramCore
import Postbox
import Translate

final class GalleryRecognition {
    private let item: MGalleryPhotoItem
    private let disposable = MetaDisposable()
    private let translateDisposable = MetaDisposable()
    
    private var result: AnyObject?
    private var translation: AnyObject?
    
    let view:NSView
    init?(_ item: MGalleryItem) {
        if let item = item as? MGalleryPhotoItem {
            if let message = item.entry.message, message.isCopyProtected() {
                return nil
            }
            self.item = item
            if #available(macOS 10.15, *) {
                self.view = TextRecognizing.ImageTextSelector(frame: .zero)
            } else {
                return nil
            }
        } else {
            return nil
        }
        if #available(macOS 10.15, *) {
            let postbox = item.context.account.postbox
            let mediaId = item.entry.mediaId
            let image: Signal<TextRecognizing.Result?, TextRecognizing.Error> = combineLatest(item.image.get(), item.magnify.get(), item.appearValue) |> castError(TextRecognizing.Error.self) |> mapToSignal { image, magnify, visible in
                if magnify == 1, visible {
                    switch image.value {
                    case let .image(image, _):
                        if let image = image {
                            return TextRecognizing.recognize(image._cgImage!, postbox: postbox, stableId: mediaId) |> map(Optional.init)
                        } else {
                            return .single(nil)
                        }
                    default:
                        return .single(nil)
                    }
                } else {
                    return .single(nil)
                }
               
            } |> deliverOnMainQueue
            
            disposable.set(image.start(next: { [weak self] result in
                self?.applyResult(result)
            }))
        }
    }
    deinit {
        disposable.dispose()
        translateDisposable.dispose()
    }
    @available(macOS 10.15, *)
    func canTranslate() -> Bool {
        guard let result = result as? TextRecognizing.Result else {
            return false
        }
        
        switch result {
        case let .finish(_, text):
            let text = text.map { $0.text }.joined(separator: "\n")
            let fromLang = Translate.detectLanguage(for: text)
            let toLang = item.context.sharedContext.baseSettings.doNotTranslate.union([appAppearance.languageCode])
            
            if fromLang == nil || !toLang.contains(fromLang!) {
                return true
            }
        default:
            break
        }
        
        return false
        
    }
    
    @available(macOS 10.15, *)
    func toggleTranslate(to: String) {
        
        if let result = result as? TextRecognizing.Result {
            guard translation == nil else {
                self.applyResult(result)
                return
            }
            
            switch result {
            case let .finish(image, text):
                var entities: [MessageTextEntity] = []
                var length = 0
                var currentText: String = ""
                let toLang = appAppearance.languageCode
                for text in text {
                    entities.append(.init(range: length ..< length + text.text.length, type: .BlockQuote(isCollapsed: false)))
                    currentText += text.text
                    length += text.text.length
                }
                
                let signal:Signal<(result: String, entities: [MessageTextEntity])?, TranslationError>
                signal = item.context.engine.messages.translate(text: currentText, toLang: toLang, entities: entities) |> mapToSignal { value in
                    if let value = value {
                        return .single((result: value.0, entities: value.1.filter { value in
                            switch value.type {
                            case .BlockQuote:
                                return true
                            default:
                                return false
                            }
                        }))
                    } else {
                        return .single(nil)
                    }
                } |> deliverOnMainQueue
                
                translateDisposable.set(signal.startStrict(next: { [weak self] translated in
                    var texts: [TextRecognizing.TranslateResult.Value] = []
                    var toRemove: [Int] = []
                    var filtered = text
                    if let result = translated {
                        for (i, entity) in result.1.enumerated() {
                            let t = result.0.nsstring.substring(with: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                            let onlyText = !text[i].text.trimmingCharacters(in: CharacterSet.decimalDigits).isEmpty
                            if text[i].text != t, onlyText {
                                texts.append(.init(text: t, detected: text[i]))
                            } else {
                                toRemove.append(i)
                            }
                        }
                    }
                    for idx in toRemove.reversed() {
                        filtered.remove(at: idx)
                    }
                    if translated == nil || translated?.result.isEmpty == true || translated?.1.isEmpty == true {
                        self?.applyResult(result, translate: nil)
                        return
                    } else {
                        self?.applyResult(result, translate: .success(translated: texts, original: .finish(image: image, text: filtered)))
                    }
                }, error: { [weak self] _ in
                    self?.applyResult(result)
                }))
            default:
                break
            }
            self.applyResult(result, translate: .progress(result))
        }
    }
    
    @available(macOS 10.15, *)
    func hideTranslate() {
        if let result = result as? TextRecognizing.Result {
            self.applyResult(result)
        }
    }
    
    func hasTranslation() -> Bool {
        return translation != nil
    }
    
    
    @available(macOS 10.15, *)
    private func applyResult(_ result: TextRecognizing.Result?, translate: TextRecognizing.TranslateResult? = nil) {
        self.result = result as AnyObject?
        self.translation = translate as AnyObject?
        
        self.selectorView.set(result, translate: translate)
        
        if translate == nil {
            self.translateDisposable.set(nil)
        }
    }
    
    @available(macOS 10.15, *)
    private var selectorView: TextRecognizing.ImageTextSelector {
        return self.view as! TextRecognizing.ImageTextSelector
    }
    
    var hasRecognition: Bool {
        if #available(macOS 10.15, *) {
            return self.selectorView.result != nil
        } else {
            return false
        }
       
    }
    var hasSelectedText: Bool {
        if #available(macOS 10.15, *) {
            return self.selectorView.hasSelectedText
        } else {
            return false
        }
    }
    func cancelSelection() {
        if #available(macOS 10.15, *) {
            self.selectorView.cancelSelection()
        }
    }
    
    func copySelectedText() -> Bool {
        if #available(macOS 10.15, *) {
            return self.selectorView.copySelectedText()
        } else {
            return false
        }
    }
    var selectedText: String? {
        if #available(macOS 10.15, *) {
            return self.selectorView.selectedText
        } else {
            return nil
        }
    }
}
