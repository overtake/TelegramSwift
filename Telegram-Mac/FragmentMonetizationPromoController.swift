//
//  FragmentMonetizationPromo.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {

}


private final class RowItem : GeneralRowItem {
    
    struct Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        let width: CGFloat
        init(image: CGImage, header: TextViewLayout, text: TextViewLayout, width: CGFloat) {
            self.image = image
            self.header = header
            self.text = text
            self.width = width
            self.header.measure(width: width - 40)
            self.text.measure(width: width - 40)
        }
        var size: NSSize {
            return NSMakeSize(width, header.layoutSize.height + 5 + text.layoutSize.height)
        }
    }
    let context: AccountContext
    let headerLayout: TextViewLayout
    let infoLayout: TextViewLayout
    let infoHeaderLayout: TextViewLayout
    
    let options: [Option]

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext) {
        self.context = context
        
        let headerText = NSAttributedString.initialize(string: strings().monetizationIntroTitle, color: theme.colors.text, font: .medium(.title))
        
        let infoHeaderAttr = NSAttributedString.initialize(string: strings().monetizationIntroInfoTitle(clown), color: theme.colors.text, font: .medium(.title)).mutableCopy() as! NSMutableAttributedString
        infoHeaderAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: theme.colors.text), for: clown)
        
        
        let infoText = strings().monetizationIntroInfoText
        
        let infoAttr = parseMarkdownIntoAttributedString(infoText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.title), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { link in
                execute(inapp: .external(link: link, false))
            }))
        })).mutableCopy() as! NSMutableAttributedString
                                                                                            
                                                                                    
        self.headerLayout = .init(headerText, alignment: .center)
        self.headerLayout.measure(width: initialSize.width - 40)
        
        self.infoHeaderLayout = .init(infoHeaderAttr, alignment: .center)
        self.infoHeaderLayout.measure(width: initialSize.width - 80)

        self.infoLayout = .init(infoAttr, alignment: .center)
        self.infoLayout.measure(width: initialSize.width - 80)
        
        self.infoLayout.interactions = globalLinkExecutor
        
        var options:[Option] = []
        
        options.append(.init(image: NSImage(resource: .iconFragmentAds).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().monetizationIntroAdsTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().monetizationIntroAdsText, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        options.append(.init(image: NSImage(resource: .iconFragmentSplitRevenue).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().monetizationIntroSplitTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().monetizationIntroSplitText("%"), color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconFragmentTonPayment).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().monetizationIntroWithdrawalTitle, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().monetizationIntroWithdrawalText, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        self.options = options

        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 80
        height += 20
        height += headerLayout.layoutSize.height
        height += 20
        for option in options {
            height += option.size.height
            height += 20
        }
        //block
        height += 20
        height += infoHeaderLayout.layoutSize.height
        height += 10
        height += infoLayout.layoutSize.height
        height += 10
        
        return height
    }
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView: GeneralContainableRowView {
    
    final class OptionView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let infoView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(titleView)
            addSubview(infoView)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            infoView.userInteractionEnabled = false
            infoView.isSelectable = false
        }
        
        func update(option: RowItem.Option) {
            self.titleView.update(option.header)
            self.infoView.update(option.text)
            self.imageView.image = option.image
            self.imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            titleView.setFrameOrigin(NSMakePoint(40, 0))
            infoView.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
        }
 
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let iconView = View(frame: NSMakeRect(0, 0, 80, 80))
    private let gradient = SimpleGradientLayer()
    private let stickerView = ImageView()
    private let headerView = TextView()
    
    private let infoBlock = View()
    private let infoHeaderView = InteractiveTextView(frame: .zero)
    private let infoView = InteractiveTextView(frame: .zero)
    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(iconView)
        gradient.frame = iconView.bounds
        iconView.layer?.addSublayer(gradient)
        infoBlock.addSubview(infoHeaderView)
        infoBlock.addSubview(infoView)
        addSubview(infoBlock)
        iconView.addSubview(stickerView)
        
        addSubview(optionsView)
        
        headerView.isSelectable = false
        iconView.layer?.cornerRadius = iconView.frame.height / 2
        
        infoView.textView.userInteractionEnabled = true
        infoView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        iconView.centerX(y: 0)
        stickerView.center()
        headerView.centerX(y: stickerView.frame.maxY + 20)
        
        optionsView.centerX(y: headerView.frame.maxY + 20)

        infoBlock.centerX(y: optionsView.frame.maxY + 20)
        
        infoHeaderView.centerX(y: 10)
        infoView.centerX(y: infoHeaderView.frame.maxY + 10)
        
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 20
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? RowItem else {
            return
        }
        infoHeaderView.set(text: item.infoHeaderLayout, context: item.context)
        infoView.set(text: item.infoLayout, context: item.context)
        
        headerView.update(item.headerLayout)
        iconView.backgroundColor = theme.colors.accent
        
        self.gradient.colors = [theme.colors.accent].map { $0.cgColor }
        self.gradient.startPoint = CGPoint(x: 0.5, y: 0)
        self.gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.gradient.type = .radial

        stickerView.image = NSImage(resource: .iconFragmentMonetization).precomposed(.white)
        stickerView.sizeToFit()
        
        infoBlock.setFrameSize(NSMakeSize(frame.width - 40, 10 + infoHeaderView.frame.height + 10 + infoView.frame.height + 10))
        
        infoBlock.backgroundColor = theme.colors.listBackground
        infoBlock.layer?.cornerRadius = 10
        
        
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: .zero))
        }
        
        var optionsSize = NSMakeSize(0, 0)
        for (i, option) in item.options.enumerated() {
            let view = optionsView.subviews[i] as! OptionView
            view.update(option: option)
            view.setFrameSize(option.size)
            optionsSize = NSMakeSize(max(option.width, optionsSize.width), option.size.height + optionsSize.height)
            if i != item.options.count - 1 {
                optionsSize.height += 20
            }
        }
        
        optionsView.setFrameSize(optionsSize)
        
        
        needsLayout = true
    }
}


private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, stableId: stableId, context: arguments.context)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    return entries
}
func FragmentMonetizationPromoController(context: AccountContext, peerId: PeerId) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context)
    
    var close:(()->Void)? = nil
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().monetizationIntroUnderstood, accept: {
       close?()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, grayForeground: theme.colors.background, activeBackground: theme.colors.background, listBackground: theme.colors.background)
    })
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(340, 0))
    
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    return modalController
}
