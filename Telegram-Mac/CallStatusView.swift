//
//  CallStatusView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

enum CallControllerStatusValue: Equatable {
    case text(String, Int32?)
    case timer(Double, Int32?)
    case startsIn(Int)
    
    var hasTimer: Bool {
        switch self {
        case .timer, .startsIn:
            return true
        default:
            return false
        }
    }
}


class CallStatusView: View {
    
    
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
    
    private let statusTextView:TextView = TextView()
    private let receptionView = CallReceptionControl(frame: NSMakeRect(0, 0, 24, 10))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        statusTextView.userInteractionEnabled = false
        statusTextView.isSelectable = false
        statusTextView.disableBackgroundDrawing = true
        addSubview(statusTextView)
        addSubview(receptionView)
    }
    
    override func layout() {
        super.layout()
        if receptionView.isHidden {
            statusTextView.center()
        } else {
            receptionView.centerY(x: 0)
            statusTextView.centerY(x: receptionView.frame.maxX)
        }
        
    }
    
    func sizeThatFits(_ size: NSSize) -> NSSize {
        if let layout = self.statusTextView.textLayout {
            layout.measure(width: size.width)
            statusTextView.update(layout)
            return NSMakeSize(max(layout.layoutSize.width, 60) + 28, size.height)
        }
        return size
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    deinit {
        statusTimer?.invalidate()
    }
    
    func updateStatus() {
        var statusText: String = ""
        switch self.status {
        case let .text(text, reception):
            statusText = text
            if let reception = reception {
                self.receptionView.reception = reception
            }
            self.receptionView.isHidden = reception == nil
        case let .timer(referenceTime, reception):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
            }
            statusText = durationString
            if let reception = reception {
                self.receptionView.reception = reception
            }
            self.receptionView.isHidden = reception == nil
        case let .startsIn(time):
            statusText = strings().chatHeaderVoiceChatStartsIn(timerText(time - Int(Date().timeIntervalSince1970)))
            self.receptionView.isHidden = true
        }
        let layout = TextViewLayout.init(.initialize(string: statusText, color: .white, font: .normal(18)), alignment: .center)
        layout.measure(width: .greatestFiniteMagnitude)
        self.statusTextView.update(layout)
        needsLayout = true
    }
   
}
