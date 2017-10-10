//
//  ChatPhotoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit
import SwiftSignalKitMac

class ChatMediaLayoutParameters : Equatable {
    
    static func layout(for media:TelegramMediaFile, isWebpage: Bool, chatInteraction:ChatInteraction) -> ChatMediaLayoutParameters {
        if media.isInstantVideo {
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Video(params):
                    duration = params.duration
                default:
                    break
                }
            }
            
            return ChatMediaVideoMessageLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, duration: duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource)
        } else if media.isVoice {
            var waveform:AudioWaveform? = nil
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Audio(params):
                    if let data = params.waveform?.makeData() {
                        waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                        duration = params.duration
                    }
                default:
                    break
                }
            }
            
            return ChatMediaVoiceLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, waveform:waveform, duration:duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource)
        } else if media.isMusic {
            var audioTitle:String?
            var audioPerformer:String?
            
            var duration:Int = 0
            for attribute in media.attributes {
                if case let .Audio(_, d, title, performer, _) = attribute {
                    duration = d
                    audioTitle = title
                    audioPerformer = performer
                    break
                }
            }
            
            let attr = NSMutableAttributedString()
            
            
            if let _audioTitle = audioTitle, let audioPerformer = audioPerformer {
                if _audioTitle.isEmpty && audioPerformer.isEmpty {
                    _ = attr.append(string: media.fileName, color: theme.colors.text, font: NSFont.normal(.title))
                    audioTitle = media.fileName
                } else {
                    _ = attr.append(string: _audioTitle + " - " + audioPerformer, color: theme.colors.text, font: NSFont.normal(.title))
                }
            } else {
                _ = attr.append(string: media.fileName, color: theme.colors.text, font: NSFont.normal(.title))
                audioTitle = media.fileName
            }
            
            return ChatMediaMusicLayoutParameters(nameLayout: TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .middle), durationLayout: TextViewLayout(.initialize(string: String.durationTransformed(elapsed: duration), color: theme.colors.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .middle), sizeLayout: TextViewLayout(.initialize(string: (media.size ?? 0).prettyNumber, color: theme.colors.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .middle), resource: media.resource, isWebpage: isWebpage, title: audioTitle, performer: audioPerformer, showPlayer:chatInteraction.inlineAudioPlayer)
        } else {
            var fileName:String = "Unknown.file"
            if let name = media.fileName {
                fileName = name
            }
            return  ChatFileLayoutParameters(fileName: fileName, hasThumb: !media.previewRepresentations.isEmpty)
        }
    }
    
}

class ChatMediaGalleryParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool
    let showMedia:()->Void
    let showMessage:(Message)->Void
    init(showMedia:@escaping()->Void, showMessage:@escaping(Message)->Void, isWebpage: Bool) {
        self.showMedia = showMedia
        self.showMessage = showMessage
        self.isWebpage = isWebpage
    }
}

func ==(lhs:ChatMediaLayoutParameters, rhs:ChatMediaLayoutParameters) -> Bool {
    return false
}


class ChatMediaItem: ChatRowItem {

    var _media:Media
    var media:Media {
        if let _media = _media as? TelegramMediaGame {
            if let file = _media.file {
                return file
            } else if let image = _media.image {
                return image
            }
        }
        return _media
    }
    
    var parameters:ChatMediaLayoutParameters?
    
    let gameTitleLayout:TextViewLayout?
    
    
    override var topInset:CGFloat {
        return 4
    }
    
    
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        
        if case let .MessageEntry(message,_,_,_,_) = object {
            _media = message.media[0]
            
            if let media = _media as? TelegramMediaGame {
                gameTitleLayout = TextViewLayout(.initialize(string: media.name, color: theme.colors.blueText, font: .medium(.text)))
            } else {
                gameTitleLayout = nil
            }
            
        } else {
            fatalError("no media for message")
        }
        
        super.init(initialSize, chatInteraction, account, object)
        
        
        if let message = message, !message.text.isEmpty {
            var caption:NSMutableAttributedString = NSMutableAttributedString()
            NSAttributedString.initialize()
            _ = caption.append(string: message.text, color: theme.colors.text, font: NSFont.normal(.custom(theme.fontSize)))
            var types:ParsingType = [.Links, .Mentions, .Hashtags]
            
            if let peer = messageMainPeer(message) as? TelegramUser {
                if peer.botInfo != nil {
                    types.insert(.Commands)
                }
            } else if let peer = messageMainPeer(message) as? TelegramChannel {
                switch peer.info {
                case .group:
                    types.insert(.Commands)
                default:
                    break
                }
            } else {
                types.insert(.Commands)
            }
            
            var hasEntities: Bool = false
            for attr in message.attributes {
                if attr is TextEntitiesMessageAttribute {
                    hasEntities = true
                    break
                }
            }
            if hasEntities {
                caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.forceSendMessage, hashtag:chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy).mutableCopy() as! NSMutableAttributedString
            }
            caption.detectLinks(type: types, account: account, openInfo:chatInteraction.openInfo, hashtag: chatInteraction.modalSearch, command: chatInteraction.forceSendMessage)
            captionLayout = TextViewLayout(caption, alignment: .left)
            captionLayout?.interactions = globalLinkExecutor

        }
        self.parameters = ChatMediaGalleryParameters(showMedia: {
            
        }, showMessage: { [weak self] message in
            self?.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, animated: true, focus: true, inset: 0))
        }, isWebpage: chatInteraction.isLogInteraction)

    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        gameTitleLayout?.measure(width: width)
        if let gameTitleLayout = gameTitleLayout {
            var contentSize = ChatLayoutUtils.contentSize(for: media, with: width)
            contentSize.height += gameTitleLayout.layoutSize.height + 6
            return contentSize
        } else {
            return ChatLayoutUtils.contentSize(for: media, with: width)
        }
    }
    
    override func menuItems() -> Signal<[ContextMenuItem], Void> {
        
        if self.chatInteraction.isLogInteraction {
            return .single([])
        }
        
        let signal = super.menuItems()
        if let account = account {
            if let file = self.media as? TelegramMediaFile {
                return signal |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                    var items = items
                    return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> mapToSignal { data in
                        if data.complete {
                            items.append(ContextMenuItem(tr(.contextCopyMedia), handler: {
                                saveAs(file, account: account)
                            }))
                        }
                        
                        if file.isSticker, let fileId = file.id {
                            return account.postbox.modify { modifier -> [ContextMenuItem] in
                                let saved = getIsStickerSaved(modifier: modifier, fileId: fileId)
                                items.append(ContextMenuItem( !saved ? tr(.chatContextAddFavoriteSticker) : tr(.chatContextRemoveFavoriteSticker), handler: {
                                    
                                    if !saved {
                                       _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                                    } else {
                                        _ = removeSavedSticker(postbox: account.postbox, mediaId: fileId).start()
                                    }
                                }))
                                
                                return items
                            }
                        }
                        
                        return .single(items)
                    }
                }
            } else if let image = self.media as? TelegramMediaImage {

                return signal |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                    var items = items
                    if let resource = image.representations.last?.resource {
                        return account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue |> map { data in
                            if data.complete {
                                items.append(ContextMenuItem(tr(.galleryContextCopyToClipboard), handler: {
                                    if let path = link(path: data.path, ext: "jpg") {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.writeObjects([NSURL(fileURLWithPath: path)])
                                    }
                                }))
                                items.append(ContextMenuItem(tr(.contextCopyMedia), handler: {
                                    savePanel(file: data.path, ext: "jpg", for: mainWindow)
                                }))
                            }
                            return items
                        }
                    } else {
                        return .single(items)
                    }
                }
            }
            
        }
        
        return signal
    }
    
    override var identifier: String {
        return super.identifier + "\(stableId)"
    }
   
    public func contentNode() -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        if _media is TelegramMediaGame {
            return ChatMediaGameView.self
        } else {
            return ChatMediaView.self
        }
    }
    
}
