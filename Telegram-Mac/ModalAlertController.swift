//
//  ModalAlertController.swift
//  Telegram
//
//  Created by Mike Renoir on 07.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let presentation: TelegramPresentationTheme
    let action: ()->Void
    let toggle: (Int)->Void
    let secondAction:()->Void
    init(presentation: TelegramPresentationTheme, action: @escaping()->Void, toggle: @escaping(Int)->Void, secondAction:@escaping()->Void) {
        self.presentation = presentation
        self.action = action
        self.toggle = toggle
        self.secondAction = secondAction
    }
}

private struct State : Equatable {
    var data: ModalAlertData
    
    var actionEnabled: Bool {
        var enabled: Bool = true
        for option in data.options {
            if option.mandatory && !option.isSelected {
                enabled = false
                break
            }
        }
        return enabled
    }
}



private final class RowItem : TableRowItem {
    struct Option {
        let selected: Bool
        let mandatory: Bool
        let text: TextViewLayout
        
        var size: NSSize {
            return NSMakeSize(text.layoutSize.width + 25 + 10, text.layoutSize.height + 4)
        }
    }
    struct Description {
        let onlyWhenEnabled: Bool
        let text: TextViewLayout
        
        var size: NSSize {
            return text.layoutSize
        }
    }
    fileprivate let state: State
    fileprivate var info: TextViewLayout?
    fileprivate var desc: Description?
    fileprivate var disclaimer: TextViewLayout?
    fileprivate let options: [Option]
    fileprivate let toggle: (Int)->Void
    fileprivate let action:()->Void
    fileprivate let secondAction:()->Void
    fileprivate let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, presentation: TelegramPresentationTheme, state: State, toggle:@escaping(Int)->Void, action: @escaping()->Void, secondAction:@escaping()->Void) {
        self.state = state
        self.presentation = presentation
        self.toggle = toggle
        self.action = action
        self.secondAction = secondAction
        if !state.data.info.isEmpty {
            let info = parseMarkdownIntoAttributedString(state.data.info, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: presentation.colors.darkGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.darkGrayText), link: MarkdownAttributeSet(font: .medium(.text), textColor: presentation.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
            })).mutableCopy() as! NSMutableAttributedString
            
            info.detectBoldColorInString(with: .medium(.text))
            self.info = .init(info, alignment: .center, alwaysStaticItems: true)
            self.info?.interactions = globalLinkExecutor

        } else {
            self.info = nil
        }
        
        if let disclaimer = state.data.disclaimer {
            self.disclaimer = .init(.initialize(string: disclaimer, color: presentation.colors.redUI, font: .medium(.text)), alignment: .center)
        } else {
            self.disclaimer = nil
        }
        
        
        if let desc = state.data.description {
            let text = parseMarkdownIntoAttributedString(desc.string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: presentation.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: presentation.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
            })).mutableCopy() as! NSMutableAttributedString
            
            text.detectBoldColorInString(with: .medium(.text))
            
            self.desc = .init(onlyWhenEnabled: desc.onlyWhenEnabled, text: .init(text, alignment: .center))
        } else {
            self.desc = nil
        }
        

        var opts: [Option] = []
        for option in state.data.options {
            let text = parseMarkdownIntoAttributedString(option.string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: presentation.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: presentation.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
            }))
            
            let layout = TextViewLayout(text)
            
            layout.interactions = globalLinkExecutor
            let value = Option(selected: option.isSelected, mandatory: option.mandatory, text: layout)
            opts.append(value)
        }
        self.options = opts
        
        super.init(initialSize)
        _ = makeSize(initialSize.width)
    }
    
    override var stableId: AnyHashable {
        return 0
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        info?.measure(width: width - 40)
        
        disclaimer?.measure(width: width - 40 - 20)
        
        for option in options {
            option.text.measure(width: width - 40 - 40)
        }
        desc?.text.measure(width: width - 40)
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
                        
        if let info = info {
            height += info.layoutSize.height
            height += 20
        }
        
        if state.data.title == nil {
            height += 20
        }
        
        if !options.isEmpty {
            height += 20
        }
        height += optionsSize.height
        
        if let descprion = desc {
            if !descprion.onlyWhenEnabled || actionEnabled {
                height += descprion.size.height
                height += 10
            }
        }
        
        if let disclaimer = disclaimer {
            height += disclaimer.layoutSize.height + 10
            height += 20
        }
        
        height += 40 //button
        height += 20
        

        return height
    }
    
    var optionsSize: NSSize {
        var height: CGFloat = 0
        var width: CGFloat = 0
        for (i, option) in options.enumerated() {
            height += option.size.height
            if i != options.count - 1 {
                height += 10
            }
            width = max(width, option.size.width)
        }
        return NSMakeSize(width, height)
    }
    
    var actionEnabled: Bool {
        return state.actionEnabled
    }
    
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView : TableRowView {
   

    private final class OptionView: Control {
        private let textView = TextView()
        private let imageView = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.generalCheck)
        private var toggle:(()->Void)? = nil
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            textView.isSelectable = false
            addSubview(textView)
            addSubview(imageView)
            
            imageView.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
            
            textView.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
            
            self.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
            
            self.layer?.masksToBounds = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(option: RowItem.Option, presentation: TelegramPresentationTheme, toggle:@escaping()->Void, animated: Bool) {
            self.toggle = toggle
            
            let selected = generateCheckSelected(foregroundColor: presentation.colors.accentIcon, backgroundColor: presentation.colors.underSelectedColor)
            
            self.imageView.update(unselectedImage: presentation.icons.chatToggleUnselected, selectedImage: selected, selected: option.selected, animated: animated)
            self.textView.update(option.text)
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 0))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: imageView.frame.maxX + 10))
        }
    }
    
    private final class DisclaimerView : View {
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(text: TextViewLayout) {
            self.textView.update(text)
            self.setFrameSize(text.layoutSize.bounds.insetBy(dx: -5, dy: -5).size)
        }
        
        override func layout() {
            super.layout()
            self.textView.center()
        }
    }
    
    private let infoView = TextView()
    private let button = TextButton(frame: .zero)
    
    private var secondButton: TextButton? = nil
    
    private let optionsView = View()
    
    private var descriptionView:TextView?
    
    private var disclaimer: DisclaimerView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(infoView)
        addSubview(button)
        addSubview(optionsView)
                
        infoView.isSelectable = true
        
        button.set(handler: { [weak self] _ in
            if let item = self?.item as? RowItem {
                item.action()
            }
        }, for: .Click)
        
        button.scaleOnClick = true
        button._thatFit = true
        button.disableActions()
        optionsView.layer?.masksToBounds = false
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? RowItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        self.infoView.update(item.info)
        
        
        self.button.userInteractionEnabled = item.actionEnabled
        self.button.isEnabled = item.actionEnabled
        self.button.alphaValue = item.actionEnabled ? 1 : 0.8
        
        if case let .confirm(string, _) = item.state.data.mode {
            let current: TextButton
            if let view = self.secondButton {
                current = view
            } else {
                current = TextButton()
                current.scaleOnClick = true
                current.disableActions()
                current.set(font: .medium(.text), for: .Normal)
                self.secondButton = current
                addSubview(current)
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? RowItem {
                        item.secondAction()
                    }
                }, for: .Click)
            }
            
            current.set(background: item.presentation.colors.background, for: .Normal)
            current.set(text: string, for: .Normal)
            current._thatFit = true
            current.set(color: item.presentation.colors.darkGrayText, for: .Normal)
            current.layer?.cornerRadius = 10
            current.layer?.borderWidth = 1
            current.layer?.borderColor = item.presentation.colors.border.cgColor
        } else if let view = self.secondButton {
            performSubviewRemoval(view, animated: animated)
            self.secondButton = nil
        }
        
        
        optionsView.setFrameSize(item.optionsSize)
        
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: NSMakeRect(0, 0, optionsView.frame.width, 20)))
        }
        for (i, option) in item.options.enumerated() {
            (optionsView.subviews[i] as! OptionView).update(option: option, presentation: item.presentation, toggle: { [weak item] in
                item?.toggle(i)
            }, animated: animated)
        }
        
        if let desc = item.desc, !desc.onlyWhenEnabled || item.actionEnabled {
            let current: TextView
            let isNew: Bool
            if let view = self.descriptionView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.descriptionView = current
                addSubview(current)
                isNew = true
            }
            current.update(desc.text)
            if isNew {
                current.centerX(y: button.frame.minY - 10 - current.frame.height)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let view = self.descriptionView {
            performSubviewRemoval(view, animated: animated, duration: 0.2, scale: true)
            self.descriptionView = nil
        }
        
        if let disclaimer = item.disclaimer {
            let current: DisclaimerView
            let isNew: Bool
            if let view = self.disclaimer {
                current = view
                isNew = false
            } else {
                current = DisclaimerView(frame: .zero)
                self.disclaimer = current
                addSubview(current)
                isNew = true
            }
            current.set(text: disclaimer)
            current.layer?.cornerRadius = .cornerRadius
            current.backgroundColor = item.presentation.colors.redUI.withAlphaComponent(0.2)
            if isNew {
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let view = self.disclaimer {
            performSubviewRemoval(view, animated: animated, duration: 0.2, scale: true)
            self.disclaimer = nil
        }
        
        button.set(background: item.presentation.colors.accent, for: .Normal)
        button.set(font: .medium(.text), for: .Normal)
        button.set(text: item.state.data.ok, for: .Normal)
        button.set(color: item.presentation.colors.underSelectedColor, for: .Normal)

        button.layer?.cornerRadius = 10
                
      
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? RowItem else {
            return
        }
        
        
        transition.updateFrame(view: infoView, frame: infoView.centerFrameX(y: item.state.data.title == nil ? 20 : 0))

        if infoView.textLayout != nil {
            transition.updateFrame(view: optionsView, frame: optionsView.centerFrameX(y: infoView.frame.maxY + 20))
        } else {
            transition.updateFrame(view: optionsView, frame: optionsView.centerFrameX(y: infoView.frame.minY))
        }
        
        
        if let second = self.secondButton {
            let btnwidth = floor((size.width - 40 - 10) / 2)
            
            button.sizeToFit(NSMakeSize(20, 0))
            second.sizeToFit(NSMakeSize(20, 0))
            
            let effectiveOk = button.frame.width
            let effectiveSecond = second.frame.width

            var btnRect: NSRect
            var secondRect: NSRect
            if effectiveOk > btnwidth {
                btnRect = CGRect(origin: CGPoint(x: frame.width - effectiveOk - 20, y: size.height - 20 - 40), size: CGSize(width: effectiveOk, height: 40))
                secondRect = CGRect(origin: CGPoint(x: 20, y: size.height - 20 - 40), size: CGSize(width: frame.width - 40 - effectiveOk - 10, height: 40))
            } else if effectiveSecond > btnwidth {
                secondRect = CGRect(origin: CGPoint(x: 20, y: size.height - 20 - 40), size: CGSize(width: effectiveSecond, height: 40))
                btnRect = CGRect(origin: CGPoint(x: secondRect.maxX, y: size.height - 20 - 40), size: CGSize(width: frame.width - 40 - effectiveSecond - 10, height: 40))
            } else {
                secondRect = CGRect(origin: CGPoint(x: 20, y: size.height - 20 - 40), size: CGSize(width: btnwidth, height: 40))
                btnRect = CGRect(origin: CGPoint(x: secondRect.maxX + 10, y: size.height - 20 - 40), size: CGSize(width: btnwidth, height: 40))
            }
            ContainedViewLayoutTransition.immediate.updateFrame(view: button, frame: btnRect)
            ContainedViewLayoutTransition.immediate.updateFrame(view: second, frame: secondRect)

        } else {
            ContainedViewLayoutTransition.immediate.updateFrame(view: button, frame: CGRect(origin: CGPoint(x: 20, y: size.height - 20 - 40), size: CGSize(width: size.width - 40, height: 40)))
        }
        
        var y: CGFloat = 0
        for (i, view) in optionsView.subviews.enumerated() {
            let view = view as! OptionView
            let option = item.options[i]
            transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: 0, y: y), size: option.size))
            view.updateLayout(size: view.frame.size, transition: transition)
            y += view.frame.height
            y += 10
        }
        if let disclaimer = disclaimer {
            transition.updateFrame(view: disclaimer, frame: disclaimer.centerFrameX(y: button.frame.minY - 20 - disclaimer.frame.height))
        }
        if let descriptionView = descriptionView {
            let y = disclaimer?.frame.minY ?? button.frame.minY
            transition.updateFrame(view: descriptionView, frame: descriptionView.centerFrameX(y: y - 10 - descriptionView.frame.height))
        }
       
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    entries.append(.custom(sectionId: 0, index: 0, value: .none, identifier: .init("whole"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, presentation: arguments.presentation, state: state, toggle: arguments.toggle, action: arguments.action, secondAction: arguments.secondAction)
    }))
    
    return entries
}


struct ModalAlertData : Equatable {
    enum Mode : Equatable {
        case alert
        case confirm(text: String, isThird: Bool)
    }
    struct Description : Equatable {
        var string: String
        var onlyWhenEnabled: Bool
    }
    struct Option : Equatable {
        var string: String
        var isSelected: Bool
        var mandatory: Bool = false
        var uncheckEverything: Bool = false
    }
    var title: String?
    var info: String
    var description: Description? = nil
    var ok: String = strings().modalOK
    var options:[Option] = []
    var mode: Mode = .alert
    
    var disclaimer: String?
    
    var hasClose: Bool {
        switch mode {
        case .alert:
            return false
        case let .confirm(_, isThird):
            return isThird
        }
    }
}

struct ModalAlertResult : Equatable {
    var selected: [Int : Bool] = [:]
}

private func minimumSize(_ data: ModalAlertData) -> NSSize {
    let ok = NSAttributedString.initialize(string: data.ok, font: .medium(.text)).sizeFittingWidth(.greatestFiniteMagnitude).width + 40
    
    var cancel: CGFloat = 0
    if case let .confirm(text, _) = data.mode {
        cancel = max(NSAttributedString.initialize(string: text, font: .medium(.text)).sizeFittingWidth(.greatestFiniteMagnitude).width + 40, ok - 80)
    }
    
    var option_w: CGFloat = 0
    
    for option in data.options {
        let text = parseMarkdownIntoAttributedString(option.string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: .white), bold: MarkdownAttributeSet(font: .bold(.text), textColor: .white), link: MarkdownAttributeSet(font: .medium(.text), textColor: .white), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
        }))
        option_w = max(text.sizeFittingWidth(.greatestFiniteMagnitude).width, option_w)
    }
    
    var size: NSSize = NSMakeSize(260, 300)
    
    size.width = max(cancel + ok + 10 + 40, size.width)
    size.width = round(min(max(size.width, 350), max(option_w + 40 + 40, size.width)))
    
    return size
}

private func ModalAlertController(data: ModalAlertData, completion: @escaping(ModalAlertResult)->Void, cancel:@escaping()->Void = {}, presentation: TelegramPresentationTheme = theme) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: data)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(presentation: presentation, action: {
        let state = stateValue.with { $0 }
        if state.actionEnabled {
            var result:[Int : Bool] = [:]
            for (i, option) in state.data.options.enumerated() {
                result[i] = option.isSelected
            }
            completion(.init(selected: result))
            close?()
        } else {
            NSSound.beep()
        }
        
    }, toggle: { index in
        updateState { current in
            var current = current
            current.data.options[index].isSelected = !current.data.options[index].isSelected
            let option = current.data.options[index]
            if option.uncheckEverything, !option.isSelected {
                for i in 0 ..< current.data.options.count {
                    current.data.options[i].isSelected = false
                }
            }
            return current
        }
    }, secondAction: {
        close?()
        if case .confirm(_, true) = data.mode {
            completion(.init(selected: [0 : true]))
        } else {
            cancel()
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: data.title ?? "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    //!TODO CALC WIDTH SIZE

    
    
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size:  minimumSize(data), presentation: presentation)
    
    
    modalController.getModalTheme = {
        return .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: presentation.colors.grayBackground)
    }
    
    controller.validateData = { _ in
        arguments.action()
        return .none
    }
    
    controller.getBackgroundColor = {
        presentation.colors.listBackground
    }
    
    if data.hasClose {
        controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: {
            close?()
            cancel()
        })
    }
    
    
    modalController.closableImpl = {
        cancel()
        return true
    }
    
    controller.didLoad = { controller, _ in
        controller.tableView.verticalScrollElasticity = .none
    }

    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}



func showModalAlert(for window: Window, data: ModalAlertData, completion: @escaping(ModalAlertResult)->Void, cancel:@escaping()->Void = {}, presentation: TelegramPresentationTheme = theme) {
    showModal(with: ModalAlertController(data: data, completion: completion, cancel: cancel, presentation: presentation), for: window, animationType: .scaleCenter)
}

