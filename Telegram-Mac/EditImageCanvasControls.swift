//
//  EditImageCanvasControls.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit




final class EditImageCanvasControlsView : View {
    let cancel = TitleButton()
    private let success = TitleButton()
    private let controlsContainer = View()
    private let undo = ImageButton()
    private let redo = ImageButton()
    private let draw = ImageButton()
    private let clear = ImageButton()
    
    private var currentData: EditedImageData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(cancel)
        addSubview(success)
        
        addSubview(controlsContainer)
        
        controlsContainer.addSubview(undo)
        controlsContainer.addSubview(redo)
        controlsContainer.addSubview(draw)
        controlsContainer.addSubview(clear)
        
        controlsContainer.border = [.Left, .Right]
        controlsContainer.borderColor = NSColor.black.withAlphaComponent(0.2)
        backgroundColor = NSColor(0x303030)
        layer?.cornerRadius = 6
        
        updateUserInterface()
    }
    
    fileprivate func updateUserInterface() {
        undo.set(image: NSImage(named: "Icon_EditImageUndo")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        redo.set(image: NSImage(named: "Icon_EditImageUndo")!.precomposed(NSColor.white.withAlphaComponent(0.8), flipHorizontal: true), for: .Normal)
        draw.set(image: NSImage(named: "Icon_EditImageDraw")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        clear.set(image: NSImage(named: "Icon_EditImageEraser")!.precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        
        
        undo.set(image: NSImage(named: "Icon_EditImageUndo")!.precomposed(.white), for: .Hover)
        redo.set(image: NSImage(named: "Icon_EditImageUndo")!.precomposed(NSColor.white, flipHorizontal: true), for: .Hover)
        draw.set(image: NSImage(named: "Icon_EditImageDraw")!.precomposed(.white), for: .Hover)
        clear.set(image: NSImage(named: "Icon_EditImageEraser")!.precomposed(.white), for: .Hover)
        
        
        _ = undo.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = redo.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = draw.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = clear.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        
        cancel.set(font: .medium(.title), for: .Normal)
        success.set(font: .medium(.title), for: .Normal)
        
        success.set(color: nightAccentPalette.accent, for: .Normal)
        cancel.set(color: .white, for: .Normal)
        
        cancel.set(text: L10n.modalCancel, for: .Normal)
        success.set(text: L10n.navigationDone, for: .Normal)
        
        _ = cancel.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        _ = success.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        
        
        undo.set(handler: { [weak self] _ in
            self?.arguments?.undo()
        }, for: .Click)
        
        redo.set(handler: { [weak self] _ in
            self?.arguments?.redo()
        }, for: .Click)
        
        draw.set(handler: { [weak self] _ in
            self?.arguments?.switchAction(.draw)
        }, for: .Click)
        
        clear.set(handler: { [weak self] _ in
            self?.arguments?.switchAction(.clear)
        }, for: .Click)
        
        
        success.set(handler: { [weak self] _ in
            self?.arguments?.save()
        }, for: .Click)
        
        cancel.set(handler: { [weak self] _ in
             self?.arguments?.cancel()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        controlsContainer.setFrameSize(draw.frame.width + undo.frame.width + redo.frame.width + clear.frame.width, draw.frame.height)
        undo.setFrameOrigin(NSMakePoint(0, 0))
        undo.setFrameOrigin(NSMakePoint(draw.frame.maxX, 0))
        draw.setFrameOrigin(NSMakePoint(undo.frame.maxX, 0))
        clear.setFrameOrigin(NSMakePoint(draw.frame.maxX, 0))
        controlsContainer.center()
        
        cancel.centerY()
        success.centerY(x: frame.width - success.frame.width)
    }
    var arguments: EditImageCanvasArguments? = nil
    
    func update(with state: EditImageCanvasState) {
        
        undo.isEnabled = !state.actionValues.isEmpty
        redo.isEnabled = !state.removedActions.isEmpty
        draw.isSelected = state.action == .draw
        clear.isSelected = state.action == .clear

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
