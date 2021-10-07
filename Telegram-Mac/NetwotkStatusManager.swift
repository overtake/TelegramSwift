//
//  ConnectingStatusController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private enum Status : Equatable {
    case core(ConnectionStatus)
    case updated
    case connected
    
    var text: String {
        switch self {
        case .connected:
            return L10n.connectionStatusConnected
        case .updated:
            return L10n.connectionStatusUpdated
        case let .core(status):
            switch status {
            case let .connecting(proxyAddress, _):
                return proxyAddress != nil ? L10n.connectionStatusConnectingToProxy : L10n.connectionStatusConnecting
            case .waitingForNetwork:
                return L10n.connectionStatusWaitingForNetwork
            case .updating:
                return L10n.connectionStatusUpdating
            case .online:
                return ""
            }
        }
    }
    
    var shouldAddProgress: Bool {
        switch self {
        case .connected:
            return false
        case .updated:
            return false
        case let .core(status):
            switch status {
            case .connecting:
                return true
            case .waitingForNetwork:
                return true
            case .updating:
                return true
            case .online:
                return false
            }
        }
    }
    
    var color: NSColor {
        switch self {
        case .connected:
            return theme.colors.greenUI
        case .updated:
            return theme.colors.greenUI
        case let .core(status):
            switch status {
            case .connecting:
                return theme.colors.peerAvatarRedTop
            case .waitingForNetwork:
                return theme.colors.peerAvatarRedBottom
            case .updating:
                return theme.colors.accent
            case .online:
                return theme.colors.greenUI
            }
        }
    }
}

private final class ConnectingStatusView: View {
    private let textView: TextView = TextView()
    private let visualEffect: VisualEffect
    private let container = View()
    private var progressView: InfiniteProgressView?
    private let imageView: ImageView
    private let backgroundView: View
    
    private var status: Status?
    
    required init(frame frameRect: NSRect) {
        self.visualEffect = VisualEffect(frame: frameRect.size.bounds)
        self.imageView = ImageView(frame: frameRect.size.bounds)
        self.backgroundView = View(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        addSubview(backgroundView)
        addSubview(imageView)
        addSubview(self.visualEffect)
        addSubview(container)
        container.addSubview(textView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override func layout() {
        super.layout()
    
        textView.resize(frame.width - 80)
        textView.center()
        if let progressView = self.progressView {
            progressView.centerY(x: 0)
            textView.centerY(x: progressView.frame.maxX + 5)
        } else {
            textView.center()
        }
        self.container.center()
        self.imageView.center()
        self.visualEffect.frame = bounds
        self.backgroundView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ status: Status, animated: Bool) {
        self.status = status
        let text: String = status.text
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.underSelectedColor, font: .medium(.text)))
        layout.measure(width: frame.width - 80)
        textView.update(layout)
        
        backgroundView.backgroundColor = status.color
        if animated {
            backgroundView.layer?.animateBackground()
        }
        imageView.image = generateImage(NSMakeSize(frame.height, frame.height), contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.2).cgColor)
            ctx.round(size, size.height / 2)
            ctx.fill(size.bounds)
        })
        imageView.sizeToFit()
        
        if animated {
            let animation = makeSpringAnimation("transform")
            
            let to: CGFloat = frame.width / imageView.frame.width
            let from: CGFloat = 0.1

            var fr = CATransform3DIdentity
            fr = CATransform3DTranslate(fr, floorToScreenPixels(System.backingScale, imageView.frame.width / 2), floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
            fr = CATransform3DScale(fr, from, from, 1)
            fr = CATransform3DTranslate(fr, -floorToScreenPixels(System.backingScale, imageView.frame.width / 2), -floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
            
            animation.timingFunction = .init(name: .easeInEaseOut)
            animation.fromValue = NSValue(caTransform3D: fr)
            animation.toValue = to
            animation.fillMode = .forwards
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = self.imageView.layer!.convertTime(CACurrentMediaTime(), from: nil) + 0.25
            let speed: Float = 1.0
            animation.speed = speed * Float(animation.duration / 1.0)
            
            var tr = CATransform3DIdentity
            tr = CATransform3DTranslate(tr, floorToScreenPixels(System.backingScale, imageView.frame.width / 2), floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
            tr = CATransform3DScale(tr, to, to, 1)
            tr = CATransform3DTranslate(tr, -floorToScreenPixels(System.backingScale, imageView.frame.width / 2), -floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
            animation.toValue = NSValue(caTransform3D: tr)

            imageView.layer?.add(animation, forKey: "transform")
        }
        
        self.visualEffect.bgColor = NSColor.black.withAlphaComponent(0.2)
        
        if status.shouldAddProgress {
            if self.progressView == nil {
                let progressView: InfiniteProgressView = .init(color: theme.colors.underSelectedColor, lineWidth: 1.5)
                self.progressView = progressView
                progressView.progress = nil
                progressView.setFrameSize(NSMakeSize(layout.layoutSize.height - 3, layout.layoutSize.height - 3))
                self.container.addSubview(progressView)
            }
            self.container.setFrameSize(NSMakeSize(layout.layoutSize.width + progressView!.frame.width + 5, max(progressView!.frame.height, layout.layoutSize.height)))
        } else {
            self.progressView?.removeFromSuperview()
            self.progressView = nil
            self.container.setFrameSize(NSMakeSize(layout.layoutSize.width, layout.layoutSize.height))
        }
        
        needsLayout = true
    }
}

final class NetworkStatusManager {
    private let account: Account
    private let window: Window
    private let disposable = MetaDisposable()
    
    private var currentView: ConnectingStatusView?
    private var backgroundView: View?
    init(account: Account, window: Window) {
        self.account = account
        self.window = window
        initialize()
    }
    
    func initialize() {
        
        let updating: Signal<Bool, NoError> = account.stateManager.isUpdating |> mapToSignal { isUpdating in
            return isUpdating ? .single(isUpdating) |> delay(1.0, queue: .mainQueue()) : .single(isUpdating)
        }
        
        let connecting: Signal<ConnectionStatus, NoError> = account.network.connectionStatus |> mapToSignal { status in
            switch status {
            case .online:
                return .single(status)
            default:
                return .single(status) |> delay(1.0, queue: .mainQueue())
            }
        }
        
        let fakeStatus: ValuePromise<ConnectionStatus?> = ValuePromise(nil)
        
        let previousStatus: Atomic<ConnectionStatus> = Atomic(value: .online(proxyAddress: nil))
        
        let connectionStatus: Signal<Status?, NoError> = combineLatest(queue: .mainQueue(), connecting, updating, fakeStatus.get()) |> deliverOnMainQueue |> map { status, isUpdating, fakeStatus -> ConnectionStatus in
            var status = fakeStatus ?? status
            switch status {
            case let .online(proxyAddress):
                if isUpdating {
                    status = .updating(proxyAddress: proxyAddress)
                }
            default:
                break
            }
            return status
        } |> mapToSignal { coreStatus in
            let previous = previousStatus.swap(coreStatus)
            
            switch coreStatus {
            case .online:
                switch previous {
                case .connecting, .waitingForNetwork:
                    return .single(.connected) |> then(.single(nil) |> delay(1.5, queue: .mainQueue()))
                case .updating:
                    return .single(.updated) |> then(.single(nil) |> delay(1.5, queue: .mainQueue()))
                default:
                    return .single(nil)
                }
            default:
                return .single(.core(coreStatus))
            }
        }
        |> deliverOnMainQueue
        |> distinctUntilChanged
                
        disposable.set(combineLatest(connectionStatus, appearanceSignal).start(next: { [weak self] status, _ in
            self?.updateStatus(status, animated: true)
        }))
        
        window.set(handler: { _ in
            let fakes:[ConnectionStatus?] = [.online(proxyAddress: nil), .connecting(proxyAddress: nil, proxyHasConnectionIssues: false), .waitingForNetwork, .updating(proxyAddress: nil), nil]
            fakeStatus.set(fakes.randomElement()!)
            
            return .rejected
        }, with: window, for: .A, priority: .supreme)
    }
    
    private func updateStatus(_ status: Status?, animated: Bool) {
        guard let windowView = windowView else {
            return
        }

        if let status = status {
            let view: ConnectingStatusView = self.currentView ?? .init(frame: windowView.superview.bounds)
            view.set(status, animated: animated)
            self.currentView = view
            
            windowView.superview.addSubview(view, positioned: .above, relativeTo: windowView.aboveView)
            
            if animated {
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            
            if self.backgroundView == nil {
                self.backgroundView = View(frame: view.bounds)
                self.backgroundView?.autoresizingMask = [.width, .height]
            }
            windowView.superview.addSubview(self.backgroundView!, positioned: .below, relativeTo: view)
            self.backgroundView?.backgroundColor = theme.colors.grayBackground
        } else {
            if let view = self.backgroundView {
                performSubviewRemoval(view, animated: animated)
                self.backgroundView = nil
            }
            if let view = currentView {
                performSubviewRemoval(view, animated: animated)
                self.currentView = nil
            }
        }
    }
    
    
    struct WindowView {
        let superview: NSView
        let aboveView: NSView?
    }
    var windowView: WindowView? {
        guard let title = self.window.titleView else {
            return nil
        }
        let subviews = title.subviews
        for subview in subviews {
            if subview is NSTextField {
                return .init(superview: title, aboveView: subview)
            }
        }
        return nil
    }
    
    deinit {
        cleanup()
    }
    
    func cleanup() {
        disposable.dispose()
        self.updateStatus(nil, animated: false)
    }
}
