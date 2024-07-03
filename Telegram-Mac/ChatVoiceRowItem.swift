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
import TelegramMedia


func canTranscribeMessage(_ message: Message, context: AccountContext) -> Bool {
    if message.autoclearTimeout != nil {
        return false
    }
    let file = message.media.first! as! TelegramMediaFile
    if context.isPremium {
        return true
    } else {
        let has_trial = context.appConfiguration.getGeneralValue("transcribe_audio_trial_weekly_number", orElse: 0) > 0
        let max_trial_duration = context.appConfiguration.getGeneralValue("transcribe_audio_trial_duration_max", orElse: 0)
        if has_trial, max_trial_duration > Int(file.duration ?? 0) {
            return true
        } else {
            return false
        }
    }
}

class ChatMediaVoiceLayoutParameters : ChatMediaLayoutParameters {
    
    enum TranscribeState {
        case possible
        case locked
        case state(TranscribeAudioState)
    }
    
    final class TranscribeData {
        let state: TranscribeState
        let text: TextViewLayout?
        let isPending: Bool
        let fontColor: NSColor
        let backgroundColor: NSColor
        init(state: TranscribeState, text: TextViewLayout?, isPending: Bool, fontColor: NSColor, backgroundColor: NSColor) {
            self.state = state
            self.text = text
            self.isPending = isPending
            self.fontColor = fontColor
            self.backgroundColor = backgroundColor
        }
        
        let dotsSize: NSSize = NSMakeSize(18, 18)
        
        func makeSize(_ width: CGFloat) -> NSSize? {
            switch state {
            case .possible:
                self.size = nil
            case .locked:
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
                        
                        var size = NSMakeSize(width, textLayout.layoutSize.height)
                        if let line = textLayout.lines.last {
                            if line.frame.maxX + dotsSize.width > width {
                                size.height += 10
                            }
                        }
                        self.size = size
                    } else {
                        self.size = dotsSize
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
    let duration: Double
    
    var transcribe:()->Void = {}
    
    fileprivate(set) var transcribeData: TranscribeData?
    
    init(showPlayer:@escaping(APController) -> Void, waveform:AudioWaveform?, duration: Double, isMarked:Bool, isWebpage: Bool, resource: TelegramMediaResource, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.showPlayer = showPlayer
        self.waveform = waveform
        self.duration = duration
        self.isMarked = isMarked
        self.isWebpage = isWebpage
        self.resource = resource
        durationLayout = TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: duration), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: AutoplayMediaPreferences.defaultSettings, isRevealed: nil)
    }
    
    func duration(for duration:TimeInterval) -> TextViewLayout {
        return TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: Int(round(duration))), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
    }
}

class ChatVoiceRowItem: ChatMediaItem {
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, theme: theme)
        
        let isIncoming = object.message!.isIncoming(context.account, object.renderType == .bubble)
        
        let file = media as! TelegramMediaFile

        var waveform:AudioWaveform? = nil
        var duration:Double = 0
        for attr in file.attributes {
            switch attr {
            case let .Audio(_, _duration, _, _, _data):
                if let data = _data {
                    waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                }
                duration = Double(_duration)
            default:
                break
            }
        }
        if waveform == nil, file.isInstantVideo {
            let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
            waveform = AudioWaveform(bitstream: Data(base64Encoded: waveformBase64)!, bitsPerSample: 5)
        }
        let parameters = ChatMediaVoiceLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, waveform: waveform, duration:duration, isMarked: true, isWebpage: false, resource: file.resource, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), media: media, automaticDownload: downloadSettings.isDownloable(object.message!))

        
        self.parameters = parameters
        
        
        let canTranscribe = canTranscribeMessage(object.message!, context: context)

        if canTranscribe, let message = object.message {
            var pending: Bool
            if let transcribe = message.audioTranscription {
                pending = transcribe.isPending
            } else {
                pending = false
            }
            let bgColor: NSColor
            if renderType == .list {
                bgColor = theme.colors.accent.withAlphaComponent(0.1)
            } else {
                if isIncoming {
                    bgColor = theme.colors.accent.withAlphaComponent(0.1)
                } else {
                    bgColor = theme.chat.grayText(false, true).withAlphaComponent(0.1)
                }
            }

            
            var transcribtedColor = theme.chat.textColor(isIncoming, object.renderType == .bubble)
            if let state = entry.additionalData.transribeState {
                
                
                var transcribed: String?
                switch state {
                case let .revealed(success):
                    if !success {
                        transcribed = strings().chatVoiceTransribeError
                        transcribtedColor = parameters.presentation.grayText
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
                
                parameters.transcribeData = .init(state: .state(state), text: textLayout, isPending: pending, fontColor: transcribtedColor, backgroundColor: bgColor)
            } else if let attributes = message.audioTranscription {
                parameters.transcribeData = .init(state: .state(.collapsed(true)), text: nil, isPending: false, fontColor: transcribtedColor, backgroundColor: bgColor)
            } else {
                let locked: Bool
                if let cooldown = context.audioTranscriptionTrial.cooldownUntilTime, cooldown > Int32(Date().timeIntervalSince1970) {
                    locked = true
                } else {
                    locked = false
                }
                parameters.transcribeData = .init(state: locked ? .locked : .possible, text: nil, isPending: pending, fontColor: transcribtedColor, backgroundColor: bgColor)
            }
            parameters.transcribe = { [weak self] in
                self?.chatInteraction.transcribeAudio(message)
            }
        }
    }
    
    public override func contentNode() -> ChatMediaContentView.Type {
        return ChatVoiceContentView.self
    }
    
    override var isBubbleFullFilled: Bool {
        return false
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
            
            let canTranscribe = canTranscribeMessage(message!, context: context)

            
            let maxVoiceWidth:CGFloat = min(min(250, blockWidth), width - 50 - (canTranscribe ? 35 : 0))

            parameters.waveformWidth = maxVoiceWidth
            
            let width = parameters.waveformWidth + 50 + (canTranscribe ? 35 : 0)
            
            var addition: CGFloat = 0
            if let height = parameters.transcribeData?.makeSize(width)?.height {
                
                addition += height + 5
                if captionLayouts.isEmpty, renderType == .bubble, reactionsLayout == nil {
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
