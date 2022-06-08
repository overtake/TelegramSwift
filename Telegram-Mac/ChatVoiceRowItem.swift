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
    
    final class TranscribeData {
        var state: TranscribeState
        var text: TextViewLayout?
        var isPending: Bool
        init(state: TranscribeState, text: TextViewLayout?, isPending: Bool) {
            self.state = state
            self.text = text
            self.isPending = isPending
        }
        
        func makeSize(_ width: CGFloat) -> NSSize? {
            switch state {
            case .possible:
                self.size = nil
            case  let .state(state):
                switch state {
                case .loading:
                    self.size = nil
                case .collapsed:
                    self.size = nil
                case .revealed:
                    if let textLayout = text {
                        textLayout.measure(width: width)
                        self.size = NSMakeSize(width, textLayout.layoutSize.height)
                    }
                }
            }
            return self.size
        }
        
        var size: NSSize?
    }
    
    let showPlayer:(APController) -> Void
    let waveform:AudioWaveform?
    let durationLayout:TextViewLayout
    let isMarked:Bool
    let isWebpage:Bool
    let resource: TelegramMediaResource
    fileprivate(set) var waveformWidth:CGFloat = 120
    let duration:Int
    
    var transcribe:()->Void = {}
    
    fileprivate(set) var transcribeData: TranscribeData?
    
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
                var pending: Bool
                if let transcribe = message.audioTranscription {
                    pending = transcribe.isPending
                } else {
                    pending = false
                }
                if let state = entry.additionalData.transribeState {
                    
                    
                    var transcribed: String?
                    var transcribtedColor = theme.chat.textColor(isIncoming, object.renderType == .bubble)
                    switch state {
                    case let .revealed(success):
                        if !success {
                            transcribed = strings().chatVoiceTransribeError
                            transcribtedColor = parameters.presentation.activityBackground
                        } else {
                            if let result = entry.message?.audioTranscription, !result.text.isEmpty {
                                transcribed = result.text
                            }
                        }
                    case .loading:
                        pending = true
                    default:
                        break
                    }
                    
                    let textLayout: TextViewLayout?
                    if let transcribed = transcribed {
                        let caption: NSAttributedString = .initialize(string: transcribed, color: transcribtedColor, font: .normal(theme.fontSize))
                        
                        textLayout = TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), strokeLinks: object.renderType == .bubble, alwaysStaticItems: true, disableTooltips: false, mayItems: !message.isCopyProtected())
                    } else {
                        textLayout = nil
                    }
                    
                    parameters.transcribeData = .init(state: .state(state), text: textLayout, isPending: pending)
                } else {
                    parameters.transcribeData = .init(state: .possible, text: nil, isPending: pending)
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
            
            let width = parameters.waveformWidth + 50 + (canTranscribe ? 35 : 0)
            
            var addition: CGFloat = 0
            if let height = parameters.transcribeData?.makeSize(width)?.height {
                
                addition += height + 5
                if captionLayouts.isEmpty, renderType == .bubble {
                    addition += rightSize.height
                }
            }

            return NSMakeSize(parameters.waveformWidth + 50 + (canTranscribe ? 35 : 0), 40 + addition)
        }
        return NSZeroSize
    }
    
    override var instantlyResize: Bool {
        return true
    }
}
