//
//  MediaPreviewEditControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class MediaPreviewEditControl: Control {
    private let crop = ImageButton()
    private let delete = ImageButton()
    override init() {
        super.init(frame: NSMakeRect(0, 0, 60, 30))
        addSubview(crop)
        addSubview(delete)
        crop.set(image: theme.icons.previewSenderCrop, for: .Normal)
        delete.set(image: theme.icons.previewSenderDelete, for: .Normal)
        _ = crop.sizeToFit(NSZeroSize, NSMakeSize(27, frame.height), thatFit: true)
        _ = delete.sizeToFit(NSZeroSize, NSMakeSize(27, frame.height), thatFit: true)
        
        backgroundColor = .blackTransparent
        layer?.cornerRadius = frame.height / 2
    }
    
    func set(edit:@escaping()->Void, delete:@escaping()->Void, hasEditedData: Bool) {
        self.crop.removeAllHandlers()
        self.delete.removeAllHandlers()
        
        self.crop.isSelected = hasEditedData
        
        self.crop.set(handler: { _ in
            edit()
        }, for: .Up)
        
        self.delete.set(handler: { _ in
            delete()
        }, for: .Up)
    }
    
    var canEdit: Bool = true {
        didSet {
            crop.isHidden = !canEdit
            self.setFrameSize(canEdit ? 60 : 30, frame.height)
        }
    }
    var canDelete: Bool = true {
        didSet {
            delete.isHidden = !canDelete
        }
    }
    
    var isInteractiveMedia: Bool = true {
        didSet {
            backgroundColor = isInteractiveMedia ? .blackTransparent : .clear
            delete.set(image: isInteractiveMedia ? theme.icons.previewSenderDelete : theme.icons.previewSenderDeleteFile, for: .Normal)
        }
    }
    
    override func layout() {
        super.layout()
        if canEdit {
            crop.centerY(x: 3)
            delete.centerY(x: crop.frame.maxX)
        } else {
            delete.center()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
