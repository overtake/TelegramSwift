//
//  ImageButton.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum ButtonHoverPolicy {
    case none
    case enlarge(value: CGFloat)
}

public enum ButtonBackgroundCornerRadius {
    case none
    case appSpecific
    case half
}

public enum ImageButtonAnimationPolicy {
    case animateContents
    case replaceScale
}

open class ImageButton: Button {

    internal private(set) var imageView:ImageView = ImageView()
    internal let additionBackgroundView: View = View()
    
    private var additionStateBackground:[ControlState:NSColor] = [:]
    private var cornerRadius:[ControlState : ButtonBackgroundCornerRadius] = [:]
    
    private var hoverAdditionPolicy:[ControlState : ButtonHoverPolicy] = [:]
    
    private var additionBackgroundMultiplier:[ControlState: CGFloat] = [:]
    
    private var images:[ControlState:CGImage] = [:]

    private var backgroundImage:[ControlState:CGImage] = [:]
    
    
    public func removeImage(for state:ControlState) {
        images.removeValue(forKey: state)
        apply(state: self.controlState)
        
    }
    
    public func setImageContentGravity(_ gravity: CALayerContentsGravity) {
        imageView.contentGravity = gravity
    }
    
    public func set(image:CGImage, for state:ControlState) -> Void {
        images[state] = image
        apply(state: self.controlState)
    }
    
    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
    }
    
    override func prepare() {
        super.prepare()
        imageView.animates = true
        additionBackgroundView.isEventLess = true
//        imageView.isEventLess = true
        self.addSubview(additionBackgroundView)
        self.addSubview(imageView)
    }
    
    public func set(additionBackgroundColor:NSColor, for state:ControlState) -> Void {
        additionStateBackground[state] = additionBackgroundColor
        apply(state: self.controlState)
    }
    public func set(additionBackgroundMultiplier: CGFloat, for state:ControlState) -> Void {
        self.additionBackgroundMultiplier[state] = additionBackgroundMultiplier
        apply(state: self.controlState)
    }
    
    
    public func set(cornerRadius: ButtonBackgroundCornerRadius, for state:ControlState) -> Void {
        self.cornerRadius[state] = cornerRadius
        apply(state: self.controlState)
    }
    public func set(hoverAdditionPolicy: ButtonHoverPolicy, for state:ControlState) -> Void {
        self.hoverAdditionPolicy[state] = hoverAdditionPolicy
        apply(state: self.controlState)
    }
    
    
    

    public override var animates: Bool {
        didSet {
            imageView.animates = animates
        }
    }
    
    private var previousState: ControlState?
    
    override public func apply(state: ControlState) {
        let previous = self.previousState
        let state:ControlState = self.isSelected ? .Highlight : state
        super.apply(state: state)
        self.previousState = state
        
        let updated: CGImage?
        
        if let image = images[state], isEnabled {
            updated = image
        } else if state == .Highlight && autohighlight, isEnabled, let image = images[.Normal] {
            updated = style.highlight(image: image)
        } else if state == .Hover && highlightHovered, isEnabled, let image = images[.Normal] {
            updated = style.highlight(image: image)
        } else {
            updated = images[.Normal]
        }
        
        if imageView.image != updated {
            self.imageView.image = updated
        }
        
        
        if let policy = self.hoverAdditionPolicy[state], previous != state {
            switch policy {
            case .none:
                break
            case let .enlarge(value):
                let current = additionBackgroundView.layer?.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat ?? 1.0
                additionBackgroundView.layer?.animateScaleSpring(from: current, to: value, duration: 0.35, removeOnCompletion: false)
            }
        }
        
        if let color = self.additionStateBackground[state] ?? self.additionStateBackground[.Normal] {
            additionBackgroundView.backgroundColor = color
        } else {
            additionBackgroundView.backgroundColor = .clear
        }

        updateLayout()
        
        if let cornerRadius = self.cornerRadius[state] {
            switch cornerRadius {
            case .none:
                self.layer?.cornerRadius = 0
                self.additionBackgroundView.layer?.cornerRadius = 0
            case .appSpecific:
                self.layer?.cornerRadius = .cornerRadius
                self.additionBackgroundView.layer?.cornerRadius = .cornerRadius
            case .half:
                self.layer?.cornerRadius = max(frame.width, frame.height) / 2
                self.additionBackgroundView.layer?.cornerRadius = max(additionBackgroundView.frame.width, additionBackgroundView.frame.height) / 2
            }
        }
        
    }
    
    public func applyAnimation(from: CGImage, to: CGImage, animation: ImageButtonAnimationPolicy) {
        switch animation {
        case .animateContents:
            self.imageView.image = to
        case .replaceScale:
            let imageView = self.imageView
            imageView.image = from
            let newImageView = ImageView()
            self.imageView = newImageView
            newImageView.image = to
            newImageView.sizeToFit()
            addSubview(newImageView)
            newImageView.center()
            
            
            imageView.layer?.animateScaleCenter(from: 1, to: 0.1, duration: 0.25, removeOnCompletion: false, completion: { [weak imageView] _ in
                imageView?.removeFromSuperview()
            })
            imageView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
            
            newImageView.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.25, removeOnCompletion: true)
        }
    }
    
    public func disableActions() {
        animates = false
        self.layer?.disableActions()
        layer?.removeAllAnimations()
        imageView.animates = false
        imageView.layer?.disableActions()
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    @discardableResult override public func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
        _ = super.sizeToFit(addition, maxSize, thatFit: thatFit)
        
        if let image = images[.Normal] {
            var size = image.backingSize
            
            if maxSize.width > 0 || maxSize.height > 0 {
                size = maxSize
            }
            
            size.width += addition.width
            size.height += addition.height
            self.setFrameSize(size)
        }
        return true
    }
    
    public override func updateLayout() {
        if let image = images[controlState] {
            switch imageView.contentGravity {
            case .resize, .resizeAspectFill:
                imageView.setFrameSize(frame.size)
            default:
                imageView.setFrameSize(image.backingSize)
            }
        }
        imageView.center()
        
        if let multiplier = additionBackgroundMultiplier[controlState] {
            additionBackgroundView.setFrameSize(NSMakeSize(floorToScreenPixels(backingScaleFactor, frame.width * multiplier), floorToScreenPixels(backingScaleFactor, frame.height * multiplier)))
        } else {
            additionBackgroundView.setFrameSize(frame.size)
        }
        
        additionBackgroundView.center()
    }
    
}
