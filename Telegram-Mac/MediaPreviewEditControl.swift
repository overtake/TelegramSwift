//
//  MediaPreviewEditControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class MediaPreviewEditControl: View {
    private let crop = ImageButton()
    private let paint = ImageButton()
    private let delete = ImageButton()
    override init() {
        super.init(frame: NSMakeRect(0, 0, 90, 30))
        addSubview(crop)
        addSubview(paint)
        addSubview(delete)
        crop.autohighlight = false
        paint.autohighlight = false
        delete.autohighlight = false
        crop.scaleOnClick = true
        paint.scaleOnClick = true
        delete.scaleOnClick = true
        crop.set(image: theme.icons.editor_crop, for: .Normal)
        paint.set(image: theme.icons.editor_draw, for: .Normal)
        delete.set(image: theme.icons.editor_delete, for: .Normal)
        _ = crop.sizeToFit(NSZeroSize, NSMakeSize(27, frame.height), thatFit: true)
        _ = delete.sizeToFit(NSZeroSize, NSMakeSize(27, frame.height), thatFit: true)
        _ = paint.sizeToFit(NSZeroSize, NSMakeSize(27, frame.height), thatFit: true)

        backgroundColor = .blackTransparent
        layer?.cornerRadius = frame.height / 2
    }
    
    func set(edit:@escaping()->Void, paint: @escaping()->Void, delete:@escaping()->Void, editedData: EditedImageData?) {
        self.crop.removeAllHandlers()
        self.delete.removeAllHandlers()
        self.paint.removeAllHandlers()
        


//        self.crop.isSelected = editedData != nil
//        self.paint.isSelected = !(editedData?.paintings.isEmpty ?? true)
        
        self.crop.set(handler: { _ in
            edit()
        }, for: .Click)
        
        self.paint.set(handler: { _ in
            paint()
        }, for: .Click)
        
        self.delete.set(handler: { _ in
            delete()
        }, for: .Click)
    }
    
    var canEdit: Bool = true {
        didSet {
            crop.isHidden = !canEdit
            self.setFrameSize(canEdit ? 90 : 30, frame.height)
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
            delete.set(image: isInteractiveMedia ? theme.icons.editor_delete : theme.icons.previewSenderDeleteFile, for: .Normal)
        }
    }
    
    override func layout() {
        super.layout()
        if canEdit {
            crop.centerY(x: 3)
            paint.centerY(x: crop.frame.maxX)
            delete.centerY(x: paint.frame.maxX)
        } else {
            delete.center()
        }
    }
    
    override var isHidden: Bool {
        didSet {
            var bp:Int = 0
            bp += 1
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
