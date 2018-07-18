//
//  PeerMediaPlayerAnimationView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class PeerMediaPlayerAnimationView: View {

    var isPlaying: Bool = false {
        didSet {
            if self.isPlaying != oldValue {
                if self.isPlaying {
                    self.animateToPlaying()
                } else {
                    self.animateToPaused()
                }
            }
        }
    }
    
    private let barNodes: [View]
    
    override init() {
        
        let baseSize = CGSize(width: 40, height: 40)
        let barSize = CGSize(width: 3.0, height: 3)
        let barSpacing: CGFloat = 2.0
        
        let barsOrigin = CGPoint(x: floor((baseSize.width - (barSize.width * 4.0 + barSpacing * 3.0)) / 2.0), y: 17)
        
        var barNodes: [View] = []
        for i in 0 ..< 4 {
            let barNode = View()
            barNode.flip = false
            barNode.frame = CGRect(origin: barsOrigin.offsetBy(dx: CGFloat(i) * (barSize.width + barSpacing), dy: 0.0), size: barSize)
            barNode.backgroundColor = .white
            barNode.layer?.anchorPoint = CGPoint(x: 0.5, y: 1)
            barNodes.append(barNode)
        }
        self.barNodes = barNodes
        
        super.init(frame: NSMakeRect(0, 0, baseSize.width, baseSize.height))
       
        flip = false
        
        self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        self.layer?.cornerRadius = .cornerRadius
        for barNode in self.barNodes {
            self.addSubview(barNode)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func animateToPlaying() {
        for barNode in self.barNodes {
            let randValueMul = Float(4 % arc4random())
            let randDurationMul = Double(arc4random()) / Double(UInt32.max)
            
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.toValue = Float(randValueMul) as NSNumber
            animation.autoreverses = true
            animation.duration = 0.25 + 0.25 * randDurationMul
            animation.repeatCount = Float.greatestFiniteMagnitude;
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            
            barNode.layer?.removeAnimation(forKey: "transform.scale.y")
            barNode.layer?.add(animation, forKey: "transform.scale.y")
        }
    }
    
    private func animateToPaused() {
        for barNode in self.barNodes {
            if let presentationLayer = barNode.layer?.presentation() {
                let animation = CABasicAnimation(keyPath: "transform.scale.y")
                animation.fromValue = (presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0
                animation.toValue = 1.0 as NSNumber
                animation.duration = 0.25
                animation.isRemovedOnCompletion = false
                barNode.layer?.add(animation, forKey: "transform.scale.y")
            }
        }
    }
    
}
