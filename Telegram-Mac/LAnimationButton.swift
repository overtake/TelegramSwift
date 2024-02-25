//
//  LAnimationButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import TelegramMedia

enum LButtonAutoplaySide {
    case left
    case right
}

class LAnimationButton: Button {
    private let animationView: LottiePlayerView = LottiePlayerView(frame: NSZeroRect)
    var speed: CGFloat = 1.0 {
        didSet {
           //animationView.animationSpeed = speed
        }
    }
    private let offset: NSSize
    var updateIfWindowChanged: Bool = true
    var played = false
    var completion: (() -> Void)?

    var autoplayOnVisibleSide: LButtonAutoplaySide? = nil
    private var animation: LottieAnimation?
    private var firstFrame: LottieAnimation?
    init(animation: String, size: NSSize, keysToColor: [String]? = nil, color: NSColor = .black, offset: NSSize = NSMakeSize(0, 0), autoplaySide: LButtonAutoplaySide? = nil, rotated: Bool = false) {
        self.offset = offset
        self.autoplayOnVisibleSide = autoplaySide
        
        animationView.setFrameSize(size)
        super.init(frame: NSMakeRect(0, 0, size.width, size.height))
        addSubview(animationView)
        
        setAnimationName(animation, keysToColor: keysToColor, color: color)
        
        if rotated {
           // animationView.rotate(byDegrees: 180)
        }
    }
    
    func setAnimationName(_ animation: String, keysToColor: [String]? = nil, color: NSColor = .black) {
        if let file = Bundle.main.path(forResource: animation, ofType: "json"), let data = try? Data(contentsOf: URL(fileURLWithPath: file)) {
            self.animation = LottieAnimation(compressed: data, key: .init(key: .bundle(animation), size: frame.size), cachePurpose: .none, playPolicy: .toEnd(from: 1), maximumFps: 60, runOnQueue: .mainQueue())
            self.firstFrame = LottieAnimation(compressed: data, key: .init(key: .bundle(animation), size: frame.size), cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, runOnQueue: .mainQueue())
        } else {
            self.animation = nil
            self.firstFrame = nil
        }
        set(keysToColor: keysToColor, color: color)
    }
    
    func set(keysToColor: [String]? = nil, color: NSColor = .black) {
        let newColor = color.usingColorSpace(.deviceRGB)!
        
        var colors: [LottieColor] = []
        if let keysToColor = keysToColor {
            for keyToColor in keysToColor {
                colors.append(LottieColor(keyPath: keyToColor, color: newColor))
            }
        }
        
        if self.animation?.colors != colors {
            self.animation = self.animation?.withUpdatedColors(colors)
            self.firstFrame = self.firstFrame?.withUpdatedColors(colors)
            animationView.set(self.firstFrame)
        }
    }
    
    
    override func viewDidMoveToWindow() {
        if updateIfWindowChanged {
            if window == nil {
                animationView.set(nil)
            } else {
                animationView.set(self.firstFrame)
            }
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
                    animationView.set(self.animation)
                }
            } else if self.played {
                self.played = false
                animationView.set(self.firstFrame)
            }
        }
       
        
        self.prevVisibleRect = visibleRect
    }
    

    
    func loop() {
        self.animationView.set(self.animation, reset: true)
    }
    


    
    override func layout() {
        super.layout()
        animationView.center()
        animationView.setFrameOrigin(animationView.frame.minX - offset.width, animationView.frame.minY - offset.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
