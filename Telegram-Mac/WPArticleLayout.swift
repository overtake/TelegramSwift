//
//  WPArticleLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import InAppVideoServices
import Postbox
import TGUIKit
import SwiftSignalKit
import InAppSettings

class WPArticleLayout: WPLayout {
    
    
    var imageSize:NSSize?
    var contrainedImageSize:NSSize = NSMakeSize(54, 54)
    var smallThumb:Bool = true
    var imageArguments:TransformImageArguments?
    
    private(set) var duration:(TextNodeLayout, TextNode)?
    private let durationAttributed:NSAttributedString?
    private let fetchDisposable = MetaDisposable()
    private let downloadSettings: AutomaticMediaDownloadSettings
    
    private(set) var groupLayout: GroupedLayout?
    private(set) var parameters:[ChatMediaLayoutParameters] = []

    init(with content: TelegramMediaWebpageLoadedContent, context: AccountContext, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation, approximateSynchronousValue: Bool, downloadSettings: AutomaticMediaDownloadSettings, autoplayMedia: AutoplayMediaPreferences, theme: TelegramPresentationTheme, mayCopyText: Bool, entities: [MessageTextEntity]? = nil, adAttribute: AdMessageAttribute? = nil) {
        
        var content = content
        
        if let story = content.story, let media = parent.associatedStories[story.storyId]?.get(Stories.StoredItem.self), groupLayout == nil {
            switch media {
            case let .item(story):
                if let image = story.media as? TelegramMediaImage {
                    content = content.withUpdatedImage(image)
                } else if let file = story.media as? TelegramMediaFile {
                    content = content.withUpdatedFile(file)
                }
            default:
                break
            }
        }
        
        
        if let duration = content.duration {
            self.durationAttributed = .initialize(string: String.durationTransformed(elapsed: duration), color: .white, font: .normal(.text))
        } else {
            durationAttributed = nil
        }
        
        if content.type == "telegram_theme" {
            for attr in content.attributes {
                switch attr {
                case let .theme(theme):
                    for file in theme.files {
                        if file.mimeType == "application/x-tgtheme-macos", !file.previewRepresentations.isEmpty {
                            content = content.withUpdatedFile(file)
                        }
                    }
                case .stickerPack:
                    break
                case .unsupported:
                    break
                }
            }
            
        }
        
        self.downloadSettings = downloadSettings
        
        super.init(with: content, context: context, chatInteraction: chatInteraction, parent:parent, fontSize: fontSize, presentation: presentation, approximateSynchronousValue: approximateSynchronousValue, mayCopyText: mayCopyText, entities: entities, adAttribute: adAttribute)
        
        if let mediaCount = mediaCount, mediaCount > 1 {
            var instantMedias = Array(instantPageMedias(for: parent.media[0] as! TelegramMediaWebpage).suffix(10))
            
            if let file = content.file {
                let page = InstantPageMedia(index: 0, media: file, webpage: parent.media[0] as! TelegramMediaWebpage, url: nil, caption: nil, credit: nil)
                for i in 0 ..< instantMedias.count {
                    instantMedias[i] = instantMedias[i].withUpdatedIndex(i + 1)
                }
                instantMedias.insert(page, at: 0)
            } else if let image = content.image {
                let page = InstantPageMedia(index: 0, media: image, webpage: parent.media[0] as! TelegramMediaWebpage, url: nil, caption: nil, credit: nil)
                for i in 0 ..< instantMedias.count {
                    instantMedias[i] = instantMedias[i].withUpdatedIndex(i + 1)
                }
                instantMedias.insert(page, at: 0)
            } else {
                for i in 0 ..< instantMedias.count {
                    instantMedias[i] = instantMedias[i].withUpdatedIndex(i)
                }
            }
            
            var messages:[Message] = []
            let groupingKey = arc4random64()
            for i in 0 ..< instantMedias.count {
                let media = instantMedias[i].media
                let message = parent.withUpdatedMedia([media]).withUpdatedStableId(arc4random()).withUpdatedId(MessageId(peerId: chatInteraction.peerId, namespace: Namespaces.Message.Local, id: MessageId.Id(i))).withUpdatedGroupingKey(groupingKey)
                messages.append(message)
                
                weak var weakParameters:ChatMediaGalleryParameters?
                
                let parameters = ChatMediaGalleryParameters(showMedia: { [weak self] _ in
                    guard let `self` = self else {return}
//
                    showInstantViewGallery(context: context, medias: instantMedias, firstIndex: i, firstStableId: ChatHistoryEntryId.message(parent), parent: parent, self.table, weakParameters)
                    
                }, showMessage: { [weak chatInteraction] _ in
                    chatInteraction?.focusMessageId(nil, .init(messageId: parent.id, string: nil), .CenterEmpty)
                }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: presentation.renderType, theme: theme), media: media, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: autoplayMedia)
                
                weakParameters = parameters
                
                self.parameters.append(parameters)
            }
            groupLayout = GroupedLayout(messages)
        }
        
        if let image = content.image, groupLayout == nil {
            if let dimensions = largestImageRepresentation(image.representations)?.dimensions.size {
                imageSize = dimensions
            }
        }
       
        
        for attr in content.attributes {
            switch attr {
            case .stickerPack:
                imageSize = NSMakeSize(50, 50)
            default:
                break
            }
        }
        
        if let file = content.file, groupLayout == nil {
            if let dimensions = file.dimensions?.size {
                imageSize = dimensions
            } else if isTheme {
                imageSize = NSMakeSize(200, 200)
            }
        } else if isTheme {
            imageSize = NSMakeSize(260, 260)
        }
        
        
        if let wallpaper = wallpaper {
            switch wallpaper {
            case let .wallpaper(_, _, preview):
                switch preview {
                case .color:
                    imageSize = NSMakeSize(150, 150)
                case .gradient:
                    imageSize = NSMakeSize(200, 200)
                default:
                    break
                }
            default:
                break
            }
        }
       
        if ExternalVideoLoader.isPlayable(content) {
            _ = sharedVideoLoader.fetch(for: content).start()
        }
    }
    
    var isAutoDownloable: Bool {
        return downloadSettings.isDownloable(parent)
    }
    
    deinit {
        fetchDisposable.dispose()
    }
    
    private let mediaTypes:[String] = ["photo","video"]
    private let fullSizeSites:[String] = ["instagram","twitter"]
    
    var isFullImageSize: Bool {
        
        
        for attr in content.attributes {
            switch attr {
            case .stickerPack:
                return false
            default:
                break
            }
        }
        
        if let attr = parent.webpagePreviewAttribute {
            if let forceLargeMedia = attr.forceLargeMedia {
                return forceLargeMedia
            }
        }
//        if let value = content.isMediaLargeByDefault {
//            return value
//        }
        
        if content.type == "telegram_background" || content.type == "telegram_theme" {
            return true
        }
       
        let website = content.websiteName?.lowercased()
        if let type = content.type, mediaTypes.contains(type) || (fullSizeSites.contains(website ?? "") || content.instantPage != nil) || content.text == nil  {
            if let imageSize = imageSize {
                if imageSize.width < 200 {
                    return false
                }
            }
            if type == "telegram_user" {
                return false
            }
            return true
        }
        return content.text == nil || content.text!.trimmed.isEmpty
    }
    
    override func measure(width: CGFloat) {
        if oldWidth != width {
            super.measure(width: width)
            
            let maxw = min(width - insets.left - insets.right, 300)
            
            var contentSize:NSSize = NSMakeSize(maxw, 0)
            
            if let groupLayout = groupLayout {
                groupLayout.measure(NSMakeSize(max(contentSize.width, maxw), maxw))
                
                contentSize.height += groupLayout.dimensions.height + 6
                contentSize.width = max(groupLayout.dimensions.width, contentSize.width)
            }
            
            var emptyColor: TransformImageEmptyColor? = nil
            if let wallpaper = wallpaper {
                switch wallpaper {
                case let .wallpaper(_, _, preview):
                    switch preview {
                    case let .slug(_, settings):
                        if !settings.colors.isEmpty {
                            var patternIntensity: CGFloat = 0.5
                            
                            let color = settings.colors.first ?? NSColor(rgb: 0xd6e2ee, alpha: 0.5).argb
                            if let intensity = settings.intensity {
                                patternIntensity = CGFloat(intensity) / 100.0
                            }
                            if settings.colors.count > 1 {
                                emptyColor = .gradient(colors: settings.colors.map { NSColor(argb: $0) }, intensity: patternIntensity, rotation: settings.rotation)
                            } else {
                                emptyColor = .color(NSColor(argb: color))
                            }
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            }
            
            if let imageSize = imageSize, isFullImageSize {
                
                if content.story != nil {
                    contrainedImageSize = imageSize.aspectFitted(NSMakeSize(maxw, maxw))
                } else if isTheme {
                    contrainedImageSize = imageSize.fitted(NSMakeSize(maxw, maxw))
                } else {
                    contrainedImageSize = imageSize.aspectFitted(NSMakeSize(maxw, maxw))
                    if action_text != nil, contrainedImageSize.width < 200 {
                        contrainedImageSize = NSMakeSize(min(300, maxw), min(300, maxw))
                    } else if contrainedImageSize.width < 200 {
                        contrainedImageSize = NSMakeSize(min(300, maxw), min(300, maxw))
                    }
                }

                textLayout?.cutout = nil
                smallThumb = false
                contentSize.height += contrainedImageSize.height
                contentSize.width = contrainedImageSize.width
                if textLayout != nil {
                    contentSize.height += insets.top
                }
            } else {
                if let _ = imageSize, !isFullImageSize {
                    contrainedImageSize = NSMakeSize(54, 54)
                    textLayout?.cutout = TextViewCutout(topRight: NSMakeSize(contrainedImageSize.width + 16, contrainedImageSize.height + 10))
                }
            }
            
            if let durationAttributed = durationAttributed {
                duration = TextNode.layoutText(durationAttributed, nil, 1, .end, NSMakeSize(contentSize.width, .greatestFiniteMagnitude), nil, false, .center)
            }
            
            
            textLayout?.measure(width: contentSize.width)
            
     
            
            if let textLayout = textLayout {
                
                contentSize.height += textLayout.layoutSize.height
                
                if textLayout.cutout != nil {
                    contentSize.height = max(imageSize != nil ? contrainedImageSize.height + imageInsets.top + imageInsets.bottom : 0, contentSize.height)
                    contentSize.width = min(max(max(textLayout.layoutSize.width, maxw), contrainedImageSize.width), maxw)
                } else if imageSize == nil {
                    contentSize.width = max(max(textLayout.layoutSize.width, maxw), groupLayout?.dimensions.width ?? 0)
                }
            }
            
            if let imageSize = imageSize {
                let imgSize: NSSize
                if isTheme {
                    imgSize = contrainedImageSize
                } else if action_text != nil {
                    imgSize = imageSize.aspectFitted(contrainedImageSize)
                } else {
                    imgSize = imageSize.aspectFilled(NSMakeSize(maxw, maxw))
                }
                
                let imageArguments = TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: imgSize, boundingSize: contrainedImageSize, intrinsicInsets: NSEdgeInsets(), resizeMode: .blurBackground, emptyColor: emptyColor)
                
                if imageArguments != self.imageArguments {
                    self.imageArguments = imageArguments
                }
            } else {
                self.imageArguments = nil
            }
            
         
            
            layout(with :contentSize)
        }
        
    }
    
}
