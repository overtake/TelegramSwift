//
//  ChatVoiceRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

enum TranscribeAudioState : Equatable {
    case loading
    case revealed(Bool)
    case collapsed(Bool)
}

import TGUIKit
import TelegramCore
import InAppSettings
import SwiftSignalKit
import Postbox
class ChatMediaVoiceLayoutParameters : ChatMediaLayoutParameters {
    
    enum TranscribeState {
        case possible
        case state(TranscribeAudioState)
    }
    
    let showPlayer:(APController) -> Void
    let waveform:AudioWaveform?
    let durationLayout:TextViewLayout
    let isMarked:Bool
    let isWebpage:Bool
    let resource: TelegramMediaResource
    fileprivate(set) var waveformWidth:CGFloat = 120
    fileprivate(set) var transcribeState: TranscribeState?
    let duration:Int
    
    var transcribe:()->Void = {}
    
    init(showPlayer:@escaping(APController) -> Void, waveform:AudioWaveform?, duration:Int, isMarked:Bool, isWebpage: Bool, resource: TelegramMediaResource, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.showPlayer = showPlayer
        self.waveform = waveform
        self.duration = duration
        self.isMarked = isMarked
        self.isWebpage = isWebpage
        self.resource = resource
        durationLayout = TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: duration), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
    
    func duration(for duration:TimeInterval) -> TextViewLayout {
        return TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: Int(round(duration))), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
    }
}

class ChatVoiceRowItem: ChatMediaItem {
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
        self.parameters = ChatMediaLayoutParameters.layout(for: media as! TelegramMediaFile, isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), autoplayMedia: object.autoplayMedia)
        
        
        let canTranscribe = context.isPremium

        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if canTranscribe, let message = object.message {
                if let state = entry.additionalData.transribeState {
                    parameters.transcribeState = .state(state)
                } else {
                    parameters.transcribeState = .possible
                }
                parameters.transcribe = { [weak self] in
                    self?.chatInteraction.transcribeAudio(message)
                }
            }
            
        }
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        return super.canMultiselectTextIn(location)
    }
    
    override var isForceRightLine: Bool {
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if parameters.durationLayout.layoutSize.width + 50 + rightSize.width + insetBetweenContentAndDate > contentSize.width {
                return true
            }
        }
        return super.isForceRightLine
    }
    
    override var blockWidth: CGFloat {
        if isBubbled {
            return min(super.blockWidth, 200)
        } else {
            return super.blockWidth
        }
    }

    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            parameters.durationLayout.measure(width: width - 50)
            
            let canTranscribe = context.isPremium

            
            let maxVoiceWidth:CGFloat = min(blockWidth, width - 50 - (canTranscribe ? 35 : 0))

            parameters.waveformWidth = maxVoiceWidth
            
            
            return NSMakeSize(parameters.waveformWidth + 50 + (canTranscribe ? 35 : 0), 40)
        }
        return NSZeroSize
    }
    
    override var instantlyResize: Bool {
        return true
    }
}
