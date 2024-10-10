//
//  GeneralInteractedRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit


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
        
    let nameLayout: TextViewLayout
    let nameLayoutSelected: TextViewLayout
    let name:String
    let nameAttributed: NSAttributedString?
    var descLayout:TextViewLayout?
    var nameStyle:ControlStyle
    let thumb:GeneralThumbAdditional?
    let activeThumb:GeneralThumbAdditional?
    let switchAppearance: SwitchViewAppearance
    let autoswitch: Bool
    
    let badgeNode:BadgeNode?
    
    let disabledAction:(()->Void)?
    
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
            case .selectableLeft:
                width -= 40
            default:
                break
            }
            if let thumb = thumb {
                width -= thumb.thumb.systemSize.width + 20
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
            case .selectableLeft:
                width -= 40
            default:
                break
            }
            if let thumb = thumb {
                width -= thumb.thumb.systemSize.width + 20
            }
            return width
        }
    }
    
    private let menuItems:(()->[ContextMenuItem])?
    let disableBorder: Bool
    let rightIcon: CGImage?
    let switchAction:(()->Void)?
    let descClick:(()->Void)?
    let afterNameImage: CGImage?
    init(_ initialSize:NSSize, stableId:AnyHashable = arc4random(), name:String, nameAttributed: NSAttributedString? = nil, icon: CGImage? = nil, activeIcon: CGImage? = nil, nameStyle:ControlStyle = ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text), description: String? = nil, descTextColor: NSColor = theme.colors.grayText, type:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping ()->Void = {}, drawCustomSeparator:Bool = true, thumb:GeneralThumbAdditional? = nil, border:BorderType = [], inset: NSEdgeInsets = NSEdgeInsets(left: 20, right: 20), enabled: Bool = true, switchAppearance: SwitchViewAppearance = switchViewAppearance, error: InputDataValueError? = nil, autoswitch: Bool = true, disabledAction: (()-> Void)? = nil, menuItems:(()->[ContextMenuItem])? = nil, customTheme: GeneralRowItem.Theme? = nil, disableBorder: Bool = false, rightIcon: CGImage? = nil, switchAction:(()->Void)? = nil, descClick:(()->Void)? = nil, afterNameImage: CGImage? = nil, iconTextInset: CGFloat? = nil, iconInset: CGFloat? = nil) {
        
        self.afterNameImage = afterNameImage
        self.name = name
        self.nameAttributed = nameAttributed
        self.switchAction = switchAction
        self.rightIcon = rightIcon
        self.menuItems = menuItems
        self.disableBorder = disableBorder
        if let description = description {
            descLayout = TextViewLayout(.initialize(string: description, color: descTextColor, font: .normal(.text)), maximumNumberOfLines: 4)
        } else {
            descLayout = nil
        }
        self.nameStyle = nameStyle
        if thumb == nil, let icon = icon {
            self.thumb = GeneralThumbAdditional(thumb: icon, textInset: iconTextInset, thumbInset: iconInset)
        } else {
            self.thumb = thumb
        }
        if case let .badge(text, color) = type {
            self.badgeNode = .init(.initialize(string: text, color: .white, font: .medium(.short)), color)
        } else {
            self.badgeNode = nil
        }
        self.disabledAction = disabledAction
        self.autoswitch = autoswitch
        self.activeThumb = activeIcon != nil ? GeneralThumbAdditional(thumb: activeIcon!, textInset: nil) : self.thumb
        self.switchAppearance = customTheme?.switchAppearance ?? switchAppearance
        self.descClick = descClick
        
        
        let nameAttributed = self.nameAttributed ?? NSAttributedString.initialize(string: name, color: enabled ? nameStyle.foregroundColor : theme.colors.grayText, font: nameStyle.font)
        
        let nameAttributedSelected = self.nameAttributed ?? NSAttributedString.initialize(string: name, color: theme.colors.underSelectedColor, font: nameStyle.font)
        
        nameLayout = .init(nameAttributed, maximumNumberOfLines: 1)
        nameLayoutSelected = .init(nameAttributedSelected, maximumNumberOfLines: 1)

        
        super.init(initialSize, height: 0, stableId:stableId, type:type, viewType: viewType, action:action, drawCustomSeparator:drawCustomSeparator, border:border, inset:inset, enabled: enabled, error: error, customTheme: customTheme)
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
            let height: CGFloat = super.height + insets.top + insets.bottom + nameLayout.layoutSize.height
            if let descLayout = self.descLayout {
                if descLayout.lines.count > 1 {
                    return height + descLayout.layoutSize.height - 10
                } else {
                    return height + 8
                }
            }
            return height
        }
    }
    
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
                

        nameLayout.measure(width: nameWidth)
        nameLayoutSelected.measure(width: nameWidth)
        
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
        } else if case let .contextSelector(_, items) = type {
            if !items.isEmpty {
                return .single(items)
            } else {
                return super.menuItems(in: location)
            }
        } else {
            return super.menuItems(in: location)
        }
    }
}
