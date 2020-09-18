//
//  ChatFileMediaItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import TGUIKit

class ChatFileLayoutParameters : ChatMediaGalleryParameters {
    var nameNode:TextNode = TextNode()
    var name:(TextNodeLayout, TextNode)?
    let hasThumb:Bool
    let fileName:String
    let finderLayout: TextViewLayout
    let downloadLayout: TextViewLayout
    fileprivate let uploadingLayout: TextViewLayout
    fileprivate let downloadingLayout: TextViewLayout
    init(fileName:String, hasThumb: Bool, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool, isIncoming: Bool, autoplayMedia: AutoplayMediaPreferences, isChatRelated: Bool = false) {
        self.fileName = fileName
        self.hasThumb = hasThumb
        
        let file = media as! TelegramMediaFile
        
        
        self.uploadingLayout = TextViewLayout(.initialize(string: L10n.messagesFileStateFetchingOut1(100), font: .normal(.text)), alwaysStaticItems: true)
        self.downloadingLayout = TextViewLayout(.initialize(string: L10n.messagesFileStateFetchingIn1(100), font: .normal(.text)), alwaysStaticItems: true)
        
        
        var attr:NSMutableAttributedString = NSMutableAttributedString()
        let _ = attr.append(string: .prettySized(with: file.elapsedSize), color: presentation.grayText, font: .normal(.text))
        if !(file.resource is LocalFileReferenceMediaResource) || isChatRelated {
            let _ = attr.append(string: " - ", color: presentation.grayText, font: .normal(.text))
            
            let range = attr.append(string: tr(L10n.messagesFileStateLocal), color: theme.bubbled && !isIncoming ? presentation.grayText : presentation.link, font: .medium(FontSize.text))
            attr.addAttribute(NSAttributedString.Key.link, value: "chat://file/finder", range: range)
        }
        finderLayout = TextViewLayout(attr, maximumNumberOfLines: 1, alwaysStaticItems: true)

        
        attr = NSMutableAttributedString()
        let _ = attr.append(string: .prettySized(with: file.elapsedSize), color: presentation.grayText, font: .normal(.text))
        if !(file.resource is LocalFileReferenceMediaResource) || isChatRelated {
            let _ = attr.append(string: " - ", color: presentation.grayText, font: .normal(.text))
            let range = attr.append(string: tr(L10n.messagesFileStateRemote), color:  theme.bubbled && !isIncoming ? presentation.grayText : presentation.link, font: .medium(.text))
            attr.addAttribute(NSAttributedString.Key.link, value: "chat://file/download", range: range)
        }
        downloadLayout = TextViewLayout(attr, maximumNumberOfLines: 1, alwaysStaticItems: true)
        

        super.init(isWebpage: false, presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: autoplayMedia)
        
    }
    override func makeLabelsForWidth(_ width: CGFloat) {
        self.name = TextNode.layoutText(maybeNode: nameNode, .initialize(string: fileName , color: presentation.text, font: .medium(.text)), nil, 1, .middle, NSMakeSize(width, 20), nil,false, .left)
        

        uploadingLayout.measure(width: width)
        downloadingLayout.measure(width: width)
        
        downloadLayout.measure(width: width)
        finderLayout.measure(width: width)

    }
}

class ChatFileMediaItem: ChatMediaItem {

    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), isFile: true, autoplayMedia: object.autoplayMedia, isChatRelated: true)
        
        (self.parameters as? ChatFileLayoutParameters)?.showMedia = { [weak self] message in
            guard let `self` = self else {return}
            
            var type:GalleryAppearType = .history
            if let parameters = self.parameters as? ChatMediaGalleryParameters, parameters.isWebpage {
                type = .alone
            } else if message.containsSecretMedia {
                type = .secret
            }
            showChatGallery(context: context, message: message, self.table, self.parameters as? ChatMediaGalleryParameters, type: type)
        }
            
        (self.parameters as? ChatFileLayoutParameters)?.showMessage = { [weak self] message in
            self?.chatInteraction.focusMessageId(nil, message.id, .CenterEmpty)
        }
        
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        var width = width
        
        let parameters = self.parameters as! ChatFileLayoutParameters
        let file = media as! TelegramMediaFile
        parameters.makeLabelsForWidth( width - (file.previewRepresentations.isEmpty ? 50 : 80))
        
       
        let progressMaxWidth = max(parameters.uploadingLayout.layoutSize.width, parameters.downloadingLayout.layoutSize.width)
        
        let optionalWidth = max(parameters.name?.0.size.width ?? 0, max(max(parameters.finderLayout.layoutSize.width, parameters.downloadLayout.layoutSize.width), progressMaxWidth)) + (file.previewRepresentations.isEmpty ? 50 : 80)

        
        if let captionLayout = self.captionLayout {
            captionLayout.measure(width: width)
            width = max(optionalWidth, captionLayout.layoutSize.width)
        } else  {
            width = optionalWidth
        }
        
        return NSMakeSize(width, parameters.hasThumb ? 70 : 40)
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        let file = media as! TelegramMediaFile
        let parameters = self.parameters as! ChatFileLayoutParameters

        let progressMaxWidth = max(parameters.uploadingLayout.layoutSize.width, parameters.downloadingLayout.layoutSize.width)

        let accesoryWidth = max(max(parameters.finderLayout.layoutSize.width, parameters.downloadLayout.layoutSize.width), progressMaxWidth) + (file.previewRepresentations.isEmpty ? 50 : 80)
        
        if file.previewRepresentations.isEmpty, accesoryWidth > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return super.additionalLineForDateInBubbleState
        }
        
        
        return file.previewRepresentations.isEmpty || captionLayout != nil ? super.additionalLineForDateInBubbleState : nil
    }
    
    override var isFixedRightPosition: Bool {
        let file = media as! TelegramMediaFile
        
        let parameters = self.parameters as! ChatFileLayoutParameters
        
        let progressMaxWidth = max(parameters.uploadingLayout.layoutSize.width, parameters.downloadingLayout.layoutSize.width)
        let accesoryWidth = max(max(parameters.finderLayout.layoutSize.width, parameters.downloadLayout.layoutSize.width), progressMaxWidth) + (file.previewRepresentations.isEmpty ? 50 : 80)
        
        if file.previewRepresentations.isEmpty, accesoryWidth < realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return true
        }
        
        return file.previewRepresentations.isEmpty || captionLayout != nil ? super.isFixedRightPosition : true
    }
    
    override func contentNode() -> ChatMediaContentView.Type {
        return ChatFileContentView.self
    }
    
}
