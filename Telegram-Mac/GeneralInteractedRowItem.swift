//
//  GeneralInteractedRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac


struct GeneralThumbAdditional {
    let thumb:CGImage
    let textInset:CGFloat?
    let thumbInset: CGFloat?
    init(thumb: CGImage, textInset: CGFloat? = nil, thumbInset: CGFloat? = nil) {
        self.thumb = thumb
        self.textInset = textInset
        self.thumbInset = thumbInset
    }
}


class GeneralInteractedRowItem: GeneralRowItem {
        
    var nameLayout:(TextNodeLayout, TextNode)?
    var nameLayoutSelected:(TextNodeLayout, TextNode)?
    let name:String
    var descLayout:TextViewLayout?
    var nameStyle:ControlStyle
    let thumb:GeneralThumbAdditional?
    let activeThumb:GeneralThumbAdditional?
    let switchAppearance: SwitchViewAppearance
    let autoswitch: Bool
    
    let disabledAction:()->Void
    
    var nameWidth:CGFloat {
        switch self.viewType {
        case .legacy:
            var width = self.size.width - (inset.left + inset.right)
            switch type {
            case .switchable:
                width -= 40
            case .context:
                width -= 40
            case .selectable:
                width -= 40
            default:
                break
            }
            if let thumb = thumb {
                width -= thumb.thumb.backingSize.width + 20
            }
            return width
        case let .modern(_, insets):
            var width = self.blockWidth - (insets.left + insets.right)
            switch type {
            case .switchable:
                width -= 40
            case .context:
                width -= 40
            case .selectable:
                width -= 40
            default:
                break
            }
            if let thumb = thumb {
                width -= thumb.thumb.backingSize.width + 20
            }
            return width
        }
    }
    
    private let menuItems:(()->[ContextMenuItem])?
    
   
    init(_ initialSize:NSSize, stableId:AnyHashable = arc4random(), name:String, icon: CGImage? = nil, activeIcon: CGImage? = nil, nameStyle:ControlStyle = ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text), description: String? = nil, descTextColor: NSColor = theme.colors.grayText, type:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping ()->Void = {}, drawCustomSeparator:Bool = true, thumb:GeneralThumbAdditional? = nil, border:BorderType = [], inset: NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), enabled: Bool = true, switchAppearance: SwitchViewAppearance = switchViewAppearance, error: InputDataValueError? = nil, autoswitch: Bool = true, disabledAction: @escaping()-> Void = {}, menuItems:(()->[ContextMenuItem])? = nil) {
        self.name = name
        self.menuItems = menuItems
        if let description = description {
            descLayout = TextViewLayout(.initialize(string: description, color: descTextColor, font: .normal(.text)))
        } else {
            descLayout = nil
        }
        self.nameStyle = nameStyle
        if thumb == nil, let icon = icon {
            self.thumb = GeneralThumbAdditional(thumb: icon, textInset: nil)
        } else {
            self.thumb = thumb
        }
        self.disabledAction = disabledAction
        self.autoswitch = autoswitch
        self.activeThumb = activeIcon != nil ? GeneralThumbAdditional(thumb: activeIcon!, textInset: nil) : self.thumb
        self.switchAppearance = switchAppearance
        super.init(initialSize, height: 0, stableId:stableId, type:type, viewType: viewType, action:action, drawCustomSeparator:drawCustomSeparator, border:border, inset:inset, enabled: enabled, error: error)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override var height: CGFloat {
        
        switch viewType {
        case .legacy:
            let height: CGFloat = super.height + 40
            if let descLayout = descLayout {
                return height + descLayout.layoutSize.height
            }
            return height
        case let .modern(_, insets):
            let height: CGFloat = super.height + insets.top + insets.bottom + nameLayout!.0.size.height
            if let descLayout = self.descLayout {
                return height + descLayout.layoutSize.height + 2
            }
            return height
        }
    }
    
    
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        nameLayout = TextNode.layoutText(maybeNode: nil,  NSAttributedString.initialize(string: name, color: enabled ? nameStyle.foregroundColor : theme.colors.grayText, font: nameStyle.font), nil, 1, .end, NSMakeSize(nameWidth, .greatestFiniteMagnitude), nil, isSelected, .left)
        nameLayoutSelected = TextNode.layoutText(maybeNode: nil,  NSAttributedString.initialize(string: name, color: theme.colors.underSelectedColor, font: nameStyle.font), nil, 1, .end, NSMakeSize(nameWidth, .greatestFiniteMagnitude), nil, isSelected, .left)
        descLayout?.measure(width: nameWidth)
        
        return result
    }
    
    override func prepare(_ selected: Bool) {
        super.prepare(selected)
    }
    
    override func viewClass() -> AnyClass {
        return GeneralInteractedRowView.self
    }
    
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        
        if let menuItems = self.menuItems {
            return .single(menuItems())
        } else {
            return super.menuItems(in: location)
        }
    }
}
