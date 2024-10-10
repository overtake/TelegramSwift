//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 15.02.2024.
//

import Foundation
import TGUIKit
import AppKit
import Localization

private let micro = NSImage(resource: .icMicrophoneoff).precomposed(.white)

final class PeerCallTooltipStatusView : NSVisualEffectView {
    
    enum TooltipType : Comparable, Identifiable {
        
        static func <(lhs: TooltipType, rhs: TooltipType) -> Bool {
            return lhs.index < rhs.index
        }
        
        case yourMicroOff
        case microOff(String)
        
        var index:Int {
            switch self {
            case .yourMicroOff:
                return 0
            case .microOff:
                return 1
            }
        }
        var stableId: AnyHashable {
            return self.index
        }
        
        var icon: CGImage {
            switch self {
            case .yourMicroOff:
                return micro
            case .microOff:
                return micro
            }
        }
        var text: String {
            switch self {
            case .yourMicroOff:
                return L10n.callToastMicroOffYour
            case let .microOff(title):
                return L10n.callToastMicroOff(title)
            }
        }
    }

    
    private let imageView = ImageView()
    private let textView = TextView()
    private let maskLayer = SimpleShapeLayer()
    private let control = Control()
    
    private var revealed = false
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.addSubview(imageView)
        self.addSubview(textView)
        
        addSubview(control)
        
        self.textView.userInteractionEnabled = false
        self.textView.isSelectable = false
        
        self.wantsLayer = true
        self.material = .light
        self.state = .active
        self.blendingMode = .withinWindow
        
        self.layer?.mask = maskLayer
        
        
//        control.set(handler: { [weak self] _ in
//            self?.reveal()
//        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var imageOffset: CGFloat {
        return 5 + self.imageView.frame.width + 5
    }
    
    func set(type: TooltipType) {
        
        self.imageView.image = type.icon
        self.imageView.sizeToFit()
        
        let layout = TextViewLayout(.initialize(string: type.text, color: NSColor.white, font: .medium(.text)), alignment: .center)
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        
        self.setFrameSize(NSMakeSize(imageOffset + layout.layoutSize.width + 10, layout.layoutSize.height + 10))
        
        self.layer?.cornerRadius = frame.height / 2
        if #available(macOS 10.15, *) {
            self.layer?.cornerCurve = .continuous
        }
        
        let rect: NSRect
        if !revealed {
            rect = NSMakeRect(0, 0, imageOffset, frame.height)
        } else {
            rect = bounds
        }
        
        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2)
        maskLayer.path = path
        maskLayer.frame = NSMakeRect(0, 0, frame.width, frame.height)

    }
    
    func reveal(animated: Bool) {
        guard !revealed else {
            return
        }
        let path = CGMutablePath()
        path.addRoundedRect(in: self.bounds, cornerWidth: self.frame.height / 2, cornerHeight: self.frame.height / 2)
        self.maskLayer.animate(from: maskLayer.path!, to: path, keyPath: "path", timingFunction: .spring, duration: 0.5, removeOnCompletion: false, completion: { [weak self] _ in
            self?.maskLayer.path = path
        })

        self.layer?.animatePosition(from: NSMakePoint(self.frame.minX + (self.frame.width / 2) - self.imageOffset / 2, self.frame.minY), to: self.frame.origin, duration: 0.5, timingFunction: .spring)
        
        revealed = true

    }
    
    
    override func layout() {
        super.layout()
        control.frame = bounds
        imageView.centerY(x: 5)
        textView.centerY(x: imageOffset)
    }

}
