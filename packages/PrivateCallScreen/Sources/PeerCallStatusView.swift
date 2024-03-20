//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 09.02.2024.
//

import Foundation
import TGUIKit
import AppKit
import SwiftSignalKit


private class SignalControl: View {
    
    var reception: Int32 = 4 {
        didSet {
            self.needsDisplay = true
        }
    }
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        context.setFillColor(NSColor.white.cgColor)
        
        let width: CGFloat = 3.0
        let spacing: CGFloat = 2.0

        for i in 0 ..< 4 {
            let height = 4.0 + 2.0 * CGFloat(i)
            let rect = CGRect(x: bounds.minX + CGFloat(i) * (width + spacing), y: frame.height - height, width: width, height: height)
            
            if i >= reception {
                context.setAlpha(0.4)
            }
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: 1.0, cornerHeight: 1.0)
            context.addPath(path)
            context.fillPath()
        }
    }
}

private class ActiveCallView : View {
   
    
    private let signalView = SignalControl(frame: NSMakeRect(0, 0, 24, 10))
    private let duration = DynamicCounterTextView()
    
    private var statusTimer: SwiftSignalKit.Timer?

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(signalView)
        addSubview(duration)
        self.layer?.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateState(_ status: PeerCallStatusValue, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        
        switch status {
        case let .timer(referenceTime, reception):
            signalView.reception = reception ?? 4
            
            let time = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let text = String.durationTransformed(elapsed: Int(time))
            
            let value = DynamicCounterTextView.make(for: text, count: text, font: .roundTimer(.text), textColor: .white, width: .greatestFiniteMagnitude)
            
            duration.update(value, animated: transition.isAnimated)
            duration.change(size: value.size, animated: transition.isAnimated)
            
            transition.updateFrame(view: self, frame: CGRect(origin: self.frame.origin, size: NSMakeSize(signalView.frame.width + 4 + duration.frame.width, self.frame.height)))
            self.updateLayout(size: self.frame.size, transition: transition)

        default:
            break
        }
        
        self.statusTimer?.invalidate()
        self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            self?.updateState(status, arguments: arguments, transition: .animated(duration: 0.2, curve: .easeOut))
        }, queue: Queue.mainQueue())
        
        self.statusTimer?.start()
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: signalView, frame: signalView.centerFrameY(x: 0))
        transition.updateFrame(view: duration, frame: duration.centerFrameY(x: signalView.frame.maxX + 4))
    }
}



internal final class PeerCallStatusView : View, CallViewUpdater {
   
    
    private let textView = TextView()
    private var networkStatus: TextView?
    private var activeView: ActiveCallView?
    
    
    private var status: PeerCallStatusValue?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        
        layer?.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        
        let previousStatus = self.status
        let status = state.status
        
        self.status = status
        
        let initUpdate: Bool = self.textView.textLayout == nil
        
        if self.textView.textLayout?.attributedString.string != state.title {
            let name: TextViewLayout = .init(.initialize(string: state.title, color: NSColor.white, font: .medium(26)), alignment: .center)
            name.measure(width: frame.width)
            textView.update(name)
        }
        
        switch status {
        case let .text(string, _):
            if let view = self.activeView {
                performSubviewRemoval(view, animated: transition.isAnimated, scale: true)
                self.activeView = nil
            }
            if string != self.networkStatus?.textLayout?.attributedString.string {
                if let view = networkStatus {
                    performSubviewRemoval(view, animated: transition.isAnimated, scale: true)
                    self.networkStatus = nil
                }
                let current: TextView = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                let layout = TextViewLayout(.initialize(string: string, color: NSColor.white, font: .roundTimer(.header)))
                layout.measure(width: .greatestFiniteMagnitude)
                current.update(layout)
                
                addSubview(current)
                self.networkStatus = current
                
                current.centerX(y: textView.frame.maxY + 10)
                
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
            }
        case .timer:
            
            if let view = networkStatus {
                performSubviewRemoval(view, animated: transition.isAnimated, scale: true)
                self.networkStatus = nil
            }
            
            let current: ActiveCallView
            let isNew: Bool
            if let view = self.activeView {
                current = view
                isNew = false
            } else {
                current = ActiveCallView(frame: NSMakeRect(0, 0, 100, 20))
                addSubview(current)
                self.activeView = current
                
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
                isNew = true
            }
            current.updateState(status, arguments: arguments, transition: isNew ? .immediate : transition)

            if isNew {
                current.centerX(y: textView.frame.maxY + 5)
            }
        }

        if initUpdate {
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.centerFrameX(y: 0))
        
        if let networkStatus {
            transition.updateFrame(view: networkStatus, frame: networkStatus.centerFrameX(y: textView.frame.maxY + 5))
        }
        if let activeView {
            transition.updateFrame(view: activeView, frame: activeView.centerFrameX(y: textView.frame.maxY + 5))
            activeView.updateLayout(size: activeView.frame.size, transition: transition)
        }
    }
    
}

