//
//  MediaTitleBarView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 14/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


final class PeerMediaTypeInteraction {
    var media:() -> Void = {}
    var files:() -> Void = {}
    var links:() -> Void = {}
    var audio:() -> Void = {}
    
    init(media:@escaping() -> Void, files:@escaping() -> Void, links:@escaping() -> Void, audio:@escaping() -> Void) {
        self.media = media
        self.files = files
        self.links = links
        self.audio = audio
    }
}



class MediaTitleBarView: TitledBarView {

    private let button:TitleButton = TitleButton()
    private let dropdownImage = ImageButton()
    
    public init(controller: ViewController, interactions:PeerMediaTypeInteraction) {
        super.init(controller: controller)
        
        button.set(font: .medium(.title), for: .Normal)
       
        
        button.highlightHovered = true
        dropdownImage.highlightHovered = true
        let showDropDown:(Control) -> Void = { [weak self] _ in
            
            if let strongSelf = self, !hasPopover(mainWindow) {
                var items:[SPopoverItem] = []
                items.append(SPopoverItem(tr(L10n.peerMediaPopoverSharedMedia), { [weak strongSelf] in
                    interactions.media()
                    strongSelf?.button.set(text: tr(L10n.peerMediaSharedMedia), for: .Normal)
                }))
                items.append(SPopoverItem(tr(L10n.peerMediaPopoverSharedFiles), { [weak strongSelf] in
                    interactions.files()
                    strongSelf?.button.set(text: tr(L10n.peerMediaPopoverSharedFiles), for: .Normal)
                }))
                items.append(SPopoverItem(tr(L10n.peerMediaPopoverSharedLinks), { [weak strongSelf] in
                    interactions.links()
                    strongSelf?.button.set(text: tr(L10n.peerMediaPopoverSharedLinks), for: .Normal)
                }))
                items.append(SPopoverItem(tr(L10n.peerMediaPopoverSharedAudio), { [weak strongSelf] in
                    interactions.audio()
                    strongSelf?.button.set(text: tr(L10n.peerMediaPopoverSharedAudio), for: .Normal)
                }))
                
                let controller = SPopoverViewController(items: items)
                showPopover(for: strongSelf, with: controller, edge: .maxY, inset: NSMakePoint( floorToScreenPixels(scaleFactor: System.backingScale, strongSelf.frame.width / 2) - floorToScreenPixels(scaleFactor: System.backingScale, controller.frame.width/2),-50))
                
            }
        }
        
        self.set(handler: showDropDown, for: .Click)
        
        dropdownImage.userInteractionEnabled = false
        button.userInteractionEnabled = false
        
        //dropdownImage.set(handler: showDropDown, for: .Click)
        
        set(handler: { [weak self] control in
            
            //self?.dropdownImage.layer?.animateRotateCenter(from: 0, to: 180, duration: 0.2, removeOnCompletion: false)
            
        }, for: .Highlight)
        
        button.sizeToFit()
        addSubview(button)
        
       
        addSubview(dropdownImage)
    }
    
    override func updateLocalizationAndTheme() {
        button.set(text: tr(L10n.peerMediaSharedMedia), for: .Normal)
        button.set(color: theme.colors.blueUI, for: .Normal)
        dropdownImage.set(image: theme.icons.mediaDropdown, for: .Normal)
        dropdownImage.sizeToFit()
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        button.center()
        dropdownImage.centerY(x: button.frame.maxX + 4)
        dropdownImage.setFrameOrigin(dropdownImage.frame.minX, dropdownImage.frame.minY + 1)
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
