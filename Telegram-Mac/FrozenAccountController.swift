
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class HeaderItem: GeneralRowItem {
    fileprivate let title: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let dismiss: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, dismiss: @escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.title = .init(.initialize(string: strings().freezeAccountTitle, color: theme.colors.text, font: .medium(.title)))
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 165
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class HeaderItemView : TableRowView {
    private let textView = TextView()
    private let dismiss = ImageButton()
    private let media = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 100, 100))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(media)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(dismiss)
        
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        textView.update(item.title)
        
        media.update(with: LocalAnimatedSticker.freeze_duck.file, size: media.frame.size, context: item.context, table: item.table, parameters: LocalAnimatedSticker.freeze_duck.parameters, animated: animated)
        
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.dismiss()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(10, 10))

        media.centerX(y: 20)
        textView.centerX(y: media.frame.maxY + 15)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
}


private final class OptionsItem : GeneralRowItem {
    
    class Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        var width: CGFloat
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
        
        func makeSize(width: CGFloat) {
            self.header.measure(width: width - 40)
            self.text.measure(width: width - 40)
            self.width = width
        }
    }
    let context: AccountContext
    
    let options: [Option]
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, appeal: @escaping()->Void) {
        self.context = context
        
        var options:[Option] = []
        
        let appealLink = context.appConfiguration.getStringValue("freeze_appeal_url", orElse: "https://t.me/spambot")
        let freezeTime = context.appConfiguration.getGeneralValue("freeze_since_date", orElse: 0)

        
        options.append(.init(image: NSImage(resource: .iconFreezeAccountOption1).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().freezeAccountOption1Title, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().freezeAccountOption1Text, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        options.append(.init(image: NSImage(resource: .iconFreezeAccountOption2).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().freezeAccountOption2Title, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().freezeAccountOption2Text, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        let option3Text = parseMarkdownIntoAttributedString(strings().freezeAccountOption3Text(stringForFullDate(timestamp: freezeTime)), attributes: .init(body: .init(font: .normal(.text), textColor: theme.colors.grayText), bold: .init(font: .medium(.text), textColor: theme.colors.grayText), link: .init(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { link in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(link, { value in
                appeal()
            }))
        }))
        
        let option3Layout = TextViewLayout(option3Text)
        option3Layout.interactions = globalLinkExecutor
        
        options.append(.init(image: NSImage(resource: .iconFreezeAccountOption3).precomposed(theme.colors.accent), header: .init(.initialize(string: strings().freezeAccountOption3Title, color: theme.colors.text, font: .medium(.text))), text: option3Layout, width: initialSize.width - 40))
        
        self.options = options

        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        for option in options {
            option.makeSize(width: width - 40)
        }
        
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += 15
        for option in options {
            height += option.size.height
            height += 15
        }
        return height
    }
    override func viewClass() -> AnyClass {
        return OptionsItemView.self
    }
}


private final class OptionsItemView: GeneralRowView {
    
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
            
//            infoView.userInteractionEnabled = false
//            infoView.isSelectable = false
        }
        
        func update(option: OptionsItem.Option) {
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
        
    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(optionsView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        optionsView.centerX(y: 15)
        
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 15
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? OptionsItem else {
            return
        }
        

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
                optionsSize.height += 15
            }
        }
        
        optionsView.setFrameSize(optionsSize)
        
        
        needsLayout = true
    }
}


private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let appeal:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void, appeal:@escaping()->Void) {
        self.dismiss = dismiss
        self.context = context
        self.appeal = appeal
    }
}

private struct State : Equatable {

}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
  
    // entries
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, dismiss: arguments.dismiss)
    }))
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("options"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return OptionsItem(initialSize, stableId: stableId, context: arguments.context, appeal: arguments.appeal)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FrozenAccountController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    let appealLink = context.appConfiguration.getStringValue("freeze_appeal_url", orElse: "https://t.me/spambot")

    
    let appeal:()->Void = {
        let link = inApp(for: appealLink.nsstring, context: context, openInfo: { peerId, _, _, action in
            let chatController = ChatController(context: context, chatLocation: .peer(peerId), initialAction: action)
            context.bindings.rootNavigation().push(chatController)
        })
        execute(inapp: link)
        close?()
    }

    let arguments = Arguments(context: context, dismiss: {
        close?()
    }, appeal: appeal)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().freezeAccountOK, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    controller.validateData = { _ in
        appeal()
        return .none
    }
    
    close = { [weak modalController] in
        modalController?.close()
    }

    
    return modalController
    
}


/*
 
 */



