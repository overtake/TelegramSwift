//
//  ChatMusicRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import SwiftSignalKit
import Postbox
class ChatMediaMusicLayoutParameters : ChatMediaLayoutParameters {
    let resource: TelegramMediaResource
    let title:String?
    let performer:String?
    let isWebpage: Bool
    let nameLayout:TextViewLayout
    let showPlayer:(APController) -> Void
    let durationLayout:TextViewLayout
    let sizeLayout:TextViewLayout
    init(nameLayout:TextViewLayout, durationLayout:TextViewLayout, sizeLayout:TextViewLayout, resource:TelegramMediaResource, isWebpage: Bool, title:String?, performer:String?, showPlayer:@escaping(APController) -> Void, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.nameLayout = nameLayout
        self.sizeLayout = sizeLayout
        self.durationLayout = durationLayout
        self.showPlayer = showPlayer
        self.isWebpage = isWebpage
        self.title = title
        self.performer = performer
        self.resource = resource
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
    
    var file: TelegramMediaFile {
        return media as! TelegramMediaFile
    }
    
    override func makeLabelsForWidth(_ width: CGFloat) -> CGFloat {
        nameLayout.measure(width: width - 50)
        durationLayout.measure(width: width - 50)
        sizeLayout.measure(width: width - 50)
        
        
        return max(nameLayout.layoutSize.width, durationLayout.layoutSize.width, sizeLayout.layoutSize.width) + 50
    }
}

class ChatMusicRowItem: ChatMediaItem {
    
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        

        self.parameters = ChatMediaLayoutParameters.layout(for: (self.media as! TelegramMediaFile), isWebpage: chatInteraction.isLogInteraction, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), autoplayMedia: object.autoplayMedia)
    }
    
    override var isForceRightLine: Bool {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            if parameters.durationLayout.layoutSize.width + 50 + rightSize.width + insetBetweenContentAndDate > contentSize.width {
                return true
            }
        }
        return super.isForceRightLine
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            
            
            let width = min(320, width - 80)
            
            for layout in captionLayouts {
                if layout.layout.layoutSize == .zero {
                    layout.layout.measure(width: width)
                }
            }
            let captionsWidth = captionLayouts.max(by: { $0.layout.layoutSize.width < $1.layout.layoutSize.width }).map { $0.layout.layoutSize.width }
            
            let labelsWidth = parameters.makeLabelsForWidth(width)
            return NSMakeSize(max(captionsWidth ?? 0, labelsWidth) + 50, 40)
        }
        return NSZeroSize
    }
}
