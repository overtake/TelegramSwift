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

private final class GroupCallUIArguments {
    let leave:()->Void
    let settings:()->Void
    let invite:(PeerId)->Void
    let mute:(PeerId)->Void
    let toggleSpeaker:()->Void
    init(leave:@escaping()->Void,
    settings:@escaping()->Void,
    invite:@escaping(PeerId)->Void,
    mute:@escaping(PeerId)->Void,
    toggleSpeaker:@escaping()->Void) {
        self.leave = leave
        self.invite = invite
        self.mute = mute
        self.settings = settings
        self.toggleSpeaker = toggleSpeaker
    }
}

private final class GroupCallControlsView : View {
    private let speak: GroupCallSpeakButton = GroupCallSpeakButton(frame: NSMakeRect(0, 0, 144, 144))
    private let settings: CallControl = CallControl(frame: .zero)
    private let end: CallControl = CallControl(frame: .zero)
    private var speakText: TextView?
    fileprivate var arguments: GroupCallUIArguments?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(speak)
        addSubview(settings)
        addSubview(end)
        
        end.set(handler: { [weak self] _ in
            self?.arguments?.leave()
        }, for: .Click)
        
        end.set(handler: { [weak self] _ in
            self?.arguments?.settings()
        }, for: .Click)
        
        speak.set(handler: { [weak self] _ in
            self?.arguments?.toggleSpeaker()
        }, for: .Click)
    }
    
    private var preiousState: PresentationGroupCallState?
    
    func update(_ state: PresentationGroupCallState, audioLevel: Float?, animated: Bool) {
                
        speak.update(with: state, audioLevel: audioLevel, animated: animated)
        
        if state != preiousState {
            
            end.updateWithData(CallControlData(text: "Leave", isVisualEffect: false, icon: GroupCallTheme.declineIcon, iconSize: NSMakeSize(60, 60), backgroundColor: GroupCallTheme.declineColor), animated: animated)

            settings.updateWithData(CallControlData(text: "Settings", isVisualEffect: false, icon: GroupCallTheme.settingsIcon, iconSize: NSMakeSize(60, 60), backgroundColor: GroupCallTheme.settingsColor), animated: animated)

            
            let statusText: String
            switch state.networkState {
            case .connected:
                if state.isMuted {
                    statusText = "Click to Unmute"
                } else {
                    statusText = "You're Live"
                }
            case .connecting:
                statusText = "Connecting..."
            }
            
            let speakText = TextView()
            speakText.userInteractionEnabled = false
            speakText.isSelectable = false
            let layout = TextViewLayout(.initialize(string: statusText, color: .white, font: .normal(.title)))
            layout.measure(width: frame.width - 60)
            speakText.update(layout)
            
            if let speakText = self.speakText {
                self.speakText = nil
                if animated {
                    speakText.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak speakText] _ in
                        speakText?.removeFromSuperview()
                    })
                    speakText.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.2)
                } else {
                    speakText.removeFromSuperview()
                }
            }
            
            
            self.speakText = speakText
            addSubview(speakText)
            speakText.centerX(y: speak.frame.maxY + 10)
            if animated {
                speakText.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                speakText.layer?.animateScaleSpring(from: 0.2, to: 1, duration: 0.2)
            }
        }
        self.preiousState = state
        needsLayout = true

    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        speak.center()
        settings.centerY(x: 60)
        end.centerY(x: frame.width - end.frame.width - 60)
        if let speakText = speakText {
            speakText.centerX(y: speak.frame.maxY + 10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class GroupCallTitleView : View {
    fileprivate let titleView: TextView = TextView()
    fileprivate let statusView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(statusView)
        titleView.isSelectable = false
        statusView.isSelectable = false
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
        titleView.centerX(y: frame.midY - titleView.frame.height)
        statusView.centerX(y: frame.midY)
    }
    
    
    func update(_ peer: Peer, _ cachedData: CachedChannelData?) {
        let layout = TextViewLayout(.initialize(string: peer.displayTitle, color: GroupCallTheme.titleColor, font: .medium(.title)), maximumNumberOfLines: 1)
        layout.measure(width: frame.width - 100)
        titleView.update(layout)
        
        let membersCount = cachedData?.participantsSummary.memberCount ?? 0
        let status: String
        if membersCount == 0 {
            status = L10n.peerStatusGroup
        } else {
            status = L10n.peerStatusMemberCountable(Int(membersCount))
        }
        let statusLayout = TextViewLayout.init(.initialize(string: status, color: GroupCallTheme.grayStatusColor, font: .normal(.text)), maximumNumberOfLines: 1)
        statusLayout.measure(width: frame.width - 100)
        statusView.update(statusLayout)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class GroupCallView : View {
    let peersTable: TableView = TableView(frame: NSMakeRect(0, 0, 440, 360))
    let titleView: GroupCallTitleView = GroupCallTitleView(frame: NSMakeRect(0, 0, 480, 54))
    private let peersTableContainer: View = View(frame: NSMakeRect(0, 0, 440, 360))
    private let controlsContainer = GroupCallControlsView(frame: .init(x: 0, y: 0, width: 480, height: 640 - 360 - 54))
    
    fileprivate var arguments: GroupCallUIArguments? {
        didSet {
            controlsContainer.arguments = arguments
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(peersTableContainer)
        addSubview(titleView)
        addSubview(controlsContainer)
        peersTableContainer.layer?.cornerRadius = 10
        peersTableContainer.addSubview(peersTable)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        peersTable.background = GroupCallTheme.membersColor
        backgroundColor = GroupCallTheme.windowBackground
        titleView.backgroundColor = GroupCallTheme.windowBackground
    }
    
    override func layout() {
        super.layout()
        peersTableContainer.centerX(y: 54)
        controlsContainer.centerX(y: peersTableContainer.frame.maxY)
    }
    
    func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, animated: Bool) {
        peersTable.merge(with: transition)
        titleView.update(state.peer, state.cachedData)
        controlsContainer.update(state.state, audioLevel: nil, animated: animated)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private struct PeerGroupCallData : Equatable, Comparable {
    let participant: RenderedChannelParticipant
    let state: PresentationGroupCallMemberState?
    let audioLevel: Float?
    
    private var weight: Int {
        var weight: Int = 0
        
        if let presence = participant.presences[participant.peer.id] as? TelegramUserPresence {
            switch presence.status {
            case let .present(until):
                weight += Int(until)
                weight |= (1 << 28)
            case .recently:
                weight |= (1 << 27)
            case .lastWeek:
                weight |= (1 << 26)
            case .lastMonth:
                weight |= (1 << 25)
            case .none:
                weight |= (1 << 24)
            }
        }
        
        if let state = state {
            weight |= (1 << 28)
            if state.isSpeaking || audioLevel != nil {
                weight |= (1 << 30)
            } else {
                weight |= (1 << 29)
            }
            weight += Int(Int32.max)
        } else if audioLevel != nil {
            weight |= (1 << 30)
            weight += Int(Int32.max)
        }
        return weight
    }
    
    static func ==(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        if lhs.participant != rhs.participant {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.audioLevel != rhs.audioLevel {
            return false
        }
        return true
    }
    
    static func <(lhs: PeerGroupCallData, rhs: PeerGroupCallData) -> Bool {
        return lhs.weight < rhs.weight
    }
}


private struct GroupCallUIState : Equatable {
    let memberDatas:[PeerGroupCallData]
    let state: PresentationGroupCallState
    let peer: Peer
    let cachedData: CachedChannelData?
    init(memberDatas: [PeerGroupCallData], state: PresentationGroupCallState, peer: Peer, cachedData: CachedChannelData?) {
        self.memberDatas = memberDatas
        self.peer = peer
        self.cachedData = cachedData
        self.state = state
        
    }
    
    static func == (lhs: GroupCallUIState, rhs: GroupCallUIState) -> Bool {
        if lhs.memberDatas != rhs.memberDatas {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsCachedData = lhs.cachedData, let rhsCachedData = rhs.cachedData {
            if !lhsCachedData.isEqual(to: rhsCachedData) {
                return false
            }
        } else if (lhs.cachedData != nil) != (rhs.cachedData != nil) {
            return false
        }
        return true
    }
}

private func makeState(_ peerView: PeerView, _ state: PresentationGroupCallState, _ participants: [RenderedChannelParticipant], _ peers:[PeerId: Peer], _ peerStates: [PeerId: PresentationGroupCallMemberState], _ audioLevels: [(PeerId, Float)], _ accountPeerId: PeerId) -> GroupCallUIState {
    
    var memberDatas: [PeerGroupCallData] = []
    
    let audioLevels:[PeerId: Float] = audioLevels.reduce([:], { current, value in
        var current = current
        current[value.0] = value.1
        return current
    })
    
    for participant in participants {
        var participantState = peerStates[participant.peer.id]
        if participant.peer.id == accountPeerId {
            participantState = PresentationGroupCallMemberState(ssrc: UInt32(participant.peer.id.id), isSpeaking: !state.isMuted)
        }
        memberDatas.append(PeerGroupCallData(participant: participant, state: participantState, audioLevel: audioLevels[participant.peer.id]))
    }
    
    return GroupCallUIState(memberDatas: memberDatas.sorted(by: >), state: state, peer: peerViewMainPeer(peerView)!, cachedData: peerView.cachedData as? CachedChannelData)
}


private func peerEntries(state: GroupCallUIState, account: Account, arguments: GroupCallUIArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    
    for (i, data) in state.memberDatas.enumerated() {
        entries.append(.custom(sectionId: 0, index: index, value: .none, identifier: InputDataIdentifier("_peer_id_\(data.participant.peer.id.toInt64())"), equatable: InputDataEquatable(data), item: { initialSize, stableId in
            return GroupCallParticipantRowItem(initialSize, stableId: stableId, account: account, participant: data.participant, state: data.state, audioLevel: data.audioLevel, isLastItem: i == state.memberDatas.count - 1, action: {
                
            }, contextMenu: {
                return .complete()
            })
        }))
        index += 1
    }
    
    return entries
}


final class GroupCallUIController : ViewController {
    
    struct UIData {
        let call: PresentationGroupCall
        let peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager
        init(call: PresentationGroupCall, peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager) {
            self.call = call
            self.peerMemberContextsManager = peerMemberContextsManager
        }
    }
    private let data: UIData
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    init(_ data: UIData) {
        self.data = data
        super.init()
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let arguments = GroupCallUIArguments(leave: { [weak self] in
            _ = self?.data.call.leave().start()
        }, settings: { [weak self] in
            
        }, invite: { [weak self] peerId in
            
        }, mute: { [weak self] peerId in
            
        }, toggleSpeaker: { [weak self] in
            self?.data.call.toggleIsMuted()
        })
        
        genericView.arguments = arguments
        
        let peerId = self.data.call.peerId
        let account = self.data.call.account
        
        var loadMoreControl: PeerChannelMemberCategoryControl?
        
        let channelMembersPromise = Promise<[RenderedChannelParticipant]>()
        let (disposable, control) = data.peerMemberContextsManager.recent(postbox: data.call.account.postbox, network: data.call.account.network, accountPeerId: data.call.peerId, peerId: data.call.peerId, updated: { state in
            channelMembersPromise.set(.single(state.list))
        })
        loadMoreControl = control
        actionsDisposable.add(disposable)
        
        let members: Signal<([PeerId: Peer], [PeerId: PresentationGroupCallMemberState]), NoError> = self.data.call.members |> mapToSignal { members in
            return account.postbox.transaction { transaction in
                var peers:[PeerId: Peer] = [:]
                for (memberId, _) in members {
                    if let peer = transaction.getPeer(memberId) {
                        peers[memberId] = peer
                    }
                }
                return (peers, members)
            }
        }
               
        let state: Signal<GroupCallUIState, NoError> = combineLatest(queue: prepareQueue, self.data.call.state, members, channelMembersPromise.get(), self.data.call.audioLevels, account.viewTracker.peerView(peerId)) |> map {
            return makeState($0.4, $0.0, $0.2, $0.1.0, $0.1.1, $0.3, account.peerId)
        } |> distinctUntilChanged
        
        
        let initialSize = NSMakeSize(440, 360)
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let animated: Atomic<Bool> = Atomic(value: false)
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {})
        
        let transition: Signal<(GroupCallUIState, TableUpdateTransition), NoError> = combineLatest(state, appearanceSignal) |> mapToQueue { state, appAppearance in
            let current = peerEntries(state: state, account: account, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
            return prepareInputDataTransition(left: previousEntries.swap(current), right: current, animated: true, searchState: nil, initialSize: initialSize, arguments: inputArguments, onMainQueue: false) |> map {
                (state, $0)
            }
        } |> deliverOnMainQueue
        
        self.disposable.set(transition.start { [weak self] value in
            self?.applyUpdates(value.0, value.1, animated: animated.swap(true))
            self?.readyOnce()
        })
        
        
        genericView.peersTable.setScrollHandler { [weak self] position in
            switch position.direction {
            case .bottom:
                self?.data.peerMemberContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
            default:
                break
            }
        }
        
    }
    
    private func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, animated: Bool) {
        self.genericView.applyUpdates(state, transition, animated: animated)
    }
    
    deinit {
        disposable.dispose()
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
