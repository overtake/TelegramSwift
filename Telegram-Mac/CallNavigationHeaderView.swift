//
//  CallNavigationHeaderView.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox


private let blue = NSColor(rgb: 0x0078ff)
private let lightBlue = NSColor(rgb: 0x59c7f8)
private let green = NSColor(rgb: 0x33c659)

private let purple =  NSColor(rgb: 0x766EE9)
private let lightPurple =  NSColor(rgb: 0xF05459)


class CallStatusBarBackgroundViewLegacy : View, CallStatusBarBackground {
    var audioLevel: Float = 0
    var speaking:(Bool, Bool, Bool)? = nil {
        didSet {
            if let speaking = self.speaking, (speaking.0 != oldValue?.0 || speaking.1 != oldValue?.1 || speaking.2 != oldValue?.2) {
                let targetColors: [NSColor]
                if speaking.1 {
                    if speaking.2 {
                        if speaking.0 {
                            targetColors = [green, blue]
                        } else {
                            targetColors = [blue, lightBlue]
                        }
                    } else {
                        targetColors = [purple, lightPurple]
                    }

                } else {
                    targetColors = [theme.colors.grayIcon, theme.colors.grayIcon.lighter()]
                }
                self.backgroundColor = targetColors.first ?? theme.colors.accent
            }
        }
    }
}

class CallStatusBarBackgroundView: View, CallStatusBarBackground {
    private let foregroundView: View
    private let foregroundGradientLayer: CAGradientLayer
    private let maskCurveLayer: VoiceCurveLayer
    var audioLevel: Float = 0.0  {
        didSet {
            self.maskCurveLayer.updateLevel(CGFloat(audioLevel))
        }
    }
    

    var speaking:(Bool, Bool, Bool)? = nil {
        didSet {
            if let speaking = self.speaking, (speaking.0 != oldValue?.0 || speaking.1 != oldValue?.1 || speaking.2 != oldValue?.2) {
                let initialColors = self.foregroundGradientLayer.colors
                let targetColors: [CGColor]
                if speaking.1 {
                    if speaking.2 {
                        if speaking.0 {
                            targetColors = [green.cgColor, blue.cgColor]
                        } else {
                            targetColors = [blue.cgColor, lightBlue.cgColor]
                        }
                    } else {
                        targetColors = [purple.cgColor, lightPurple.cgColor]
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
    private let occlusionDisposable = MetaDisposable()
    private var isCurrentlyInHierarchy: Bool = false {
        didSet {
            updateAnimations()
        }
    }
    
    deinit {
        occlusionDisposable.dispose()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = window as? Window {
            occlusionDisposable.set(window.takeOcclusionState.start(next: { [weak self] value in
                self?.isCurrentlyInHierarchy = value.contains(.visible)
            }))
        } else {
            occlusionDisposable.set(nil)
            isCurrentlyInHierarchy = false
        }
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
    
    override init(layer: Any) {
        let maxLevel: CGFloat = 2.5
        let smallCurveRange:CurveRange = (0.0, 0.0)
        let mediumCurveRange:CurveRange = (0.1, 0.55)
        let bigCurveRange:CurveRange = (0.1, 1.0)
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
        super.init(layer: layer)
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


protocol CallStatusBarBackground : View {
    var audioLevel: Float { get set }
    var speaking:(Bool, Bool, Bool)? { get set }
}


class CallHeaderBasicView : NavigationHeaderView {

    
    private let _backgroundView: CallStatusBarBackground

    var backgroundView: CallStatusBarBackground {
        return _backgroundView
    }
    
    private let container = View()
    
    fileprivate let callInfo:TitleButton = TitleButton()
    fileprivate let endCall:ImageButton = ImageButton()
    fileprivate let statusTextView:DynamicCounterTextView = DynamicCounterTextView()
    fileprivate let muteControl:ImageButton = ImageButton()

    let disposable = MetaDisposable()
    let hideDisposable = MetaDisposable()


    override func hide(_ animated: Bool) {
        super.hide(true)
        disposable.set(nil)
        hideDisposable.set(nil)
    }
    
    private var statusTimer: SwiftSignalKit.Timer?

    
    var status: CallControllerStatusValue = .text("", nil) {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.updateStatus()
                    }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                    self.updateStatus()
                } else {
                    self.updateStatus()
                }
            }
        }
    }
    
    private func updateStatus(animated: Bool = true) {
        var statusText: String = ""
        switch self.status {
        case let .text(text, _):
            statusText = text
        case let .timer(referenceTime, _):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
            }
            statusText = durationString
        }
        let dynamicResult = DynamicCounterTextView.make(for: statusText, count: statusText.trimmingCharacters(in: CharacterSet.decimalDigits.inverted), font: .normal(.text), textColor: .white, width: 120, onlyFade: true)
        self.statusTextView.update(dynamicResult.values, animated: animated)
        self.statusTextView.change(size: dynamicResult.size, animated: animated)

        needsLayout = true
    }
    
    deinit {
        disposable.dispose()
        hideDisposable.dispose()
    }
    
    override init(_ header: NavigationHeader) {
        if #available(OSX 10.12, *) {
            self._backgroundView = CallStatusBarBackgroundView()
        } else {
            self._backgroundView = CallStatusBarBackgroundViewLegacy()
        }
        super.init(header)
        
        backgroundView.frame = bounds
        backgroundView.wantsLayer = true
        addSubview(backgroundView)
        addSubview(container)
        statusTextView.backgroundColor = .clear


        callInfo.set(font: .medium(.text), for: .Normal)
        callInfo.disableActions()
        container.addSubview(callInfo)
        callInfo.userInteractionEnabled = false
        
        endCall.disableActions()
        container.addSubview(endCall)
        
        endCall.scaleOnClick = true
        muteControl.scaleOnClick = true

        container.addSubview(statusTextView)

        callInfo.set(handler: { [weak self] _ in
            self?.showInfoWindow()
        }, for: .Click)
        
    
        endCall.set(handler: { [weak self] _ in
            self?.hangUp()
        }, for: .Click)
        
        
        muteControl.autohighlight = false
        container.addSubview(muteControl)
        
        muteControl.set(handler: { [weak self] _ in
            self?.toggleMute()
        }, for: .Click)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    func toggleMute() {
        
    }
    func showInfoWindow() {
        
    }
    func hangUp() {
        
    }

    func setInfo(_ text: String) {
        self.callInfo.set(text: text, for: .Normal)
    }
    func setMicroIcon(_ image: CGImage) {
        muteControl.set(image: image, for: .Normal)
        _ = muteControl.sizeToFit()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = self.convert(event.locationInWindow, from: nil)
        if let header = header, point.y <= header.height {
            showInfoWindow()
        }
    }
    
    var blueColor:NSColor {
        return theme.colors.accentSelect
    }
    var grayColor:NSColor {
        return theme.colors.grayText
    }

    func getEndText() -> String {
        return L10n.callHeaderEndCall
    }
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = bounds
        container.frame = NSMakeRect(0, 0, frame.width, height)
        muteControl.centerY(x:18)
        statusTextView.centerY(x: muteControl.frame.maxX + 6)
        endCall.centerY(x: frame.width - endCall.frame.width - 20)
        _ = callInfo.sizeToFit(NSZeroSize, NSMakeSize(frame.width - 140 - 20 - endCall.frame.width - 10, callInfo.frame.height), thatFit: false)
        
        let rect = container.focus(callInfo.frame.size)
        callInfo.setFrameOrigin(NSMakePoint(max(140, min(rect.minX, endCall.frame.minX - 10 - callInfo.frame.width)), rect.minY))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        endCall.set(image: theme.icons.callInlineDecline, for: .Normal)
        endCall.set(image: theme.icons.callInlineDecline, for: .Highlight)
        _ = endCall.sizeToFit(NSMakeSize(10, 10), thatFit: false)
        callInfo.set(color: .white, for: .Normal)

        needsLayout = true

    }
    
}

class CallNavigationHeaderView: CallHeaderBasicView {
    
    var session: PCallSession? {
        get {
            self.header?.contextObject as? PCallSession
        }
    }
    private let audioLevelDisposable = MetaDisposable()

    deinit {
        audioLevelDisposable.dispose()
    }
    
    fileprivate weak var accountPeer: Peer?
    fileprivate var state: CallState?

    override func showInfoWindow() {
        if let session = self.session {
            showCallWindow(session)
        }
    }
    override func hangUp() {
        self.session?.hangUpCurrentCall()
    }
    
    override func toggleMute() {
        session?.toggleMute()
    }
    
    override func update(with contextObject: Any) {
        super.update(with: contextObject)
        let session = contextObject as! PCallSession
        let account = session.account
        let signal = Signal<Peer?, NoError>.single(session.peer) |> then(session.account.postbox.loadedPeerWithId(session.peerId) |> map(Optional.init) |> deliverOnMainQueue)

        let accountPeer: Signal<Peer?, NoError> =  session.sharedContext.activeAccounts |> mapToSignal { accounts in
            if accounts.accounts.count == 1 {
                return .single(nil)
            } else {
                return account.postbox.loadedPeerWithId(account.peerId) |> map(Optional.init)
            }
        }

        disposable.set(combineLatest(queue: .mainQueue(), session.state, signal, accountPeer).start(next: { [weak self] state, peer, accountPeer in
            if let peer = peer {
                self?.setInfo(peer.displayTitle)
            }
            self?.updateState(state, accountPeer: accountPeer, animated: false)
            self?.needsLayout = true
            self?.ready.set(.single(true))
        }))
        
        audioLevelDisposable.set((session.audioLevel |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.backgroundView.audioLevel = value
        }))

        hideDisposable.set((session.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.hide(true)
            }
        }))
    }
    
    private func updateState(_ state:CallState, accountPeer: Peer?, animated: Bool) {
        self.state = state
        self.status = state.state.statusText(accountPeer, state.videoState)
        var isConnected: Bool = false
        let isMuted = state.isMuted
        switch state.state {
        case .active:
            isConnected = true
        default:
            isConnected = false
        }
        self.backgroundView.speaking = (isConnected && !isMuted, isConnected, true)
        if animated {
            backgroundView.layer?.animateBackground()
        }
        setMicroIcon(!state.isMuted ? theme.icons.callInlineUnmuted : theme.icons.callInlineMuted)
        needsLayout = true
        
        switch state.state {
        case let .terminated(_, reason, _):
            if let reason = reason, reason.recall {
                
            } else {
                muteControl.removeAllHandlers()
                endCall.removeAllHandlers()
                callInfo.removeAllHandlers()
                muteControl.change(opacity: 0.8, animated: animated)
                endCall.change(opacity: 0.8, animated: animated)
                statusTextView._change(opacity: 0.8, animated: animated)
                callInfo._change(opacity: 0.8, animated: animated)
            }
        default:
            break
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        if let state = state {
            self.updateState(state, accountPeer: accountPeer, animated: false)
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(_ header: NavigationHeader) {
        super.init(header)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}

