//
//  GroupCallControlsView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


final class GroupCallControlsView : View {
    
    enum Mode : Equatable {
        case normal
        case fullscreen
    }
    
    private(set) var mode: Mode = .normal
    private(set) var callMode: GroupCallUIState.Mode = .voice
    
    private(set) var hasVideo: Bool = false
    
    private let speak: GroupCallSpeakButton = GroupCallSpeakButton(frame: NSMakeRect(0, 0, 140, 140))
    private let leftButton: CallControl = CallControl(frame: .zero)
    private let end: CallControl = CallControl(frame: .zero)
    private var speakText: TextView?
    var arguments: GroupCallUIArguments?

    private let backgroundView = VoiceChatActionButtonBackgroundView()
    private let fullscreenBackgroundView = NSVisualEffectView(frame: .zero)

    required init(frame frameRect: NSRect) {


        super.init(frame: frameRect)

        self.fullscreenBackgroundView.material = .ultraDark
        self.fullscreenBackgroundView.blendingMode = .withinWindow
        self.fullscreenBackgroundView.state = .active
        self.fullscreenBackgroundView.wantsLayer = true
        self.fullscreenBackgroundView.layer?.cornerRadius = 20
        self.fullscreenBackgroundView.layer?.opacity = 0
        
        addSubview(fullscreenBackgroundView)
        
        addSubview(backgroundView)
        addSubview(speak)

        addSubview(leftButton)
        addSubview(end)
        
        backgroundView.isEventLess = true
        backgroundView.userInteractionEnabled = false
        
        self.isEventLess = true

        end.set(handler: { [weak self] _ in
            self?.arguments?.leave()
        }, for: .Click)
                
        speak.set(handler: { [weak self] _ in
            if let state = self?.currentState {
                if let _ = state.state.scheduleTimestamp {
                    if state.state.canManageCall {
                        self?.arguments?.startVoiceChat()
                    } else {
                        self?.arguments?.toggleReminder(!state.state.subscribedToScheduled)
                    }
                } else if let muteState = state.state.muteState, !muteState.canUnmute {
                    if !state.state.raisedHand {
                        self?.arguments?.toggleRaiseHand()
                    }
                    self?.speak.playRaiseHand()
                } else {
                    self?.arguments?.toggleSpeaker()
                }
            }
            
        }, for: .Click)

        self.backgroundView.update(state: .connecting, animated: false)

        self.updateMode(self.mode, callMode: self.callMode, hasVideo: false, animated: false, force: true)
    }
    
    private func updateMode(_ mode: Mode, callMode: GroupCallUIState.Mode, hasVideo: Bool, animated: Bool, force: Bool = false) {
        let previous = self.mode
       
        if previous != mode || hasVideo != self.hasVideo || self.callMode != callMode || force {
            self.speakText?.change(opacity: mode == .fullscreen ? 0 : 1, animated: animated)
            self.fullscreenBackgroundView._change(opacity: mode == .fullscreen ? 1 : 0, animated: animated)
            
            let leftButtonText: String
            let leftBg: CallControlData.Mode
            switch callMode {
            case .voice:
                if hasVideo {
                    leftButtonText = L10n.voiceChatVideoStream
                    leftBg = .animated(.screenoff, GroupCallTheme.settingsColor)
                } else {
                    leftButtonText = L10n.voiceChatSettings
                    leftBg = .normal(GroupCallTheme.settingsColor, GroupCallTheme.settingsIcon)
                }
            case .video:
                leftButtonText = L10n.voiceChatVideoStream
                leftBg = .animated(!hasVideo ? .screenoff : .screenon, GroupCallTheme.settingsColor)
            }
            
            switch mode {
            case .fullscreen:
                end.updateWithData(CallControlData(text: nil, mode: .normal(GroupCallTheme.declineColor, GroupCallTheme.declineIcon), iconSize: NSMakeSize(48, 48)), animated: animated)
                leftButton.updateWithData(CallControlData(text: nil, mode: leftBg, iconSize: NSMakeSize(48, 48)), animated: animated)
            case .normal:
                end.updateWithData(CallControlData(text: L10n.voiceChatLeave, mode: .normal(GroupCallTheme.declineColor, GroupCallTheme.declineIcon), iconSize: NSMakeSize(48, 48)), animated: animated)
                leftButton.updateWithData(CallControlData(text: leftButtonText, mode: leftBg, iconSize: NSMakeSize(48, 48)), animated: animated)
            }
            if previous != mode {
                let from: CGFloat
                let to: CGFloat
                switch mode {
                case .fullscreen:
                    from = 1.0
                    to = 0.5
                case .normal:
                    from = 0.5
                    to = 1.0
                }
                if animated {
                    self.backgroundView.layer?.transform = CATransform3DIdentity
                    self.backgroundView.layer?.animateScaleCenter(from: from, to: to, duration: 0.2, removeOnCompletion: false)
                } else {
                    let rect = self.backgroundView.bounds
                    var fr = CATransform3DIdentity
                    fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
                    fr = CATransform3DScale(fr, to, to, 1)
                    fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                    self.backgroundView.layer?.transform = fr
                    self.backgroundView.layer?.removeAnimation(forKey: "transform")
                }
            }
        }
        self.mode = mode
        self.callMode = callMode
        self.hasVideo = hasVideo
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        switch mode {
        case .normal:
            speak.update(size: NSMakeSize(140, 140), transition: transition)
            transition.updateFrame(view: speak, frame: focus(NSMakeSize(140, 140)))
            transition.updateFrame(view: leftButton, frame: leftButton.centerFrameY(x: 30))
            transition.updateFrame(view: end, frame: end.centerFrameY(x: frame.width - end.frame.width - 30))
            if let speakText = speakText {
                let speakFrame = speakText.centerFrameX(y: speak.frame.maxY + floorToScreenPixels(backingScaleFactor, ((frame.height - speak.frame.maxY) - speakText.frame.height) / 2 - 33))
                transition.updateFrame(view: speakText, frame: speakFrame)
            }
            transition.updateFrame(view: self.backgroundView, frame: focus(.init(width: 360, height: 360)))
            transition.updateFrame(view: self.fullscreenBackgroundView, frame: focus(.init(width: 250, height: 80)))
        case .fullscreen:
            let bgRect = focus( NSMakeSize(230, 70))
            
            speak.update(size: NSMakeSize(86, 86), transition: transition)
            transition.updateFrame(view: speak, frame: focus(NSMakeSize(86, 86)))
            transition.updateFrame(view: leftButton, frame: leftButton.centerFrameY(x: bgRect.minX + 10))
            transition.updateFrame(view: end, frame: end.centerFrameY(x: bgRect.maxX - end.frame.width - 10))
            transition.updateFrame(view: self.backgroundView, frame: focus(.init(width: 360, height: 360)))
            transition.updateFrame(view: self.fullscreenBackgroundView, frame: bgRect)
        }
        
    }
    
        
    
    fileprivate private(set) var currentState: GroupCallUIState?
    private var leftToken: UInt32?
    func update(_ callState: GroupCallUIState, voiceSettings: VoiceCallSettings, audioLevel: Float?, animated: Bool) {


        let mode: Mode = callState.isFullScreen && callState.currentDominantSpeakerWithVideo != nil ? .fullscreen : .normal
        
        
        self.updateMode(mode, callMode: callState.mode, hasVideo: callState.hasVideo, animated: animated)

        let state = callState.state
        speak.update(with: state, isMuted: callState.isMuted, animated: animated)

        
        if let leftToken = leftToken {
            leftButton.removeHandler(leftToken)
        }
        
        leftToken = leftButton.set(handler: { [weak self, weak callState] _ in
            if let callState = callState {
                switch callState.mode {
                case .video:
                    if !callState.hasVideo {
                        self?.arguments?.shareSource()
                    } else {
                        self?.arguments?.cancelSharing()
                    }
                case .voice:
                    if callState.hasVideo {
                        self?.arguments?.cancelSharing()
                    } else {
                        self?.arguments?.settings()
                    }
                }
            }

        }, for: .Click)

        var backgroundState: VoiceChatActionButtonBackgroundView.State
        if state.scheduleTimestamp == nil {
            switch state.networkState {
                case .connected:
                    if callState.isMuted {
                        if let muteState = callState.state.muteState {
                            if muteState.canUnmute {
                                backgroundState = .blob(false)
                            } else {
                                backgroundState = .disabled
                            }
                        } else {
                            backgroundState = .blob(true)
                        }
                    } else {
                        backgroundState = .blob(true)
                    }
                case .connecting:
                    backgroundState = .connecting
            }
        } else {
            backgroundState = .disabled
        }
        
        self.backgroundView.isDark = false
        self.backgroundView.update(state: backgroundState, animated: animated)

        self.backgroundView.audioLevel = CGFloat(audioLevel ?? 0)

        
        let statusText: String
        var secondary: String? = nil
        if state.scheduleTimestamp == nil {
            switch state.networkState {
            case .connected:
                if callState.isMuted {
                    if let muteState = state.muteState {
                        if muteState.canUnmute {
                            statusText = L10n.voiceChatClickToUnmute
                            switch voiceSettings.mode {
                            case .always:
                                if let pushToTalk = voiceSettings.pushToTalk, !pushToTalk.isSpace {
                                    secondary = L10n.voiceChatClickToUnmuteSecondaryPress(pushToTalk.string)
                                } else {
                                    secondary = L10n.voiceChatClickToUnmuteSecondaryPressDefault
                                }
                            case .pushToTalk:
                                if let pushToTalk = voiceSettings.pushToTalk, !pushToTalk.isSpace {
                                    secondary = L10n.voiceChatClickToUnmuteSecondaryHold(pushToTalk.string)
                                } else {
                                    secondary = L10n.voiceChatClickToUnmuteSecondaryHoldDefault
                                }
                            case .none:
                                secondary = nil
                            }
                        } else {
                            if !state.raisedHand {
                                statusText = L10n.voiceChatMutedByAdmin
                                secondary = L10n.voiceChatClickToRaiseHand
                            } else {
                                statusText = L10n.voiceChatRaisedHandTitle
                                secondary = L10n.voiceChatRaisedHandText
                            }
                           
                        }
                    } else {
                        statusText = L10n.voiceChatYouLive
                    }
                } else {
                    statusText = L10n.voiceChatYouLive
                }
            case .connecting:
                statusText = L10n.voiceChatConnecting
            }
        } else if let _ = state.scheduleTimestamp {
            if state.canManageCall {
                statusText = L10n.voiceChatStartNow
            } else if state.subscribedToScheduled {
                statusText = L10n.voiceChatRemoveReminder
            } else {
                statusText = L10n.voiceChatSetReminder
            }
        } else {
            statusText = ""
        }
        

        let string = NSMutableAttributedString()
        string.append(.initialize(string: statusText, color: .white, font: .medium(.title)))
        if let secondary = secondary {
            string.append(.initialize(string: "\n", color: .white, font: .medium(.text)))
            string.append(.initialize(string: secondary, color: .white, font: .normal(.short)))
        }

        if string.string != self.speakText?.layout?.attributedString.string {
            let speakText = TextView()
            speakText.userInteractionEnabled = false
            speakText.isSelectable = false
            let layout = TextViewLayout(string, alignment: .center)
            layout.measure(width: frame.width - 60)
            speakText.update(layout)

            switch mode {
            case .fullscreen:
                speakText.layer?.opacity = 0
            case .normal:
                speakText.layer?.opacity = 1
            }
            
            let animated = animated && mode == .normal
            
            if let speakText = self.speakText {
                self.speakText = nil
                if animated {
                    speakText.layer?.animateAlpha(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak speakText] _ in
                        speakText?.removeFromSuperview()
                    })
                    speakText.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.5)
                } else {
                    speakText.removeFromSuperview()
                }
            }


            self.speakText = speakText
            addSubview(speakText)
            speakText.centerX(y: speak.frame.maxY + floorToScreenPixels(backingScaleFactor, ((frame.height - speak.frame.maxY) - speakText.frame.height) / 2) - 33)
            if animated {
                speakText.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                speakText.layer?.animateScaleSpring(from: 0.2, to: 1, duration: 0.5)
            }
        }

        self.currentState = callState
        needsLayout = true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }


    private var blue:NSColor {
        return GroupCallTheme.speakInactiveColor
    }

    private var lightBlue: NSColor {
        return NSColor(rgb: 0x59c7f8)
    }

    private var green: NSColor {
        return GroupCallTheme.speakActiveColor
    }

   
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
