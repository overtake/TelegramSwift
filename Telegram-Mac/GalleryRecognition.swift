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

final class GalleryRecognition {
    private let item: MGalleryPhotoItem
    private let disposable = MetaDisposable()
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
            let mediaId = item.entry.message?.media.first?.id
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
    }
    @available(macOS 10.15, *)
    private func applyResult(_ result: TextRecognizing.Result?) {
        self.selectorView.set(result)
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
