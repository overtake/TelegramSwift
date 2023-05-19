//
//  SelectingControl.swift
//  TGUIKit
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class SelectingControl: Control {
    
   
    private var selectedView:ImageView?
    private let unselectedView = ImageView()
    private var unselectedImage:CGImage
    private var selectedImage:CGImage
    
    public init(unselectedImage:CGImage, selectedImage:CGImage, selected: Bool = false) {
        self.unselectedImage = unselectedImage
        self.selectedImage = selectedImage
        
        self.unselectedView.image = unselectedImage
        self.unselectedView.sizeToFit()
        super.init(frame:NSMakeRect(0, 0, max(unselectedImage.backingSize.width ,selectedImage.backingSize.width ), max(unselectedImage.backingSize.height,selectedImage.backingSize.height )))
        userInteractionEnabled = false
        addSubview(unselectedView)
        self.set(selected: selected, animated: false)
    }
    
    public override func layout() {
        super.layout()
        unselectedView.center()
        selectedView?.center()
    }
    
    public func set(selected:Bool, animated:Bool = false) {
        if selected != isSelected {

            self.isSelected = selected
            if selected {
                if selectedView == nil {
                    selectedView = ImageView()
                    addSubview(selectedView!)
                    selectedView!.image = selectedImage
                    selectedView!.sizeToFit()
                    selectedView!.center()
                    if animated {
                        selectedView!.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        selectedView!.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.3)
                    }
                }
            } else {
                if let selectedView = self.selectedView {
                    self.selectedView = nil
                    if animated {
                        selectedView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.3, removeOnCompletion: false)
                        selectedView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak selectedView] _ in
                            selectedView?.removeFromSuperview()
                        })
                    } else {
                        selectedView.removeFromSuperview()
                    }
                }
            }
            
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        
    }
    
}
