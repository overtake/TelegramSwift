//
//  LAnimationButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import Lottie

enum LButtonAutoplaySide {
    case left
    case right
}

class LAnimationButton: Button {
    private let scale: CGFloat
    private let animationView: AnimationView
    var speed: CGFloat = 1.0 {
        didSet {
           animationView.animationSpeed = speed
        }
    }
    private let offset: CGFloat
    private var colorCallbacks: [ColorValueProvider] = []
    
    var played = false
    var completion: (() -> Void)?

    var autoplayOnVisibleSide: LButtonAutoplaySide? = nil
    
    init(animation: String, keysToColor: [String]? = nil, color: NSColor = .black, scale: CGFloat = 1.0, offset: CGFloat = 0, autoplaySide: LButtonAutoplaySide? = nil, rotated: Bool = false) {
        self.scale = scale
        self.offset = offset
        self.autoplayOnVisibleSide = autoplaySide
        let animation = Animation.named(animation, bundle: Bundle.main, subdirectory: nil, animationCache: LRUAnimationCache.sharedCache)
        self.animationView = AnimationView(animation: animation)
        super.init(frame: NSZeroRect)
        //self.animationView.background = .red
        addSubview(animationView)
        animationView.setFrameSize(animationView.frame.width * scale, animationView.frame.height)
        self.set(keysToColor: keysToColor, color: color)
        
        if rotated {
            animationView.rotate(byDegrees: 180)
        }
       
    }
    
    func set(keysToColor: [String]? = nil, color: NSColor = .black) {
        let newColor = color.usingColorSpace(.deviceRGB)!
        
        
        let colorCallback = ColorValueProvider(Color(r: Double(newColor.redComponent), g: Double(newColor.greenComponent), b: Double(newColor.blueComponent), a: Double(newColor.alphaComponent)))
        self.colorCallbacks.append(colorCallback)
        if let keysToColor = keysToColor {
            for key in keysToColor {
                animationView.setValueProvider(colorCallback, keypath: AnimationKeypath(keypath: "\(key).Color"))
            }
        }
    }
    
    
    override func viewDidMoveToWindow() {
        if window == nil {
            animationView.stop()
        }
    }
    
    private var prevVisibleRect: NSRect = NSZeroRect
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let audoplaySide = self.autoplayOnVisibleSide {
            let point: NSPoint
            switch audoplaySide {
            case .right:
                point = NSMakePoint(frame.width - frame.width / 3, frame.height / 2)
            case .left:
                point = NSMakePoint(frame.width / 3, frame.height / 2)
            }
            let locationInWindow = self.convert(point, to: nil)
            
            if window?.contentView?.hitTest(locationInWindow) == self.animationView {
                if !self.played {
                    self.played = true
                    animationView.play()
                }
            } else if self.played {
                self.played = false
                animationView.play(toFrame: AnimationFrameTime())
            }
        }
       
        
        self.prevVisibleRect = visibleRect
    }
    
    func play() {
        if !animationView.isAnimationPlaying, !self.played {
            self.played = true
            animationView.play { [weak self] _ in
                self?.completion?()
            }
        }
    }
    
    func loop() {
        animationView.play()
    }
    
    func reset() {
        if self.played {
            self.played = false
            animationView.stop()
        }
    }
    
    func goToEnd(animated: Bool) {
        isSelected = true
        if !animated {
           // animationView.play(fromFrame: .greatestFiniteMagnitude, toFrame: .greatestFiniteMagnitude, loopMode: nil, completion: nil)
            animationView.currentFrame = .greatestFiniteMagnitude
          //  animationView.stop()
        } else {
            animationView.play(fromFrame: animationView.realtimeAnimationFrame, toFrame: .greatestFiniteMagnitude, loopMode: nil, completion: nil)
        }
    }
    
    func goToStart(animated: Bool) {
        isSelected = false
        if !animated {
            animationView.currentFrame = .init()
            animationView.stop()

        } else  {
            animationView.play(fromFrame: animationView.realtimeAnimationFrame, toFrame: .init(), loopMode: nil, completion: nil)
        }
    }
    
    override func layout() {
        super.layout()
    //    animationView.setFrameSize(frame.size)
        animationView.center()
        animationView.setFrameOrigin(animationView.frame.minX, animationView.frame.minY - offset)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
