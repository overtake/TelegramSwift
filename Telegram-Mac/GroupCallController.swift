//
//  GroupCallController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import HotKey

let fullScreenThreshold: CGFloat = 600

private final class GroupCallUIArguments {
    let leave:()->Void
    let settings:()->Void
    let invite:(PeerId)->Void
    let mute:(PeerId, Bool)->Void
    let toggleSpeaker:()->Void
    let remove:(Peer)->Void
    let openInfo: (Peer)->Void
    let inviteMembers:()->Void
    let shareSource:()->Void
    let takeVideo:(PeerId)->NSView?
    let setVolume: (PeerId, Double, Bool) -> Void
    let pinVideo:(PeerId, UInt32)->Void
    let unpinVideo:()->Void
    let isPinnedVideo:(PeerId)->Bool
    let getAccountPeerId: ()->PeerId?
    let cancelSharing: ()->Void
    let toggleRaiseHand:()->Void
    let recordClick:(PresentationGroupCallState)->Void
    let audioLevel:(PeerId)->Signal<Float?, NoError>?
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId, Bool)->Void,
    toggleSpeaker:@escaping()->Void,
    remove:@escaping(Peer)->Void,
    openInfo: @escaping(Peer)->Void,
    inviteMembers:@escaping()->Void,
    shareSource: @escaping()->Void,
    takeVideo:@escaping(PeerId)->NSView?,
    pinVideo:@escaping(PeerId, UInt32)->Void,
    unpinVideo:@escaping()->Void,
    isPinnedVideo:@escaping(PeerId)->Bool,
    setVolume: @escaping(PeerId, Double, Bool)->Void,
    getAccountPeerId: @escaping()->PeerId?,
    cancelSharing: @escaping()->Void,
    toggleRaiseHand:@escaping()->Void,
    recordClick:@escaping(PresentationGroupCallState)->Void,
    audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?) {
        self.leave = leave
        self.invite = invite
        self.mute = mute
        self.settings = settings
        self.toggleSpeaker = toggleSpeaker
        self.remove = remove
        self.openInfo = openInfo
        self.inviteMembers = inviteMembers
        self.shareSource = shareSource
        self.takeVideo = takeVideo
        self.pinVideo = pinVideo
        self.unpinVideo = unpinVideo
        self.isPinnedVideo = isPinnedVideo
        self.setVolume = setVolume
        self.getAccountPeerId = getAccountPeerId
        self.cancelSharing = cancelSharing
        self.toggleRaiseHand = toggleRaiseHand
        self.recordClick = recordClick
        self.audioLevel = audioLevel
    }
}



private final class GroupCallControlsView : View {
    private let speak: GroupCallSpeakButton = GroupCallSpeakButton(frame: NSMakeRect(0, 0, 144, 144))
    private let videoStream: CallControl = CallControl(frame: .zero)
    private let end: CallControl = CallControl(frame: .zero)
    private var speakText: TextView?
    fileprivate var arguments: GroupCallUIArguments?

    private let backgroundView = VoiceChatActionButtonBackgroundView()

    required init(frame frameRect: NSRect) {


        super.init(frame: frameRect)

        addSubview(backgroundView)
        addSubview(speak)

        addSubview(videoStream)
        addSubview(end)


        backgroundView.isEventLess = true
        backgroundView.userInteractionEnabled = false
        
        self.isEventLess = true


        end.set(handler: { [weak self] _ in
            self?.arguments?.leave()
        }, for: .Click)
        

        
        speak.set(handler: { [weak self] _ in
            if let muteState = self?.currentState?.state.muteState, !muteState.canUnmute {
                if self?.currentState?.state.raisedHand == false {
                    self?.arguments?.toggleRaiseHand()
                }
                self?.speak.playRaiseHand()
//                self?.speakText?.shake()
//                NSSound.beep()
            } else {
                self?.arguments?.toggleSpeaker()
            }
        }, for: .Click)


        end.updateWithData(CallControlData(text: L10n.voiceChatLeave, isVisualEffect: false, icon: GroupCallTheme.declineIcon, iconSize: NSMakeSize(48, 48), backgroundColor: GroupCallTheme.declineColor), animated: false)
        
        videoStream.updateWithData(CallControlData(text: L10n.voiceChatSettings, isVisualEffect: false, icon: GroupCallTheme.settingsIcon, iconSize: NSMakeSize(48, 48), backgroundColor: GroupCallTheme.settingsColor), animated: false)
    }
        
    
    fileprivate private(set) var currentState: GroupCallUIState?
    private var videoStreamToken: UInt32?
    func update(_ callState: GroupCallUIState, voiceSettings: VoiceCallSettings, audioLevel: Float?, animated: Bool) {



        let state = callState.state
        speak.update(with: state, isMuted: callState.isMuted, audioLevel: audioLevel, animated: animated)

        let isStreaming: Bool
        if let arguments = arguments, let peerId = arguments.getAccountPeerId() {
            isStreaming = callState.activeVideoSources[peerId] != nil
        } else {
            isStreaming = false
        }

        if let videoStreamToken = videoStreamToken {
            videoStream.removeHandler(videoStreamToken)
        }
        
        videoStreamToken = videoStream.set(handler: { [weak self] _ in
//            self?.arguments?.settings()
            if !isStreaming {
                self?.arguments?.shareSource()
            } else {
                self?.arguments?.cancelSharing()
            }
        }, for: .Click)

        var backgroundState: VoiceChatActionButtonBackgroundView.State
        
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
        self.backgroundView.isDark = false
        self.backgroundView.update(state: backgroundState, animated: animated)

        self.backgroundView.audioLevel = CGFloat(audioLevel ?? 0)

        
        let statusText: String
        var secondary: String? = nil
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

    
    override func layout() {
        super.layout()
        speak.center()

        videoStream.centerY(x: 30)
        end.centerY(x: frame.width - end.frame.width - 30)
        if let speakText = speakText {
            speakText.centerX(y: speak.frame.maxY + floorToScreenPixels(backingScaleFactor, ((frame.height - speak.frame.maxY) - speakText.frame.height) / 2 - 33))
        }

        self.backgroundView.frame = focus(.init(width: 360, height: 360))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class GroupCallRecordingView : Control {
    private let indicator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(indicator)
        
        indicator.isEventLess = true
        
        self.set(handler: { [weak self] control in
            self?.recordClick?()
        }, for: .Click)
        

        indicator.backgroundColor = GroupCallTheme.customTheme.redColor
        indicator.setFrameSize(NSMakeSize(8, 8))
        indicator.layer?.cornerRadius = indicator.frame.height / 2
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.timingFunction = .init(name: .easeInEaseOut)
        animation.fromValue = 0.5
        animation.toValue = 1.0
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        indicator.layer?.add(animation, forKey: "opacity")

    }
    private var recordingStartTime: Int32 = 0
    private var account: Account?
    private var recordClick:(()->Void)? = nil
    
    var updateParentLayout:(()->Void)? = nil
    
    func update(recordingStartTime: Int32, account: Account, recordClick: (()->Void)?) {
        self.account = account
        self.recordClick = recordClick
        self.recordingStartTime = recordingStartTime
        self.backgroundColor = .clear
        self.updateParentLayout?()
        
        setFrameSize(NSMakeSize(8, 8))
    }
 
    override func layout() {
        super.layout()
        indicator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class GroupCallTitleView : View {
    fileprivate let titleView: TextView = TextView()
    fileprivate let statusView: DynamicCounterTextView = DynamicCounterTextView()
    private var recordingView: GroupCallRecordingView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(statusView)
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        statusView.userInteractionEnabled = false
    }
    
    override var backgroundColor: NSColor {
        didSet {
            titleView.backgroundColor = backgroundColor
            statusView.backgroundColor = backgroundColor
        }
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        statusView.centerX(y: frame.midY)
        
        if let recordingView = recordingView {
            
            let layout = titleView.layout
            layout?.measure(width: frame.width - 115 - recordingView.frame.width - 10)
            titleView.update(layout)
            
            
            let rect = focus(titleView.frame.size)
            titleView.setFrameOrigin(NSMakePoint(max(90, rect.minX), frame.midY - titleView.frame.height))

            recordingView.setFrameOrigin(NSMakePoint(titleView.frame.maxX + 5, titleView.frame.minY + 6))
            
        } else {
        }
        let rect = focus(titleView.frame.size)
        titleView.setFrameOrigin(NSMakePoint(max(90, rect.minX), frame.midY - titleView.frame.height))

    }
    
    
    private var currentState: GroupCallUIState?
    private var currentPeer: Peer?
    func update(_ peer: Peer, _ state: GroupCallUIState, _ account: Account, recordClick: @escaping()->Void, animated: Bool) {
        
        let title: String
        if let custom = state.state.title, !custom.isEmpty {
            title = custom
        } else {
            title = peer.displayTitle
        }
        
        let oldTitle: String?
        if let custom = currentState?.state.title, !custom.isEmpty {
            oldTitle = custom
        } else {
            oldTitle = currentPeer?.displayTitle
        }
        
        let titleUpdated = title != oldTitle
                
        let recordingUpdated = state.state.recordingStartTimestamp != currentState?.state.recordingStartTimestamp
        let participantsUpdated = state.summaryState?.participantCount != currentState?.summaryState?.participantCount
        
        let updated = titleUpdated || recordingUpdated || participantsUpdated
                
        guard updated else {
            self.currentState = state
            self.currentPeer = peer
            return
        }
        
        if titleUpdated {
            let title: String
            if let custom = state.state.title, !custom.isEmpty {
                title = custom
            } else {
                title = peer.displayTitle
            }
            let layout = TextViewLayout(.initialize(string: title, color: GroupCallTheme.titleColor, font: .medium(.title)), maximumNumberOfLines: 1)
            layout.measure(width: frame.width - 115 - (recordingView != nil ? 80 : 0))
            titleView.update(layout)
        }

        if recordingUpdated {
            if let recordingStartTimestamp = state.state.recordingStartTimestamp {
                let view: GroupCallRecordingView
                if let current = self.recordingView {
                    view = current
                } else {
                    view = GroupCallRecordingView(frame: .zero)
                    addSubview(view)
                    self.recordingView = view
                    
                    if animated {
                        recordingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                view.update(recordingStartTime: recordingStartTimestamp, account: account, recordClick: recordClick)
                
                view.updateParentLayout = { [weak self] in
                    self?.needsLayout = true
                }
            } else {
                if let recordingView = recordingView {
                    self.recordingView = nil
                    if animated {
                        recordingView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false,completion: { [weak recordingView] _ in
                            recordingView?.removeFromSuperview()
                        })
                    } else {
                        recordingView.removeFromSuperview()
                    }
                }
            }

        }
        if participantsUpdated {
            let status: String
            let count: Int
            if let summaryState = state.summaryState {
                status = L10n.voiceChatStatusMembersCountable(summaryState.participantCount)
                count = summaryState.participantCount
            } else {
                status = L10n.voiceChatStatusLoading
                count = 0
            }

            let dynamicResult = DynamicCounterTextView.make(for: status, count: "\(count)", font: .normal(.text), textColor: GroupCallTheme.grayStatusColor, width: frame.width - 140)

            self.statusView.update(dynamicResult.values, animated: animated)

            self.statusView.change(size: dynamicResult.size, animated: animated)
            self.statusView.change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - dynamicResult.size.width) / 2), frame.midY), animated: animated)
        }
        self.currentState = state
        self.currentPeer = peer
        if updated {
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private final class MainVideoContainerView: View {
    private let call: PresentationGroupCall
    
    private(set) var currentVideoView: GroupVideoView?
    private var currentPeer: (PeerId, UInt32)?
    
    private var validLayout: CGSize?
    
    init(call: PresentationGroupCall) {
        self.call = call
        
        super.init()
        
        self.backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func updatePeer(peer: (peerId: PeerId, source: UInt32)?) {
        if self.currentPeer?.0 == peer?.0 && self.currentPeer?.1 == peer?.1 {
            return
        }
        self.currentPeer = peer
        if let (_, source) = peer {
            self.call.makeVideoView(source: source, completion: { [weak self] videoView in
                Queue.mainQueue().async {
                    guard let strongSelf = self, let videoView = videoView else {
                        return
                    }
                    
                    videoView.setVideoContentMode(.resizeAspect)

                    let videoViewValue = GroupVideoView(videoView: videoView)
                    if let currentVideoView = strongSelf.currentVideoView {
                        currentVideoView.removeFromSuperview()
                        strongSelf.currentVideoView = nil
                    }
                    strongSelf.currentVideoView = videoViewValue
                    strongSelf.addSubview(videoViewValue)
                    if let size = strongSelf.validLayout {
                        strongSelf.update(size: size, transition: .immediate)
                    }
                }
            })
        } else {
            if let currentVideoView = self.currentVideoView {
                currentVideoView.removeFromSuperview()
                self.currentVideoView = nil
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        if let currentVideoView = self.currentVideoView {
            currentVideoView.frame = CGRect(origin: CGPoint(), size: size)
           // transition.updateFrame(node: currentVideoView, frame: CGRect(origin: CGPoint(), size: size))
            currentVideoView.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func layout() {
        super.layout()
        update(size: frame.size, transition: .immediate)
    }
}


private final class GroupCallView : View {
    let peersTable: TableView = TableView(frame: NSMakeRect(0, 0, 340, 329))
    let titleView: GroupCallTitleView = GroupCallTitleView(frame: NSMakeRect(0, 0, 380, 54))
    private let peersTableContainer: View = View(frame: NSMakeRect(0, 0, 340, 329))
    private let controlsContainer = GroupCallControlsView(frame: .init(x: 0, y: 0, width: 360, height: 320))
    
    private var mainVideoView: MainVideoContainerView? = nil
    
    fileprivate var arguments: GroupCallUIArguments? {
        didSet {
            controlsContainer.arguments = arguments
        }
    }
    
    override func viewDidMoveToWindow() {
        if window == nil {
            var bp:Int = 0
            bp += 1
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(peersTableContainer)
        addSubview(peersTable)
        addSubview(controlsContainer)
        peersTableContainer.layer?.cornerRadius = 10
        updateLocalizationAndTheme(theme: theme)

        peersTable._mouseDownCanMoveWindow = true
        
        peersTable.getBackgroundColor = {
            .clear
        }
        peersTable.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] pos in
            guard let `self` = self else {
                return
            }
            self.peersTableContainer.frame = self.substrateRect()
        }))
    }
    
    private func substrateRect() -> NSRect {
        var h = self.peersTable.listHeight
        if peersTable.documentOffset.y < 0 {
            h -= peersTable.documentOffset.y
        }
        h = min(h, self.peersTable.frame.height)
        return .init(origin:  tableRect.origin, size: NSMakeSize(self.peersTable.frame.width, h))

    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        peersTableContainer.backgroundColor = GroupCallTheme.membersColor
        backgroundColor = GroupCallTheme.windowBackground
        titleView.backgroundColor = GroupCallTheme.windowBackground
    }
    
    override func layout() {
        super.layout()
        
        let isVertical = isFullScreen && state?.currentDominantSpeakerWithVideo != nil
        
        peersTable.frame = tableRect
        peersTableContainer.frame = substrateRect()
        if isVertical {
            controlsContainer.centerX(y: frame.height - controlsContainer.frame.height + 50, addition: peersTable.frame.width / 2)
        } else {
            controlsContainer.centerX(y: frame.height - controlsContainer.frame.height + 50)
        }
        titleView.frame = NSMakeRect(0, 0, frame.width, 54)
        mainVideoView?.frame = mainVideoRect
    }
    
    
    private var tableRect: NSRect {
        var size = peersTable.frame.size
        let width = min(frame.width - 40, 600)
        if let state = state, state.currentDominantSpeakerWithVideo != nil {
            if isFullScreen {
                size = NSMakeSize(80, frame.height - 40 - 10)
            } else {
                size = NSMakeSize(width, frame.height - round(width * 0.4) - 271 )
            }
        } else {
            size = NSMakeSize(width, frame.height - 271)
        }
        var rect = focus(size)
        rect.origin.y = 53
        
        if let state = state, state.currentDominantSpeakerWithVideo != nil {
            if !isFullScreen {
                rect.origin.y = mainVideoRect.maxY + 10
            } else {
                rect.origin.x = 10
                rect.origin.y = 40
            }
        }
        return rect
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        let prevFullScreen = self.isFullScreen
        super.setFrameSize(newSize)
        
        if prevFullScreen != self.isFullScreen, let state = self.state {
            updateUIAfterFullScreenUpdated(state, reloadTable: true)
        }
    }
    
    var isFullScreen: Bool {
        if frame.width > fullScreenThreshold {
            return true
        }
        return false
    }
    
    private var mainVideoRect: NSRect {
        var rect: CGRect
        if isFullScreen {
            let width = frame.width - 100
            let height = frame.height
            rect = CGRect(origin: .init(x: 100, y: 0), size: .init(width: width, height: height))
        } else {
            let width = min(frame.width - 40, 600)
            rect = focus(NSMakeSize(width, width * 0.4))
            rect.origin.y = 53
        }
        return rect
    }
    
    var state: GroupCallUIState?
    
    func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
                
        let previousState = self.state
        self.state = state
        peersTable.merge(with: transition)
        titleView.update(state.peer, state, call.account, recordClick: { [weak self, weak state] in
            if let state = state {
                self?.arguments?.recordClick(state.state)
            }
        }, animated: animated)
        controlsContainer.update(state, voiceSettings: state.voiceSettings, audioLevel: state.myAudioLevel, animated: animated)
            
        if let currentDominantSpeakerWithVideo = state.currentDominantSpeakerWithVideo {
            let mainVideo: MainVideoContainerView
            var isPresented: Bool = false
            if let video = self.mainVideoView {
                mainVideo = video
            } else {
                mainVideo = MainVideoContainerView(call: call)
                mainVideo.frame = mainVideoRect
                self.mainVideoView = mainVideo
                addSubview(mainVideo, positioned: .below, relativeTo: controlsContainer)
                isPresented = true
            }
            mainVideo.updatePeer(peer: currentDominantSpeakerWithVideo)
            
            
            if isPresented && animated {
                mainVideo.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                mainVideo.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.4, bounce: false)
            }
        } else {
            if let mainVideo = self.mainVideoView {
                self.mainVideoView = nil
                if animated {
                    mainVideo.layer?.animateAlpha(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak mainVideo] _ in
                        mainVideo?.removeFromSuperview()
                    })
                    mainVideo.layer?.animateScaleSpring(from: 1, to: 0.01, duration: 0.2, removeOnCompletion: false, bounce: false)
                } else {
                    mainVideo.removeFromSuperview()
                }
            }
        }
        
      
        
        mainVideoView?.change(pos: mainVideoRect.origin, animated: animated)
        mainVideoView?.change(size: mainVideoRect.size, animated: animated)

        peersTable.change(pos: tableRect.origin, animated: animated)
        peersTable.change(size: tableRect.size, animated: animated)
        
        peersTableContainer.change(pos: substrateRect().origin, animated: animated)
        peersTableContainer.change(size: substrateRect().size, animated: animated)

        updateUIAfterFullScreenUpdated(state, reloadTable: false)
        
        
        let currentSpeakerWithVideo = state.currentDominantSpeakerWithVideo
        let previousSpeakerWithVideo = previousState?.currentDominantSpeakerWithVideo

        
        if previousSpeakerWithVideo?.0 != currentSpeakerWithVideo?.0
            || previousSpeakerWithVideo?.1 != currentSpeakerWithVideo?.1
            || previousState?.isFullScreen != state.isFullScreen {
            needsLayout = true
        }
    }
    
    private func updateUIAfterFullScreenUpdated(_ state: GroupCallUIState, reloadTable: Bool) {
        let isVertical = isFullScreen && state.currentDominantSpeakerWithVideo != nil
        
        peersTableContainer.isHidden = isVertical
        peersTable.layer?.cornerRadius = isVertical ? 0 : 10
        
        mainVideoView?.layer?.cornerRadius = isVertical ? 0 : 10
        
        if reloadTable {
            peersTable.enumerateItems(with: { item in
                item.redraw(animated: false, options: .none, presentAsNew: true)
                return true
            })
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


struct PeerGroupCallData : Equatable, Comparable {

    
    struct AudioLevel {
        let timestamp: Int32
        let value: Float
    }

    let peer: Peer
    let state: GroupCallParticipantsContext.Participant?
    let isSpeaking: Bool
    let isInvited: Bool
    let unsyncVolume: Int32?
    let isPinned: Bool
    let accountPeerId: PeerId
    let accountAbout: String?
    let canManageCall: Bool
    let hideWantsToSpeak: Bool
    let activityTimestamp: Int32
    let firstTimestamp: Int32
    let videoMode: Bool
    var isRaisedHand: Bool {
        return self.state?.hasRaiseHand == true
    }
    var wantsToSpeak: Bool {
        return isRaisedHand && !hideWantsToSpeak
    }
    
    var about: String? {
        let about: String?
        if self.peer.id == accountPeerId {
            about = accountAbout
        } else {
            about = self.state?.about
        }
        if let about = about, about.isEmpty {
            return nil
        } else {
            return about
        }
    }
    
    var index: Int32 {
        return 0
    }
    
    private var weight: Int {
        var weight: Int = 0
                
        
        return weight
    }
    
    static func ==(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.isInvited != rhs.isInvited {
            return false
        }
        if lhs.isPinned != rhs.isPinned {
            return false
        }
        if lhs.unsyncVolume != rhs.unsyncVolume {
            return false
        }
        if lhs.firstTimestamp != rhs.firstTimestamp {
            return false
        }
        if lhs.accountPeerId != rhs.accountPeerId {
            return false
        }
        if lhs.accountAbout != rhs.accountAbout {
            return false
        }
        if lhs.hideWantsToSpeak != rhs.hideWantsToSpeak {
            return false
        }
        if lhs.videoMode != rhs.videoMode {
            return false
        }
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if lhs.activityTimestamp != rhs.activityTimestamp {
            return lhs.activityTimestamp > rhs.activityTimestamp
        }
        return lhs.firstTimestamp > rhs.firstTimestamp
    }
}




private final class GroupCallUIState : Equatable {

    struct RecentActive : Equatable {
        let peerId: PeerId
        let timestamp: TimeInterval
    }

    let memberDatas:[PeerGroupCallData]
    let isMuted: Bool
    let state: PresentationGroupCallState
    let summaryState: PresentationGroupCallSummaryState?
    let peer: Peer
    let cachedData: CachedChannelData?
    let myAudioLevel: Float
    let voiceSettings: VoiceCallSettings
    let isWindowVisible: Bool
    let currentDominantSpeakerWithVideo: (PeerId, UInt32)?
    let activeVideoSources: [PeerId: UInt32]
    let isFullScreen: Bool
    init(memberDatas: [PeerGroupCallData], state: PresentationGroupCallState, isMuted: Bool, summaryState: PresentationGroupCallSummaryState?, myAudioLevel: Float, peer: Peer, cachedData: CachedChannelData?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, currentDominantSpeakerWithVideo: (PeerId, UInt32)?, activeVideoSources: [PeerId: UInt32], isFullScreen: Bool) {
        self.summaryState = summaryState
        self.memberDatas = memberDatas
        self.peer = peer
        self.isMuted = isMuted
        self.cachedData = cachedData
        self.state = state
        self.myAudioLevel = myAudioLevel
        self.voiceSettings = voiceSettings
        self.isWindowVisible = isWindowVisible
        self.currentDominantSpeakerWithVideo = currentDominantSpeakerWithVideo
        self.activeVideoSources = activeVideoSources
        self.isFullScreen = isFullScreen
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    static func == (lhs: GroupCallUIState, rhs: GroupCallUIState) -> Bool {
        if lhs.memberDatas != rhs.memberDatas {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.myAudioLevel != rhs.myAudioLevel {
            return false
        }
        if lhs.summaryState != rhs.summaryState {
            return false
        }
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.voiceSettings != rhs.voiceSettings {
            return false
        }
        if let lhsCachedData = lhs.cachedData, let rhsCachedData = rhs.cachedData {
            if !lhsCachedData.isEqual(to: rhsCachedData) {
                return false
            }
        } else if (lhs.cachedData != nil) != (rhs.cachedData != nil) {
            return false
        }
        if lhs.isWindowVisible != rhs.isWindowVisible {
            return false
        }
        if lhs.currentDominantSpeakerWithVideo?.0 != rhs.currentDominantSpeakerWithVideo?.0 || lhs.currentDominantSpeakerWithVideo?.1 != rhs.currentDominantSpeakerWithVideo?.1 {
            return false
        }
        if lhs.activeVideoSources != rhs.activeVideoSources {
            return false
        }
        if lhs.isFullScreen != rhs.isFullScreen {
            return false
        }
        return true
    }
}

private func makeState(peerView: PeerView, state: PresentationGroupCallState, isMuted: Bool, invitedPeers: [Peer], peerStates: PresentationGroupCallMembers?, myAudioLevel: Float, summaryState: PresentationGroupCallSummaryState?, voiceSettings: VoiceCallSettings, isWindowVisible: Bool, accountPeer: (Peer, String?), unsyncVolumes: [PeerId: Int32], currentDominantSpeakerWithVideo: (PeerId, UInt32)?, activeVideoSources: [PeerId: UInt32], hideWantsToSpeak: Set<PeerId>, isFullScreen: Bool) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let accountPeerId = accountPeer.0.id
    let accountPeerAbout = accountPeer.1
    var activeParticipants: [GroupCallParticipantsContext.Participant] = []
    
    activeParticipants = peerStates?.participants ?? []
    var index: Int32 = 0
    
//    var currentDominantSpeakerWithVideo = currentDominantSpeakerWithVideo
//    if currentDominantSpeakerWithVideo == nil {
//       /// currentDominantSpeakerWithVideo = (accountPeerId, 0)
//    }
    //test
    
    
    if !activeParticipants.contains(where: { $0.peer.id == accountPeerId }) {
        
        memberDatas.append(PeerGroupCallData(peer: accountPeer.0, state: nil, isSpeaking: false, isInvited: false, unsyncVolume: unsyncVolumes[accountPeerId], isPinned: currentDominantSpeakerWithVideo?.0 == accountPeerId, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(accountPeerId), activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil))
        index += 1
    } 




    for value in activeParticipants {
        var isSpeaking = peerStates?.speakingParticipants.contains(value.peer.id) ?? false
        if accountPeerId == value.peer.id, isMuted {
            isSpeaking = false
        }
        memberDatas.append(PeerGroupCallData(peer: value.peer, state: value, isSpeaking: isSpeaking, isInvited: false, unsyncVolume: unsyncVolumes[value.peer.id], isPinned: currentDominantSpeakerWithVideo?.0 == value.peer.id, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: hideWantsToSpeak.contains(value.peer.id), activityTimestamp: Int32.max - 1 - index, firstTimestamp: value.joinTimestamp, videoMode: currentDominantSpeakerWithVideo != nil))
        index += 1
    }
    
    for invited in invitedPeers {
        if !activeParticipants.contains(where: { $0.peer.id == invited.id}) {
            memberDatas.append(PeerGroupCallData(peer: invited, state: nil, isSpeaking: false, isInvited: true, unsyncVolume: nil, isPinned: false, accountPeerId: accountPeerId, accountAbout: accountPeerAbout, canManageCall: state.canManageCall, hideWantsToSpeak: false, activityTimestamp: Int32.max - 1 - index, firstTimestamp: 0, videoMode: currentDominantSpeakerWithVideo != nil))
            index += 1
        }
    }

    return GroupCallUIState(memberDatas: memberDatas.sorted(), state: state, isMuted: isMuted, summaryState: summaryState, myAudioLevel: myAudioLevel, peer: peerViewMainPeer(peerView)!, cachedData: peerView.cachedData as? CachedChannelData, voiceSettings: voiceSettings, isWindowVisible: isWindowVisible, currentDominantSpeakerWithVideo: currentDominantSpeakerWithVideo, activeVideoSources: activeVideoSources, isFullScreen: isFullScreen)
}


private func peerEntries(state: GroupCallUIState, account: Account, arguments: GroupCallUIArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    
    let nameStyle = ControlStyle(font: .normal(.title), foregroundColor: .white)
    
    let canInvite: Bool = true//!state.isFullScreen || state.currentDominantSpeakerWithVideo == nil
    
    if canInvite {
        entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("invite"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.voiceChatInviteInviteMembers, nameStyle: nameStyle, type: .none, viewType: GeneralViewType.singleItem.withUpdatedInsets(NSEdgeInsetsMake(12, 16, 12, 0)), action: {
                arguments.inviteMembers()
            }, drawCustomSeparator: true, thumb: GeneralThumbAdditional(thumb: GroupCallTheme.inviteIcon, textInset: 44, thumbInset: 1), border: [.Bottom], inset: NSEdgeInsets(), customTheme: GroupCallTheme.customTheme)
        }))
        index += 1

    }




    for (i, data) in state.memberDatas.enumerated() {

        let drawLine = i != state.memberDatas.count - 1

        var viewType: GeneralViewType = bestGeneralViewType(state.memberDatas, for: i)
        if i == 0, canInvite {
            viewType = i != state.memberDatas.count - 1 ? .innerItem : .lastItem
        }

        struct Tuple : Equatable {
            let drawLine: Bool
            let data: PeerGroupCallData
            let canManageCall:Bool
            let adminIds: Set<PeerId>
            let viewType: GeneralViewType
        }

        let tuple = Tuple(drawLine: drawLine, data: data, canManageCall: state.state.canManageCall, adminIds: state.state.adminIds, viewType: viewType)


        let comparable = InputDataComparableIndex(data: data, compare: { lhs, rhs in
            let lhs = lhs as? PeerGroupCallData
            let rhs = rhs as? PeerGroupCallData
            if let lhs = lhs, let rhs = rhs {
                return lhs < rhs
            } else {
                return false
            }
        }, equatable: { lhs, rhs in
            let lhs = lhs as? PeerGroupCallData
            let rhs = rhs as? PeerGroupCallData
            if let lhs = lhs, let rhs = rhs {
                return lhs.state == rhs.state
            } else {
                return false
            }
        })
        
        entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("_peer_id_\(data.peer.id.toInt64())"), equatable: InputDataEquatable(tuple), comparable: comparable, item: { initialSize, stableId in
            return GroupCallParticipantRowItem(initialSize, stableId: stableId, account: account, data: tuple.data, canManageCall: tuple.canManageCall, isInvited: tuple.data.isInvited, isLastItem: false, drawLine: drawLine, viewType: viewType, action: {
                
            }, invite: arguments.invite, contextMenu: {
                var items: [ContextMenuItem] = []

                let data = tuple.data
                if let state = tuple.data.state {
                    
                    if data.peer.id == arguments.getAccountPeerId(), data.isRaisedHand {
                        items.append(ContextMenuItem(L10n.voiceChatDownHand, handler: arguments.toggleRaiseHand))
                    }
                    
                    if data.peer.id != arguments.getAccountPeerId(), state.muteState == nil || state.muteState?.canUnmute == true {
                        let volume: ContextMenuItem = .init("Volume", handler: {

                        })

                        let volumeControl = VolumeMenuItemView(frame: NSMakeRect(0, 0, 160, 26))
                        volumeControl.stateImages = (on: NSImage(named: "Icon_VolumeMenu_On")!.precomposed(.white),
                                                     off: NSImage(named: "Icon_VolumeMenu_Off")!.precomposed(.white))
                        volumeControl.value = CGFloat((state.volume ?? 10000)) / 10000.0
                        volumeControl.lineColor = GroupCallTheme.memberSeparatorColor.lighter()
                        volume.view = volumeControl

                        volumeControl.didUpdateValue = { value, sync in
                            if value == 0 {
                                arguments.mute(data.peer.id, true)
                            } else {
                                arguments.setVolume(data.peer.id, Double(value), sync)
                            }
                        }

                        items.append(volume)
                        items.append(ContextSeparatorItem())
                    }
                   // if data.peer.id != arguments.getAccountPeerId() {
                        if arguments.takeVideo(data.peer.id) != nil, let ssrc = state.ssrc {
                            if !arguments.isPinnedVideo(data.peer.id) {
                                items.append(ContextMenuItem(L10n.voiceChatPinVideo, handler: {
                                    if data.peer.id != arguments.getAccountPeerId() {
                                        arguments.pinVideo(data.peer.id, ssrc)
                                    } else {
                                        arguments.pinVideo(data.peer.id, 0)
                                    }
                                }))
                            } else {
                                items.append(ContextMenuItem(L10n.voiceChatUnpinVideo, handler: {
                                    arguments.unpinVideo()
                                }))
                            }
                        }
                  //  }
                    
                    
                    if !tuple.canManageCall, data.peer.id != arguments.getAccountPeerId() {
                        if let muteState = state.muteState {
                            if muteState.mutedByYou {
                                items.append(.init(L10n.voiceChatUnmuteForMe, handler: {
                                    arguments.mute(data.peer.id, false)
                                }))
                            } else {
                                items.append(.init(L10n.voiceChatMuteForMe, handler: {
                                    arguments.mute(data.peer.id, true)
                                }))
                            }
                        } else {
                            items.append(.init(L10n.voiceChatMuteForMe, handler: {
                                arguments.mute(data.peer.id, true)
                            }))
                        }                        
                        items.append(ContextSeparatorItem())
                    }
                    
                    if tuple.canManageCall, data.peer.id != arguments.getAccountPeerId() {
                        if tuple.adminIds.contains(data.peer.id) {
                            if state.muteState == nil {
                                items.append(.init(L10n.voiceChatMutePeer, handler: {
                                    arguments.mute(data.peer.id, true)
                                }))
                            }
                            if !tuple.adminIds.contains(data.peer.id), !tuple.data.peer.isChannel {
                                items.append(.init(L10n.voiceChatRemovePeer, handler: {
                                    arguments.remove(data.peer)
                                }))
                            }
                            if !items.isEmpty {
                                items.append(ContextSeparatorItem())
                            }
                        } else if let muteState = state.muteState, !muteState.canUnmute {
                            items.append(.init(L10n.voiceChatUnmutePeer, handler: {
                                arguments.mute(data.peer.id, false)
                            }))
                        } else {
                            items.append(.init(L10n.voiceChatMutePeer, handler: {
                                arguments.mute(data.peer.id, true)
                            }))
                        }
                        if !tuple.adminIds.contains(data.peer.id), !tuple.data.peer.isChannel {
                            items.append(.init(L10n.voiceChatRemovePeer, handler: {
                                arguments.remove(data.peer)
                            }))
                        }
                        if !items.isEmpty {
                            items.append(ContextSeparatorItem())
                        }
                    }
                    
                    if data.peer.id != arguments.getAccountPeerId() {
                        items.append(.init(L10n.voiceChatShowInfo, handler: {
                            arguments.openInfo(data.peer)
                        }))
                    }
                }
                return .single(items)
            }, takeVideo: {
                return arguments.takeVideo(data.peer.id)
            }, audioLevel: arguments.audioLevel)
        }))
//        index += 1

    }
    
    return entries
}



final class GroupCallUIController : ViewController {
    
    final class UIData {
        let call: PresentationGroupCall
        let peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager
        init(call: PresentationGroupCall, peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager) {
            self.call = call
            self.peerMemberContextsManager = peerMemberContextsManager
        }
    }
    private let data: UIData
    private let disposable = MetaDisposable()
    private let pushToTalkDisposable = MetaDisposable()
    private let requestPermissionDisposable = MetaDisposable()
    private let voiceSourcesDisposable = MetaDisposable()
    private var pushToTalk: PushToTalk?
    private let actionsDisposable = DisposableSet()
    private var canManageCall: Bool = false
    private let connecting = MetaDisposable()
    private let isFullScreen = ValuePromise(false, ignoreRepeated: true)
    private weak var sharing: DesktopCapturerWindow?
    
    private var requestedVideoSources = Set<UInt32>()
    private var videoViews: [(PeerId, UInt32, GroupVideoView)] = []
    private var currentDominantSpeakerWithVideoSignal:Promise<(PeerId, UInt32)?> = Promise(nil)
    private var currentDominantSpeakerWithVideo: (PeerId, UInt32)? {
        didSet {
            currentDominantSpeakerWithVideoSignal.set(.single(currentDominantSpeakerWithVideo))
        }
    }

    
    var disableSounds: Bool = false
    init(_ data: UIData, size: NSSize) {
        self.data = data
        super.init(frame: NSMakeRect(0, 0, size.width, size.height))
        bar = .init(height: 0)
        isFullScreen.set(size.width > fullScreenThreshold)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        self.isFullScreen.set(size.width > fullScreenThreshold)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let actionsDisposable = self.actionsDisposable
                
        let peerId = self.data.call.peerId
        let account = self.data.call.account

                
        let displayedRaisedHandsPromise = ValuePromise<Set<PeerId>>([], ignoreRepeated: true)
        let displayedRaisedHands: Atomic<Set<PeerId>> = Atomic(value: [])
        
        var raisedHandDisplayDisposables: [PeerId: Disposable] = [:]


        let updateDisplayedRaisedHands:(@escaping(Set<PeerId>)->Set<PeerId>)->Void = { f in
            _ = displayedRaisedHands.modify(f)
        }
        
        
        
        guard let window = self.navigationController?.window else {
            fatalError()
        }
        
        let animate: Signal<Bool, NoError> = window.takeOcclusionState |> map {
            $0.contains(.visible)
        }

        self.pushToTalk = PushToTalk(sharedContext: data.call.sharedContext, window: window)

        let sharedContext = self.data.call.sharedContext
        
        let unsyncVolumes = ValuePromise<[PeerId: Int32]>([:])
        
        var askedForSpeak: Bool = false
        
        let arguments = GroupCallUIArguments(leave: { [weak self] in

            guard let `self` = self, let window = self.window else {
                return
            }
            if self.canManageCall {
                modernConfirm(for: window, account: account, peerId: nil, header: L10n.voiceChatEndTitle, information: L10n.voiceChatEndText, okTitle: L10n.voiceChatEndOK, thridTitle: L10n.voiceChatEndThird, thridAutoOn: false, successHandler: {
                    [weak self] result in
                    _ = self?.data.call.sharedContext.endGroupCall(terminate: result == .thrid).start()
                })
            } else {
                _ = self.data.call.sharedContext.endGroupCall(terminate: false).start()
            }
        }, settings: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.navigationController?.push(GroupCallSettingsController(sharedContext: sharedContext, account: account, call: self.data.call))
        }, invite: { [weak self] peerId in
            _ = self?.data.call.invitePeer(peerId)
        }, mute: { [weak self] peerId, isMuted in
            _ = self?.data.call.updateMuteState(peerId: peerId, isMuted: isMuted)
        }, toggleSpeaker: { [weak self] in
            self?.data.call.toggleIsMuted()
        }, remove: { [weak self] peer in
            guard let window = self?.window else {
                return
            }
            let isChannel = self?.data.call.peer?.isChannel == true
            
            modernConfirm(for: window, account: account, peerId: peer.id, information: isChannel ? L10n.voiceChatRemovePeerConfirmChannel(peer.displayTitle) : L10n.voiceChatRemovePeerConfirm(peer.displayTitle), okTitle: L10n.voiceChatRemovePeerConfirmOK, cancelTitle: L10n.voiceChatRemovePeerConfirmCancel, successHandler: { [weak window] _ in

                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    _ = self?.data.peerMemberContextsManager.updateMemberBannedRights(account: account, peerId: peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: 0)).start()
                } else if let window = window {
                    _ = showModalProgress(signal: removePeerMember(account: account, peerId: peerId, memberId: peer.id), for: window).start()
                }

            }, appearance: darkPalette.appearance)
        }, openInfo: { [weak self] peer in
            guard let window = self?.window else {
                return
            }
            showModal(with: GroupCallPeerController(account: account, peer: peer), for: window)
//            appDelegate?.navigateProfile(peerId, account: account)
        }, inviteMembers: { [weak self] in
            guard let window = self?.window, let data = self?.data else {
                return
            }
            
            actionsDisposable.add(GroupCallAddmembers(data, window: window).start(next: { [weak window, weak self] peerId in
                if let peerId = peerId.first, let window = window, let `self` = self {
                    if self.data.call.invitePeer(peerId) {
                        _ = showModalSuccess(for: window, icon: theme.icons.successModalProgress, delay: 2.0).start()
                    }
                }
            }))
                
        }, shareSource: { [weak self] in
            self?.sharing = presentDesktopCapturerWindow(select: { [weak self] source in
                self?.data.call.requestVideo(deviceId: source.deviceIdKey())
            }, devices: sharedContext.devicesContext)
        }, takeVideo: { [weak self] peerId in
            return self?.videoViews.first(where: { $0.0 == peerId })?.2
        }, pinVideo: { [weak self] peerId, ssrc in
            self?.currentDominantSpeakerWithVideo = (peerId, ssrc)
            self?.data.call.setFullSizeVideo(peerId: peerId)
        }, unpinVideo: { [weak self]  in
            self?.currentDominantSpeakerWithVideo = nil
            self?.data.call.setFullSizeVideo(peerId: nil)
        }, isPinnedVideo: { [weak self] peerId in
            return self?.currentDominantSpeakerWithVideo?.0 == peerId
        }, setVolume: { [weak self] peerId, volume, sync in
            let value = Int32(volume * 10000)
            self?.data.call.setVolume(peerId: peerId, volume: value, sync: sync)
            if sync {
                unsyncVolumes.set([:])
            } else {
                unsyncVolumes.set([peerId : value])
            }
        }, getAccountPeerId:{ [weak self] in
            return self?.data.call.joinAsPeerId
        }, cancelSharing: { [weak self] in
            self?.data.call.disableVideo()
        }, toggleRaiseHand: { [weak self] in
            if let strongSelf = self, let state = self?.genericView.state {
                let call = strongSelf.data.call
                
                if !state.state.raisedHand {
                    askedForSpeak = true
                    call.raiseHand()
                } else {
                    askedForSpeak = false
                    call.lowerHand()
                }
            }
        }, recordClick: { [weak self] state in
            if let window = self?.window {
                if state.canManageCall {
                    confirm(for: window, header: L10n.voiceChatRecordingStopTitle, information: L10n.voiceChatRecordingStopText, okTitle: L10n.voiceChatRecordingStopOK, successHandler: { [weak window] _ in
                        self?.data.call.setShouldBeRecording(false, title: nil)
                        if let window = window {
                            showModalText(for: window, text: L10n.voiceChatToastStop)
                        }
                    })
                } else {
                    showModalText(for: window, text: L10n.voiceChatAlertRecording)
                }
            }
        }, audioLevel: { [weak self] peerId in
            if let call = self?.data.call {
                if peerId == call.joinAsPeerId {
                    return combineLatest(animate, call.myAudioLevel)
                        |> map (Optional.init)
                        |> map { $0?.1 == 0 || $0?.0 == false ? nil : $0?.1 }
                        |> deliverOnMainQueue
                } else {
                    return combineLatest(animate, call.audioLevels) |> map { (visible, values) in
                        if visible {
                            for value in values {
                                if value.0 == peerId {
                                    return value.2
                                }
                            }
                        }
                        return nil
                    } |> deliverOnMainQueue
                }
            }
            return nil
        })
        

        genericView.arguments = arguments
        
        self.voiceSourcesDisposable.set((self.data.call.incomingVideoSources |> deliverOnMainQueue).start(next: { [weak self] sources in
                    guard let strongSelf = self else {
                        return
                    }
                    var updated = false
                    var validSources = Set<UInt32>()
                    for (peerId, source) in sources {
                        validSources.insert(source)
                        if !strongSelf.requestedVideoSources.contains(source) {
                            strongSelf.requestedVideoSources.insert(source)
                            strongSelf.data.call.makeVideoView(source: source, completion: { videoView in
                                Queue.mainQueue().async {
                                    guard let strongSelf = self, let videoView = videoView else {
                                        return
                                    }
                                    let videoViewValue = GroupVideoView(videoView: videoView)
                                    videoView.setVideoContentMode(.resizeAspectFill)

                                    strongSelf.videoViews.append((peerId, source, videoViewValue))
                                    strongSelf.genericView.peersTable.enumerateItems(with: { item in
                                        item.redraw(animated: true)
                                        return true
                                    })
                                }
                            })
                        }
                    }

                    for i in (0 ..< strongSelf.videoViews.count).reversed() {
                        if !validSources.contains(strongSelf.videoViews[i].1) {
                            let ssrc = strongSelf.videoViews[i].1
                            strongSelf.videoViews.remove(at: i)
                            strongSelf.requestedVideoSources.remove(ssrc)
                            updated = true
                       }
                   }

                    if let (_, source) = strongSelf.currentDominantSpeakerWithVideo {
                        if !validSources.contains(source) {
                            strongSelf.currentDominantSpeakerWithVideo = nil
                            strongSelf.data.call.setFullSizeVideo(peerId: nil)
                           //strongSelf.mainVideoContainer.updatePeer(peer: nil)
                        }
                    }

                    if updated {
                        strongSelf.genericView.peersTable.enumerateItems(with: { item in
                            item.redraw(animated: true)
                            return true
                        })
                    }
                }))

        
        
        let members: Signal<PresentationGroupCallMembers?, NoError> = self.data.call.members
        

        
        let invited: Signal<[Peer], NoError> = self.data.call.invitedPeers |> mapToSignal { ids in
            return account.postbox.transaction { transaction -> [Peer] in
                var peers:[Peer] = []
                for id in ids {
                    if let peer = transaction.getPeer(id) {
                        peers.append(peer)
                    }
                }
                return peers
            }
        }
        
               
        let queue = Queue(name: "voicechat.ui")

        let joinAsPeer:Signal<(Peer, String?), NoError> = self.data.call.joinAsPeerIdValue |> mapToSignal {
            return account.postbox.peerView(id: $0) |> map { view in
                if let cachedData = view.cachedData as? CachedChannelData {
                    return (peerViewMainPeer(view)!, cachedData.about)
                } else if let cachedData = view.cachedData as? CachedUserData {
                    return (peerViewMainPeer(view)!, cachedData.about)
                } else {
                    return (peerViewMainPeer(view)!, nil)
                }
            }
        }
        
        let some = combineLatest(queue: .mainQueue(), self.data.call.isMuted, animate, joinAsPeer, unsyncVolumes.get(), currentDominantSpeakerWithVideoSignal.get(), self.data.call.incomingVideoSources, isFullScreen.get())


        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: .mainQueue(), self.data.call.state, members, (.single(0) |> then(data.call.myAudioLevel)), account.viewTracker.peerView(peerId), invited, self.data.call.summaryState, voiceCallSettings(data.call.sharedContext.accountManager), some, displayedRaisedHandsPromise.get()) |> mapToQueue { values in
            return .single(makeState(peerView: values.3,
                                     state: values.0,
                                     isMuted: values.7.0,
                                     invitedPeers: values.4,
                                     peerStates: values.1,
                                     myAudioLevel: values.2,
                                     summaryState: values.5,
                                     voiceSettings: values.6,
                                     isWindowVisible: values.7.1,
                                     accountPeer: values.7.2,
                                     unsyncVolumes: values.7.3,
                                     currentDominantSpeakerWithVideo: values.7.4,
                                     activeVideoSources: values.7.5,
                                     hideWantsToSpeak: values.8,
                                     isFullScreen: values.7.6))
        } |> distinctUntilChanged
        
        
//        var invokeAfterTransaction:()
//        window.processFullScreen = { f in
//
//        }
//
        let initialSize = self.atomicSize
        var previousIsFullScreen: Bool = initialSize.with { $0.width > fullScreenThreshold }
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let animated: Atomic<Bool> = Atomic(value: false)
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {})
        
                
        let transition: Signal<(GroupCallUIState, TableUpdateTransition), NoError> = combineLatest(state, appearanceSignal) |> mapToQueue { state, appAppearance in
            let current = peerEntries(state: state, account: account, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
            let previous = previousEntries.swap(current)
            
            let signal = prepareInputDataTransition(left: previous, right: current, animated: abs(current.count - previous.count) <= 10 && state.isWindowVisible && state.isFullScreen == previousIsFullScreen, searchState: nil, initialSize: initialSize.with { $0 - NSMakeSize(40, 0) }, arguments: inputArguments, onMainQueue: state.isFullScreen != previousIsFullScreen)
            
            previousIsFullScreen = state.isFullScreen
            
            return combineLatest(.single(state), signal)
        } |> deliverOnMainQueue
        
        var currentState: PresentationGroupCallState?
        
        self.disposable.set(transition.start { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            switch value.0.state.networkState {
            case .connected:
                var notifyCanSpeak: Bool = false
                var notifyStartRecording: Bool = false
                
                if let previous = currentState {
                    if previous.muteState != value.0.state.muteState {
                        if askedForSpeak, let muteState = value.0.state.muteState, muteState.canUnmute {
                            notifyCanSpeak = true
                        }
                    }
                    if previous.recordingStartTimestamp == nil && value.0.state.recordingStartTimestamp != nil {
                        notifyStartRecording = true
                    }
                }
                if notifyCanSpeak {
                    askedForSpeak = false
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_unmuted")
                    if let window = strongSelf.window {
                        showModalText(for: window, text: L10n.voiceChatToastYouCanSpeak)
                    }
                }
                if notifyStartRecording {
                    SoundEffectPlay.play(postbox: account.postbox, name: "voip_group_recording_started")
                    if let window = strongSelf.window {
                        showModalText(for: window, text: L10n.voiceChatAlertRecording)
                    }
                }
            case .connecting:
                break
            }
            currentState = value.0.state
            
            
            strongSelf.applyUpdates(value.0, value.1, strongSelf.data.call, animated: animated.swap(true))
            strongSelf.readyOnce()
            
            for member in value.0.memberDatas {
                if member.isRaisedHand {
                    let displayedRaisedHands = displayedRaisedHands.with { $0 }
                    let signal: Signal<Never, NoError> = Signal.complete() |> delay(3.0, queue: Queue.mainQueue())
                    if !displayedRaisedHands.contains(member.peer.id) {
                        if raisedHandDisplayDisposables[member.peer.id] == nil {
                            raisedHandDisplayDisposables[member.peer.id] = signal.start(completed: {
                                updateDisplayedRaisedHands { current in
                                    var current = current
                                    current.insert(member.peer.id)
                                    return current
                                }
                                raisedHandDisplayDisposables[member.peer.id] = nil
                            })
                        }
                    }
                } else {
                    raisedHandDisplayDisposables[member.peer.id]?.dispose()
                    raisedHandDisplayDisposables[member.peer.id] = nil
                    updateDisplayedRaisedHands { current in
                        var current = current
                        current.remove(member.peer.id)
                        return current
                    }
                }
            }
            DispatchQueue.main.async {
                displayedRaisedHandsPromise.set(displayedRaisedHands.with { $0 })
            }
        })
        

        self.onDeinit = {
            currentState = nil
            _ = previousEntries.swap([])
        }

        genericView.peersTable.setScrollHandler { [weak self] position in
            switch position.direction {
            case .bottom:
                self?.data.call.loadMore()
            default:
                break
            }
        }

        var connectedMusicPlayed: Bool = false
        
        let connecting = self.connecting
                
        pushToTalkDisposable.set(combineLatest(queue: .mainQueue(), data.call.state, data.call.isMuted, data.call.canBeRemoved).start(next: { [weak self] state, isMuted, canBeRemoved in
            
            let disableSounds = self?.disableSounds ?? true
            
            switch state.networkState {
            case .connected:
                if !connectedMusicPlayed && !disableSounds {
                    SoundEffectPlay.play(postbox: account.postbox, name: "call up")
                    connectedMusicPlayed = true
                }
                if canBeRemoved, connectedMusicPlayed  && !disableSounds {
                    SoundEffectPlay.play(postbox: account.postbox, name: "call down")
                }
                connecting.set(nil)
            case .connecting:
                connecting.set((Signal<Void, NoError>.single(Void()) |> delay(3.0, queue: .mainQueue()) |> restart).start(next: {
                    SoundEffectPlay.play(postbox: account.postbox, name: "reconnecting")
                }))
            }

            self?.pushToTalk?.update = { [weak self] mode in
                switch state.networkState {
                case .connected:
                    switch mode {
                    case .speaking:
                        if isMuted {
                            if let muteState = state.muteState {
                                if muteState.canUnmute {
                                    self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                    self?.pushToTalkIsActive = true
                                }
                            }
                        }
                    case .waiting:
                        if !isMuted, self?.pushToTalkIsActive == true {
                            self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                        }
                        self?.pushToTalkIsActive = false
                    case .toggle:
                        if let muteState = state.muteState {
                            if muteState.canUnmute {
                                self?.data.call.setIsMuted(action: .unmuted)
                            }
                        } else {
                            self?.data.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                        }
                    }
                case .connecting:
                    break
                }
            }
        }))
        
        var hasMicroPermission: Bool? = nil
        
        let alertPermission = { [weak self] in
            guard let window = self?.window else {
                return
            }
            confirm(for: window, information: L10n.voiceChatRequestAccess, okTitle: L10n.modalOK, cancelTitle: "", thridTitle: L10n.requestAccesErrorConirmSettings, successHandler: { result in
                switch result {
                case .thrid:
                    openSystemSettings(.microphone)
                default:
                    break
                }
            }, appearance: darkPalette.appearance)
        }
        
        data.call.permissions = { action, f in
            switch action {
            case .unmuted, .muted(isPushToTalkActive: true):
                if let permission = hasMicroPermission {
                    f(permission)
                    if !permission {
                        alertPermission()
                    }
                } else {
                    _ = requestMicrophonePermission().start(next: { permission in
                        hasMicroPermission = permission
                        f(permission)
                        if !permission {
                            alertPermission()
                        }
                    })
                }
            default:
                f(true)
            }
        }
        
    }
    
    override func readyOnce() {
        let was = self.didSetReady
        super.readyOnce()
        if didSetReady, !was {
            requestPermissionDisposable.set(requestMicrophonePermission().start())
        }
    }
    
    private var pushToTalkIsActive: Bool = false

    
    private func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
        self.genericView.applyUpdates(state, transition, call, animated: transition.animated)
        canManageCall = state.state.canManageCall
    }
    
    deinit {
        disposable.dispose()
        pushToTalkDisposable.dispose()
        requestPermissionDisposable.dispose()
        actionsDisposable.dispose()
        connecting.dispose()
        sharing?.orderOut(nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    private var genericView: GroupCallView {
        return self.view as! GroupCallView
    }
    
    
    override func viewClass() -> AnyClass {
        return GroupCallView.self
    }
}
