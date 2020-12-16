//
//  GroupCallNavigationHeaderView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore



private let blue = NSColor(rgb: 0x0078ff)
private let lightBlue = NSColor(rgb: 0x59c7f8)
private let green = NSColor(rgb: 0x33c659)


private class CallStatusBarBackgroundView: View {
    private let foregroundView: View
    private let foregroundGradientLayer: CAGradientLayer
    private let maskCurveLayer: VoiceCurveLayer
    var audioLevel: Float = 0.0  {
        didSet {
            self.maskCurveLayer.updateLevel(CGFloat(audioLevel))
        }
    }
    

    var speaking:(Bool, Bool)? = nil {
        didSet {
            if let speaking = self.speaking, (speaking.0 != oldValue?.0 || speaking.1 != oldValue?.1) {
                let initialColors = self.foregroundGradientLayer.colors
                let targetColors: [CGColor]
                if speaking.1 {
                    if speaking.0 {
                        targetColors = [green.cgColor, blue.cgColor]
                    } else {
                        targetColors = [blue.cgColor, lightBlue.cgColor]
                    }
                } else {
                    targetColors = [theme.colors.grayIcon.cgColor, theme.colors.grayIcon.lighter().cgColor]
                }
                
                self.foregroundGradientLayer.colors = targetColors
                self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: .linear, duration: 0.3)
            }
        }
    }



    override init() {
        self.foregroundView = View()
        self.foregroundGradientLayer = CAGradientLayer()
        self.maskCurveLayer = VoiceCurveLayer(frame: CGRect(), maxLevel: 2.5, smallCurveRange: (0.0, 0.0), mediumCurveRange: (0.1, 0.55), bigCurveRange: (0.1, 1.0))
        self.maskCurveLayer.setColor(NSColor(rgb: 0xffffff))


        super.init()


        self.addSubview(self.foregroundView)
        self.foregroundView.layer?.addSublayer(self.foregroundGradientLayer)


        self.foregroundGradientLayer.colors = [theme.colors.grayIcon.cgColor, theme.colors.grayIcon.lighter().cgColor]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 2.0, y: 0.5)

        self.foregroundView.layer?.mask = maskCurveLayer
        //layer?.addSublayer(maskCurveLayer)

        self.updateAnimations()

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }


    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.foregroundView.frame = NSMakeRect(0, 0, frame.width, frame.height)
        self.foregroundGradientLayer.frame = foregroundView.bounds
        self.maskCurveLayer.frame = NSMakeRect(0, 0, frame.width, frame.height)
        CATransaction.commit()
    }

    private var isCurrentlyInHierarchy: Bool = false
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        isCurrentlyInHierarchy = window != nil
        updateAnimations()
    }

    func updateAnimations() {
        if !isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.maskCurveLayer.stopAnimating()
            return
        }
        self.maskCurveLayer.startAnimating()
    }
}



class GroupCallNavigationHeaderView: CallHeaderBasicView {


    private let _backgroundView: CallStatusBarBackgroundView = CallStatusBarBackgroundView()

    override var backgroundView: NSView {
        return _backgroundView
    }

    override init(_ header: NavigationHeader) {
        super.init(header)
        addSubview(_backgroundView)
    }

    override func layout() {
        super.layout()
        _backgroundView.frame = bounds
    }


    private let audioLevelDisposable = MetaDisposable()

    var context: GroupCallContext? {
        get {
            return self.header?.contextObject as? GroupCallContext
        }
    }

    override func toggleMute() {
        self.context?.call.toggleIsMuted()
    }

    override func showInfoWindow() {
        self.context?.present()
    }

    override func hangUp() {
        self.context?.leave()
    }

    override var blueColor: NSColor {
        return NSColor(rgb: 0x0078ff)
    }
    override var grayColor: NSColor {
        return NSColor(rgb: 0x33c659)
    }

    override func hide(_ animated: Bool) {
        super.hide(true)
        audioLevelDisposable.set(nil)
    }

    override func update(with contextObject: Any) {
        super.update(with: contextObject)


        let context = contextObject as! GroupCallContext
        let peerId = context.call.peerId


        let data = context.call.summaryState
        |> filter { $0 != nil }
        |> map { $0! }
        |> map { summary -> GroupCallPanelData in
            return GroupCallPanelData(
                peerId: peerId,
                info: summary.info,
                topParticipants: summary.topParticipants,
                participantCount: summary.participantCount,
                activeSpeakers: summary.activeSpeakers,
                groupCall: nil
            )
        }

        let account = context.call.account

        let signal = Signal<Peer?, NoError>.single(context.call.peer) |> then(context.call.account.postbox.loadedPeerWithId(context.call.peerId) |> map(Optional.init) |> deliverOnMainQueue)

        let accountPeer: Signal<Peer?, NoError> = context.call.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }

        disposable.set(combineLatest(queue: .mainQueue(), context.call.state, context.call.isMuted, data, signal, accountPeer, appearanceSignal).start(next: { [weak self] state, isMuted, data, peer, accountPeer, _ in
            if let peer = peer {
                self?.setInfo(peer.displayTitle)
            }
            self?.updateState(state, isMuted: isMuted, data: data, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))

        hideDisposable.set((context.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.hide(true)
            }
        }))

        self.audioLevelDisposable.set((combineLatest(context.call.myAudioLevel, .single([]) |> then(context.call.audioLevels), context.call.isMuted, context.call.state)
           |> deliverOnMainQueue).start(next: { [weak self] myAudioLevel, audioLevels, isMuted, state in
                guard let strongSelf = self else {
                    return
                }
                var effectiveLevel: Float = 0.0
                switch state.networkState {
                case .connected:
                    if !isMuted {
                        effectiveLevel = myAudioLevel
                    } else {
                        effectiveLevel = audioLevels.reduce(0, { current, value in
                            return current + value.1
                        })
                        if !audioLevels.isEmpty {
                            effectiveLevel = effectiveLevel / Float(audioLevels.count)
                        }
                    }
                case .connecting:
                    effectiveLevel = 0
                }
                strongSelf._backgroundView.audioLevel = effectiveLevel
           }))
    }

    deinit {
        audioLevelDisposable.dispose()
    }


    private func updateState(_ state: PresentationGroupCallState, isMuted: Bool, data: GroupCallPanelData, accountPeer: Peer?, animated: Bool) {
        let isConnected: Bool
        switch state.networkState {
        case .connecting:
            self.status = .text(L10n.voiceChatStatusConnecting, nil)
            isConnected = false
        case .connected:
            self.status = .text(L10n.voiceChatStatusMembersCountable(data.participantCount), nil)
            isConnected = true
        }

        self._backgroundView.speaking = (isConnected && !isMuted, isConnected)


        setMicroIcon(isMuted ? theme.icons.callInlineMuted : theme.icons.callInlineUnmuted)
        needsLayout = true

    }

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func getEndText() -> String {
        return L10n.voiceChatTitleEnd
    }


}



private final class VoiceCurveLayer: CALayer {
    private let smallCurve: CurveLayer
    private let mediumCurve: CurveLayer
    private let bigCurve: CurveLayer


    private let maxLevel: CGFloat

    private var displayLinkAnimator: ConstantDisplayLinkAnimator?

    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0

    private(set) var isAnimating = false

    public typealias CurveRange = (min: CGFloat, max: CGFloat)

    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallCurveRange: CurveRange,
        mediumCurveRange: CurveRange,
        bigCurveRange: CurveRange
    ) {
        self.maxLevel = maxLevel

        self.smallCurve = CurveLayer(
            pointsCount: 7,
            minRandomness: 1,
            maxRandomness: 1.3,
            minSpeed: 0.9,
            maxSpeed: 3.2,
            minOffset: smallCurveRange.min,
            maxOffset: smallCurveRange.max
        )
        self.mediumCurve = CurveLayer(
            pointsCount: 7,
            minRandomness: 1.2,
            maxRandomness: 1.5,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minOffset: mediumCurveRange.min,
            maxOffset: mediumCurveRange.max
        )
        self.bigCurve = CurveLayer(
            pointsCount: 7,
            minRandomness: 1.2,
            maxRandomness: 1.7,
            minSpeed: 1.0,
            maxSpeed: 5.8,
            minOffset: bigCurveRange.min,
            maxOffset: bigCurveRange.max
        )

        super.init()

        self.addSublayer(bigCurve)
        self.addSublayer(mediumCurve)
        self.addSublayer(smallCurve)

        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1

            strongSelf.smallCurve.level = strongSelf.presentationAudioLevel
            strongSelf.mediumCurve.level = strongSelf.presentationAudioLevel
            strongSelf.bigCurve.level = strongSelf.presentationAudioLevel
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    public func setColor(_ color: NSColor) {
        smallCurve.setColor(color.withAlphaComponent(1.0))
        mediumCurve.setColor(color.withAlphaComponent(0.55))
        bigCurve.setColor(color.withAlphaComponent(0.35))
    }

    public func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))

        smallCurve.updateSpeedLevel(to: normalizedLevel)
        mediumCurve.updateSpeedLevel(to: normalizedLevel)
        bigCurve.updateSpeedLevel(to: normalizedLevel)

        audioLevel = normalizedLevel
    }

    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        updateCurvesState()

        displayLinkAnimator?.isPaused = false
    }

    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }

    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false

        updateCurvesState()

        displayLinkAnimator?.isPaused = true
    }

    private func updateCurvesState() {
        if isAnimating {
            if smallCurve.frame.size != .zero {
                smallCurve.startAnimating()
                mediumCurve.startAnimating()
                bigCurve.startAnimating()
            }
        } else {
            smallCurve.stopAnimating()
            mediumCurve.stopAnimating()
            bigCurve.stopAnimating()
        }
    }

    override var frame: NSRect {
        didSet {
            if oldValue != frame {
                smallCurve.frame = bounds
                mediumCurve.frame = bounds
                bigCurve.frame = bounds

                updateCurvesState()
            }
        }
    }
}

final class CurveLayer: CAShapeLayer {
    let pointsCount: Int
    let smoothness: CGFloat

    let minRandomness: CGFloat
    let maxRandomness: CGFloat

    let minSpeed: CGFloat
    let maxSpeed: CGFloat

    let minOffset: CGFloat
    let maxOffset: CGFloat

    var level: CGFloat = 0 {
        didSet {
            guard self.minOffset > 0.0 else {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minOffset + (maxOffset - minOffset) * level
            self.transform = CATransform3DMakeTranslation(0.0, lv * 16.0, 0.0)
            CATransaction.commit()
        }
    }

    private var curveAnimation: DisplayLinkAnimator?


    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0



    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            self.path = CGPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness, curve: true)
        }
    }

    override var frame: CGRect {
        didSet {

            if oldValue != frame {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
                self.bounds = self.bounds
                CATransaction.commit()
            }

            if self.frame.size != oldValue.size {
                self.fromPoints = nil
                self.toPoints = nil
                self.curveAnimation = nil
                self.animateToNewShape()
            }
        }
    }
    

    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?

    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }

        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }

    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minOffset: CGFloat,
        maxOffset: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minOffset = minOffset
        self.maxOffset = maxOffset

        self.smoothness = 0.35

        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    func setColor(_ color: NSColor) {
        self.fillColor = color.cgColor
    }

    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)

    }

    func startAnimating() {
        animateToNewShape()
    }

    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        curveAnimation = nil
    }

    private func animateToNewShape() {

        if curveAnimation != nil {
            fromPoints = currentPoints
            toPoints = nil
            curveAnimation = nil
        }

        if fromPoints == nil {
            fromPoints = generateNextCurve(for: bounds.size)
        }
        if toPoints == nil {
            toPoints = generateNextCurve(for: bounds.size)
        }


        let duration = CGFloat(1 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        let fromValue: CGFloat = 0
        let toValue: CGFloat = 1

        let animation = DisplayLinkAnimator(duration: Double(duration), from: fromValue, to: toValue, update: { [weak self] value in
            self?.transition = value
        }, completion: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.fromPoints = self.currentPoints
            self.toPoints = nil
            self.curveAnimation = nil
            self.animateToNewShape()
        })
        self.curveAnimation = animation

        lastSpeedLevel = speedLevel
        speedLevel = 0
    }

    private func generateNextCurve(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return curve(pointsCount: pointsCount, randomness: randomness).map {
            return CGPoint(x: $0.x * CGFloat(size.width), y: size.height - 18.0 + $0.y * 12.0)
        }
    }

    private func curve(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let segment = 1.0 / CGFloat(pointsCount - 1)

        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let segmentRandomness: CGFloat = randomness

            let pointX: CGFloat
            let pointY: CGFloat
            let randomXDelta: CGFloat
            if i == 0 {
                pointX = 0.0
                pointY = 0.0
                randomXDelta = 0.0
            } else if i == pointsCount - 1 {
                pointX = 1.0
                pointY = 0.0
                randomXDelta = 0.0
            } else {
                pointX = segment * CGFloat(i)
                pointY = ((segmentRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - segmentRandomness * 0.5) * randPointOffset
                randomXDelta = segment - segment * randPointOffset
            }

            return CGPoint(x: pointX + randomXDelta, y: pointY)
        }

        return points
    }

}
