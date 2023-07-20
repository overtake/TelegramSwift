//
//  WPMediaLayout.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import InAppSettings



class WPMediaLayout: WPLayout {

    var mediaSize:NSSize = NSZeroSize
    private(set) var media: Media
    let parameters:ChatMediaLayoutParameters?
    init(with content: TelegramMediaWebpageLoadedContent, context: AccountContext, chatInteraction:ChatInteraction, parent:Message, fontSize: CGFloat, presentation: WPLayoutPresentation, approximateSynchronousValue: Bool, downloadSettings: AutomaticMediaDownloadSettings, autoplayMedia: AutoplayMediaPreferences, theme: TelegramPresentationTheme, mayCopyText: Bool) {
        self.media = (content.file ?? content.image)!
        if let representations = content.image?.representations, let file = self.media as? TelegramMediaFile {
            self.media = file.withUpdatedPreviewRepresentations(representations)
        }
        
        
        self.parameters = ChatMediaGalleryParameters(isWebpage: true, media: self.media, automaticDownload: downloadSettings.isDownloable(parent))
        
        self.parameters?.cancelOperation = { [unowned context] message, media in
            if let media = media as? TelegramMediaFile {
                messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: media)
            } else if let media = media as? TelegramMediaImage {
                chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
            }
        }
        
        super.init(with: content, context: context, chatInteraction: chatInteraction, parent:parent, fontSize: fontSize, presentation: presentation, approximateSynchronousValue: approximateSynchronousValue, mayCopyText: mayCopyText)
        
    }
    
    override func measure(width: CGFloat) {
        super.measure(width: width)
        
        var contentSize = ChatLayoutUtils.contentSize(for: media, with: width - insets.left, hasText: textLayout != nil && theme.bubbled)
        
        
        self.mediaSize = contentSize
        
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            contentSize.width = max(50 + max(parameters.nameLayout.layoutSize.width, parameters.durationLayout.layoutSize.width), contentSize.width)
        }
        
        textLayout?.measure(width: contentSize.width)
        
        if let textLayout = textLayout {
            contentSize.height += textLayout.layoutSize.height + 6
        }
        
        if let parameters = parameters as? ChatFileLayoutParameters {
            parameters.name = TextNode.layoutText(maybeNode: parameters.nameNode, NSAttributedString.initialize(string: parameters.fileName , color: theme.colors.text, font: .medium(.text)), nil, 1, .middle, NSMakeSize(width - (parameters.hasThumb ? 80 : 50), 20), nil,false, .left)
        }
        
        parameters?.makeLabelsForWidth(contentSize.width - 50)
        

        
        layout(with: contentSize)
        
    }
    
    public func contentNode() -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return WPMediaContentView.self
    }
    
    
    
}
