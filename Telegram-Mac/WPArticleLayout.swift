//
//  WPArticleLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit
import SwiftSignalKitMac

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

    init(with content: TelegramMediaWebpageLoadedContent, account:Account, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation, downloadSettings: AutomaticMediaDownloadSettings) {
        if let duration = content.duration {
            self.durationAttributed = .initialize(string: String.durationTransformed(elapsed: duration), color: .white, font: .normal(.text))
        } else {
            durationAttributed = nil
        }
        self.downloadSettings = downloadSettings
        
        super.init(with: content, account:account, chatInteraction: chatInteraction, parent:parent, fontSize: fontSize, presentation: presentation)
        
        if let mediaCount = mediaCount, mediaCount > 1 {
            var instantMedias = Array(instantPageMedias(for: parent.media[0] as! TelegramMediaWebpage).suffix(10))
            if let file = content.file {
                let page = InstantPageMedia(index: 0, media: file, caption: nil)
                for i in 0 ..< instantMedias.count {
                    instantMedias[i] = instantMedias[i].withUpdatedIndex(i + 1)
                }
                instantMedias.insert(page, at: 0)
            }
            
            var messages:[Message] = []
            for i in 0 ..< instantMedias.count {
                let media = instantMedias[i].media
                let message = parent.withUpdatedMedia([media]).withUpdatedStableId(arc4random()).withUpdatedId(MessageId(peerId: chatInteraction.peerId, namespace: Namespaces.Message.Local, id: MessageId.Id(i)))
                messages.append(message)
                
                weak var weakParameters:ChatMediaGalleryParameters?
                
                let parameters = ChatMediaGalleryParameters(showMedia: { [weak self] _ in
                    guard let `self` = self else {return}
//
                    showInstantViewGallery(account: account, medias: instantMedias, firstIndex: i, firstStableId: ChatHistoryEntryId.message(parent), self.table, weakParameters)
                    
                }, showMessage: { [weak chatInteraction] _ in
                    chatInteraction?.focusMessageId(nil, parent.id, .center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
                }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: account, renderType: presentation.renderType), media: media, automaticDownload: downloadSettings.isDownloable(message))
                
                weakParameters = parameters
                
                self.parameters.append(parameters)
            }
            groupLayout = GroupedLayout(messages)
        }
        
        if let image = content.image, groupLayout == nil {
            
            if let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                imageSize = dimensions
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
        let website = content.websiteName?.lowercased()
        if let type = content.type, mediaTypes.contains(type) || (fullSizeSites.contains(website ?? "") || content.instantPage != nil) || content.text == nil  {
            if let imageSize = imageSize {
                if imageSize.width < 200 {
                    return false
                }
            }
            return true
        }
        return content.text == nil || content.text!.trimmed.isEmpty
    }
    
    override func measure(width: CGFloat) {
        if oldWidth != width {
            super.measure(width: width)
            
            var contentSize:NSSize = NSMakeSize(width - insets.left, 0)
            
            if let groupLayout = groupLayout {
                groupLayout.measure(NSMakeSize(max(contentSize.width, 250), 320))
                
                contentSize.height += groupLayout.dimensions.height + 6
                contentSize.width = max(groupLayout.dimensions.width, contentSize.width)
            }
            
            if let imageSize = imageSize, isFullImageSize {
                contrainedImageSize = imageSize.fitted(NSMakeSize(min(width - insets.left, 320), 300))
                if presentation.renderType == .bubble {
                    contrainedImageSize.width = max(contrainedImageSize.width, 280)
                }
                textLayout?.cutout = nil
                smallThumb = false
                contentSize.height += contrainedImageSize.height
                contentSize.width = contrainedImageSize.width
                if textLayout != nil {
                    contentSize.height += 6
                }
            } else {
                if let _ = imageSize {
                    contrainedImageSize = NSMakeSize(54, 54)
                    textLayout?.cutout = TextViewCutout(position: .TopRight, size: NSMakeSize(contrainedImageSize.width + 16, contrainedImageSize.height + 10))
                }
            }
            
            if let durationAttributed = durationAttributed {
                duration = TextNode.layoutText(durationAttributed, nil, 1, .end, NSMakeSize(contentSize.width, .greatestFiniteMagnitude), nil, false, .center)
            }
            
            
            textLayout?.measure(width: contentSize.width)
            
     
            
            if let textLayout = textLayout {
                
                contentSize.height += textLayout.layoutSize.height
                
                if textLayout.cutout != nil {
                    contentSize.height = max(content.image != nil ? contrainedImageSize.height : 0,contentSize.height)
                    contentSize.width = min(max(textLayout.layoutSize.width, (siteName?.0.size.width ?? 0) + contrainedImageSize.width), width - insets.left)
                } else if imageSize == nil {
                    contentSize.width = max(max(textLayout.layoutSize.width, groupLayout?.dimensions.width ?? 0), (siteName?.0.size.width ?? 0))
                }
            }
            
            if let imageSize = imageSize {
                let imageArguments = TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: imageSize.fitted(NSMakeSize(320, 320)), boundingSize: contrainedImageSize, intrinsicInsets: NSEdgeInsets(), resizeMode: .blurBackground)
                
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
