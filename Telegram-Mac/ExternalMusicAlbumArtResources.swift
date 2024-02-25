//
//  ExternalMusicAlbumArtResources.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

import Foundation
import TelegramCore

import SwiftSignalKit
import Postbox

private func urlEncodedStringFromString(_ string: String) -> String {
    var nsString: NSString = string as NSString
    if let value = nsString.replacingPercentEscapes(using: String.Encoding.utf8.rawValue) {
        nsString = value as NSString
    }
    
    let result = CFURLCreateStringByAddingPercentEscapes(nil, nsString as CFString, nil, "?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ " as CFString, CFStringConvertNSStringEncodingToEncoding(String.Encoding.utf8.rawValue))!
    return result as String
}

func fetchExternalMusicAlbumArtResource(resource: ExternalMusicAlbumArtResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        if resource.performer.isEmpty || resource.performer.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "unknown artist" || resource.title.isEmpty {
            subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
            subscriber.putCompletion()
            return EmptyDisposable
        } else {
            let excludeWords: [String] = [
                " vs. ",
                " vs ",
                " versus ",
                " ft. ",
                " ft ",
                " featuring ",
                " feat. ",
                " feat ",
                " presents ",
                " pres. ",
                " pres ",
                " and ",
                " & ",
                " . "
            ]
            
            var performer = resource.performer
            
            for word in excludeWords {
                performer = performer.replacingOccurrences(of: word, with: " ")
            }
            
            let metaUrl = "https://itunes.apple.com/search?term=\(urlEncodedStringFromString("\(performer) \(resource.title)"))&entity=song&limit=4"
            
            let fetchDisposable = MetaDisposable()
            
            let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
                if case let .dataPart(_, data, _, complete) = result, complete {
                    guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard let results = dict["results"] as? [Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard let result = results.first as? [String: Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard var artworkUrl = result["artworkUrl100"] as? String else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    if !resource.isThumbnail {
                        artworkUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                    }
                    
                    if artworkUrl.isEmpty {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    } else {
                        fetchDisposable.set(fetchHttpResource(url: artworkUrl).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        }))
                    }
                }
            })
            
            return ActionDisposable {
                disposable.dispose()
                fetchDisposable.dispose()
            }
        }
    }
}
