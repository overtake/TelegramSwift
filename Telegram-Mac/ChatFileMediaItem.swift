//
//  ChatFileMediaItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import InAppSettings
import Postbox
import TGUIKit

class ChatFileLayoutParameters : ChatMediaGalleryParameters {
    var nameNode:TextNode = TextNode()
    var name:(TextNodeLayout, TextNode)?
    let hasThumb:Bool
    let fileName:String
    let finderLayout: TextViewLayout
    let downloadLayout: TextViewLayout
    let uploadingLayout: TextViewLayout
    let downloadingLayout: TextViewLayout
    init(fileName:String, hasThumb: Bool, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool, isIncoming: Bool, autoplayMedia: AutoplayMediaPreferences, isChatRelated: Bool = false, isCopyProtected: Bool) {
        self.fileName = fileName
        self.hasThumb = hasThumb
        
        let file = media as! TelegramMediaFile
        
        
        self.uploadingLayout = TextViewLayout(.initialize(string: strings().messagesFileStateFetchingOut1(100), font: .normal(.text)), alwaysStaticItems: true)
        self.downloadingLayout = TextViewLayout(.initialize(string: strings().messagesFileStateFetchingIn1(100), font: .normal(.text)), alwaysStaticItems: true)
        
        
        var attr:NSMutableAttributedString = NSMutableAttributedString()
        let _ = attr.append(string: .prettySized(with: file.elapsedSize), color: presentation.grayText, font: .normal(.text))
        if !(file.resource is LocalFileReferenceMediaResource) || isChatRelated  {
            if !isCopyProtected {
                let _ = attr.append(string: " - ", color: presentation.grayText, font: .normal(.text))
                
                let range = attr.append(string: strings().messagesFileStateLocal, color: theme.bubbled && !isIncoming ? presentation.grayText : presentation.link, font: .medium(FontSize.text))
                attr.addAttribute(NSAttributedString.Key.link, value: "chat://file/finder", range: range)
            }
        }
        finderLayout = TextViewLayout(attr, maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        attr = NSMutableAttributedString()
        let _ = attr.append(string: .prettySized(with: file.elapsedSize), color: presentation.grayText, font: .normal(.text))
        if !(file.resource is LocalFileReferenceMediaResource) || isChatRelated {
            let _ = attr.append(string: " - ", color: presentation.grayText, font: .normal(.text))
            let range = attr.append(string: strings().messagesFileStateRemote, color:  theme.bubbled && !isIncoming ? presentation.grayText : presentation.link, font: .medium(.text))
            attr.addAttribute(NSAttributedString.Key.link, value: "chat://file/download", range: range)
        }
        downloadLayout = TextViewLayout(attr, maximumNumberOfLines: 1, alwaysStaticItems: true)
        

        super.init(isWebpage: false, presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: autoplayMedia)
        
    }
    override func makeLabelsForWidth(_ width: CGFloat) -> CGFloat {
        self.name = TextNode.layoutText(maybeNode: nameNode, .initialize(string: fileName , color: presentation.text, font: .medium(.text)), nil, 1, .middle, NSMakeSize(width - (hasThumb ? 80 : 50), 20), nil,false, .left)
        

        uploadingLayout.measure(width: width - (hasThumb ? 80 : 50))
        downloadingLayout.measure(width: width - (hasThumb ? 80 : 50))
        
        downloadLayout.measure(width: width - (hasThumb ? 80 : 50))
        finderLayout.measure(width: width - (hasThumb ? 80 : 50))
        
        return max(downloadLayout.layoutSize.width, uploadingLayout.layoutSize.width, finderLayout.layoutSize.width, downloadingLayout.layoutSize.width, self.name!.0.size.width) + (hasThumb ? 80 : 50)

    }
}

class ChatFileMediaItem: ChatMediaItem {

    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), isFile: true, autoplayMedia: object.autoplayMedia, isChatRelated: true, isCopyProtected: object.message!.isCopyProtected())
        
        (self.parameters as? ChatFileLayoutParameters)?.showMedia = { [weak self] message in
            guard let `self` = self else {return}
            
            var type:GalleryAppearType = .history
            if let parameters = self.parameters as? ChatMediaGalleryParameters, parameters.isWebpage {
                type = .alone
            } else if message.containsSecretMedia {
                type = .secret
            }
                        
            showChatGallery(context: context, message: message, self.table, self.parameters as? ChatMediaGalleryParameters, type: type, chatMode: self.chatInteraction.mode, contextHolder: self.chatInteraction.contextHolder())
        }
            
        (self.parameters as? ChatFileLayoutParameters)?.showMessage = { [weak self] message in
            self?.chatInteraction.focusMessageId(nil, message.id, .CenterEmpty)
        }
        
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        var width = width
        
        let parameters = self.parameters as! ChatFileLayoutParameters
        let optionalWidth = parameters.makeLabelsForWidth(width)
                
        width = min(width, optionalWidth)
        
        return NSMakeSize(width, parameters.hasThumb ? 70 : 40)
    }
    

    override var lastLineContentWidth: ChatRowItem.LastLineData? {
        if let lastLineContentWidth = super.lastLineContentWidth {
            return lastLineContentWidth
        }
        let file = media as! TelegramMediaFile
        if file.previewRepresentations.isEmpty {
            let parameters = self.parameters as! ChatFileLayoutParameters

            let mwidth = max(parameters.uploadingLayout.layoutSize.width, parameters.downloadingLayout.layoutSize.width, parameters.finderLayout.layoutSize.width)

            let width = mwidth + 50
            return ChatRowItem.LastLineData(width: width, single: false)
        }
        return nil
    }
    
    
    override func contentNode() -> ChatMediaContentView.Type {
        return ChatFileContentView.self
    }
    
}
